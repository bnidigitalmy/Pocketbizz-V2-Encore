import { api, APIError } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import { OnProductionCreated } from "./events";
import {
  ConfirmProductionRequest,
  ConfirmProductionResponse,
  PlanPreviewRequest,
  PlanPreviewResponse,
} from "./types";
import {
  BatchConsumption,
  FINISHED_BATCHES_TABLE,
  IngredientUsageRecord,
  buildProductionPlan,
  consumeIngredientStock,
  ensurePositiveNumber,
  insertUsageRecords,
  recordInventoryMovements,
  sanitizeString,
} from "./utils";

interface MovementRow {
  batchId: string | null;
  productId: string;
  type: "in" | "out";
  quantity: number;
  note: string;
}

export const planPreview = api<PlanPreviewRequest, PlanPreviewResponse>(
  { method: "POST", path: "/production/plan-preview" },
  async ({ authorization, productId, quantity }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedProductId = sanitizeString(productId);
    if (!normalizedProductId) {
      throw APIError.invalidArgument("productId is required");
    }

    const planComputation = await buildProductionPlan(client, ownerId, normalizedProductId, quantity);

    return {
      success: true,
      data: planComputation.plan,
    };
  }
);

const buildMovementRows = (
  ingredientId: string,
  batches: BatchConsumption[],
  batchReference: string
): MovementRow[] =>
  batches.map((batch) => ({
    batchId: batch.batchId,
    productId: ingredientId,
    type: "out",
    quantity: batch.quantity,
    note: `production:${batchReference}`,
  }));

export const confirmProduction = api<ConfirmProductionRequest, ConfirmProductionResponse>(
  { method: "POST", path: "/production/confirm" },
  async ({ authorization, productId, quantity, batchDate, expiryDate, notes }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    const normalizedProductId = sanitizeString(productId);
    if (!normalizedProductId) {
      throw APIError.invalidArgument("productId is required");
    }

    const normalizedDate = sanitizeString(batchDate);
    if (!normalizedDate) {
      throw APIError.invalidArgument("batchDate is required");
    }

    const normalizedQuantity = ensurePositiveNumber(quantity, "quantity");

    const planComputation = await buildProductionPlan(
      client,
      ownerId,
      normalizedProductId,
      normalizedQuantity
    );
    const { plan } = planComputation;

    if (!plan.canProduce) {
      throw APIError.failedPrecondition("Insufficient stock. Please purchase materials first.");
    }

    const usageRecords: IngredientUsageRecord[] = [];
    const pendingBatchMovements: Array<{ ingredientId: string; batches: BatchConsumption[] }> = [];
    let totalCost = 0;

    for (const material of plan.materialsNeeded) {
      const { batches, totalCost: materialCost } = await consumeIngredientStock(
        client,
        ownerId,
        material.ingredientId,
        material.quantityNeeded
      );

      usageRecords.push({
        ingredientId: material.ingredientId,
        ingredientName: material.ingredientName,
        unit: material.usageUnit,
        quantity: material.quantityNeeded,
        cost: materialCost,
        batches,
      });

      totalCost += materialCost;
      pendingBatchMovements.push({ ingredientId: material.ingredientId, batches });
    }

    const totalUnits = plan.totalUnits;
    if (totalUnits <= 0) {
      throw APIError.failedPrecondition("Recipe yield must be greater than zero");
    }

    const roundedTotalCost = Number(totalCost.toFixed(4));
    const costPerUnit = Number((roundedTotalCost / totalUnits).toFixed(6));

    const { data: batchData, error: batchError } = await client
      .from(FINISHED_BATCHES_TABLE)
      .insert({
        business_owner_id: ownerId,
        product_id: normalizedProductId,
        recipe_id: planComputation.recipe.id,
        quantity: totalUnits,
        available_quantity: totalUnits,
        total_cost: roundedTotalCost,
        cost_per_unit: costPerUnit,
        production_date: normalizedDate,
        expiry_date: sanitizeString(expiryDate) ?? null,
        notes: sanitizeString(notes) ?? null,
      })
      .select("id, product_id")
      .single();

    if (batchError) {
      throw APIError.internal(batchError.message);
    }

    const batchId = (batchData as { id: string }).id;

    await insertUsageRecords(client, ownerId, batchId, usageRecords);

    const movementRows: MovementRow[] = pendingBatchMovements.flatMap((entry) =>
      buildMovementRows(entry.ingredientId, entry.batches, batchId)
    );
    movementRows.push({
      batchId: null,
      productId: normalizedProductId,
      type: "in",
      quantity: totalUnits,
      note: `production:${batchId}`,
    });
    await recordInventoryMovements(client, ownerId, movementRows);

    await OnProductionCreated.publish({
      businessOwnerId: ownerId,
      productionBatchId: batchId,
    });

    return {
      success: true,
      data: {
        status: "success",
        batchId,
        totalCost: roundedTotalCost,
        costPerUnit,
        totalUnits,
      },
    };
  }
);

import { api, APIError } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import {
  ApprovePORequest,
  ApprovePOResponse,
  CreateGRNRequest,
  CreateGRNResponse,
  CreatePORequest,
  GoodsReceivedNote,
  GetPORequest,
  GRNPrintRequest,
  GRNPrintResponse,
  ListGRNResponse,
  ListPORequest,
  ListPOResponse,
  PurchaseOrder,
  PurchaseOrderResponse,
  ReceiveGRNRequest,
  ReceiveGRNResponse,
} from "./types";
import {
  OnGRNCreated,
  OnPOApproved,
  OnPOCreated,
} from "./events";
import {
  buildGRNThermalPayload,
  buildPOThermalPayload,
} from "./print";
import {
  PURCHASE_ORDERS_TABLE,
  PURCHASE_ORDER_ITEMS_TABLE,
  GRN_TABLE,
  GRN_ITEMS_TABLE,
  computePOTotals,
  createInventoryBatchFromGRNItem,
  ensureVendorOwnership,
  fetchGRNById,
  fetchPurchaseOrderById,
  generateReference,
  insertPOLog,
  mapGRN,
  mapPurchaseOrder,
  mergeShoppingItemsIntoPO,
  sanitizeString,
  updatePOStatusFromItems,
} from "./utils";

const encodePayload = (payload: unknown): string =>
  Buffer.from(JSON.stringify(payload), "utf8").toString("base64");

const normalizePOItems = (items: CreatePORequest["po"]["items"]) => {
  if (!Array.isArray(items) || !items.length) {
    throw APIError.invalidArgument("PO must contain at least one item");
  }
  return items.map((item, index) => {
    if (!item.ingredient_id && !item.product_id) {
      throw APIError.invalidArgument(`items[${index}] must include ingredient_id or product_id`);
    }
    const qtyOrdered = Number(item.qty_ordered);
    const unit = sanitizeString(item.unit);
    if (!unit) {
      throw APIError.invalidArgument(`items[${index}].unit is required`);
    }
    if (!Number.isFinite(qtyOrdered) || qtyOrdered <= 0) {
      throw APIError.invalidArgument(`items[${index}].qty_ordered must be greater than zero`);
    }
    return {
      ...item,
      qty_ordered: qtyOrdered,
      unit,
      unit_price: Number(item.unit_price ?? 0),
      description: sanitizeString(item.description) ?? null,
    };
  });
};

const normalizeGRNItems = (items: CreateGRNRequest["grn"]["items"]) => {
  if (!Array.isArray(items) || !items.length) {
    throw APIError.invalidArgument("GRN must contain at least one item");
  }
  return items.map((item, index) => {
    if (!item.ingredient_id && !item.product_id && !item.po_item_id) {
      throw APIError.invalidArgument(
        `grn.items[${index}] must include ingredient_id, product_id, or po_item_id`
      );
    }
    const qtyReceived = Number(item.qty_received);
    if (!Number.isFinite(qtyReceived) || qtyReceived <= 0) {
      throw APIError.invalidArgument(`grn.items[${index}].qty_received must be greater than zero`);
    }
    const unit = sanitizeString(item.unit);
    if (!unit) {
      throw APIError.invalidArgument(`grn.items[${index}].unit is required`);
    }
    return {
      ...item,
      qty_received: qtyReceived,
      unit,
      unit_price: Number(item.unit_price ?? 0),
      description: sanitizeString(item.description) ?? null,
    };
  });
};

export const createPurchaseOrder = api<CreatePORequest, PurchaseOrderResponse>(
  { method: "POST", path: "/purchase/po/create" },
  async ({ authorization, po }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    const vendorId = sanitizeString(po.vendor_id);
    if (!vendorId) {
      throw APIError.invalidArgument("vendor_id is required");
    }

    const vendor = await ensureVendorOwnership(client, ownerId, vendorId);
    const normalizedItems = normalizePOItems(po.items);
    const totals = computePOTotals(normalizedItems);
    const reference = generateReference("PO");

    const { data: poData, error: poError } = await client
      .from(PURCHASE_ORDERS_TABLE)
      .insert({
        business_owner_id: ownerId,
        vendor_id: vendorId,
        reference,
        status: "draft",
        currency: sanitizeString(po.currency) ?? "MYR",
        total_value: totals.total_value,
        notes: sanitizeString(po.notes) ?? null,
      })
      .select("*")
      .single();

    if (poError) {
      throw APIError.internal(poError.message);
    }

    const itemsPayload = normalizedItems.map((item) => ({
      po_id: (poData as { id: string }).id,
      ingredient_id: item.ingredient_id ?? null,
      product_id: item.product_id ?? null,
      description: item.description,
      qty_ordered: item.qty_ordered,
      qty_received: 0,
      unit: item.unit,
      unit_price: item.unit_price,
      total_price: Number((item.qty_ordered * item.unit_price).toFixed(4)),
    }));

    const { error: itemsError } = await client.from(PURCHASE_ORDER_ITEMS_TABLE).insert(itemsPayload);
    if (itemsError) {
      throw APIError.internal(itemsError.message);
    }

    if (po.linked_shopping_item_ids?.length) {
      await mergeShoppingItemsIntoPO(client, ownerId, po.linked_shopping_item_ids, (poData as any).id);
      // TODO: maintain dedicated linked_po_id column for better traceability.
    }

    const { order, items } = await fetchPurchaseOrderById(client, ownerId, (poData as any).id);
    const responsePO = mapPurchaseOrder(order, items, vendor);

    await OnPOCreated.publish({
      po_id: responsePO.id,
      business_owner_id: ownerId,
    });

    return { success: true, data: { purchaseOrder: responsePO } };
  }
);

export const getPurchaseOrder = api<GetPORequest, PurchaseOrderResponse>(
  { method: "GET", path: "/purchase/po/:id" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const poId = sanitizeString(id);
    if (!poId) {
      throw APIError.invalidArgument("id is required");
    }
    const { order, items, vendor } = await fetchPurchaseOrderById(client, ownerId, poId);
    return { success: true, data: { purchaseOrder: mapPurchaseOrder(order, items, vendor) } };
  }
);

export const listPurchaseOrders = api<ListPORequest, ListPOResponse>(
  { method: "GET", path: "/purchase/po/list" },
  async ({ authorization, status }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    let query = client.from(PURCHASE_ORDERS_TABLE).select("*").eq("business_owner_id", ownerId);
    if (status) {
      query = query.eq("status", status);
    }
    const { data, error } = await query.order("created_at", { ascending: false });
    if (error) {
      throw APIError.internal(error.message);
    }
    const results: PurchaseOrder[] = [];
    for (const row of data ?? []) {
      const { order, items, vendor } = await fetchPurchaseOrderById(client, ownerId, row.id);
      results.push(mapPurchaseOrder(order, items, vendor));
    }
    return { success: true, data: { purchaseOrders: results } };
  }
);

export const approvePurchaseOrder = api<ApprovePORequest, ApprovePOResponse>(
  { method: "POST", path: "/purchase/po/:id/approve" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const poId = sanitizeString(id);
    if (!poId) {
      throw APIError.invalidArgument("id is required");
    }

    const timestamp = new Date().toISOString();
    const { error: updateError } = await client
      .from(PURCHASE_ORDERS_TABLE)
      .update({ status: "sent", updated_at: timestamp })
      .eq("business_owner_id", ownerId)
      .eq("id", poId);

    if (updateError) {
      throw APIError.internal(updateError.message);
    }

    const { order, items, vendor } = await fetchPurchaseOrderById(client, ownerId, poId);
    const purchaseOrder = mapPurchaseOrder(order, items, vendor);

    const payload = buildPOThermalPayload(
      purchaseOrder,
      purchaseOrder.items,
      purchaseOrder.vendor ?? { id: purchaseOrder.vendorId, name: "Vendor" }
    );

    await OnPOApproved.publish({ po_id: purchaseOrder.id, business_owner_id: ownerId });

    return {
      success: true,
      data: {
        purchaseOrder,
        thermalPayload: encodePayload(payload),
      },
    };
  }
);

export const createGRN = api<CreateGRNRequest, CreateGRNResponse>(
  { method: "POST", path: "/purchase/grn/create" },
  async ({ authorization, grn }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedItems = normalizeGRNItems(grn.items);
    const reference = generateReference("GRN");

    let associatedPO: PurchaseOrder | undefined;
    if (grn.po_id) {
      const poDetails = await fetchPurchaseOrderById(client, ownerId, grn.po_id);
      associatedPO = mapPurchaseOrder(poDetails.order, poDetails.items, poDetails.vendor);
    }

    const { data: grnRow, error: grnError } = await client
      .from(GRN_TABLE)
      .insert({
        business_owner_id: ownerId,
        po_id: grn.po_id ?? null,
        reference,
        status: "pending",
        total_received_value: 0,
        notes: sanitizeString(grn.notes) ?? null,
      })
      .select("*")
      .single();

    if (grnError) {
      throw APIError.internal(grnError.message);
    }

    const grnId = (grnRow as { id: string }).id;

    let totalValue = 0;
    const itemPayload = normalizedItems.map((item) => {
      const lineTotal = Number((item.qty_received * item.unit_price).toFixed(4));
      totalValue += lineTotal;
      return {
        grn_id: grnId,
        po_item_id: item.po_item_id ?? null,
        ingredient_id: item.ingredient_id ?? null,
        product_id: item.product_id ?? null,
        qty_received: item.qty_received,
        unit: item.unit,
        unit_price: item.unit_price,
        total_price: lineTotal,
        description: item.description ?? null,
      };
    });

    const { error: grnItemsError } = await client.from(GRN_ITEMS_TABLE).insert(itemPayload);
    if (grnItemsError) {
      throw APIError.internal(grnItemsError.message);
    }

    if (grn.po_id) {
      for (const item of normalizedItems) {
        if (!item.po_item_id) continue;
        const { data: existing, error: fetchExistingError } = await client
          .from(PURCHASE_ORDER_ITEMS_TABLE)
          .select("qty_received")
          .eq("id", item.po_item_id)
          .maybeSingle();
        if (fetchExistingError) {
          throw APIError.internal(fetchExistingError.message);
        }
        const current = Number(existing?.qty_received ?? 0);
        const updatedQty = Number((current + item.qty_received).toFixed(4));
        const { error: secondUpdate } = await client
          .from(PURCHASE_ORDER_ITEMS_TABLE)
          .update({ qty_received: updatedQty })
          .eq("id", item.po_item_id);
        if (secondUpdate) {
          throw APIError.internal(secondUpdate.message);
        }
      }

      await updatePOStatusFromItems(client, ownerId, grn.po_id);
    }

    const { error: updateTotalError } = await client
      .from(GRN_TABLE)
      .update({
        total_received_value: Number(totalValue.toFixed(2)),
        updated_at: new Date().toISOString(),
      })
      .eq("id", grnId);

    if (updateTotalError) {
      throw APIError.internal(updateTotalError.message);
    }

    await insertPOLog(client, ownerId, "grn", grnId, "grn_created", {
      po_id: grn.po_id,
      items: normalizedItems.length,
    });

    const { grn: grnRowFetched, items } = await fetchGRNById(client, ownerId, grnId);
    const responseGRN = mapGRN(grnRowFetched, items);

    await OnGRNCreated.publish({
      grn_id: grnId,
      business_owner_id: ownerId,
    });

    return { success: true, data: { grn: responseGRN } };
  }
);

export const receiveGRN = api<ReceiveGRNRequest, ReceiveGRNResponse>(
  { method: "POST", path: "/purchase/grn/:id/receive" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const grnId = sanitizeString(id);
    if (!grnId) {
      throw APIError.invalidArgument("id is required");
    }
    const {
      grn: grnRow,
      items,
    } = await fetchGRNById(client, ownerId, grnId);

    if (grnRow.status === "completed") {
      throw APIError.failedPrecondition("GRN already completed");
    }

    const inventoryResults = [];
    for (const item of items) {
      const result = await createInventoryBatchFromGRNItem(client, ownerId, {
        ingredient_id: item.ingredient_id ?? undefined,
        product_id: item.product_id ?? undefined,
        qty_received: item.qty_received,
        unit: item.unit,
        unit_price: item.unit_price,
      });
      inventoryResults.push(result);
    }

    const { error: grnUpdateError } = await client
      .from(GRN_TABLE)
      .update({ status: "completed", updated_at: new Date().toISOString() })
      .eq("id", grnId);

    if (grnUpdateError) {
      throw APIError.internal(grnUpdateError.message);
    }

    if (grnRow.po_id) {
      await updatePOStatusFromItems(client, ownerId, grnRow.po_id);
      // TODO: mark linked shopping list rows as purchased when schema includes linked_po_id.
    }

    const responseGRN: GoodsReceivedNote = mapGRN(grnRow, items);
    return {
      success: true,
      data: {
        grn: responseGRN,
        inventoryBatches: inventoryResults,
      },
    };
  }
);

export const printGRN = api<GRNPrintRequest, GRNPrintResponse>(
  { method: "GET", path: "/purchase/grn/:id/print" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const grnId = sanitizeString(id);
    if (!grnId) {
      throw APIError.invalidArgument("id is required");
    }

    const { grn, items } = await fetchGRNById(client, ownerId, grnId);
    const mappedGRN = mapGRN(grn, items);

    let purchaseOrder: PurchaseOrder | null = null;
    if (grn.po_id) {
      const { order, items: poItems, vendor } = await fetchPurchaseOrderById(
        client,
        ownerId,
        grn.po_id
      );
      purchaseOrder = mapPurchaseOrder(order, poItems, vendor);
    }

    const payload = buildGRNThermalPayload(mappedGRN, mappedGRN.items, purchaseOrder ?? undefined);
    return { success: true, data: { thermalPayload: encodePayload(payload) } };
  }
);


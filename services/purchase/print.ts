import type { GoodsReceivedNote, GoodsReceivedItem, PurchaseOrder, PurchaseOrderItem } from "./types";

export const buildPOThermalPayload = (
  po: PurchaseOrder,
  items: PurchaseOrderItem[],
  vendor: { id: string; name: string; phone?: string | null }
) => ({
  type: "purchase_order",
  reference: po.reference,
  vendor: {
    id: vendor.id,
    name: vendor.name,
    phone: vendor.phone ?? null,
  },
  created_at: po.createdAt,
  items: items.map((item) => ({
    name: item.description ?? "Item",
    qty: item.qtyOrdered,
    unit: item.unit,
    unit_price: item.unitPrice,
    total_price: item.totalPrice,
  })),
  totals: {
    total_value: po.totalValue,
  },
});

export const buildGRNThermalPayload = (
  grn: GoodsReceivedNote,
  items: GoodsReceivedItem[],
  po?: PurchaseOrder | null
) => ({
  type: "grn",
  reference: grn.reference,
  po_reference: po?.reference ?? null,
  created_at: grn.createdAt,
  items: items.map((item) => ({
    name: item.description ?? "Item",
    qty: item.qtyReceived,
    unit: item.unit,
    unit_price: item.unitPrice,
    total_price: item.totalPrice,
  })),
  totals: {
    total_received_value: grn.totalReceivedValue,
  },
});


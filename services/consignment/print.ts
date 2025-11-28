import type {
  ConsignmentClaim,
  ConsignmentItemDetail,
  ConsignmentSessionDetail,
} from "./types";

interface InvoiceDocumentPayload {
  session: {
    id: string;
    reference: string;
    status: string;
    note?: string;
    totals: ConsignmentSessionDetail["metrics"];
  };
  vendor: {
    id: string;
    name: string;
    type?: string;
    contact?: ConsignmentSessionDetail["vendor"]["contact"];
  };
  items: Array<
    Pick<
      ConsignmentItemDetail,
      | "productId"
      | "qtySent"
      | "qtySold"
      | "qtyReturned"
      | "listPrice"
      | "unitPrice"
      | "commissionType"
      | "commissionRate"
      | "commissionAmount"
    > & { total: number }
  >;
}

interface ClaimDocumentPayload {
  claim: ConsignmentClaim;
  session: {
    id: string;
    reference: string;
  };
}

const encodeDocument = <T>(type: string, payload: T): Buffer =>
  Buffer.from(
    JSON.stringify({
      type,
      version: 1,
      generatedAt: new Date().toISOString(),
      payload,
    })
  );

export const buildInvoiceForThermal = (
  detail: ConsignmentSessionDetail
): Buffer => {
  const payload: InvoiceDocumentPayload = {
    session: {
      id: detail.id,
      reference: detail.reference,
      status: detail.status,
      note: detail.note,
      totals: detail.metrics,
    },
    vendor: detail.vendor,
    items: detail.items.map((item) => ({
      productId: item.productId,
      qtySent: item.qtySent,
      qtySold: item.qtySold,
      qtyReturned: item.qtyReturned,
      listPrice: item.listPrice,
      unitPrice: item.unitPrice,
      commissionType: item.commissionType,
      commissionRate: item.commissionRate,
      commissionAmount: item.commissionAmount,
      total: item.unitPrice * item.qtySent,
    })),
  };

  return encodeDocument("consignment_invoice", payload);
};

export const buildClaimForThermal = (
  detail: ConsignmentSessionDetail,
  claim: ConsignmentClaim
): Buffer => {
  const payload: ClaimDocumentPayload = {
    claim,
    session: {
      id: detail.id,
      reference: detail.reference,
    },
  };

  return encodeDocument("consignment_claim", payload);
};


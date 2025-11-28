import { Vendor } from "../../pkg/types";

export const normalizeVendorPayload = (vendor: Vendor) => ({
  ...vendor,
  type: vendor.type ?? "supplier",
});


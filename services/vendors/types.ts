import { Vendor } from "../../pkg/types";

export interface UpsertVendorRequest {
  vendor: Vendor;
}

export interface VendorResponse {
  vendor?: Vendor;
}

export interface VendorListResponse {
  vendors: Vendor[];
}


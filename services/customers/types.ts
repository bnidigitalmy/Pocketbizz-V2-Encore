import { Customer, Order } from "../../pkg/types";

export interface UpsertCustomerRequest {
  customer: Customer;
}

export interface CustomerResponse {
  customer?: Customer;
}

export interface CustomerListResponse {
  customers: Customer[];
}

export interface OrderNotificationPayload {
  order: Order;
  customer?: Customer;
}


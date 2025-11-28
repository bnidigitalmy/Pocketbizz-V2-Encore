import { Order } from "../../pkg/types";

export interface CreateOrderRequest {
  order: Order;
}

export interface OrderResponse {
  order?: Order;
}

export interface OrderListResponse {
  orders: Order[];
}

export interface OrderCreatedEvent {
  orderId: string;
  customerId?: string;
  total: number;
}


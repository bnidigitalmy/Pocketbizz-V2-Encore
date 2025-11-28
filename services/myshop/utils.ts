import { Order } from "../../pkg/types";

export const generateOrderReference = (order: Order): string =>
  order.reference || `MYSHOP-${Date.now()}`;


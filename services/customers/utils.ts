import { Customer } from "../../pkg/types";

export const anonymizeCustomer = (customer: Customer): Partial<Customer> => ({
  id: customer.id,
  name: customer.name,
  loyaltyTier: customer.loyaltyTier,
});


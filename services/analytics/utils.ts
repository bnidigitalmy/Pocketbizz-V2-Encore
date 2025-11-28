export const formatCurrency = (value: number, currency = "MYR") =>
  new Intl.NumberFormat("en-MY", {
    style: "currency",
    currency,
  }).format(value);


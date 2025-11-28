import { Header } from "encore.dev/api";

import { Product } from "../../pkg/types";

export interface ProductCreate {
  sku: string;
  name: string;
  description?: string;
  category?: string;
  unit: string;
  costPrice: number;
  salePrice: number;
  isActive?: boolean;
}

export interface ProductUpdate extends Partial<ProductCreate> {
  id: string;
}

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface AddProductRequest extends AuthorizedRequest {
  product: ProductCreate;
}

export interface ListProductsRequest extends AuthorizedRequest {}

export interface GetProductRequest extends AuthorizedRequest {
  id: string;
}

export interface UpdateProductRequest extends AuthorizedRequest {
  product: ProductUpdate;
}

export interface DeleteProductRequest extends AuthorizedRequest {
  productId: string;
}

export interface ProductListResponse {
  products: Product[];
}

export interface ProductResponse {
  product: Product;
}

export interface DeleteProductResponse {
  success: true;
}
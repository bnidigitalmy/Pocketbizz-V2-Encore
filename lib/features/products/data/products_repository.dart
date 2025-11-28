import '../../../data/api/api.dart';

class ProductsRepository {
  ProductsRepository(this._api);

  final ProductsApi _api;

  Future<List<Product>> fetchProducts() => _api.listProducts();

  Future<Product> getProduct(String id) => _api.getProduct(id);

  Future<Product> createProduct(ProductCreate request) =>
      _api.addProduct(request);

  Future<Product> updateProduct(ProductUpdate request) =>
      _api.updateProduct(request);

  Future<void> deleteProduct(String id) => _api.deleteProduct(id);
}


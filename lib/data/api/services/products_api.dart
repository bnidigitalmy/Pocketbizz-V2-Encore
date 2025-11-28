import '../api_client.dart';
import '../models/product_models.dart';

class ProductsApi {
  ProductsApi(this._client);

  final ApiClient _client;

  Future<Product> addProduct(ProductCreate request) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/products/add',
      body: {'product': request.toJson()},
    );
    return Product.fromJson(response['product'] as Map<String, dynamic>);
  }

  Future<List<Product>> listProducts() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/products/list',
    );
    final products = response['products'] as List<dynamic>? ?? [];
    return products
        .map((json) => Product.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Product> getProduct(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/products/$id',
    );
    return Product.fromJson(response['product'] as Map<String, dynamic>);
  }

  Future<Product> updateProduct(ProductUpdate request) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/products/update',
      body: {'product': request.toJson()},
    );
    return Product.fromJson(response['product'] as Map<String, dynamic>);
  }

  Future<void> deleteProduct(String id) async {
    await _client.delete(
      '/products/delete',
      body: {'productId': id},
    );
  }
}


import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api.dart';
import '../../../data/api/api_providers.dart';
import '../data/products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepository(ref.watch(productsApiProvider)),
);

final productsListControllerProvider =
    StateNotifierProvider<ProductsListController, ProductsListState>(
  (ref) => ProductsListController(ref.watch(productsRepositoryProvider))..load(),
);

final productDetailControllerProvider = FutureProvider.family<Product, String>(
  (ref, id) => ref.watch(productsRepositoryProvider).getProduct(id),
);

class ProductsListController extends StateNotifier<ProductsListState> {
  ProductsListController(this._repository)
      : super(const ProductsListState.loading());

  final ProductsRepository _repository;

  Future<void> load() async {
    try {
      final products = await _repository.fetchProducts();
      state = ProductsListState.data(products);
    } on Object catch (error) {
      state = ProductsListState.error(error.toString());
    }
  }

  Future<void> deleteProduct(String id) async {
    await _repository.deleteProduct(id);
    await load();
  }
}

class ProductsListState {
  const ProductsListState._({
    required this.isLoading,
    this.products,
    this.error,
  });

  const ProductsListState.loading() : this._(isLoading: true);

  const ProductsListState.data(List<Product> products)
      : this._(isLoading: false, products: products);

  const ProductsListState.error(String error)
      : this._(isLoading: false, error: error);

  final bool isLoading;
  final List<Product>? products;
  final String? error;
}


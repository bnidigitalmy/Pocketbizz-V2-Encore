import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_providers.dart';
import 'data/products_repository.dart';
import 'presentation/products_controller.dart';

final productsModuleRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepository(ref.watch(productsApiProvider)),
);

final productsModuleListControllerProvider =
    StateNotifierProvider<ProductsListController, ProductsListState>(
  (ref) => ProductsListController(ref.watch(productsModuleRepositoryProvider))
    ..load(),
);

final productsModuleDetailProvider = FutureProvider.family.autoDispose(
  (ref, String id) =>
      ref.watch(productsModuleRepositoryProvider).getProduct(id),
);


import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

const _defaultBaseUrl =
    String.fromEnvironment('POCKETBIZZ_API_BASE_URL', defaultValue: 'http://localhost:4000');

final apiConfigProvider = Provider<ApiConfig>(
  (ref) => ApiConfig(baseUrl: _defaultBaseUrl),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(config: ref.watch(apiConfigProvider)),
);

final productsApiProvider = Provider<ProductsApi>(
  (ref) => ProductsApi(ref.watch(apiClientProvider)),
);

final inventoryApiProvider = Provider<InventoryApi>(
  (ref) => InventoryApi(ref.watch(apiClientProvider)),
);

final salesApiProvider = Provider<SalesApi>(
  (ref) => SalesApi(ref.watch(apiClientProvider)),
);

final expensesApiProvider = Provider<ExpensesApi>(
  (ref) => ExpensesApi(ref.watch(apiClientProvider)),
);


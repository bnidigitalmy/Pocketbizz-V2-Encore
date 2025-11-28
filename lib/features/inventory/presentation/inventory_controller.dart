import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api.dart';
import '../../../data/api/api_providers.dart';
import '../data/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(inventoryApiProvider)),
);

final inventoryListControllerProvider =
    StateNotifierProvider<InventoryListController, InventoryListState>(
  (ref) => InventoryListController(ref.watch(inventoryRepositoryProvider))
    ..load(),
);

final lowStockProvider = FutureProvider<List<InventorySnapshot>>(
  (ref) => ref.watch(inventoryRepositoryProvider).lowStock(),
);

class InventoryListController extends StateNotifier<InventoryListState> {
  InventoryListController(this._repository)
      : super(const InventoryListState.loading());

  final InventoryRepository _repository;

  Future<void> load() async {
    try {
      final batches = await _repository.fetchBatches();
      state = InventoryListState.data(batches);
    } on Object catch (error) {
      state = InventoryListState.error(error.toString());
    }
  }

  Future<void> addBatch(BatchCreateRequest request) async {
    await _repository.addBatch(request);
    await load();
  }
}

class InventoryListState {
  const InventoryListState._({
    required this.isLoading,
    this.batches,
    this.error,
  });

  const InventoryListState.loading() : this._(isLoading: true);

  const InventoryListState.data(List<InventoryBatch> batches)
      : this._(isLoading: false, batches: batches);

  const InventoryListState.error(String error)
      : this._(isLoading: false, error: error);

  final bool isLoading;
  final List<InventoryBatch>? batches;
  final String? error;
}


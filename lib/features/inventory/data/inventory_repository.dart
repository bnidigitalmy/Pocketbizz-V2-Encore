import '../../../data/api/api.dart';

class InventoryRepository {
  InventoryRepository(this._api);

  final InventoryApi _api;

  Future<List<InventoryBatch>> fetchBatches() => _api.listInventory();

  Future<InventoryBatch> addBatch(BatchCreateRequest request) =>
      _api.addBatch(request);

  Future<Map<String, dynamic>> consumeInventory(
    InventoryConsumeRequest request,
  ) =>
      _api.consumeInventory(request);

  Future<List<InventorySnapshot>> lowStock() => _api.getLowStock();
}


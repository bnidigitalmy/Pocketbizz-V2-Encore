import '../api_client.dart';
import '../models/inventory_models.dart';

class InventoryApi {
  InventoryApi(this._client);

  final ApiClient _client;

  Future<InventoryBatch> addBatch(BatchCreateRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/inventory/batch/add',
      body: {'batch': request.toJson()},
    );
    return InventoryBatch.fromJson(response['batch'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> consumeInventory(
    InventoryConsumeRequest request,
  ) async {
    return _client.post<Map<String, dynamic>>(
      '/inventory/consume',
      body: request.toJson(),
    );
  }

  Future<List<InventoryBatch>> listInventory() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/inventory/list',
    );
    final batches = response['batches'] as List<dynamic>? ?? [];
    return batches
        .map((json) => InventoryBatch.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<InventoryBatch> getBatch(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/inventory/$id',
    );
    return InventoryBatch.fromJson(response['batch'] as Map<String, dynamic>);
  }

  Future<List<InventorySnapshot>> getLowStock() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/inventory/low-stock',
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((json) => InventorySnapshot.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}


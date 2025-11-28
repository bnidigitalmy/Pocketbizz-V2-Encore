import '../api_client.dart';
import '../models/sales_models.dart';

class SalesApi {
  SalesApi(this._client);

  final ApiClient _client;

  Future<Sale> createSale(SaleCreateRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/sales/create',
      body: {'sale': request.toJson()},
    );
    return Sale.fromJson(response['sale'] as Map<String, dynamic>);
  }

  Future<List<Sale>> listSales() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/sales/list',
    );
    final sales = response['sales'] as List<dynamic>? ?? [];
    return sales
        .map((json) => Sale.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Sale> getSale(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/sales/$id',
    );
    return Sale.fromJson(response['sale'] as Map<String, dynamic>);
  }

  Future<List<SalesSummaryEntry>> getDailySummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/sales/daily',
    );
    final entries = response['entries'] as List<dynamic>? ?? [];
    return entries
        .map(
          (json) => SalesSummaryEntry.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<SalesSummaryEntry>> getMonthlySummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/sales/monthly',
    );
    final entries = response['entries'] as List<dynamic>? ?? [];
    return entries
        .map(
          (json) => SalesSummaryEntry.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }
}


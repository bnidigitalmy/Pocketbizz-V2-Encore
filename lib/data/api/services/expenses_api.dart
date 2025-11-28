import '../api_client.dart';
import '../models/expenses_models.dart';

class ExpensesApi {
  ExpensesApi(this._client);

  final ApiClient _client;

  Future<Expense> addExpense(Expense expense) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/expenses/add',
      body: {
        'expense': {
          'id': expense.id,
          'category': expense.category,
          'amount': expense.amount,
          'currency': expense.currency,
          'expenseDate': expense.expenseDate.toIso8601String(),
          'notes': expense.notes,
          'vendorId': expense.vendorId,
          'ocrReceiptId': expense.ocrReceiptId,
        }
      },
    );
    return Expense.fromJson(response['expense'] as Map<String, dynamic>);
  }

  Future<String> uploadReceipt(ExpenseUploadRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/expenses/upload-receipt',
      body: request.toJson(),
    );
    return response['receiptId'] as String;
  }

  Future<List<Expense>> listExpenses() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/expenses/list',
    );
    final expenses = response['expenses'] as List<dynamic>? ?? [];
    return expenses
        .map((json) => Expense.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}


class Expense {
  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.currency,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.vendorId,
    this.ocrReceiptId,
  });

  final String id;
  final String category;
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final String? vendorId;
  final String? ocrReceiptId;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        expenseDate: DateTime.parse(json['expenseDate'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        notes: json['notes'] as String?,
        vendorId: json['vendorId'] as String?,
        ocrReceiptId: json['ocrReceiptId'] as String?,
      );
}

class ExpenseUploadRequest {
  ExpenseUploadRequest({
    required this.fileName,
    required this.data,
    this.ownerId,
    this.contentType,
  });

  final String? ownerId;
  final String fileName;
  final String data; // base64
  final String? contentType;

  Map<String, dynamic> toJson() => {
        'ownerId': ownerId,
        'fileName': fileName,
        'data': data,
        'contentType': contentType,
      }..removeWhere((_, value) => value == null);
}


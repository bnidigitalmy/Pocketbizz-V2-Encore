class Sale {
  Sale({
    required this.id,
    required this.channel,
    required this.status,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    this.customerId,
    this.cogs,
    this.profit,
  });

  final String id;
  final String? customerId;
  final String channel;
  final String status;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final double? cogs;
  final double? profit;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        customerId: json['customerId'] as String?,
        channel: json['channel'] as String,
        status: json['status'] as String,
        subtotal: (json['subtotal'] as num).toDouble(),
        tax: (json['tax'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        cogs: (json['cogs'] as num?)?.toDouble(),
        profit: (json['profit'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class SaleLineItem {
  SaleLineItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.costOfGoods,
  });

  final String productId;
  final double quantity;
  final double unitPrice;
  final double? costOfGoods;

  factory SaleLineItem.fromJson(Map<String, dynamic> json) => SaleLineItem(
        productId: json['productId'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        costOfGoods: (json['costOfGoods'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'costOfGoods': costOfGoods,
      };
}

class SaleCreateRequest {
  SaleCreateRequest({
    required this.channel,
    required this.lineItems,
    this.customerId,
    this.status,
    this.tax,
    this.discount,
    this.occurredAt,
  });

  final String channel;
  final List<SaleLineItem> lineItems;
  final String? customerId;
  final String? status;
  final double? tax;
  final double? discount;
  final DateTime? occurredAt;

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'customerId': customerId,
        'status': status,
        'tax': tax,
        'discount': discount,
        'occurredAt': occurredAt?.toIso8601String(),
        'lineItems': lineItems.map((item) => item.toJson()).toList(),
      }..removeWhere((_, value) => value == null);
}

class SalesSummaryEntry {
  SalesSummaryEntry({
    required this.period,
    required this.total,
    required this.cogs,
    required this.profit,
  });

  final String period;
  final double total;
  final double cogs;
  final double profit;

  factory SalesSummaryEntry.fromJson(Map<String, dynamic> json) =>
      SalesSummaryEntry(
        period: json['period'] as String,
        total: (json['total'] as num).toDouble(),
        cogs: (json['cogs'] as num).toDouble(),
        profit: (json['profit'] as num).toDouble(),
      );
}


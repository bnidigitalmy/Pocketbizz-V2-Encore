class InventoryBatch {
  InventoryBatch({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.availableQuantity,
    required this.createdAt,
    required this.updatedAt,
    this.batchCode,
    this.costPerUnit,
    this.manufactureDate,
    this.expiryDate,
    this.warehouse,
  });

  final String id;
  final String productId;
  final double quantity;
  final double availableQuantity;
  final String? batchCode;
  final double? costPerUnit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? manufactureDate;
  final DateTime? expiryDate;
  final String? warehouse;

  factory InventoryBatch.fromJson(Map<String, dynamic> json) => InventoryBatch(
        id: json['id'] as String,
        productId: json['productId'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        availableQuantity: (json['availableQuantity'] as num).toDouble(),
        batchCode: json['batchCode'] as String?,
        costPerUnit: (json['costPerUnit'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        manufactureDate: json['manufactureDate'] != null
            ? DateTime.parse(json['manufactureDate'] as String)
            : null,
        expiryDate: json['expiryDate'] != null
            ? DateTime.parse(json['expiryDate'] as String)
            : null,
        warehouse: json['warehouse'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'quantity': quantity,
        'availableQuantity': availableQuantity,
        'batchCode': batchCode,
        'costPerUnit': costPerUnit,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'manufactureDate': manufactureDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'warehouse': warehouse,
      };
}

class BatchCreateRequest {
  BatchCreateRequest({
    required this.productId,
    required this.quantity,
    required this.costPerUnit,
    this.batchCode,
    this.manufactureDate,
    this.expiryDate,
    this.warehouse,
  });

  final String productId;
  final double quantity;
  final double costPerUnit;
  final String? batchCode;
  final DateTime? manufactureDate;
  final DateTime? expiryDate;
  final String? warehouse;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'costPerUnit': costPerUnit,
        'batchCode': batchCode,
        'manufactureDate': manufactureDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'warehouse': warehouse,
      };
}

class InventoryConsumeRequest {
  InventoryConsumeRequest({
    required this.productId,
    required this.quantity,
    this.reason,
  });

  final String productId;
  final double quantity;
  final String? reason;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'reason': reason,
      };
}

class InventorySnapshot {
  InventorySnapshot({
    required this.productId,
    required this.totalQuantity,
    required this.availableQuantity,
    required this.threshold,
    required this.lowStock,
  });

  final String productId;
  final double totalQuantity;
  final double availableQuantity;
  final double threshold;
  final bool lowStock;

  factory InventorySnapshot.fromJson(Map<String, dynamic> json) =>
      InventorySnapshot(
        productId: json['productId'] as String,
        totalQuantity: (json['totalQuantity'] as num).toDouble(),
        availableQuantity: (json['availableQuantity'] as num).toDouble(),
        threshold: (json['threshold'] as num).toDouble(),
        lowStock: json['lowStock'] as bool? ?? false,
      );
}


/// Stock Movement Type
enum StockMovementType {
  purchase('purchase'),
  replenish('replenish'),
  adjust('adjust'),
  productionUse('production_use'),
  waste('waste'),
  returnToSupplier('return'),
  transfer('transfer'),
  correction('correction');

  final String value;
  const StockMovementType(this.value);

  static StockMovementType fromString(String value) {
    return StockMovementType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => StockMovementType.adjust,
    );
  }

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case StockMovementType.purchase:
        return 'Initial Purchase';
      case StockMovementType.replenish:
        return 'Stock Replenishment';
      case StockMovementType.adjust:
        return 'Manual Adjustment';
      case StockMovementType.productionUse:
        return 'Used in Production';
      case StockMovementType.waste:
        return 'Waste/Damaged';
      case StockMovementType.returnToSupplier:
        return 'Return to Supplier';
      case StockMovementType.transfer:
        return 'Transfer';
      case StockMovementType.correction:
        return 'Inventory Correction';
    }
  }

  /// Get icon for UI
  String get icon {
    switch (this) {
      case StockMovementType.purchase:
        return '📦';
      case StockMovementType.replenish:
        return '➕';
      case StockMovementType.adjust:
        return '🔧';
      case StockMovementType.productionUse:
        return '🏭';
      case StockMovementType.waste:
        return '🗑️';
      case StockMovementType.returnToSupplier:
        return '↩️';
      case StockMovementType.transfer:
        return '🔄';
      case StockMovementType.correction:
        return '✅';
    }
  }
}

/// Stock Movement Model
/// Complete audit trail of all stock quantity changes
class StockMovement {
  final String id;
  final String businessOwnerId;
  final String stockItemId;
  final StockMovementType movementType;
  final double quantityBefore;
  final double quantityChange;
  final double quantityAfter;
  final String? reason;
  final String? referenceId;
  final String? referenceType;
  final String? createdBy;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.businessOwnerId,
    required this.stockItemId,
    required this.movementType,
    required this.quantityBefore,
    required this.quantityChange,
    required this.quantityAfter,
    this.reason,
    this.referenceId,
    this.referenceType,
    this.createdBy,
    required this.createdAt,
  });

  /// Check if this was an increase (+) or decrease (-)
  bool get isIncrease => quantityChange > 0;

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      stockItemId: json['stock_item_id'] as String,
      movementType: StockMovementType.fromString(json['movement_type'] as String),
      quantityBefore: (json['quantity_before'] as num).toDouble(),
      quantityChange: (json['quantity_change'] as num).toDouble(),
      quantityAfter: (json['quantity_after'] as num).toDouble(),
      reason: json['reason'] as String?,
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'stock_item_id': stockItemId,
      'movement_type': movementType.value,
      'quantity_before': quantityBefore,
      'quantity_change': quantityChange,
      'quantity_after': quantityAfter,
      'reason': reason,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Input model for recording stock movements
class StockMovementInput {
  final String stockItemId;
  final StockMovementType movementType;
  final double quantityChange;
  final String? reason;
  final String? referenceId;
  final String? referenceType;

  StockMovementInput({
    required this.stockItemId,
    required this.movementType,
    required this.quantityChange,
    this.reason,
    this.referenceId,
    this.referenceType,
  });

  Map<String, dynamic> toJson() {
    return {
      'p_stock_item_id': stockItemId,
      'p_movement_type': movementType.value,
      'p_quantity_change': quantityChange,
      'p_reason': reason,
      'p_reference_id': referenceId,
      'p_reference_type': referenceType,
    };
  }
}


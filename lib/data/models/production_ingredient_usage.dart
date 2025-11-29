// Production Ingredient Usage - Audit trail of what was actually used in production

class ProductionIngredientUsage {
  final String id;
  final String businessOwnerId;
  final String productionBatchId;
  final String stockItemId;
  final String? recipeItemId;  // What was expected
  
  // What was ACTUALLY used
  final double quantityUsed;
  final String unit;
  
  // Cost snapshot at time of production
  final double costPerUnit;
  final double totalCost;
  
  // Variance tracking
  final double varianceQuantity;     // Actual vs expected
  final double variancePercentage;   // Percentage difference
  
  final DateTime createdAt;

  ProductionIngredientUsage({
    required this.id,
    required this.businessOwnerId,
    required this.productionBatchId,
    required this.stockItemId,
    this.recipeItemId,
    required this.quantityUsed,
    required this.unit,
    required this.costPerUnit,
    required this.totalCost,
    this.varianceQuantity = 0,
    this.variancePercentage = 0,
    required this.createdAt,
  });

  factory ProductionIngredientUsage.fromJson(Map<String, dynamic> json) {
    return ProductionIngredientUsage(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      productionBatchId: json['production_batch_id'] as String,
      stockItemId: json['stock_item_id'] as String,
      recipeItemId: json['recipe_item_id'] as String?,
      quantityUsed: (json['quantity_used'] as num).toDouble(),
      unit: json['unit'] as String,
      costPerUnit: (json['cost_per_unit'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      varianceQuantity: (json['variance_quantity'] as num?)?.toDouble() ?? 0,
      variancePercentage: (json['variance_percentage'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'production_batch_id': productionBatchId,
      'stock_item_id': stockItemId,
      'recipe_item_id': recipeItemId,
      'quantity_used': quantityUsed,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'variance_quantity': varianceQuantity,
      'variance_percentage': variancePercentage,
      'created_at': createdAt.toIso8601String(),
    };
  }
}


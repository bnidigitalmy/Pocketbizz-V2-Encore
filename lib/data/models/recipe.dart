// Recipe Model - Master recipe information
// One product can have multiple recipes (versions)

class Recipe {
  final String id;
  final String businessOwnerId;
  final String productId;
  
  // Recipe Details
  final String name;                // e.g., "Chocolate Cake Recipe V1"
  final String? description;        // Optional notes
  
  // Yield Information
  final double yieldQuantity;       // How many units this recipe produces
  final String yieldUnit;           // What unit (pieces, kg, boxes, etc.)
  
  // Cost Tracking (Auto-calculated)
  final double materialsCost;       // Sum of all recipe items
  final double totalCost;           // Materials + labour + other
  final double costPerUnit;         // total_cost / yield_quantity
  
  // Version Control
  final int version;                // Recipe version number
  final bool isActive;              // Current active recipe?
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe({
    required this.id,
    required this.businessOwnerId,
    required this.productId,
    required this.name,
    this.description,
    required this.yieldQuantity,
    required this.yieldUnit,
    this.materialsCost = 0,
    this.totalCost = 0,
    this.costPerUnit = 0,
    this.version = 1,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // From Supabase (snake_case)
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      productId: json['product_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      yieldQuantity: (json['yield_quantity'] as num).toDouble(),
      yieldUnit: json['yield_unit'] as String,
      materialsCost: (json['materials_cost'] as num?)?.toDouble() ?? 0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      costPerUnit: (json['cost_per_unit'] as num?)?.toDouble() ?? 0,
      version: json['version'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // To Supabase (snake_case)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'product_id': productId,
      'name': name,
      'description': description,
      'yield_quantity': yieldQuantity,
      'yield_unit': yieldUnit,
      'materials_cost': materialsCost,
      'total_cost': totalCost,
      'cost_per_unit': costPerUnit,
      'version': version,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // For insert/update (exclude auto-generated fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'business_owner_id': businessOwnerId,
      'product_id': productId,
      'name': name,
      'description': description,
      'yield_quantity': yieldQuantity,
      'yield_unit': yieldUnit,
      'version': version,
      'is_active': isActive,
    };
  }

  Recipe copyWith({
    String? id,
    String? businessOwnerId,
    String? productId,
    String? name,
    String? description,
    double? yieldQuantity,
    String? yieldUnit,
    double? materialsCost,
    double? totalCost,
    double? costPerUnit,
    int? version,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      businessOwnerId: businessOwnerId ?? this.businessOwnerId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      description: description ?? this.description,
      yieldQuantity: yieldQuantity ?? this.yieldQuantity,
      yieldUnit: yieldUnit ?? this.yieldUnit,
      materialsCost: materialsCost ?? this.materialsCost,
      totalCost: totalCost ?? this.totalCost,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


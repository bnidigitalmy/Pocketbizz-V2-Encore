import 'package:meta/meta.dart';

@immutable
class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.costPrice,
    required this.salePrice,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.ownerId,
    this.description,
    this.category,
  });

  final String id;
  final String? ownerId;
  final String sku;
  final String name;
  final String unit;
  final double costPrice;
  final double salePrice;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String? category;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String?,
        sku: json['sku'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        costPrice: (json['costPrice'] as num).toDouble(),
        salePrice: (json['salePrice'] as num).toDouble(),
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        description: json['description'] as String?,
        category: json['category'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'sku': sku,
        'name': name,
        'unit': unit,
        'costPrice': costPrice,
        'salePrice': salePrice,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'description': description,
        'category': category,
      };
}

class ProductCreate {
  ProductCreate({
    required this.sku,
    required this.name,
    required this.unit,
    required this.costPrice,
    required this.salePrice,
    this.description,
    this.category,
    this.ownerId,
  });

  final String? ownerId;
  final String sku;
  final String name;
  final String unit;
  final double costPrice;
  final double salePrice;
  final String? description;
  final String? category;

  Map<String, dynamic> toJson() => {
        'ownerId': ownerId,
        'sku': sku,
        'name': name,
        'unit': unit,
        'costPrice': costPrice,
        'salePrice': salePrice,
        'description': description,
        'category': category,
      };
}

class ProductUpdate {
  ProductUpdate({
    required this.id,
    this.ownerId,
    this.sku,
    this.name,
    this.unit,
    this.costPrice,
    this.salePrice,
    this.description,
    this.category,
    this.isActive,
  });

  final String id;
  final String? ownerId;
  final String? sku;
  final String? name;
  final String? unit;
  final double? costPrice;
  final double? salePrice;
  final String? description;
  final String? category;
  final bool? isActive;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'sku': sku,
        'name': name,
        'unit': unit,
        'costPrice': costPrice,
        'salePrice': salePrice,
        'description': description,
        'category': category,
        'isActive': isActive,
      }..removeWhere((_, value) => value == null);
}


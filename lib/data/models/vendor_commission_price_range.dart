/// Vendor Commission Price Range Model
/// Defines commission amount for specific price ranges
class VendorCommissionPriceRange {
  final String id;
  final String vendorId;
  final String businessOwnerId;
  final double minPrice;
  final double? maxPrice; // NULL means unlimited (last range)
  final double commissionAmount; // Fixed commission for this range
  final int position; // Order/position of range
  final DateTime createdAt;
  final DateTime updatedAt;

  VendorCommissionPriceRange({
    required this.id,
    required this.vendorId,
    required this.businessOwnerId,
    required this.minPrice,
    this.maxPrice,
    required this.commissionAmount,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorCommissionPriceRange.fromJson(Map<String, dynamic> json) {
    return VendorCommissionPriceRange(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      minPrice: (json['min_price'] as num).toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      commissionAmount: (json['commission_amount'] as num).toDouble(),
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'business_owner_id': businessOwnerId,
      'min_price': minPrice,
      'max_price': maxPrice,
      'commission_amount': commissionAmount,
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'vendor_id': vendorId,
      'business_owner_id': businessOwnerId,
      'min_price': minPrice,
      'max_price': maxPrice,
      'commission_amount': commissionAmount,
      'position': position,
    };
  }

  /// Check if a price falls within this range
  /// Note: For ranges with maxPrice, we use <= to include the upper bound
  /// This matches typical price range logic where RM10.01-RM13.00 includes RM13.00
  bool isPriceInRange(double price) {
    if (maxPrice == null) {
      return price >= minPrice;
    }
    // Use <= to include the upper bound (e.g., RM13.00 is included in RM10.01-RM13.00)
    return price >= minPrice && price <= maxPrice!;
  }
}


/// Vendor Claim Item Model - Individual product in a vendor claim
class VendorClaimItem {
  final String id;
  final String businessOwnerId;
  final String claimId;
  final String productId;
  
  // Sale Details
  final double quantity;
  final double unitPrice;
  final double totalAmount;
  
  // Commission
  final double commissionRate;
  final double commissionAmount;
  
  // Timestamps
  final DateTime createdAt;
  
  // For joins
  String? productName;

  VendorClaimItem({
    required this.id,
    required this.businessOwnerId,
    required this.claimId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.createdAt,
    this.productName,
  });

  factory VendorClaimItem.fromJson(Map<String, dynamic> json) {
    return VendorClaimItem(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      claimId: json['claim_id'] as String,
      productId: json['product_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      commissionRate: (json['commission_rate'] as num).toDouble(),
      commissionAmount: (json['commission_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      productName: json['product_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'claim_id': claimId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}


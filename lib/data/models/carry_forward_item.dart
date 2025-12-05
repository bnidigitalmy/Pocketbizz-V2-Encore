/// Carry Forward Item Model
/// Represents items that were not sold in previous claims
/// and are available for use in the next claim
class CarryForwardItem {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  final String? sourceClaimId;
  final String? sourceClaimItemId;
  final String? sourceDeliveryId;
  final String? sourceDeliveryItemId;
  final String? productId;
  final String productName;
  final double quantityAvailable;
  final double unitPrice;
  final CarryForwardStatus status;
  final String? originalClaimNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? usedAt;
  final String? usedInClaimId;
  
  // Denormalized fields (from joins)
  final String? vendorName;
  final String? productNameFull;
  final String? productUnit;

  CarryForwardItem({
    required this.id,
    required this.businessOwnerId,
    required this.vendorId,
    this.sourceClaimId,
    this.sourceClaimItemId,
    this.sourceDeliveryId,
    this.sourceDeliveryItemId,
    this.productId,
    required this.productName,
    required this.quantityAvailable,
    required this.unitPrice,
    required this.status,
    this.originalClaimNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.usedAt,
    this.usedInClaimId,
    this.vendorName,
    this.productNameFull,
    this.productUnit,
  });

  factory CarryForwardItem.fromJson(Map<String, dynamic> json) {
    return CarryForwardItem(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      vendorId: json['vendor_id'] as String,
      sourceClaimId: json['source_claim_id'] as String?,
      sourceClaimItemId: json['source_claim_item_id'] as String?,
      sourceDeliveryId: json['source_delivery_id'] as String?,
      sourceDeliveryItemId: json['source_delivery_item_id'] as String?,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      quantityAvailable: (json['quantity_available'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      status: _parseStatus(json['status'] as String),
      originalClaimNumber: json['original_claim_number'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      usedAt: json['used_at'] != null 
          ? DateTime.parse(json['used_at'] as String) 
          : null,
      usedInClaimId: json['used_in_claim_id'] as String?,
      vendorName: json['vendor_name'] as String?,
      productNameFull: json['product_name_full'] as String?,
      productUnit: json['product_unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'vendor_id': vendorId,
      'source_claim_id': sourceClaimId,
      'source_claim_item_id': sourceClaimItemId,
      'source_delivery_id': sourceDeliveryId,
      'source_delivery_item_id': sourceDeliveryItemId,
      'product_id': productId,
      'product_name': productName,
      'quantity_available': quantityAvailable,
      'unit_price': unitPrice,
      'status': status.toString().split('.').last,
      'original_claim_number': originalClaimNumber,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'used_at': usedAt?.toIso8601String(),
      'used_in_claim_id': usedInClaimId,
    };
  }

  static CarryForwardStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return CarryForwardStatus.available;
      case 'used':
        return CarryForwardStatus.used;
      case 'expired':
        return CarryForwardStatus.expired;
      case 'cancelled':
        return CarryForwardStatus.cancelled;
      default:
        return CarryForwardStatus.available;
    }
  }

  /// Check if this C/F item can be used
  bool get canBeUsed => status == CarryForwardStatus.available && quantityAvailable > 0;

  /// Get display name (prefer full name if available)
  String get displayName => productNameFull ?? productName;
}

enum CarryForwardStatus {
  available,
  used,
  expired,
  cancelled,
}





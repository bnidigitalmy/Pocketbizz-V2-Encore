/// Vendor Payment Model - Payment made to vendor
class VendorPayment {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  
  // Payment Details
  final String paymentNumber;
  final DateTime paymentDate;
  
  // Amount
  final double amount;
  
  // Payment Method
  final String paymentMethod;
  final String? paymentReference;
  
  // Related Claims
  final List<String>? claimIds;
  
  // Notes
  final String? notes;
  
  // Created by
  final String? createdBy;
  
  // Timestamps
  final DateTime createdAt;
  
  // For joins
  String? vendorName;

  VendorPayment({
    required this.id,
    required this.businessOwnerId,
    required this.vendorId,
    required this.paymentNumber,
    required this.paymentDate,
    required this.amount,
    required this.paymentMethod,
    this.paymentReference,
    this.claimIds,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.vendorName,
  });

  factory VendorPayment.fromJson(Map<String, dynamic> json) {
    return VendorPayment(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      vendorId: json['vendor_id'] as String,
      paymentNumber: json['payment_number'] as String,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentReference: json['payment_reference'] as String?,
      claimIds: json['claim_ids'] != null 
          ? List<String>.from(json['claim_ids'] as List) 
          : null,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      vendorName: json['vendor_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'vendor_id': vendorId,
      'payment_number': paymentNumber,
      'payment_date': paymentDate.toIso8601String().split('T')[0],
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'claim_ids': claimIds,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}


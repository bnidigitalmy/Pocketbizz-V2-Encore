/// Consignment Payment Model
class ConsignmentPayment {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  final String? vendorName;
  final String paymentNumber;
  final DateTime paymentDate;
  final PaymentMethod paymentMethod;
  final double totalAmount;
  final String? paymentReference;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConsignmentPaymentAllocation>? allocations;

  ConsignmentPayment({
    required this.id,
    required this.businessOwnerId,
    required this.vendorId,
    this.vendorName,
    required this.paymentNumber,
    required this.paymentDate,
    required this.paymentMethod,
    required this.totalAmount,
    this.paymentReference,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.allocations,
  });

  factory ConsignmentPayment.fromJson(Map<String, dynamic> json) {
    return ConsignmentPayment(
      id: json['id'] as String,
      businessOwnerId: json['businessOwnerId'] as String? ?? json['business_owner_id'] as String,
      vendorId: json['vendorId'] as String? ?? json['vendor_id'] as String,
      vendorName: json['vendorName'] as String? ?? json['vendor_name'] as String?,
      paymentNumber: json['paymentNumber'] as String? ?? json['payment_number'] as String,
      paymentDate: DateTime.parse(json['paymentDate'] as String? ?? json['payment_date'] as String),
      paymentMethod: _parsePaymentMethod(json['paymentMethod'] as String? ?? json['payment_method'] as String? ?? 'per_claim'),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 
                  (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentReference: json['paymentReference'] as String? ?? json['payment_reference'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? json['updated_at'] as String),
      allocations: json['allocations'] != null
          ? (json['allocations'] as List<dynamic>)
              .map((alloc) => ConsignmentPaymentAllocation.fromJson(alloc as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessOwnerId': businessOwnerId,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'paymentNumber': paymentNumber,
      'paymentDate': paymentDate.toIso8601String(),
      'paymentMethod': paymentMethod.toString().split('.').last,
      'totalAmount': totalAmount,
      'paymentReference': paymentReference,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'allocations': allocations?.map((alloc) => alloc.toJson()).toList(),
    };
  }

  static PaymentMethod _parsePaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'bill_to_bill':
        return PaymentMethod.billToBill;
      case 'per_claim':
        return PaymentMethod.perClaim;
      case 'partial':
        return PaymentMethod.partial;
      case 'carry_forward':
        return PaymentMethod.carryForward;
      default:
        return PaymentMethod.perClaim;
    }
  }
}

enum PaymentMethod {
  billToBill,
  perClaim,
  partial,
  carryForward,
}

/// Consignment Payment Allocation Model
class ConsignmentPaymentAllocation {
  final String id;
  final String paymentId;
  final String claimId;
  final String? claimItemId;
  final double allocatedAmount;
  final DateTime createdAt;
  // Denormalized
  final String? claimNumber;

  ConsignmentPaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.claimId,
    this.claimItemId,
    required this.allocatedAmount,
    required this.createdAt,
    this.claimNumber,
  });

  factory ConsignmentPaymentAllocation.fromJson(Map<String, dynamic> json) {
    return ConsignmentPaymentAllocation(
      id: json['id'] as String,
      paymentId: json['paymentId'] as String? ?? json['payment_id'] as String,
      claimId: json['claimId'] as String? ?? json['claim_id'] as String,
      claimItemId: json['claimItemId'] as String? ?? json['claim_item_id'] as String?,
      allocatedAmount: (json['allocatedAmount'] as num?)?.toDouble() ?? 
                      (json['allocated_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
      claimNumber: json['claimNumber'] as String? ?? json['claim_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentId': paymentId,
      'claimId': claimId,
      'claimItemId': claimItemId,
      'allocatedAmount': allocatedAmount,
      'createdAt': createdAt.toIso8601String(),
      'claimNumber': claimNumber,
    };
  }
}

/// Outstanding Balance Model
class OutstandingBalance {
  final double totalOutstanding;
  final List<OutstandingClaim> claims;

  OutstandingBalance({
    required this.totalOutstanding,
    required this.claims,
  });

  factory OutstandingBalance.fromJson(Map<String, dynamic> json) {
    return OutstandingBalance(
      totalOutstanding: (json['totalOutstanding'] as num?)?.toDouble() ?? 
                       (json['total_outstanding'] as num?)?.toDouble() ?? 0.0,
      claims: (json['claims'] as List<dynamic>?)
          ?.map((c) => OutstandingClaim.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class OutstandingClaim {
  final String claimId;
  final String claimNumber;
  final double balanceAmount;

  OutstandingClaim({
    required this.claimId,
    required this.claimNumber,
    required this.balanceAmount,
  });

  factory OutstandingClaim.fromJson(Map<String, dynamic> json) {
    return OutstandingClaim(
      claimId: json['claimId'] as String? ?? json['claim_id'] as String,
      claimNumber: json['claimNumber'] as String? ?? json['claim_number'] as String,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 
                    (json['balance_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}




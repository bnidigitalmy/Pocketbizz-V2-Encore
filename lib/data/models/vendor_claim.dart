/// Vendor Claim Model - Sales claim submitted by vendor
class VendorClaim {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  
  // Claim Details
  final String claimNumber;
  final DateTime claimDate;
  
  // Status
  final String status; // pending, approved, rejected, paid
  
  // Amounts
  final double totalSalesAmount;
  final double totalCommission;
  
  // Proof
  final String? proofUrl;
  
  // Notes
  final String? vendorNotes;
  final String? adminNotes;
  
  // Review Info
  final String? reviewedBy;
  final DateTime? reviewedAt;
  
  // Payment Info
  final String? paidBy;
  final DateTime? paidAt;
  final String? paymentReference;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // For joins
  String? vendorName;

  VendorClaim({
    required this.id,
    required this.businessOwnerId,
    required this.vendorId,
    required this.claimNumber,
    required this.claimDate,
    this.status = 'pending',
    this.totalSalesAmount = 0.0,
    this.totalCommission = 0.0,
    this.proofUrl,
    this.vendorNotes,
    this.adminNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.paidBy,
    this.paidAt,
    this.paymentReference,
    required this.createdAt,
    required this.updatedAt,
    this.vendorName,
  });

  factory VendorClaim.fromJson(Map<String, dynamic> json) {
    return VendorClaim(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      vendorId: json['vendor_id'] as String,
      claimNumber: json['claim_number'] as String,
      claimDate: DateTime.parse(json['claim_date'] as String),
      status: json['status'] as String? ?? 'pending',
      totalSalesAmount: (json['total_sales_amount'] as num?)?.toDouble() ?? 0.0,
      totalCommission: (json['total_commission'] as num?)?.toDouble() ?? 0.0,
      proofUrl: json['proof_url'] as String?,
      vendorNotes: json['vendor_notes'] as String?,
      adminNotes: json['admin_notes'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at'] as String) : null,
      paidBy: json['paid_by'] as String?,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      paymentReference: json['payment_reference'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      vendorName: json['vendor_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'vendor_id': vendorId,
      'claim_number': claimNumber,
      'claim_date': claimDate.toIso8601String().split('T')[0],
      'status': status,
      'total_sales_amount': totalSalesAmount,
      'total_commission': totalCommission,
      'proof_url': proofUrl,
      'vendor_notes': vendorNotes,
      'admin_notes': adminNotes,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'paid_by': paidBy,
      'paid_at': paidAt?.toIso8601String(),
      'payment_reference': paymentReference,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Get status color
  String getStatusColor() {
    switch (status) {
      case 'pending':
        return '#F59E0B'; // Gold/Orange
      case 'approved':
        return '#10B981'; // Green
      case 'rejected':
        return '#EF4444'; // Red
      case 'paid':
        return '#6366F1'; // Blue
      default:
        return '#6B7280'; // Gray
    }
  }

  // Get status display text
  String getStatusText() {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'paid':
        return 'Paid';
      default:
        return status;
    }
  }
}


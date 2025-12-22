/// Vendor Model - Represents a Consignee (kedai yang jual produk untuk user)
/// 
/// This is part of the Consignment System:
/// - User (Consignor) = Pengeluar/owner produk yang guna app PocketBizz
/// - Vendor (Consignee) = Kedai yang jual produk untuk user dengan commission
/// 
/// Flow: User hantar produk → Vendor jual → Vendor dapat commission → User dapat payment
class Vendor {
  final String id;
  final String businessOwnerId;
  
  // Vendor Information
  final String name;
  final String? vendorNumber; // NV - Nombor Vendor
  final String? email;
  final String? phone;
  final String? address;
  
  // Commission Settings
  final String commissionType; // 'percentage' or 'price_range'
  final double defaultCommissionRate; // Percentage (for percentage type)
  
  // Bank Details
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountHolder;
  
  // Status
  final bool isActive;
  
  // Notes
  final String? notes;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  Vendor({
    required this.id,
    required this.businessOwnerId,
    required this.name,
    this.vendorNumber,
    this.email,
    this.phone,
    this.address,
    this.commissionType = 'percentage',
    this.defaultCommissionRate = 0.0,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountHolder,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      name: json['name'] as String,
      vendorNumber: json['vendor_number'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      commissionType: json['commission_type'] as String? ?? 'percentage',
      defaultCommissionRate: (json['default_commission_rate'] as num?)?.toDouble() ?? 0.0,
      bankName: json['bank_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankAccountHolder: json['bank_account_holder'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'name': name,
      'vendor_number': vendorNumber,
      'email': email,
      'phone': phone,
      'address': address,
      'commission_type': commissionType,
      'default_commission_rate': defaultCommissionRate,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_holder': bankAccountHolder,
      'is_active': isActive,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'business_owner_id': businessOwnerId,
      'name': name,
      'vendor_number': vendorNumber,
      'email': email,
      'phone': phone,
      'address': address,
      'commission_type': commissionType,
      'default_commission_rate': defaultCommissionRate,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_holder': bankAccountHolder,
      'is_active': isActive,
      'notes': notes,
    };
  }
}


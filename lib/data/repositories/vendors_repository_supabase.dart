import '../../core/supabase/supabase_client.dart';
import '../models/vendor.dart';
import '../models/vendor_claim.dart';
import '../models/vendor_claim_item.dart';
import '../models/vendor_payment.dart';

class VendorsRepositorySupabase {
  // ============================================================================
  // VENDORS CRUD
  // ============================================================================

  /// Get all vendors
  Future<List<Vendor>> getAllVendors({bool activeOnly = false}) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    dynamic query = supabase
        .from('vendors')
        .select()
        .eq('business_owner_id', userId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    query = query.order('name');

    final response = await query;
    return (response as List)
        .map((json) => Vendor.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get vendor by ID
  Future<Vendor?> getVendorById(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await supabase
        .from('vendors')
        .select()
        .eq('id', vendorId)
        .eq('business_owner_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Vendor.fromJson(response as Map<String, dynamic>);
  }

  /// Create vendor
  Future<Vendor> createVendor({
    required String name,
    String? email,
    String? phone,
    String? address,
    double defaultCommissionRate = 0.0,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('vendors')
        .insert({
      'business_owner_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'default_commission_rate': defaultCommissionRate,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_holder': bankAccountHolder,
      'notes': notes,
    })
        .select()
        .single();

    return Vendor.fromJson(response as Map<String, dynamic>);
  }

  /// Update vendor
  Future<void> updateVendor(String vendorId, Map<String, dynamic> updates) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await supabase
        .from('vendors')
        .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', vendorId)
        .eq('business_owner_id', userId);
  }

  /// Delete vendor
  Future<void> deleteVendor(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await supabase
        .from('vendors')
        .delete()
        .eq('id', vendorId)
        .eq('business_owner_id', userId);
  }

  /// Toggle vendor active status
  Future<void> toggleVendorStatus(String vendorId, bool isActive) async {
    await updateVendor(vendorId, {'is_active': isActive});
  }

  // ============================================================================
  // VENDOR PRODUCTS
  // ============================================================================

  /// Assign product to vendor
  Future<void> assignProductToVendor({
    required String vendorId,
    required String productId,
    double? commissionRate,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    await supabase
        .from('vendor_products')
        .insert({
      'business_owner_id': userId,
      'vendor_id': vendorId,
      'product_id': productId,
      'commission_rate': commissionRate,
    });
  }

  /// Remove product from vendor
  Future<void> removeProductFromVendor(String vendorId, String productId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await supabase
        .from('vendor_products')
        .delete()
        .eq('vendor_id', vendorId)
        .eq('product_id', productId)
        .eq('business_owner_id', userId);
  }

  /// Get products assigned to vendor
  Future<List<Map<String, dynamic>>> getVendorProducts(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await supabase
        .from('vendor_products')
        .select('''
          *,
          products!inner(id, sku, name, sale_price, image_url)
        ''')
        .eq('vendor_id', vendorId)
        .eq('business_owner_id', userId)
        .eq('is_active', true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  // ============================================================================
  // VENDOR CLAIMS
  // ============================================================================

  /// Get all claims
  Future<List<VendorClaim>> getAllClaims({String? status, String? vendorId}) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    dynamic query = supabase
        .from('vendor_claims')
        .select('''
          *,
          vendors!inner(name)
        ''')
        .eq('business_owner_id', userId);

    if (status != null) {
      query = query.eq('status', status);
    }

    if (vendorId != null) {
      query = query.eq('vendor_id', vendorId);
    }

    query = query.order('claim_date', ascending: false);

    final response = await query;
    
    return (response as List).map((json) {
      final claim = VendorClaim.fromJson(json as Map<String, dynamic>);
      final vendorData = json['vendors'];
      if (vendorData != null) {
        claim.vendorName = vendorData['name'] as String?;
      }
      return claim;
    }).toList();
  }

  /// Get claim by ID with items
  Future<Map<String, dynamic>?> getClaimById(String claimId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final claimResponse = await supabase
        .from('vendor_claims')
        .select('''
          *,
          vendors!inner(name, phone, email)
        ''')
        .eq('id', claimId)
        .eq('business_owner_id', userId)
        .maybeSingle();

    if (claimResponse == null) return null;

    final itemsResponse = await supabase
        .from('vendor_claim_items')
        .select('''
          *,
          products!inner(name, sku)
        ''')
        .eq('claim_id', claimId)
        .eq('business_owner_id', userId);

    return {
      'claim': claimResponse,
      'items': itemsResponse,
    };
  }

  /// Create claim (call DB function)
  Future<String> createClaim({
    required String vendorId,
    required List<Map<String, dynamic>> items, // [{product_id, quantity, unit_price}]
    String? vendorNotes,
    String? proofUrl,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase.rpc('create_vendor_claim', params: {
      'p_business_owner_id': userId,
      'p_vendor_id': vendorId,
      'p_claim_items': items,
      'p_vendor_notes': vendorNotes,
      'p_proof_url': proofUrl,
    });

    return response as String;
  }

  /// Approve claim
  Future<void> approveClaim(String claimId, {String? adminNotes}) async {
    await supabase.rpc('update_claim_status', params: {
      'p_claim_id': claimId,
      'p_status': 'approved',
      'p_admin_notes': adminNotes,
    });
  }

  /// Reject claim
  Future<void> rejectClaim(String claimId, {String? adminNotes}) async {
    await supabase.rpc('update_claim_status', params: {
      'p_claim_id': claimId,
      'p_status': 'rejected',
      'p_admin_notes': adminNotes,
    });
  }

  /// Get pending claims count
  Future<int> getPendingClaimsCount() async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await supabase
        .from('vendor_claims')
        .select()
        .eq('status', 'pending')
        .eq('business_owner_id', userId);

    return (response as List).length;
  }

  // ============================================================================
  // VENDOR PAYMENTS
  // ============================================================================

  /// Record payment to vendor
  Future<String> recordPayment({
    required String vendorId,
    required double amount,
    required String paymentMethod,
    required List<String> claimIds,
    String? paymentReference,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase.rpc('record_vendor_payment', params: {
      'p_business_owner_id': userId,
      'p_vendor_id': vendorId,
      'p_amount': amount,
      'p_payment_method': paymentMethod,
      'p_claim_ids': claimIds,
      'p_payment_reference': paymentReference,
      'p_notes': notes,
    });

    return response as String;
  }

  /// Get vendor payments
  Future<List<VendorPayment>> getVendorPayments(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await supabase
        .from('vendor_payments')
        .select('''
          *,
          vendors!inner(name)
        ''')
        .eq('vendor_id', vendorId)
        .eq('business_owner_id', userId)
        .order('payment_date', ascending: false);

    return (response as List).map((json) {
      final payment = VendorPayment.fromJson(json as Map<String, dynamic>);
      final vendorData = json['vendors'];
      if (vendorData != null) {
        payment.vendorName = vendorData['name'] as String?;
      }
      return payment;
    }).toList();
  }

  /// Get vendor summary (total sales, commission, payments)
  Future<Map<String, dynamic>> getVendorSummary(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final claims = await supabase
        .from('vendor_claims')
        .select('status, total_sales_amount, total_commission')
        .eq('vendor_id', vendorId)
        .eq('business_owner_id', userId);

    final payments = await supabase
        .from('vendor_payments')
        .select('amount')
        .eq('vendor_id', vendorId)
        .eq('business_owner_id', userId);

    double totalSales = 0;
    double totalCommission = 0;
    double pendingCommission = 0;
    double approvedCommission = 0;
    double paidAmount = 0;

    for (final claim in claims as List) {
      final sales = (claim['total_sales_amount'] as num?)?.toDouble() ?? 0;
      final commission = (claim['total_commission'] as num?)?.toDouble() ?? 0;
      final status = claim['status'] as String;

      totalSales += sales;
      totalCommission += commission;

      if (status == 'pending') pendingCommission += commission;
      if (status == 'approved') approvedCommission += commission;
    }

    for (final payment in payments as List) {
      paidAmount += (payment['amount'] as num?)?.toDouble() ?? 0;
    }

    return {
      'total_sales': totalSales,
      'total_commission': totalCommission,
      'pending_commission': pendingCommission,
      'approved_commission': approvedCommission,
      'paid_amount': paidAmount,
      'outstanding_balance': approvedCommission - paidAmount,
    };
  }
}


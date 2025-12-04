import '../../core/supabase/supabase_client.dart';
import '../models/consignment_claim.dart';
import '../models/claim_validation_result.dart';
import '../models/claim_summary.dart';
import '../models/delivery.dart';

/// Simplified Consignment Claims Repository
/// Easy to understand and use for non-techy users
class ConsignmentClaimsRepositorySupabase {
  
  // ============================================================================
  // PUBLIC METHODS - Simple & Clear
  // ============================================================================

  /// Validate claim request before creating
  /// Returns clear feedback about what's wrong
  Future<ClaimValidationResult> validateClaimRequest({
    required String vendorId,
    required List<String> deliveryIds,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      return ClaimValidationResult(
        isValid: false,
        errors: ['Anda perlu log masuk untuk menuntut bayaran'],
      );
    }

    final errors = <String>[];
    final warnings = <String>[];

    // Check vendor selected
    if (vendorId.isEmpty) {
      errors.add('Sila pilih vendor');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Check deliveries selected
    if (deliveryIds.isEmpty) {
      errors.add('Sila pilih sekurang-kurangnya satu penghantaran');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Validate vendor exists
    final vendor = await _getVendor(vendorId, userId);
    if (vendor == null) {
      errors.add('Vendor tidak dijumpai. Sila pilih vendor yang betul.');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Validate deliveries exist and belong to vendor
    final deliveries = await _getDeliveries(deliveryIds, userId);
    if (deliveries.length != deliveryIds.length) {
      final missing = deliveryIds.length - deliveries.length;
      errors.add('$missing penghantaran tidak dijumpai. Sila semak semula.');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Check all deliveries are for same vendor
    final wrongVendorDeliveries = deliveries
        .where((d) => (d['vendor_id'] as String) != vendorId)
        .toList();
    if (wrongVendorDeliveries.isNotEmpty) {
      errors.add('Semua penghantaran mesti untuk vendor yang sama');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Check deliveries have items with sold quantity
    final deliveryItems = await _getDeliveryItems(deliveryIds);
    final itemsWithSold = deliveryItems.where((item) {
      final sold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      return sold > 0;
    }).toList();

    if (itemsWithSold.isEmpty) {
      errors.add('Tiada produk yang terjual untuk dituntut. Sila pastikan vendor telah update kuantiti terjual.');
      warnings.add('Tip: Vendor perlu update kuantiti terjual dalam sistem sebelum anda boleh buat tuntutan');
      return ClaimValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    // Check if deliveries already claimed
    final claimedDeliveries = await _getClaimedDeliveries(deliveryIds);
    if (claimedDeliveries.isNotEmpty) {
      warnings.add('Beberapa penghantaran mungkin sudah dituntut. Sistem akan skip item yang sudah dituntut.');
    }

    return ClaimValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Get summary of claim amounts before creating
  /// Helps user understand what they're claiming
  Future<ClaimSummary> getClaimSummary({
    required String vendorId,
    required List<String> deliveryIds,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get vendor commission rate
    final commissionRate = await _getVendorCommissionRate(vendorId, userId);

    // Get delivery items
    final deliveryItems = await _getDeliveryItems(deliveryIds);

    // Auto-balance quantities if needed
    await _autoBalanceQuantities(deliveryItems);

    // Calculate summary
    return ClaimSummary.fromDeliveryItems(
      deliveryItems: deliveryItems,
      commissionRate: commissionRate,
    );
  }

  /// Create claim - simplified version
  /// Handles all complexity internally
  Future<ConsignmentClaim> createClaim({
    required String vendorId,
    required List<String> deliveryIds,
    required DateTime claimDate,
    String? notes,
  }) async {
    // Step 1: Validate
    final validation = await validateClaimRequest(
      vendorId: vendorId,
      deliveryIds: deliveryIds,
    );

    if (!validation.isValid) {
      throw ClaimValidationException(validation);
    }

    // Step 2: Prepare data
    final claimData = await _prepareClaimData(
      vendorId: vendorId,
      deliveryIds: deliveryIds,
      claimDate: claimDate,
      notes: notes,
    );

    // Step 3: Create claim with retry
    return await _createClaimWithRetry(claimData);
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  Future<Map<String, dynamic>?> _getVendor(String vendorId, String userId) async {
    final response = await supabase
        .from('vendors')
        .select('id, name, default_commission_rate')
        .eq('id', vendorId)
        .eq('business_owner_id', userId)
        .maybeSingle();
    return response as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>> _getDeliveries(
    List<String> deliveryIds,
    String userId,
  ) async {
    if (deliveryIds.isEmpty) return [];
    
    final response = await supabase
        .from('vendor_deliveries')
        .select('id, vendor_id, vendor_name, status')
        .filter('id', 'in', _buildInFilter(deliveryIds))
        .eq('business_owner_id', userId);
    
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _getDeliveryItems(
    List<String> deliveryIds,
  ) async {
    if (deliveryIds.isEmpty) return [];
    
    final response = await supabase
        .from('vendor_delivery_items')
        .select('*')
        .filter('delivery_id', 'in', _buildInFilter(deliveryIds));
    
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<String>> _getClaimedDeliveries(List<String> deliveryIds) async {
    if (deliveryIds.isEmpty) return [];
    
    final response = await supabase
        .from('consignment_claim_items')
        .select('delivery_id')
        .filter('delivery_id', 'in', _buildInFilter(deliveryIds));
    
    final claimedIds = (response as List)
        .map((item) => (item as Map<String, dynamic>)['delivery_id'] as String)
        .toSet()
        .toList();
    
    return claimedIds;
  }

  Future<double> _getVendorCommissionRate(String vendorId, String userId) async {
    final vendor = await _getVendor(vendorId, userId);
    return (vendor?['default_commission_rate'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _autoBalanceQuantities(List<Map<String, dynamic>> deliveryItems) async {
    final itemsToUpdate = <Map<String, dynamic>>[];
    
    for (var item in deliveryItems) {
      final itemId = item['id'] as String;
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      var sold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      var unsold = (item['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
      var expired = (item['quantity_expired'] as num?)?.toDouble() ?? 0.0;
      var damaged = (item['quantity_damaged'] as num?)?.toDouble() ?? 0.0;
      final total = sold + unsold + expired + damaged;

      bool needsUpdate = false;

      // If quantities not set, assume all are unsold
      if (total == 0 && quantity > 0) {
        unsold = quantity;
        needsUpdate = true;
      } else if ((total - quantity).abs() > 0.01) {
        // If quantities don't balance, adjust unsold
        final difference = quantity - total;
        if (difference > 0) {
          unsold = (unsold + difference).clamp(0.0, quantity);
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        itemsToUpdate.add({
          'id': itemId,
          'quantity_unsold': unsold,
        });
        // Update in-memory data
        item['quantity_unsold'] = unsold;
      }
    }

    // Batch update in database
    if (itemsToUpdate.isNotEmpty) {
      for (var update in itemsToUpdate) {
        await supabase
            .from('vendor_delivery_items')
            .update({'quantity_unsold': update['quantity_unsold']})
            .eq('id', update['id']);
      }
    }
  }

  Future<Map<String, dynamic>> _prepareClaimData({
    required String vendorId,
    required List<String> deliveryIds,
    required DateTime claimDate,
    String? notes,
  }) async {
    final userId = SupabaseHelper.currentUserId!;
    final commissionRate = await _getVendorCommissionRate(vendorId, userId);
    final deliveryItems = await _getDeliveryItems(deliveryIds);
    
    // Auto-balance quantities
    await _autoBalanceQuantities(deliveryItems);

    // Calculate amounts
    double grossAmount = 0.0;
    for (var item in deliveryItems) {
      final sold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      grossAmount += sold * unitPrice;
    }

    final commissionAmount = grossAmount * (commissionRate / 100);
    final netAmount = grossAmount - commissionAmount;

    return {
      'userId': userId,
      'vendorId': vendorId,
      'deliveryIds': deliveryIds,
      'claimDate': claimDate,
      'notes': notes,
      'grossAmount': grossAmount,
      'commissionRate': commissionRate,
      'commissionAmount': commissionAmount,
      'netAmount': netAmount,
      'deliveryItems': deliveryItems,
    };
  }

  Future<ConsignmentClaim> _createClaimWithRetry(Map<String, dynamic> claimData) async {
    final userId = claimData['userId'] as String;
    final vendorId = claimData['vendorId'] as String;
    final claimDate = claimData['claimDate'] as DateTime;
    final grossAmount = claimData['grossAmount'] as double;
    final commissionRate = claimData['commissionRate'] as double;
    final commissionAmount = claimData['commissionAmount'] as double;
    final netAmount = claimData['netAmount'] as double;
    final notes = claimData['notes'] as String?;
    final deliveryItems = claimData['deliveryItems'] as List<Map<String, dynamic>>;

    // Create claim with retry logic
    Map<String, dynamic>? claimResponse;
    int retries = 5;
    Exception? lastError;

    while (retries > 0) {
      try {
        claimResponse = await supabase
            .from('consignment_claims')
            .insert({
              'business_owner_id': userId,
              'vendor_id': vendorId,
              'claim_date': claimDate.toIso8601String().split('T')[0],
              'status': 'draft',
              'gross_amount': grossAmount,
              'commission_rate': commissionRate,
              'commission_amount': commissionAmount,
              'net_amount': netAmount,
              'paid_amount': 0,
              'balance_amount': netAmount,
              'notes': notes,
            })
            .select()
            .single() as Map<String, dynamic>;

        break; // Success
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        final errorStr = e.toString().toLowerCase();

        final isDuplicateError = errorStr.contains('duplicate key') ||
            errorStr.contains('23505') ||
            errorStr.contains('409') ||
            errorStr.contains('claim_number') ||
            errorStr.contains('conflict') ||
            (e.toString().contains('PostgrestException') && errorStr.contains('unique'));

        if (isDuplicateError) {
          retries--;
          if (retries > 0) {
            final delayMs = 300 + (200 * (5 - retries));
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          } else {
            throw Exception(
              'Gagal mencipta tuntutan selepas beberapa percubaan. '
              'Nombor tuntutan mungkin konflik. Sila cuba lagi dalam beberapa saat.',
            );
          }
        }
        rethrow;
      }
    }

    if (claimResponse == null) {
      throw Exception('Gagal mencipta tuntutan: ${lastError?.toString() ?? "Ralat tidak diketahui"}');
    }

    final claimId = claimResponse['id'] as String;

    // Create claim items
    final claimItems = <Map<String, dynamic>>[];
    for (var item in deliveryItems) {
      final sold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      if (sold <= 0) continue;

      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final itemGross = sold * unitPrice;
      final itemCommission = itemGross * (commissionRate / 100);
      final itemNet = itemGross - itemCommission;

      claimItems.add({
        'claim_id': claimId,
        'delivery_id': item['delivery_id'],
        'delivery_item_id': item['id'],
        'quantity_delivered': item['quantity'],
        'quantity_sold': sold,
        'quantity_unsold': item['quantity_unsold'] ?? 0,
        'quantity_expired': item['quantity_expired'] ?? 0,
        'quantity_damaged': item['quantity_damaged'] ?? 0,
        'unit_price': unitPrice,
        'gross_amount': itemGross,
        'commission_rate': commissionRate,
        'commission_amount': itemCommission,
        'net_amount': itemNet,
        'paid_amount': 0,
        'balance_amount': itemNet,
        'carry_forward': false,
      });
    }

    if (claimItems.isEmpty) {
      throw Exception('Tiada item yang terjual untuk dituntut');
    }

    await supabase.from('consignment_claim_items').insert(claimItems);

    // Return full claim
    return await getClaimById(claimId);
  }

  String _buildInFilter(List<String> values) {
    return '(${values.map((v) => '"$v"').join(',')})';
  }

  // Keep existing methods for backward compatibility
  Future<ConsignmentClaim> getClaimById(String claimId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final claimResponse = await supabase
        .from('consignment_claims')
        .select('''
          *,
          vendors (id, name, phone)
        ''')
        .eq('id', claimId)
        .eq('business_owner_id', userId)
        .single();

    final claimJson = claimResponse as Map<String, dynamic>;
    final vendor = claimJson['vendors'] as Map<String, dynamic>?;

    final itemsResponse = await supabase
        .from('consignment_claim_items')
        .select('''
          *,
          delivery:vendor_deliveries(invoice_number),
          delivery_item:vendor_delivery_items(product_id, product_name)
        ''')
        .eq('claim_id', claimId);

    final items = (itemsResponse as List).map((itemJson) {
      final item = itemJson as Map<String, dynamic>;
      final delivery = item['delivery'] as Map<String, dynamic>?;
      final deliveryItem = item['delivery_item'] as Map<String, dynamic>?;
      return {
        ...item,
        'delivery_number': delivery?['invoice_number'],
        'product_id': deliveryItem?['product_id'],
        'product_name': deliveryItem?['product_name'],
      };
    }).toList();

    return ConsignmentClaim.fromJson({
      ...claimJson,
      'vendor_name': vendor?['name'],
      'items': items,
    });
  }

  // Add other existing methods here (submitClaim, approveClaim, etc.)
  // ... (keep existing implementation)
}


import '../../core/supabase/supabase_client.dart';
import '../models/consignment_payment.dart';
import '../models/consignment_claim.dart';

/// Consignment Payments Repository for Supabase
/// Works with consignment_payments and consignment_payment_allocations tables
class ConsignmentPaymentsRepositorySupabase {
  
  /// Get all payments
  Future<List<ConsignmentPayment>> getAll() async {
    try {
      final userId = SupabaseHelper.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await supabase
          .from('consignment_payments')
          .select('*')
          .eq('business_owner_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ConsignmentPayment.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get payments: $e');
    }
  }
  
  /// Create payment
  Future<ConsignmentPayment> createPayment({
    required String vendorId,
    required PaymentMethod paymentMethod,
    required DateTime paymentDate,
    required double totalAmount,
    List<String>? claimIds,
    String? claimId,
    List<String>? claimItemIds,
    String? paymentReference,
    String? notes,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Create payment
    final paymentResponse = await supabase
        .from('consignment_payments')
        .insert({
          'business_owner_id': userId,
          'vendor_id': vendorId,
          'payment_date': paymentDate.toIso8601String().split('T')[0],
          'payment_method': paymentMethod.toString().split('.').last,
          'total_amount': totalAmount,
          'payment_reference': paymentReference,
          'notes': notes,
        })
        .select()
        .single();

    final paymentId = (paymentResponse as Map<String, dynamic>)['id'] as String;

    // Auto-allocate based on payment method
    final allocations = <Map<String, dynamic>>[];

    if (paymentMethod == PaymentMethod.billToBill && claimIds != null && claimIds.isNotEmpty) {
      // Allocate to multiple claims proportionally
      final claimsResponse = await supabase
          .from('consignment_claims')
          .select('id, balance_amount')
          .eq('business_owner_id', userId)
          .inFilter('id', claimIds)
          .eq('status', 'approved');

      final claims = claimsResponse as List;
      double totalOutstanding = 0.0;
      for (var claim in claims) {
        totalOutstanding += ((claim as Map)['balance_amount'] as num?)?.toDouble() ?? 0.0;
      }

      if (totalOutstanding == 0) {
        throw Exception('No outstanding balance to allocate');
      }

      for (var claim in claims) {
        final claimMap = claim as Map<String, dynamic>;
        final balance = (claimMap['balance_amount'] as num?)?.toDouble() ?? 0.0;
        if (balance <= 0) continue;

        final proportion = balance / totalOutstanding;
        final allocated = (totalAmount * proportion).roundToDouble();
        final finalAllocated = allocated > balance ? balance : allocated;

        if (finalAllocated > 0) {
          allocations.add({
            'payment_id': paymentId,
            'claim_id': claimMap['id'],
            'allocated_amount': finalAllocated,
          });
        }
      }
    } else if (paymentMethod == PaymentMethod.perClaim && claimId != null) {
      // Allocate to single claim
      final claimResponse = await supabase
          .from('consignment_claims')
          .select('id, balance_amount')
          .eq('business_owner_id', userId)
          .eq('id', claimId)
          .eq('status', 'approved')
          .maybeSingle();

      if (claimResponse == null) {
        throw Exception('Approved claim not found');
      }

      final claim = claimResponse as Map<String, dynamic>;
      final balance = (claim['balance_amount'] as num?)?.toDouble() ?? 0.0;

      if (totalAmount > balance) {
        throw Exception('Payment amount exceeds claim balance');
      }

      allocations.add({
        'payment_id': paymentId,
        'claim_id': claim['id'],
        'allocated_amount': totalAmount,
      });
    } else if (paymentMethod == PaymentMethod.partial && claimId != null) {
      // Partial payment
      final claimResponse = await supabase
          .from('consignment_claims')
          .select('id, balance_amount')
          .eq('business_owner_id', userId)
          .eq('id', claimId)
          .maybeSingle();

      if (claimResponse == null) {
        throw Exception('Claim not found');
      }

      final claim = claimResponse as Map<String, dynamic>;
      final balance = (claim['balance_amount'] as num?)?.toDouble() ?? 0.0;

      if (totalAmount > balance) {
        throw Exception('Payment amount exceeds claim balance');
      }

      allocations.add({
        'payment_id': paymentId,
        'claim_id': claim['id'],
        'allocated_amount': totalAmount,
      });
    }
    // carry_forward doesn't create allocations yet

    // Insert allocations
    if (allocations.isNotEmpty) {
      await supabase.from('consignment_payment_allocations').insert(allocations);
    }

    // Return payment detail (claim balances auto-updated by trigger)
    return await getPaymentById(paymentId);
  }

  /// Allocate payment to claims
  Future<ConsignmentPayment> allocatePayment({
    required String paymentId,
    required List<Map<String, dynamic>> allocations,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Validate payment ownership
    final paymentResponse = await supabase
        .from('consignment_payments')
        .select('id, total_amount')
        .eq('business_owner_id', userId)
        .eq('id', paymentId)
        .maybeSingle();

    if (paymentResponse == null) {
      throw Exception('Payment not found');
    }

    final payment = paymentResponse as Map<String, dynamic>;
    final totalAmount = (payment['total_amount'] as num?)?.toDouble() ?? 0.0;

    // Validate allocations don't exceed payment amount
    double totalAllocated = 0.0;
    for (var alloc in allocations) {
      totalAllocated += (alloc['amount'] as num?)?.toDouble() ?? 0.0;
    }

    if (totalAllocated > totalAmount) {
      throw Exception('Total allocated amount exceeds payment amount');
    }

    // Validate claims exist
    final claimIds = allocations.map((a) => a['claimId'] as String).toList();
    final claimsResponse = await supabase
        .from('consignment_claims')
        .select('id, balance_amount, status')
        .eq('business_owner_id', userId)
        .inFilter('id', claimIds);

    final claims = claimsResponse as List;
    final claimsMap = <String, Map<String, dynamic>>{};
    for (var claim in claims) {
      final claimMap = claim as Map<String, dynamic>;
      claimsMap[claimMap['id'] as String] = claimMap;
    }

    for (var allocation in allocations) {
      final claimId = allocation['claimId'] as String;
      final amount = (allocation['amount'] as num?)?.toDouble() ?? 0.0;
      final claim = claimsMap[claimId];

      if (claim == null) {
        throw Exception('Claim $claimId not found');
      }

      final status = claim['status'] as String? ?? '';
      if (status != 'approved' && status != 'settled') {
        throw Exception('Claim $claimId must be approved before payment allocation');
      }

      final balance = (claim['balance_amount'] as num?)?.toDouble() ?? 0.0;
      if (amount > balance) {
        throw Exception('Allocated amount exceeds claim balance');
      }
    }

    // Delete existing allocations
    await supabase
        .from('consignment_payment_allocations')
        .delete()
        .eq('payment_id', paymentId);

    // Insert new allocations
    final allocationRows = allocations.map((alloc) {
      return {
        'payment_id': paymentId,
        'claim_id': alloc['claimId'],
        'claim_item_id': alloc['claimItemId'],
        'allocated_amount': alloc['amount'],
      };
    }).toList();

    await supabase.from('consignment_payment_allocations').insert(allocationRows);

    // Return payment detail (claim balances auto-updated by trigger)
    return await getPaymentById(paymentId);
  }

  /// List payments with filters
  Future<Map<String, dynamic>> listPayments({
    String? vendorId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    var query = supabase
        .from('consignment_payments')
        .select('''
          *,
          vendors (id, name, phone)
        ''')
        .eq('business_owner_id', userId);

    if (vendorId != null) {
      query = query.eq('vendor_id', vendorId);
    }
    if (fromDate != null) {
      query = query.gte('payment_date', fromDate.toIso8601String().split('T')[0]);
    }
    if (toDate != null) {
      query = query.lte('payment_date', toDate.toIso8601String().split('T')[0]);
    }

    final response = await query
        .order('payment_date', ascending: false)
        .range(offset, offset + limit - 1);

    final payments = (response as List).map((json) {
      final paymentJson = json as Map<String, dynamic>;
      final vendor = paymentJson['vendors'] as Map<String, dynamic>?;
      return ConsignmentPayment.fromJson({
        ...paymentJson,
        'vendor_name': vendor?['name'],
      });
    }).toList();

    final hasMore = payments.length == limit;

    return {
      'data': payments,
      'hasMore': hasMore,
      'total': offset + payments.length + (hasMore ? 1 : 0),
    };
  }

  /// Get payment by ID with allocations
  Future<ConsignmentPayment> getPaymentById(String paymentId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get payment
    final paymentResponse = await supabase
        .from('consignment_payments')
        .select('''
          *,
          vendors (id, name, phone)
        ''')
        .eq('id', paymentId)
        .eq('business_owner_id', userId)
        .single();

    final paymentJson = paymentResponse as Map<String, dynamic>;
    final vendor = paymentJson['vendors'] as Map<String, dynamic>?;

    // Get allocations
    final allocationsResponse = await supabase
        .from('consignment_payment_allocations')
        .select('''
          *,
          claim:consignment_claims(claim_number)
        ''')
        .eq('payment_id', paymentId);

    final allocations = (allocationsResponse as List).map((allocJson) {
      final alloc = allocJson as Map<String, dynamic>;
      final claim = alloc['claim'] as Map<String, dynamic>?;
      return {
        ...alloc,
        'claim_number': claim?['claim_number'],
      };
    }).toList();

    return ConsignmentPayment.fromJson({
      ...paymentJson,
      'vendor_name': vendor?['name'],
      'allocations': allocations,
    });
  }

  /// Get payments allocated to a specific claim (payment + allocated amount)
  Future<List<Map<String, dynamic>>> getPaymentsByClaim(String claimId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // 1) Get allocations for the claim
    final allocationsResponse = await supabase
        .from('consignment_payment_allocations')
        .select('payment_id, allocated_amount')
        .eq('claim_id', claimId);

    final allocations = allocationsResponse as List;
    if (allocations.isEmpty) return [];

    final paymentIds = allocations
        .map((a) => (a as Map<String, dynamic>)['payment_id'] as String)
        .toSet()
        .toList();

    // 2) Fetch payments in one query
    final paymentsResponse = await supabase
        .from('consignment_payments')
        .select('''
          *,
          vendors (id, name, phone)
        ''')
        .eq('business_owner_id', userId)
        .inFilter('id', paymentIds);

    final payments = paymentsResponse as List;
    final paymentsMap = <String, Map<String, dynamic>>{};
    for (var p in payments) {
      final pMap = p as Map<String, dynamic>;
      paymentsMap[pMap['id'] as String] = pMap;
    }

    // 3) Merge allocated_amount into payment info
    final result = <Map<String, dynamic>>[];
    for (var alloc in allocations) {
      final allocMap = alloc as Map<String, dynamic>;
      final paymentId = allocMap['payment_id'] as String;
      final payment = paymentsMap[paymentId];
      if (payment == null) continue;
      final vendor = payment['vendors'] as Map<String, dynamic>?;
      result.add({
        ...payment,
        'vendor_name': vendor?['name'],
        'allocated_amount': (allocMap['allocated_amount'] as num?)?.toDouble() ?? 0.0,
      });
    }

    // Sort by payment_date desc
    result.sort((a, b) {
      final da = DateTime.parse(a['payment_date'] as String);
      final db = DateTime.parse(b['payment_date'] as String);
      return db.compareTo(da);
    });

    return result;
  }

  /// Simple helper: record payment for a single claim (any status) and allocate fully
  Future<void> recordPaymentForClaim({
    required String claimId,
    required String vendorId,
    required double amount,
    required DateTime paymentDate,
    String? paymentReference,
    String? notes,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Insert payment with simple retry to avoid duplicate payment_number race (unique constraint)
    Map<String, dynamic>? paymentResponse;
    int retries = 5;
    bool usedFallbackNumber = false;

    while (true) {
      try {
        paymentResponse = await supabase
            .from('consignment_payments')
            .insert({
              'business_owner_id': userId,
              'vendor_id': vendorId,
              'payment_date': paymentDate.toIso8601String().split('T')[0],
              'payment_method': 'per_claim',
              'total_amount': amount,
              'payment_reference': paymentReference,
              'notes': notes,
              if (usedFallbackNumber)
                'payment_number':
                    'PAY-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch % 1000}',
            })
            .select()
            .single();
        break; // success
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final isDuplicate = msg.contains('23505') ||
            msg.contains('duplicate key') ||
            msg.contains('payment_number');
        if (isDuplicate && retries > 0) {
          retries--;
          // jitter retry
          await Future.delayed(
              Duration(milliseconds: 120 + (retries * 40)));
          // on final retry, force custom payment_number to avoid collision
          if (retries == 0 && !usedFallbackNumber) {
            usedFallbackNumber = true;
            retries = 1; // one final attempt with fallback number
          }
          continue;
        }
        rethrow;
      }
    }

    if (paymentResponse == null) {
      throw Exception('Gagal merekod bayaran: tiada respons daripada pelayan');
    }

    final paymentId = paymentResponse['id'] as String;

    // Insert allocation to the claim
    await supabase.from('consignment_payment_allocations').insert({
      'payment_id': paymentId,
      'claim_id': claimId,
      'allocated_amount': amount,
    });
  }

  /// Get outstanding balance for vendor
  Future<OutstandingBalance> getOutstandingBalance(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await supabase
        .from('consignment_claims')
        .select('id, claim_number, balance_amount')
        .eq('business_owner_id', userId)
        .eq('vendor_id', vendorId)
        .inFilter('status', ['approved', 'submitted'])
        .gt('balance_amount', 0)
        .order('claim_date', ascending: false);

    final claims = response as List;
    double totalOutstanding = 0.0;
    final outstandingClaims = <OutstandingClaim>[];

    for (var claim in claims) {
      final claimMap = claim as Map<String, dynamic>;
      final balance = (claimMap['balance_amount'] as num?)?.toDouble() ?? 0.0;
      totalOutstanding += balance;
      outstandingClaims.add(OutstandingClaim.fromJson({
        'claim_id': claimMap['id'],
        'claim_number': claimMap['claim_number'],
        'balance_amount': balance,
      }));
    }

    return OutstandingBalance(
      totalOutstanding: totalOutstanding,
      claims: outstandingClaims,
    );
  }
}


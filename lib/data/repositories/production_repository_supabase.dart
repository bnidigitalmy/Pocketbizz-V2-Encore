import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/production_batch.dart';

/// Production Repository for managing production batches
class ProductionRepository {
  final SupabaseClient _supabase;

  ProductionRepository(this._supabase);

  // ============================================================================
  // PRODUCTION BATCHES CRUD
  // ============================================================================

  /// Get all production batches
  Future<List<ProductionBatch>> getAllBatches({
    String? productId,
    bool onlyWithRemaining = false,
  }) async {
    try {
      dynamic query = _supabase
          .from('production_batches')
          .select();

      if (productId != null) {
        query = query.eq('product_id', productId);
      }

      if (onlyWithRemaining) {
        query = query.gt('remaining_qty', 0);
      }

      query = query.order('batch_date', ascending: false);

      final response = await query;
      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch production batches: $e');
    }
  }

  /// Get batch by ID
  Future<ProductionBatch?> getBatchById(String id) async {
    try {
      final response = await _supabase
          .from('production_batches')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? ProductionBatch.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch production batch: $e');
    }
  }

  /// Get recent batches (last N)
  Future<List<ProductionBatch>> getRecentBatches({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('production_batches')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recent batches: $e');
    }
  }

  /// Get batches by date range
  Future<List<ProductionBatch>> getBatchesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from('production_batches')
          .select()
          .gte('batch_date', startDate.toIso8601String().split('T')[0])
          .lte('batch_date', endDate.toIso8601String().split('T')[0])
          .order('batch_date', ascending: false);

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch batches by date range: $e');
    }
  }

  /// Record production batch (uses DB function - auto-deducts stock!)
  Future<String> recordProductionBatch(ProductionBatchInput input) async {
    try {
      final response = await _supabase.rpc(
        'record_production_batch',
        params: input.toJson(),
      );

      // Response is the batch ID
      return response as String;
    } catch (e) {
      throw Exception('Failed to record production batch: $e');
    }
  }

  /// Update batch (for corrections, not for stock deduction)
  Future<ProductionBatch> updateBatch(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final data = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('production_batches')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return ProductionBatch.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update production batch: $e');
    }
  }

  /// Update remaining quantity (used when selling from batch)
  Future<void> updateRemainingQty(String id, double newRemainingQty) async {
    try {
      await _supabase
          .from('production_batches')
          .update({
            'remaining_qty': newRemainingQty,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update remaining quantity: $e');
    }
  }

  /// Delete batch (hard delete - use carefully!)
  Future<void> deleteBatch(String id) async {
    try {
      await _supabase.from('production_batches').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete production batch: $e');
    }
  }

  // ============================================================================
  // FIFO OPERATIONS
  // ============================================================================

  /// Get oldest batches with remaining qty (for FIFO sales)
  Future<List<ProductionBatch>> getOldestBatchesForProduct(
    String productId, {
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('production_batches')
          .select()
          .eq('product_id', productId)
          .gt('remaining_qty', 0)
          .order('batch_date', ascending: true) // Oldest first
          .limit(limit);

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch oldest batches: $e');
    }
  }

  /// Deduct quantity from batch (FIFO)
  /// Returns remaining quantity to deduct if batch is fully consumed
  Future<double> deductFromBatch(String batchId, double quantity) async {
    try {
      final batch = await getBatchById(batchId);
      if (batch == null) {
        throw Exception('Batch not found');
      }

      final newRemaining = batch.remainingQty - quantity;

      if (newRemaining < 0) {
        // Batch fully consumed, return excess quantity
        await updateRemainingQty(batchId, 0);
        return -newRemaining; // Return positive excess
      } else {
        // Batch partially consumed
        await updateRemainingQty(batchId, newRemaining);
        return 0; // No excess
      }
    } catch (e) {
      throw Exception('Failed to deduct from batch: $e');
    }
  }

  /// Deduct quantity using FIFO (from oldest to newest)
  Future<List<Map<String, dynamic>>> deductFIFO(
    String productId,
    double quantityToDeduct,
  ) async {
    try {
      final batches = await getOldestBatchesForProduct(productId);
      final deductions = <Map<String, dynamic>>[];
      double remaining = quantityToDeduct;

      for (final batch in batches) {
        if (remaining <= 0) break;

        final deductedFromThis = remaining.clamp(0.0, batch.remainingQty);
        final excess = await deductFromBatch(batch.id, deductedFromThis);

        deductions.add({
          'batch_id': batch.id,
          'quantity_deducted': deductedFromThis,
          'cost_per_unit': batch.costPerUnit,
          'total_cost': deductedFromThis * batch.costPerUnit,
        });

        remaining = excess;
      }

      if (remaining > 0) {
        throw Exception(
          'Insufficient stock in batches. Remaining: $remaining',
        );
      }

      return deductions;
    } catch (e) {
      throw Exception('Failed to deduct FIFO: $e');
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get production statistics
  Future<Map<String, dynamic>> getProductionStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      dynamic query = _supabase.from('production_batches').select();

      if (startDate != null) {
        query = query.gte('batch_date', startDate.toIso8601String().split('T')[0]);
      }

      if (endDate != null) {
        query = query.lte('batch_date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query;
      final batches = (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();

      final totalBatches = batches.length;
      final totalUnitsProduced = batches.fold<int>(
        0,
        (sum, batch) => sum + batch.quantity,
      );
      final totalCost = batches.fold<double>(
        0.0,
        (sum, batch) => sum + batch.totalCost,
      );
      final totalRemaining = batches.fold<double>(
        0.0,
        (sum, batch) => sum + batch.remainingQty,
      );
      final expiredBatches = batches.where((b) => b.isExpired).length;

      return {
        'total_batches': totalBatches,
        'total_units_produced': totalUnitsProduced,
        'total_cost': totalCost,
        'total_remaining': totalRemaining,
        'expired_batches': expiredBatches,
        'avg_cost_per_batch':
            totalBatches > 0 ? totalCost / totalBatches : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get production statistics: $e');
    }
  }

  /// Get total remaining units for a product
  Future<double> getTotalRemainingForProduct(String productId) async {
    try {
      final batches = await getAllBatches(
        productId: productId,
        onlyWithRemaining: true,
      );

      return batches.fold<double>(
        0.0,
        (sum, batch) => sum + batch.remainingQty,
      );
    } catch (e) {
      throw Exception('Failed to get total remaining: $e');
    }
  }

  /// Get expired batches
  Future<List<ProductionBatch>> getExpiredBatches() async {
    try {
      final now = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('production_batches')
          .select()
          .not('expiry_date', 'is', null)
          .lt('expiry_date', now)
          .gt('remaining_qty', 0)
          .order('expiry_date', ascending: true);

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch expired batches: $e');
    }
  }
}


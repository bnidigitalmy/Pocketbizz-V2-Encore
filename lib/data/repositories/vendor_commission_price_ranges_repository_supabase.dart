import '../../core/supabase/supabase_client.dart';
import '../models/vendor_commission_price_range.dart';

/// Vendor Commission Price Ranges Repository
class VendorCommissionPriceRangesRepository {
  /// Get all price ranges for a vendor
  Future<List<VendorCommissionPriceRange>> getPriceRanges(String vendorId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('vendor_commission_price_ranges')
          .select()
          .eq('vendor_id', vendorId)
          .eq('business_owner_id', userId)
          .order('position');

      return (response as List)
          .map((json) => VendorCommissionPriceRange.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch price ranges: $e');
    }
  }

  /// Get commission amount for a specific price
  Future<double?> getCommissionForPrice(String vendorId, double retailPrice) async {
    try {
      final ranges = await getPriceRanges(vendorId);
      
      // Find the range that matches this price
      for (var range in ranges) {
        if (range.isPriceInRange(retailPrice)) {
          return range.commissionAmount;
        }
      }
      
      return null; // No matching range found
    } catch (e) {
      return null;
    }
  }

  /// Create price range
  Future<VendorCommissionPriceRange> createPriceRange({
    required String vendorId,
    required double minPrice,
    double? maxPrice,
    required double commissionAmount,
    int position = 0,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = {
        'vendor_id': vendorId,
        'business_owner_id': userId,
        'min_price': minPrice,
        'max_price': maxPrice,
        'commission_amount': commissionAmount,
        'position': position,
      };

      final response = await supabase
          .from('vendor_commission_price_ranges')
          .insert(data)
          .select()
          .single();

      return VendorCommissionPriceRange.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create price range: $e');
    }
  }

  /// Update price range
  Future<VendorCommissionPriceRange> updatePriceRange({
    required String id,
    double? minPrice,
    double? maxPrice,
    double? commissionAmount,
    int? position,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = <String, dynamic>{};
      if (minPrice != null) data['min_price'] = minPrice;
      if (maxPrice != null) data['max_price'] = maxPrice;
      if (commissionAmount != null) data['commission_amount'] = commissionAmount;
      if (position != null) data['position'] = position;
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await supabase
          .from('vendor_commission_price_ranges')
          .update(data)
          .eq('id', id)
          .eq('business_owner_id', userId)
          .select()
          .single();

      return VendorCommissionPriceRange.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update price range: $e');
    }
  }

  /// Delete price range
  Future<void> deletePriceRange(String id) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('vendor_commission_price_ranges')
          .delete()
          .eq('id', id)
          .eq('business_owner_id', userId);
    } catch (e) {
      throw Exception('Failed to delete price range: $e');
    }
  }

  /// Delete all price ranges for a vendor
  Future<void> deleteAllPriceRanges(String vendorId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('vendor_commission_price_ranges')
          .delete()
          .eq('vendor_id', vendorId)
          .eq('business_owner_id', userId);
    } catch (e) {
      throw Exception('Failed to delete price ranges: $e');
    }
  }
}


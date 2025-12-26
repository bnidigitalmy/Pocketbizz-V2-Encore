/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import '../../data/repositories/vendor_commission_price_ranges_repository_supabase.dart';

/// Utility class for calculating vendor price based on commission type
class VendorPriceCalculator {
  /// Calculate vendor price from retail price based on commission type
  /// 
  /// For percentage: vendorPrice = retailPrice - (retailPrice * commissionRate / 100)
  /// For price_range: vendorPrice = retailPrice - commissionAmount (from matching range)
  static Future<double> calculateVendorPrice({
    required String vendorId,
    required double retailPrice,
    required String commissionType,
    double? commissionRate, // For percentage type
  }) async {
    if (retailPrice <= 0) return retailPrice;

    if (commissionType == 'percentage') {
      // Percentage-based commission
      final rate = commissionRate ?? 0.0;
      if (rate <= 0) return retailPrice;
      
      final commission = retailPrice * (rate / 100);
      return retailPrice - commission;
    } else if (commissionType == 'price_range') {
      // Price range-based commission
      final priceRangesRepo = VendorCommissionPriceRangesRepository();
      final commissionAmount = await priceRangesRepo.getCommissionForPrice(vendorId, retailPrice);
      
      if (commissionAmount == null) {
        // No matching range found, return retail price (no commission)
        return retailPrice;
      }
      
      return retailPrice - commissionAmount;
    }

    // Unknown commission type, return retail price
    return retailPrice;
  }

  /// Calculate vendor price synchronously (for percentage type only)
  static double calculateVendorPriceSync({
    required double retailPrice,
    required String commissionType,
    double? commissionRate, // For percentage type
    double? commissionAmount, // For price_range type (if already fetched)
  }) {
    if (retailPrice <= 0) return retailPrice;

    if (commissionType == 'percentage') {
      final rate = commissionRate ?? 0.0;
      if (rate <= 0) return retailPrice;
      
      final commission = retailPrice * (rate / 100);
      return retailPrice - commission;
    } else if (commissionType == 'price_range') {
      if (commissionAmount == null) return retailPrice;
      return retailPrice - commissionAmount;
    }

    return retailPrice;
  }
}


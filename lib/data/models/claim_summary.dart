/// Summary of claim amounts for display in UI
class ClaimSummary {
  final double totalDeliveredValue;
  final double totalSoldValue;
  final double totalUnsoldValue;
  final double totalExpiredValue;
  final double totalDamagedValue;
  final double commissionRate;
  final double commissionAmount;
  final double netAmount;
  final int totalItems;
  final int totalDeliveries;
  final String? commissionType; // 'percentage' or 'price_range'
  final Map<double, double>? priceRangeCommissions; // For price_range type

  ClaimSummary({
    required this.totalDeliveredValue,
    required this.totalSoldValue,
    required this.totalUnsoldValue,
    required this.totalExpiredValue,
    required this.totalDamagedValue,
    required this.commissionRate,
    required this.commissionAmount,
    required this.netAmount,
    required this.totalItems,
    required this.totalDeliveries,
    this.commissionType,
    this.priceRangeCommissions,
  });

  /// Calculate summary from delivery items
  /// 
  /// For percentage commission: commissionRate is the percentage (e.g., 10.0 for 10%)
  /// For price_range commission: commissionRate is 0, and commissionAmount is calculated per item
  factory ClaimSummary.fromDeliveryItems({
    required List<Map<String, dynamic>> deliveryItems,
    required double commissionRate,
    String? commissionType, // 'percentage' or 'price_range'
    Map<double, double>? priceRangeCommissions, // Map of unit_price -> commission_amount
  }) {
    double totalDelivered = 0.0;
    double totalSold = 0.0;
    double totalUnsold = 0.0;
    double totalExpired = 0.0;
    double totalDamaged = 0.0;
    double totalCommission = 0.0;
    int itemCount = 0;

    for (var item in deliveryItems) {
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final sold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      final unsold = (item['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
      final expired = (item['quantity_expired'] as num?)?.toDouble() ?? 0.0;
      final damaged = (item['quantity_damaged'] as num?)?.toDouble() ?? 0.0;

      // unit_price is already consignment price (retail - commission)
      final itemDelivered = quantity * unitPrice;
      final itemSold = sold * unitPrice;

      totalDelivered += itemDelivered;
      totalSold += itemSold;
      totalUnsold += unsold * unitPrice;
      totalExpired += expired * unitPrice;
      totalDamaged += damaged * unitPrice;
      
      // Commission was already deducted in delivery, so commission = 0
      // No need to calculate commission again
      
      if (quantity > 0) itemCount++;
    }

    // grossAmount = totalSold (qty × unit_price where unit_price already has commission deducted)
    final grossAmount = totalSold;
    final netAmount = grossAmount; // net = gross because commission already deducted in delivery
    // totalCommission is already 0.0 (declared above) - commission already deducted in delivery

    return ClaimSummary(
      totalDeliveredValue: totalDelivered,
      totalSoldValue: totalSold,
      totalUnsoldValue: totalUnsold,
      totalExpiredValue: totalExpired,
      totalDamagedValue: totalDamaged,
      commissionRate: 0.0, // Commission already deducted in delivery
      commissionAmount: totalCommission, // 0.0
      netAmount: netAmount,
      totalItems: itemCount,
      totalDeliveries: 0, // Will be set separately
      commissionType: commissionType,
      priceRangeCommissions: priceRangeCommissions,
    );
  }
}


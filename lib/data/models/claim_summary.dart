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
  });

  /// Calculate summary from delivery items
  factory ClaimSummary.fromDeliveryItems({
    required List<Map<String, dynamic>> deliveryItems,
    required double commissionRate,
  }) {
    double totalDelivered = 0.0;
    double totalSold = 0.0;
    double totalUnsold = 0.0;
    double totalExpired = 0.0;
    double totalDamaged = 0.0;
    int itemCount = 0;

    for (var item in deliveryItems) {
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final sold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      final unsold = (item['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
      final expired = (item['quantity_expired'] as num?)?.toDouble() ?? 0.0;
      final damaged = (item['quantity_damaged'] as num?)?.toDouble() ?? 0.0;

      totalDelivered += quantity * unitPrice;
      totalSold += sold * unitPrice;
      totalUnsold += unsold * unitPrice;
      totalExpired += expired * unitPrice;
      totalDamaged += damaged * unitPrice;
      
      if (quantity > 0) itemCount++;
    }

    final grossAmount = totalSold;
    final commissionAmount = grossAmount * (commissionRate / 100);
    final netAmount = grossAmount - commissionAmount;

    return ClaimSummary(
      totalDeliveredValue: totalDelivered,
      totalSoldValue: totalSold,
      totalUnsoldValue: totalUnsold,
      totalExpiredValue: totalExpired,
      totalDamagedValue: totalDamaged,
      commissionRate: commissionRate,
      commissionAmount: commissionAmount,
      netAmount: netAmount,
      totalItems: itemCount,
      totalDeliveries: 0, // Will be set separately
    );
  }
}


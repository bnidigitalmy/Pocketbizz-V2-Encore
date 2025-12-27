/// Subscription Limit Exception
/// Thrown when user exceeds subscription usage limits
/// 
/// PHASE 3: Revenue leak stopper - prevents users from exceeding limits
class SubscriptionLimitException implements Exception {
  final String message;
  final String? limitType; // 'products', 'stock', 'transactions'
  final int? current;
  final int? max;

  SubscriptionLimitException(
    this.message, {
    this.limitType,
    this.current,
    this.max,
  });

  @override
  String toString() => message;

  /// Get user-friendly error message
  String get userMessage {
    if (limitType != null && current != null && max != null) {
      return 'Had $limitType telah dicapai ($current / $max). Upgrade untuk teruskan.';
    }
    return message;
  }
}




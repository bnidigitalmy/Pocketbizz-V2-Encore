import 'package:intl/intl.dart';

/// Subscription Payment Model
/// Represents a payment record for subscription
class SubscriptionPayment {
  final String id;
  final String subscriptionId;
  final String userId;
  final double amount;
  final String currency;
  final String paymentGateway;
  final String? paymentReference;
  final String? gatewayTransactionId;
  final String status;
  final String? failureReason;
  final String? paymentMethod;
  final int retryCount;
  final DateTime? lastRetryAt;
  final DateTime? paidAt;
  final String? receiptUrl;
  
  // Refund
  final double refundedAmount;
  final DateTime? refundedAt;
  final String? refundReason;
  final String? refundReference;
  final String? refundReceiptUrl;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionPayment({
    required this.id,
    required this.subscriptionId,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.paymentGateway,
    this.paymentReference,
    this.gatewayTransactionId,
    required this.status,
    this.failureReason,
    this.paymentMethod,
    this.retryCount = 0,
    this.lastRetryAt,
    this.paidAt,
    this.receiptUrl,
    this.refundedAmount = 0.0,
    this.refundedAt,
    this.refundReason,
    this.refundReference,
    this.refundReceiptUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionPayment.fromJson(Map<String, dynamic> json) {
    return SubscriptionPayment(
      id: json['id'] as String,
      subscriptionId: json['subscription_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'MYR',
      paymentGateway: json['payment_gateway'] as String? ?? 'bcl_my',
      paymentReference: json['payment_reference'] as String?,
      gatewayTransactionId: json['gateway_transaction_id'] as String?,
      status: json['status'] as String,
      failureReason: json['failure_reason'] as String?,
      paymentMethod: json['payment_method'] as String?,
      retryCount: (json['retry_count'] as int?) ?? 0,
      lastRetryAt: json['last_retry_at'] != null
          ? DateTime.parse(json['last_retry_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      receiptUrl: json['receipt_url'] as String?,
      refundedAmount: (json['refunded_amount'] as num?)?.toDouble() ?? 0.0,
      refundedAt: json['refunded_at'] != null
          ? DateTime.parse(json['refunded_at'] as String)
          : null,
      refundReason: json['refund_reason'] as String?,
      refundReference: json['refund_reference'] as String?,
      refundReceiptUrl: json['refund_receipt_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscription_id': subscriptionId,
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'payment_gateway': paymentGateway,
      'payment_reference': paymentReference,
      'gateway_transaction_id': gatewayTransactionId,
      'status': status,
      'failure_reason': failureReason,
      'payment_method': paymentMethod,
      'retry_count': retryCount,
      'last_retry_at': lastRetryAt?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'receipt_url': receiptUrl,
      'refunded_amount': refundedAmount,
      'refunded_at': refundedAt?.toIso8601String(),
      'refund_reason': refundReason,
      'refund_reference': refundReference,
      'refund_receipt_url': refundReceiptUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
  bool get isRefunded => status == 'refunded' || status == 'refunding';
  bool get hasRefund => refundedAmount > 0;
  bool get isFullRefund => refundedAmount >= amount;

  String get formattedAmount => 'RM ${amount.toStringAsFixed(2)}';

  String get formattedDate {
    final date = paidAt ?? createdAt;
    return DateFormat('dd MMM yyyy, hh:mm a', 'ms').format(date);
  }

  String get formattedDateShort {
    final date = paidAt ?? createdAt;
    return DateFormat('dd MMM yyyy', 'ms').format(date);
  }

  String get formattedPaymentMethod {
    final methodLabels = {
      'credit_card': 'Kad Kredit',
      'online_banking': 'Online Banking',
      'e_wallet': 'E-Wallet',
      'bank_transfer': 'Bank Transfer',
      'bcl_my': 'BCL.my',
    };
    if (paymentMethod != null) {
      final label = methodLabels[paymentMethod!.toLowerCase()];
      return label ?? paymentMethod!;
    }
    return paymentGateway;
  }
}


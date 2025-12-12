import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/models/subscription.dart';
import '../services/subscription_service.dart';

enum _PaymentStatus { processing, success, pending, failed }

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({super.key});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();

  _PaymentStatus _status = _PaymentStatus.processing;
  int _countdown = 5;
  int _elapsedMs = 0;
  bool _confirming = false;
  bool _confirmationTriggered = false;
  Subscription? _active;
  bool _isLoading = true;
  bool _unauthorized = false;
  Timer? _pollTimer;
  Timer? _elapsedTimer;
  Timer? _countdownTimer;
  RealtimeChannel? _subscriptionChannel;
  RealtimeChannel? _paymentChannel;

  String? _orderNumber;
  String? _amount;
  String? _gatewayRef;
  String? _statusId;
  String? _paymentMethod;

  @override
  void initState() {
    super.initState();
    _parseQuery();
    _startElapsedTimer();
    _setupRealtimeSubscription();
    _loadInitialData();
  }

  /// Setup Supabase realtime subscription for payment status updates
  void _setupRealtimeSubscription() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || _orderNumber == null) {
      // Fallback to polling if no order number
      _pollSubscription();
      return;
    }

    try {
      // Subscribe to subscriptions table changes
      _subscriptionChannel = supabase
          .channel('subscription_payment_${_orderNumber}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'payment_reference',
              value: _orderNumber,
            ),
            callback: (payload) {
              if (!mounted) return;
              _handleSubscriptionUpdate(payload.newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'payment_reference',
              value: _orderNumber,
            ),
            callback: (payload) {
              if (!mounted) return;
              _handleSubscriptionUpdate(payload.newRecord);
            },
          )
          .subscribe();

      // Subscribe to subscription_payments table changes for payment method
      _paymentChannel = supabase
          .channel('payment_details_${_orderNumber}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'subscription_payments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'payment_reference',
              value: _orderNumber,
            ),
            callback: (payload) {
              if (!mounted) return;
              _handlePaymentUpdate(payload.newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'subscription_payments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'payment_reference',
              value: _orderNumber,
            ),
            callback: (payload) {
              if (!mounted) return;
              _handlePaymentUpdate(payload.newRecord);
            },
          )
          .subscribe();

      print('✅ Realtime subscription setup for payment: $_orderNumber');
    } catch (e) {
      print('⚠️ Failed to setup realtime subscription, falling back to polling: $e');
      // Fallback to polling if realtime fails
      _pollSubscription();
    }
  }

  /// Handle subscription table update from realtime
  void _handleSubscriptionUpdate(Map<String, dynamic>? newRecord) async {
    if (newRecord == null) return;

    try {
      // Check if subscription is now active
      final status = newRecord['status'] as String?;
      if (status == 'active') {
        // Fetch full subscription details
        final sub = await _subscriptionService.getCurrentSubscription();
        if (!mounted) return;
        
        setState(() {
          _active = sub;
          _isLoading = false;
          _status = _PaymentStatus.success;
        });

        // Cancel polling and start countdown
        _pollTimer?.cancel();
        _startCountdown();
      } else if (status == 'pending_payment') {
        setState(() {
          _status = _PaymentStatus.pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error handling subscription update: $e');
    }
  }

  /// Handle payment table update from realtime
  void _handlePaymentUpdate(Map<String, dynamic>? newRecord) {
    if (newRecord == null) return;

    final status = newRecord['status'] as String?;
    final paymentMethod = newRecord['payment_method'] as String?;

    if (!mounted) return;

    setState(() {
      if (paymentMethod != null) {
        _paymentMethod = paymentMethod;
      }
      if (status == 'completed') {
        _status = _PaymentStatus.success;
      } else if (status == 'failed') {
        _status = _PaymentStatus.failed;
      }
    });
  }

  /// Load initial subscription and payment data
  Future<void> _loadInitialData() async {
    try {
      // Load current subscription
      final sub = await _subscriptionService.getCurrentSubscription();
      if (!mounted) return;

      setState(() {
        _active = sub != null && (sub.isActive || sub.status == SubscriptionStatus.active)
            ? sub
            : null;
        _isLoading = false;
        _status = _active != null ? _PaymentStatus.success : _PaymentStatus.processing;
      });

      if (_active != null) {
        _startCountdown();
      } else if (_orderNumber != null) {
        // Load payment details to get payment method
        _loadPaymentDetails();
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.toLowerCase().contains('unauthorized')) {
        if (!mounted) return;
        setState(() {
          _unauthorized = true;
          _isLoading = false;
          _status = _PaymentStatus.pending;
        });
      }
    }
  }

  /// Load payment details to get payment method
  Future<void> _loadPaymentDetails() async {
    final orderNumber = _orderNumber;
    if (orderNumber == null) return;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('subscription_payments')
          .select('payment_method, status')
          .eq('payment_reference', orderNumber)
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _paymentMethod = response['payment_method'] as String?;
          final status = response['status'] as String?;
          if (status == 'completed') {
            _status = _PaymentStatus.success;
          } else if (status == 'failed') {
            _status = _PaymentStatus.failed;
          }
        });
      }
    } catch (e) {
      print('Error loading payment details: $e');
    }
  }

  void _parseQuery() {
    final params = Uri.base.queryParameters;
    _orderNumber = params['order'] ?? params['order_number'] ?? params['order_id'];
    _amount = params['amount'];
    _gatewayRef = params['refno'] ?? params['billcode'];
    _statusId = params['status_id'] ?? params['status'];

    // Map status from gateway (fallback to pending if not provided)
    switch (_statusId) {
      case '1': // success
        _status = _PaymentStatus.success;
        break;
      case '3': // failed
        _status = _PaymentStatus.failed;
        break;
      case '2': // pending
        _status = _PaymentStatus.pending;
        break;
      default:
        _status = _PaymentStatus.processing;
    }

    // Always try confirm if we have order number (handles BCL callbacks without status_id)
    if (_orderNumber != null && _status != _PaymentStatus.failed) {
      _confirmPaymentIfNeeded();
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedMs += 2000;
      });
      if (_elapsedMs >= 30000) {
        _elapsedTimer?.cancel();
        _pollTimer?.cancel();
        if (_active == null && !_unauthorized) {
          _navigateTo('/subscription');
        }
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown <= 0) {
        timer.cancel();
        _navigateTo('/subscription');
        return;
      }
      setState(() {
        _countdown--;
      });
    });
  }

  /// Fallback polling (only used if realtime fails or as backup)
  Future<void> _pollSubscription() async {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final sub = await _subscriptionService.getCurrentSubscription();
        if (!mounted) return;
        setState(() {
          _active = sub != null && (sub.isActive || sub.status == SubscriptionStatus.active)
              ? sub
              : null;
          _isLoading = false;
          _status = _active != null ? _PaymentStatus.success : _PaymentStatus.processing;
        });
        if (_active != null) {
          _pollTimer?.cancel();
          _startCountdown();
        }
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('401') || msg.toLowerCase().contains('unauthorized')) {
          if (!mounted) return;
          setState(() {
            _unauthorized = true;
            _isLoading = false;
            _status = _PaymentStatus.pending;
          });
          _pollTimer?.cancel();
        }
      }
    });
  }

  Future<void> _confirmPaymentIfNeeded() async {
    if (_confirmationTriggered) return;
    if (_orderNumber == null) return;
    _confirmationTriggered = true;
    try {
      setState(() {
        _confirming = true;
      });
      await _subscriptionService.confirmPendingPayment(
        orderId: _orderNumber!,
        gatewayTransactionId: _gatewayRef,
      );
      // After confirmation, force refresh immediately
      await _pollSubscription();
    } catch (e) {
      // Ignore errors here; polling will continue or unauthorized will be handled
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
        });
      }
    }
  }

  void _navigateTo(String route) {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    _countdownTimer?.cancel();
    _subscriptionChannel?.unsubscribe();
    _paymentChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSuccess = _status == _PaymentStatus.success && _active != null;
    final showPending = _status == _PaymentStatus.pending || _status == _PaymentStatus.processing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildHeader(showSuccess, showPending),
                const SizedBox(height: 16),
                _buildPaymentDetails(),
                const SizedBox(height: 16),
                _buildActivationStatus(showSuccess, showPending),
                const SizedBox(height: 16),
                _buildActions(showSuccess),
                const SizedBox(height: 16),
                _buildHelpText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool showSuccess, bool showPending) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (showSuccess) {
      icon = Icons.check_circle;
      color = Colors.green;
      title = 'Pembayaran Berjaya!';
      subtitle = 'Terima kasih atas pembayaran anda';
    } else if (_status == _PaymentStatus.failed) {
      icon = Icons.error;
      color = AppColors.error;
      title = 'Pembayaran Gagal';
      subtitle = 'Sila cuba lagi atau hubungi sokongan.';
    } else {
      icon = Icons.schedule;
      color = Colors.orange;
      title = 'Sedang Diproses';
      subtitle = 'Sistem sedang mengesahkan pembayaran anda.';
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 48, color: color),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaymentDetails() {
    if (_orderNumber == null && _amount == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maklumat Pembayaran',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (_orderNumber != null) _buildDetailRow('Order Number', _orderNumber!),
          if (_amount != null) _buildDetailRow('Jumlah Dibayar', 'RM $_amount'),
          if (_paymentMethod != null) _buildDetailRow('Kaedah Pembayaran', _formatPaymentMethod(_paymentMethod!)),
          if (_gatewayRef != null) _buildDetailRow('Rujukan Gateway', _gatewayRef!),
        ],
      ),
    );
  }

  String _formatPaymentMethod(String method) {
    final methodLabels = {
      'credit_card': 'Kad Kredit',
      'online_banking': 'Online Banking',
      'e_wallet': 'E-Wallet',
      'bank_transfer': 'Bank Transfer',
      'bcl_my': 'BCL.my',
    };
    return methodLabels[method.toLowerCase()] ?? method;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationStatus(bool showSuccess, bool showPending) {
    if (_unauthorized) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: AppColors.info, size: 18),
              SizedBox(width: 6),
              Text('Sila log masuk untuk semak status', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Pembayaran diterima. Sila log masuk semula untuk melihat status aktivasi.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    if (_isLoading) {
      return Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Sedang mengaktifkan akaun anda...', style: TextStyle(fontSize: 13)),
        ],
      );
    }

    if (showSuccess && _active != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 18),
              SizedBox(width: 6),
              Text('Akaun telah diaktifkan!', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Langganan: ${_active!.planName}\nTempoh: ${_active!.durationMonths} bulan',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Redirect ke Subscription dalam $_countdown saat...',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    if (showPending) {
      final elapsedSeconds = (_elapsedMs / 1000).floor();
      final progress = (elapsedSeconds / 30).clamp(0.0, 1.0);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.hourglass_top, color: AppColors.info, size: 18),
              SizedBox(width: 6),
              Text('Menunggu pengesahan pembayaran...', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          // Progress indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _confirming
                        ? 'Sedang mengesahkan pembayaran...'
                        : 'Sistem sedang memproses pembayaran anda',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${elapsedSeconds}s / 30s',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.8 ? AppColors.warning : AppColors.primary,
                ),
                minHeight: 6,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pembayaran anda sedang diproses. Akaun akan diaktifkan secara automatik dalam masa 1-2 minit.',
                    style: TextStyle(fontSize: 11, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActions(bool showSuccess) {
    if (_unauthorized) {
      return ElevatedButton(
        onPressed: () => _navigateTo('/login'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        child: const Text('Login Ke Akaun'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => _navigateTo('/subscription'),
          style: ElevatedButton.styleFrom(
            backgroundColor: showSuccess ? AppColors.primary : Colors.white,
            foregroundColor: showSuccess ? Colors.white : AppColors.textPrimary,
            side: showSuccess ? null : const BorderSide(color: AppColors.primary),
          ),
          child: Text(showSuccess ? 'Lihat Subscription' : 'Semak Status'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _navigateTo('/home'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: Colors.grey),
          ),
          child: const Text('Ke Dashboard'),
        ),
      ],
    );
  }

  Widget _buildHelpText() {
    return Column(
      children: [
        const Text(
          'Jika akaun anda tidak diaktifkan dalam 5 minit, sila hubungi support.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          'Ref: ${_orderNumber ?? 'N/A'}',
          style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontFamily: 'monospace'),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}


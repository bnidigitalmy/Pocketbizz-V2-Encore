/// Expired Subscription Banner Widget
/// Shows global banner when subscription is expired
/// PHASE: Subscriber Expired System - UX Copy Lengkap
/// 
/// 🟡 A. TOP BANNER (GLOBAL)
/// Trigger: subscription = expired
/// 
/// Title: "Akaun dalam Mod Baca Sahaja"
/// Body: "Langganan PocketBizz anda telah tamat. Data anda selamat & masih boleh dilihat."
/// CTA: 🔓 Aktifkan Semula | 📤 Export Data

import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../data/models/subscription.dart';
import '../../../core/theme/app_colors.dart';
import '../presentation/subscription_page.dart';

/// Global expired banner that appears at top of app
/// Shows when subscription is expired (not in grace period)
class ExpiredBanner extends StatelessWidget {
  const ExpiredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Subscription?>(
      future: SubscriptionService().getCurrentSubscription(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        final subscription = snapshot.data;
        
        // Show if account is in read-only mode (no active access) and not currently in payment flow.
        // We intentionally don't rely only on DB status, because status transitions may lag behind time.
        final isExpired = subscription != null &&
            !subscription.isActive &&
            !subscription.isOnTrial &&
            subscription.status != SubscriptionStatus.pendingPayment;

        if (!isExpired) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.orange.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Akaun dalam Mod Baca Sahaja',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Langganan PocketBizz anda telah tamat. Data anda selamat & masih boleh dilihat.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // CTA Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: const Text('Aktifkan'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade900,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}




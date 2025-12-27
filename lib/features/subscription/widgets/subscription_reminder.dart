/// Subscription Reminder Widget
/// PHASE: Subscriber Expired System - Soft Reminders
/// 
/// 🔵 D. REMINDER COPY (SOFT)
/// D-3: "⏰ Langganan PocketBizz akan tamat dalam 3 hari. Elakkan gangguan operasi bisnes anda."
/// D-0: "Akaun kini dalam mod baca sahaja. Aktifkan semula bila-bila masa."

import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../data/models/subscription.dart';
import '../../../core/theme/app_colors.dart';
import '../presentation/subscription_page.dart';

/// Shows reminder banner when subscription is expiring soon or expired
class SubscriptionReminder extends StatelessWidget {
  const SubscriptionReminder({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Subscription?>(
      future: SubscriptionService().getCurrentSubscription(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        final subscription = snapshot.data;
        if (subscription == null) return const SizedBox.shrink();

        // D-3: Expiring in 3 days or less (but not expired yet)
        if (subscription.isExpiringSoon && subscription.isActive) {
          final daysRemaining = subscription.daysRemaining;
          if (daysRemaining <= 3 && daysRemaining > 0) {
            return _buildD3Reminder(context, daysRemaining);
          }
        }

        // D-0: Just expired (not in grace)
        if (subscription.status == SubscriptionStatus.expired && 
            !subscription.isActive) {
          return _buildD0Reminder(context);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildD3Reminder(BuildContext context, int daysRemaining) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '⏰ Langganan PocketBizz akan tamat dalam $daysRemaining hari',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elakkan gangguan operasi bisnes anda.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPage(),
                ),
              );
            },
            child: const Text('Renew'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildD0Reminder(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Akaun kini dalam mod baca sahaja. Aktifkan semula bila-bila masa.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPage(),
                ),
              );
            },
            child: const Text('Aktifkan'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}




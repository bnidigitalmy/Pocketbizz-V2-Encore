/// Subscription Success Message
/// PHASE: Subscriber Expired System - Instant Unlock Message
/// 
/// 🟢 C. SUCCESS MESSAGE (LEPAS RENEW)
/// "🎉 Langganan Aktif Semula! Semua fungsi PocketBizz telah dibuka. Terima kasih kerana bersama kami 💙"
/// 
/// (Tutup modal → terus guna, no refresh, no logout)

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Show success message after subscription reactivation
/// Instant unlock - no refresh, no logout needed
class SubscriptionSuccessMessage {
  static void show(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🎉 Langganan Aktif Semula!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Semua fungsi PocketBizz telah dibuka. Terima kasih kerana bersama kami 💙',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}




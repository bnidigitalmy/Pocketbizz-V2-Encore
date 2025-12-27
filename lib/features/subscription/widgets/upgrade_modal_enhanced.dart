/// Enhanced Upgrade Modal
/// PHASE: Subscriber Expired System - High Conversion Modal
/// 
/// 🧠 MODAL STRUCTURE:
/// - Header: "Langganan Tamat"
/// - Content: Benefits (Data selamat, Export, Instant activation)
/// - Plan Card: Single plan (less thinking = higher conversion)
/// - CTA: "Aktifkan Sekarang" | "Nanti Dulu"

import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../data/models/subscription.dart';
import '../data/models/subscription_plan.dart';
import '../../../core/theme/app_colors.dart';
import '../presentation/subscription_page.dart';

/// Enhanced upgrade modal with high-conversion design
/// Shows when user tries to perform action that requires active subscription
class UpgradeModalEnhanced {
  /// Show upgrade modal with action context
  static Future<void> show(
    BuildContext context, {
    required String action,
    Subscription? subscription,
  }) async {
    final service = SubscriptionService();
    final plans = await service.getAvailablePlans();
    final isEarlyAdopter = await service.isEarlyAdopter();
    
    // Get recommended plan (1 month plan)
    final recommendedPlan = plans.firstWhere(
      (p) => p.durationMonths == 1,
      orElse: () => plans.first,
    );

    final pricePerMonth = isEarlyAdopter ? 29.0 : recommendedPlan.pricePerMonth;
    final totalPrice = isEarlyAdopter 
        ? recommendedPlan.getPriceForEarlyAdopter() 
        : recommendedPlan.totalPrice;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Langganan Tamat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content - Benefits
              _buildBenefitsSection(),
              const SizedBox(height: 20),

              // Plan Card
              _buildPlanCard(
                context,
                recommendedPlan,
                pricePerMonth,
                totalPrice,
                isEarlyAdopter,
              ),
              const SizedBox(height: 24),

              // CTA Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Nanti Dulu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubscriptionPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Aktifkan Sekarang',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildBenefitsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBenefitItem(
            Icons.check_circle,
            'Data masih selamat',
            'Semua data anda kekal dan boleh diakses',
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            Icons.file_download,
            'Boleh export & backup',
            'Export data anda dalam format CSV/PDF',
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            Icons.flash_on,
            'Aktif serta-merta',
            'Selepas bayaran, semua fungsi dibuka',
          ),
        ],
      ),
    );
  }

  static Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildPlanCard(
    BuildContext context,
    SubscriptionPlan plan,
    double pricePerMonth,
    double totalPrice,
    bool isEarlyAdopter,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.primary.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isEarlyAdopter)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Early Adopter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RM${pricePerMonth.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ bulan',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFeatureItem('Unlimited produk'),
          _buildFeatureItem('Inventory & sales automation'),
          _buildFeatureItem('Report & export'),
        ],
      ),
    );
  }

  static Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.check,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}




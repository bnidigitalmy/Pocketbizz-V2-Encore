import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/api/models/inventory_models.dart';
import '../../../../core/widgets/section_header.dart';

class LowStockList extends StatelessWidget {
  const LowStockList({
    super.key,
    required this.items,
  });

  final List<InventorySnapshot> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Low Stock Alerts'),
            const SizedBox(height: 12),
            Column(
              children: items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Product ${item.productId}'),
                      subtitle: Text(
                        'Available: ${item.availableQuantity.toStringAsFixed(1)}',
                      ),
                      trailing: Chip(
                        label: Text('Threshold ${item.threshold.toStringAsFixed(0)}'),
                        backgroundColor: AppColors.danger.withOpacity(0.1),
                        labelStyle: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}


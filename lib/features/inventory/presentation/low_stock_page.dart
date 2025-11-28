import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory_controller.dart';

class LowStockPage extends ConsumerWidget {
  const LowStockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(lowStockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Low Stock Alerts')),
      body: lowStock.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('All good! No low-stock items.'));
          }
          return ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text('Product ${item.productId}'),
                  subtitle: Text(
                    'Available: ${item.availableQuantity.toStringAsFixed(1)} / Threshold ${item.threshold}',
                  ),
                  trailing: const Icon(Icons.warning_amber, color: Colors.red),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


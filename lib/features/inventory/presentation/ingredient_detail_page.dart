import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/presentation/products_controller.dart';
import 'inventory_controller.dart';
import 'widgets/batch_card.dart';

class IngredientDetailPage extends ConsumerWidget {
  const IngredientDetailPage({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsListControllerProvider);
    final product = productsState.products
        ?.firstWhere((p) => p.id == productId, orElse: () => null);
    final batches = ref
            .watch(inventoryListControllerProvider)
            .batches
            ?.where((batch) => batch.productId == productId)
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: Text(product?.name ?? 'Ingredient Detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(product?.name ?? productId),
              subtitle: Text(product?.description ?? 'No description'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Sale RM ${product?.salePrice.toStringAsFixed(2) ?? '-'}'),
                  Text('Cost RM ${product?.costPrice.toStringAsFixed(2) ?? '-'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Batches',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (batches.isEmpty)
            const Text('No batches for this ingredient.')
          else
            ...batches.map(
              (batch) => BatchCard(batch: batch),
            ),
        ],
      ),
    );
  }
}


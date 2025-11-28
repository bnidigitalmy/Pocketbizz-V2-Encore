import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory_controller.dart';
import 'widgets/batch_card.dart';

class InventoryListPage extends ConsumerWidget {
  const InventoryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(inventoryListControllerProvider.notifier)
                .load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed('/inventory/add'),
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (_) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(child: Text(state.error!));
          }
          final batches = state.batches!;
          if (batches.isEmpty) {
            return const Center(child: Text('No inventory batches yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (_, index) => BatchCard(
              batch: batches[index],
              onTap: () => Navigator.of(context).pushNamed(
                '/inventory/${batches[index].productId}',
              ),
            ),
          );
        },
      ),
    );
  }
}


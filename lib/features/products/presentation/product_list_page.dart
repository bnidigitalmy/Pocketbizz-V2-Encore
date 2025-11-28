import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../products_providers.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productsModuleListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(productsModuleListControllerProvider.notifier)
                .load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
              Navigator.of(context).pushNamed('/products/add');
        },
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
          final products = state.products!;
          if (products.isEmpty) {
            return const Center(child: Text('No products yet.'));
          }
          return ListView.separated(
            itemCount: products.length,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final product = products[index];
              return Card(
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text('RM ${product.salePrice.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () => ref
                        .read(productsModuleListControllerProvider.notifier)
                        .deleteProduct(product.id),
                  ),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      '/products/${product.id}',
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/models/product_models.dart';
import '../products_providers.dart';
import 'widgets/product_form.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({
    super.key,
    this.productId,
  });

  final String? productId;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.productId == null ? 'Add Product' : 'Edit Product';
    final productAsync = widget.productId == null
        ? const AsyncValue<Product?>.data(null)
        : ref.watch(productDetailControllerProvider(widget.productId!));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (product) => Padding(
          padding: const EdgeInsets.all(16),
          child: ProductForm(
            initial: product,
            onSubmit: (request) async {
              setState(() => _isSaving = true);
              try {
                final repo = ref.read(productsModuleRepositoryProvider);
                if (widget.productId == null) {
                  await repo.createProduct(request);
                } else {
                  await repo.updateProduct(
                    ProductUpdate(
                      id: widget.productId!,
                      sku: request.sku,
                      name: request.name,
                      unit: request.unit,
                      costPrice: request.costPrice,
                      salePrice: request.salePrice,
                      category: request.category,
                      description: request.description,
                    ),
                  );
                }
                if (!mounted) return;
                Navigator.of(context).pop(true);
              } finally {
                if (mounted) {
                  setState(() => _isSaving = false);
                }
              }
            },
          ),
        ),
      ),
      bottomNavigationBar: _isSaving
          ? const LinearProgressIndicator(minHeight: 2)
          : const SizedBox.shrink(),
    );
  }
}


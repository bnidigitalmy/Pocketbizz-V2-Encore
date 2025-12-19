import 'package:flutter/material.dart';
import '../../../../data/models/product.dart';
import '../../data/models/cart_item.dart';
import 'pos_product_card.dart';

/// POS Product Grid Widget
/// Displays products in 2x2 grid layout optimized for fast selection
class PosProductGrid extends StatelessWidget {
  final List<Product> products;
  final Map<String, double> stockCache; // productId -> availableStock
  final Map<String, CartItem> cart; // productId -> CartItem
  final Function(Product) onProductTap;

  const PosProductGrid({
    super.key,
    required this.products,
    required this.stockCache,
    required this.cart,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Tiada produk tersedia',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75, // Tall cards for images
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final availableStock = stockCache[product.id] ?? 0.0;
        final cartItem = cart[product.id];
        final cartQuantity = cartItem?.quantity.toInt();

        return PosProductCard(
          product: product,
          availableStock: availableStock,
          cartQuantity: cartQuantity,
          onTap: () => onProductTap(product),
        );
      },
    );
  }
}


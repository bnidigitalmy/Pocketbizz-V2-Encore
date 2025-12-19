import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/cart_item.dart';

/// POS Cart Item Widget
/// Displays cart item with inline quantity controls (+ / -)
class PosCartItem extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onRemove;

  const PosCartItem({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey[400],
                            size: 24,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.grey[400],
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Quantity Controls
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Decrement Button
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: item.canDecrement
                        ? () {
                            HapticFeedback.selectionClick();
                            onDecrement();
                          }
                        : null,
                    color: item.canDecrement ? Colors.red : Colors.grey,
                  ),
                  // Quantity Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    constraints: const BoxConstraints(minWidth: 40),
                    child: Text(
                      item.quantity.toStringAsFixed(0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Increment Button
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: item.canIncrement
                        ? () {
                            HapticFeedback.selectionClick();
                            onIncrement();
                          }
                        : null,
                    color: item.canIncrement ? Theme.of(context).colorScheme.primary : Colors.grey,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Subtotal
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM${item.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                if (!item.canIncrement && item.quantity >= item.availableStock)
                  Text(
                    'Max',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[700],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


import '../../../../data/models/product.dart';

class CartItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final String? imageUrl;
  double quantity;
  final double availableStock;

  CartItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.imageUrl,
    required this.quantity,
    required this.availableStock,
  });

  double get subtotal => unitPrice * quantity;

  bool get canIncrement => quantity < availableStock;

  bool get canDecrement => quantity > 0;

  void increment() {
    if (canIncrement) quantity++;
  }

  bool decrement() {
    if (quantity > 0) {
      quantity--;
      return true;
    }
    return false;
  }

  Map<String, dynamic> toApiFormat() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'price': unitPrice,
      'subtotal': subtotal,
    };
  }
}

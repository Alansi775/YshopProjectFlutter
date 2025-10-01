// lib/models/cart_item_model.dart

import 'package:yshop/models/product.dart'; // تأكد من المسار الصحيح

class CartItemModel {
  final Product product;
  int quantity;

  CartItemModel({
    required this.product,
    required this.quantity,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      // يجب أن تتأكد أن دالة Product.fromJson() موجودة في ملف Product.dart
      product: Product.fromJson(json['product']), 
      quantity: json['quantity'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // يجب أن تتأكد أن دالة product.toJson() موجودة في ملف Product.dart
      'product': product.toJson(), 
      'quantity': quantity,
    };
  }
}
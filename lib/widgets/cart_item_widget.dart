// lib/widgets/cart_item_widget.dart (تم تصحيحه)

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // <--- تم إصلاح الخطأ 
import '../state_management/cart_manager.dart';
import '../models/cart_item_model.dart'; // <--- تم إصلاح الخطأ

class CartItemWidget extends StatelessWidget {
  final CartItemModel item; // <--- تم إصلاح خطأ نوع البيانات
  
  const CartItemWidget({Key? key, required this.item}) : super(key: key);

  TextStyle _getTenorSansStyle(double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    return TextStyle(
      fontFamily: 'TenorSans', 
      fontSize: size,
      fontWeight: weight,
      color: color ?? Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context, listen: false);
    
    // استخدام NumberFormat بشكل صحيح
    final String priceFormatted = NumberFormat.currency(symbol: '\$').format(item.product.price); 

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          // تم تغيير 'radius' إلى 'blurRadius'
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2)), 
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... (بقية كود الصورة)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.product.imageUrl,
              fit: BoxFit.cover,
              width: 80,
              height: 80,
              placeholder: (context, url) => Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade300,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade300,
                child: const Icon(Icons.error_outline, size: 40, color: Colors.grey),
              ),
            ),
          ),
          
          const SizedBox(width: 15),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Product Name
                Text(
                  item.product.name,
                  style: _getTenorSansStyle(16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                // Price
                Text(
                  priceFormatted,
                  style: _getTenorSansStyle(14).copyWith(color: Colors.grey.shade600),
                ),
                
                const SizedBox(height: 8),

                // Quantity Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // زر Minus
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        // استخدام removeFromCart إذا كانت الكمية 1، وإلا نقوم بـ addToCart بـ -1
                        if (item.quantity <= 1) {
                             cartManager.removeFromCart(item.product); // <--- تم إصلاح اسم الدالة
                        } else {
                            cartManager.addToCart(product: item.product, quantity: -1);
                        }
                      },
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "${item.quantity}",
                        style: _getTenorSansStyle(16, weight: FontWeight.w600),
                      ),
                    ),
                    
                    // زر Plus
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        cartManager.addToCart(product: item.product, quantity: 1);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 3. Remove Button (Trash)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              cartManager.removeFromCart(item.product); // <--- تم إصلاح اسم الدالة
            },
          ),
        ],
      ),
    );
  }
}
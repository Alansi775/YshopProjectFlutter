// lib/widgets/checkout_item_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/cart_item_model.dart';

class CheckoutItemWidget extends StatelessWidget {
  final CartItemModel item;

  const CheckoutItemWidget({Key? key, required this.item}) : super(key: key);

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
    // تنسيق السعر لعرضه بشكل فردي
    final String priceFormatted = NumberFormat.currency(symbol: '\$').format(item.product.price);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. الصورة (AsyncImage في Swift)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: item.product.imageUrl,
              fit: BoxFit.cover,
              width: 60,
              height: 60,
              placeholder: (context, url) => Container(
                width: 60, height: 60, color: Colors.grey.shade300,
              ),
              errorWidget: (context, url, error) => Container(
                width: 60, height: 60, color: Colors.grey.shade300, child: const Icon(Icons.error),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 2. الاسم والتفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: _getTenorSansStyle(16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // (item.count) × (item.product.price)
                Text(
                  "${item.quantity} × $priceFormatted",
                  style: _getTenorSansStyle(14).copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          
          // 3. مسافة (Spacer في Swift)
          const SizedBox(width: 8), 
        ],
      ),
    );
  }
}
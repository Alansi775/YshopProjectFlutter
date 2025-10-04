// lib/widgets/checkout_item_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/cart_item_model.dart';

class CheckoutItemWidget extends StatelessWidget {
  final CartItemModel item;

  const CheckoutItemWidget({Key? key, required this.item}) : super(key: key);

  // 💡 تم تعديل الدالة لتقبل context وتستخدم primaryColor افتراضيًا
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return TextStyle(
      fontFamily: 'TenorSans', 
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
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
                width: 60, height: 60, color: secondaryColor.withOpacity(0.1), // 💡 لون ديناميكي
              ),
              errorWidget: (context, url, error) => Container(
                width: 60, height: 60, color: secondaryColor.withOpacity(0.1), 
                child: Icon(Icons.error, color: secondaryColor), // 💡 لون ديناميكي
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
                  style: _getTenorSansStyle(context, 16), // 💡 تمرير context
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // (item.count) × (item.product.price)
                Text(
                  "${item.quantity} × $priceFormatted",
                  // 💡 استخدام secondaryColor
                  style: _getTenorSansStyle(context, 14).copyWith(color: secondaryColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          
          // 3. مسافة
          const SizedBox(width: 8), 
        ],
      ),
    );
  }
}
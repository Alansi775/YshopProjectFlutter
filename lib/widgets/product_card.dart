// lib/widgets/product_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import './custom_form_widgets.dart'; // للوصول إلى primaryText و secondaryText
import './shimmer_effect.dart'; // لتأثير Shimmer أثناء التحميل

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({Key? key, required this.product, required this.onTap}) : super(key: key);

  // لافتراض وجود المتغيرات
  final Color primaryText = Colors.black;
  final Color secondaryText = Colors.grey;

  Widget _buildImagePlaceholder() {
    return ShimmerEffect(
      child: Container(
        height: 120,
        color: Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 120,
                placeholder: (context, url) => _buildImagePlaceholder(),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                  ),
                ),
              ),
            ),
            
            // Product Info
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "\$${product.price.toStringAsFixed(2)}", // تنسيق السعر
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: secondaryText, // لون مختلف للسعر
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
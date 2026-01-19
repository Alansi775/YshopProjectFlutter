// lib/widgets/store_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/store.dart';
import './shimmer_effect.dart';
// import './custom_form_widgets.dart'; //  لم نعد بحاجة لهذا الاستيراد للألوان الثابتة

class StoreCard extends StatefulWidget {
  final Store store;
  final VoidCallback onTap;

  const StoreCard({Key? key, required this.store, required this.onTap}) : super(key: key);

  @override
  State<StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<StoreCard> {
  bool _isHovering = false;
  
  // مكافئ لـ shimmerPlaceholder
  Widget _buildImagePlaceholder() {
    //  نستخدم ShimmerEffect كما هو
    return ShimmerEffect(
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //  1. الحصول على الألوان الديناميكية من الثيم
    final Color primaryColor = Theme.of(context).colorScheme.primary; // للعنوان والنص الأساسي
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6); // للنص الثانوي والعنوان
    final Color cardBackgroundColor = Theme.of(context).cardColor; // للون خلفية البطاقة

    // مكافئ لـ scaleEffect و .animation(.spring) في Swift
    final scale = _isHovering ? 0.98 : 1.0; 

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              //  استخدام لون البطاقة الديناميكي
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(16),
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
                // Image with Circular Icon Overlay
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Gradient
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withOpacity(0.15),
                            primaryColor.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                    
                    // Circular Icon Badge (Center)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: widget.store.storeIconUrl.isEmpty
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withOpacity(0.15),
                              ),
                              child: Icon(Icons.store, size: 45, color: primaryColor),
                            )
                          : ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: widget.store.storeIconUrl,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: primaryColor.withOpacity(0.1),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: primaryColor.withOpacity(0.1),
                                  child: Icon(Icons.store, size: 45, color: primaryColor),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),

                // Store Info
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.store.storeName,
                        //  التعديل 2: إزالة 'const' من TextStyle واستخدام primaryColor
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600,
                          color: primaryColor, // حل مشكلة primaryText
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      
                      // Address
                      Row(
                        children: [
                          //  التعديل 3: إزالة 'const' واستخدام secondaryColor
                          Icon(Icons.location_on, size: 14, color: secondaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.store.address ?? "No address",
                              //  التعديل 4: إزالة 'const' واستخدام secondaryColor
                              style: TextStyle(fontSize: 14, color: secondaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Rating (مؤقت)
                      Row(
                        children: List.generate(5, (index) {
                          return const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.yellow,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
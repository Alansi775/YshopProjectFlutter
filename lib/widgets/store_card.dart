// lib/widgets/store_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/store.dart';
import './shimmer_effect.dart';
import './custom_form_widgets.dart'; // لاستخدام الألوان مثل primaryText

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
              color: Colors.white,
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
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: widget.store.storeIconUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 160,
                    placeholder: (context, url) => _buildImagePlaceholder(),
                    errorWidget: (context, url, error) => Container(
                      height: 160,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: secondaryText),
                      ),
                    ),
                  ),
                ),

                // Store Info
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.store.storeName,
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      
                      // Address
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: secondaryText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.store.address ?? "No address",
                              style: const TextStyle(fontSize: 14, color: secondaryText),
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
// lib/screens/product_detail_view.dart

import 'dart:ui'; //  (1) هذا هو السطر الناقص لإصلاح ImageFilter
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/product.dart';
import '../../models/currency.dart';
import '../../widgets/store_admin_widgets.dart'; 
import '../../state_management/cart_manager.dart';
import '../../widgets/centered_notification.dart';
import '../stores/chat_view.dart';

// دالة للحصول على رمز العملة الصحيح
String getCurrencySymbol(String? currencyCode) {
  if (currencyCode == null || currencyCode.isEmpty) return '';
  final currency = Currency.fromCode(currencyCode);
  return currency?.symbol ?? '';
}


class ProductDetailView extends StatefulWidget {
  final Product product;
  const ProductDetailView({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  int _quantity = 1;
  final GlobalKey _cartIconKey = GlobalKey();
  final String fontTenor = 'TenorSans';

  // --- Helper Methods ---
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    return TextStyle(
      fontFamily: fontTenor,
      fontSize: size,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onBackground,
    );
  }

  // 🖼️ Show image in full screen modal
  void _showImageFullScreen(bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred background
              CachedNetworkImage(
                imageUrl: widget.product.imageUrl,
                fit: BoxFit.cover,
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(color: Colors.black.withOpacity(0.4)),
              ),
              // Main image centered
              Center(
                child: GestureDetector(
                  onTap: () {}, // منع انتشار الـ tap للخلفية
                  child: CachedNetworkImage(
                    imageUrl: widget.product.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // ✕ Close button (X)
              Positioned(
                top: 30,
                right: 30,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close,
                    color: isDark ? Colors.white : Colors.black,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Actions ---
  void _startChat() {
    final String? currentUserID = FirebaseAuth.instance.currentUser?.uid; 
    if (currentUserID == null) {
      CenteredNotification.show(context, 'Please sign in to start a chat.', success: false);
      return;
    }
    
    final ProductS chatProduct = ProductS.fromProduct(widget.product);
    final String customerOrUID = currentUserID;
    final String storeOwnerEmail = widget.product.storeOwnerEmail ?? 'N/A';
    
    final List<String> participants = [customerOrUID, storeOwnerEmail];
    participants.sort();
    final String chatID = '${participants[0]}_${participants[1]}_${widget.product.id}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatView(
          chatID: chatID,
          product: chatProduct, 
          currentUserID: currentUserID, 
          isStoreOwner: false, 
        ),
      ),
    );
  }

  void _showAddedToCartNotification(BuildContext context) {
    final RenderBox? renderBox = _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final Offset iconPosition = renderBox.localToGlobal(Offset.zero);
    final Size iconSize = renderBox.size;

    OverlayEntry? overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => FocusTransitionOverlay(
        productName: widget.product.name,
        startPosition: iconPosition,
        startSize: iconSize,
        endPosition: Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2),
        onDismiss: () {
          overlayEntry?.remove();
          overlayEntry = null;
        },
        getTenorSansStyle: _getTenorSansStyle,
      ),
    );

    //  (2) تم إضافة علامة التعجب ! هنا لحل مشكلة النوع
    Overlay.of(context).insert(overlayEntry!);
  }

  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Immersive Full-Screen Image with Blur Background
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.6,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white : Colors.black,
                      size: 28,
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 🔥 Blurred background image (full cover)
                      CachedNetworkImage(
                        imageUrl: widget.product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[300]),
                      ),
                      // Blur filter
                      ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(color: Colors.black.withOpacity(0.3)),
                        ),
                      ),
                      // 🎯 Main Product Image (Hero Animation) - Clickable
                      Center(
                        child: GestureDetector(
                          onTap: () => _showImageFullScreen(isDark),
                          child: Hero(
                            tag: 'product_${widget.product.id}',
                            child: CachedNetworkImage(
                              imageUrl: widget.product.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 64),
                            ),
                          ),
                        ),
                      ),
                      // No close button here - just the image is clickable
                    ],
                  ),
                ),
              ),
              
              // 2. Product Details Section
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  transform: Matrix4.translationValues(0, -30, 0),
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.product.name,
                              style: _getTenorSansStyle(context, 28, weight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "${getCurrencySymbol(widget.product.currency)}${widget.product.price.toStringAsFixed(2)}",
                            style: _getTenorSansStyle(context, 24, weight: FontWeight.w900, color: theme.primaryColor),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 25),
                      
                      // Description
                      Text(
                        "Description",
                        style: _getTenorSansStyle(context, 18, weight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.product.description,
                        style: _getTenorSansStyle(context, 16, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8))
                            .copyWith(height: 1.6),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Quantity Selector (Modernized)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => setState(() {
                                if (_quantity > 1) _quantity--;
                              }),
                              icon: const Icon(Icons.remove),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text("$_quantity", style: _getTenorSansStyle(context, 20, weight: FontWeight.bold)),
                            ),
                            IconButton(
                              onPressed: () {
                                final int stock = widget.product.stock;
                                if (_quantity >= stock) {
                                  CenteredNotification.show(context, 'Sorry, only $stock items available in stock.', success: false);
                                  return;
                                }
                                setState(() => _quantity++);
                              },
                              icon: Icon(Icons.add, color: theme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      // Store Info Card (Minimal)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.primaryColor.withOpacity(0.1),
                              child: Icon(Icons.store, color: theme.primaryColor),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.product.storeName ?? "Store", style: _getTenorSansStyle(context, 16, weight: FontWeight.bold)),
                                Text("View Profile", style: TextStyle(color: theme.primaryColor, fontSize: 12)),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: _startChat,
                              tooltip: "Chat with Store",
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Floating Sticky Bottom Bar (Glassmorphism Style)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                //  هنا كان الخطأ الثاني وتم حله باستدعاء dart:ui
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark 
                        ? Colors.black.withOpacity(0.8) 
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Total",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Text(
                            "${getCurrencySymbol(widget.product.currency)}${(widget.product.price * _quantity).toStringAsFixed(2)}",
                            style: _getTenorSansStyle(
                              context,
                              20,
                              weight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final int stock = widget.product.stock;
                          if (_quantity > stock) {
                            CenteredNotification.show(context, 'Sorry\n only $stock items available in stock.', success: false);
                            return;
                          }

                          // show the flying cart overlay immediately (visual affordance)
                          _showAddedToCartNotification(context);

                          try {
                            await Provider.of<CartManager>(context, listen: false).addToCart(product: widget.product, quantity: _quantity);
                            // We already show the flying overlay with product name; avoid a second centered notification.
                            // If you still want a persistent toast, enable the line below instead of the overlay.
                            // if (mounted) CenteredNotification.show(context, 'Added to cart', success: true);
                          } catch (e) {
                            // show centered error; overlay will auto-dismiss itself
                            if (mounted) CenteredNotification.show(context, e?.toString() ?? 'An error occurred, please try again.', success: false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? theme.colorScheme.primary : theme.primaryColor,
                          foregroundColor: isDark ? theme.colorScheme.onPrimary : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: const StadiumBorder(),
                          elevation: 5,
                        ),
                        child: Row(
                          children: [
                            Text(
                              "Add to Cart",
                              style: _getTenorSansStyle(
                                context,
                                16,
                                weight: FontWeight.bold,
                                color: isDark ? theme.colorScheme.onPrimary : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.shopping_bag_outlined,
                              key: _cartIconKey,
                              size: 20,
                               color: isDark ? theme.colorScheme.onPrimary : Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//  هذا هو الويدجت الخاص بالأنيميشن اللي اتفقنا عليه
class FocusTransitionOverlay extends StatefulWidget {
  final String productName;
  final Offset startPosition;
  final Size startSize;
  final Offset endPosition;
  final VoidCallback onDismiss;
  final TextStyle Function(BuildContext, double, {FontWeight weight, Color? color}) getTenorSansStyle;

  const FocusTransitionOverlay({
    Key? key,
    required this.productName,
    required this.startPosition,
    required this.startSize,
    required this.endPosition,
    required this.onDismiss,
    required this.getTenorSansStyle,
  }) : super(key: key);

  @override
  State<FocusTransitionOverlay> createState() => _FocusTransitionOverlayState();
}

class _FocusTransitionOverlayState extends State<FocusTransitionOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), 
    );

    final double finalNotificationWidth = 250; 
    final double finalNotificationHeight = 50; 
    
    final Offset startOffset = widget.startPosition + Offset(widget.startSize.width / 2, widget.startSize.height / 2);
    final Offset endOffset = widget.endPosition - Offset(finalNotificationWidth / 2, finalNotificationHeight / 2);
    
    const double entryEndInterval = 0.3; 
    
    _positionAnimation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, entryEndInterval, curve: Curves.easeOutCubic), 
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.1), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 40),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, entryEndInterval, curve: Curves.decelerate)),
    );
    
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, entryEndInterval, curve: Curves.easeIn)), 
    );
    
    const double fadeStartInterval = 0.8; 
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(fadeStartInterval, 1.0, curve: Curves.easeOut)),
    );

    _controller.forward().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color elegantGreen = Color(0xFF8BC34A); 
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _fadeAnimation.value,
              child: Transform.scale(
              scale: _scaleAnimation.value,
                child: Builder(builder: (ctx) {
                final t = Theme.of(ctx);
                final bool isDarkLocal = t.brightness == Brightness.dark;
                final Color bg = isDarkLocal ? Colors.white.withOpacity(0.95) : Colors.black87;
                final Color txt = isDarkLocal ? Colors.black87 : Colors.white;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(22.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Green status icon (cart -> check)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _controller.value < 0.3 ? Icons.shopping_cart : Icons.check_circle_rounded,
                        color: elegantGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Opacity(
                      opacity: _textOpacityAnimation.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product name (highlighted)
                          SizedBox(
                            width: 220,
                            child: Text(
                              widget.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: widget.getTenorSansStyle(ctx, 15).copyWith(
                                color: elegantGreen,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Secondary message
                          Text(
                            'Added to cart',
                            style: widget.getTenorSansStyle(ctx, 14).copyWith(
                              color: txt,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      );
    },
    );
  }
}
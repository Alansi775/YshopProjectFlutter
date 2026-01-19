// lib/widgets/side_cart_view_contents.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state_management/cart_manager.dart';
import '../screens/customers/checkout_screen.dart';
import 'cart_item_widget.dart';

class SideCartViewContents extends StatelessWidget {
  const SideCartViewContents({Key? key}) : super(key: key);

  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    return TextStyle(
      fontFamily: 'TenorSans',
      fontSize: size,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<CartManager>(
      builder: (context, cartManager, child) {
        final items = cartManager.items;

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Header الأنيق
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "MY CART",
                      style: _getTenorSansStyle(context, 22, weight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    )
                  ],
                ),
              ),

              // قائمة المنتجات
              Expanded(
                child: items.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          // هنا نستخدم Hero Animation خفيف عند الحذف أو الإضافة
                          return Dismissible(
                            key: Key(item['id']?.toString() ?? index.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            ),
                            onDismissed: (_) => cartManager.removeItem(item['id']?.toString() ?? ''),
                            child: CartItemWidget(item: item),
                          );
                        },
                      ),
              ),

              // Bottom Bar (Checkout) - تصميم زجاجي
              if (items.isNotEmpty) _buildModernBottomBar(context, cartManager),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernBottomBar(BuildContext context, CartManager cartManager) {
    final theme = Theme.of(context);
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.9),
            border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("SUBTOTAL", style: _getTenorSansStyle(context, 14, color: Colors.grey)),
                    Text(
                      "${cartManager.currencySymbol}${cartManager.totalAmount.toStringAsFixed(2)}",
                      style: _getTenorSansStyle(context, 20, weight: FontWeight.bold, color: theme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 20),
                      const SizedBox(width: 10),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text(
                            "CONTINUE TO CHECKOUT",
                            style: _getTenorSansStyle(context, 14, weight: FontWeight.bold, color: theme.colorScheme.onPrimary),
                            textAlign: TextAlign.center,
                          ),
                        ),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text("Your cart is empty", style: _getTenorSansStyle(context, 18, color: Colors.grey)),
        ],
      ),
    );
  }
}
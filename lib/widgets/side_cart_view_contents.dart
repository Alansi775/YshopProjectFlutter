// lib/widgets/side_cart_view_contents.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state_management/cart_manager.dart';
import '../screens/customers/checkout_screen.dart';
import 'cart_item_widget.dart';
import '../screens/auth/sign_in_ui.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CartManager>(
      builder: (context, cartManager, child) {
        final items = cartManager.items;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? LuxuryTheme.kDarkBackground : LuxuryTheme.kLightBackground,
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
                      style: TextStyle(
                        fontFamily: 'Didot',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? LuxuryTheme.kDarkSurface.withOpacity(0.8)
                : LuxuryTheme.kLightSurface.withOpacity(0.8),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? LuxuryTheme.kPlatinum.withOpacity(0.1)
                    : LuxuryTheme.kDeepNavy.withOpacity(0.1),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "SUBTOTAL",
                      style: TextStyle(
                        fontFamily: 'TenorSans',
                        fontSize: 14,
                        color: isDark
                            ? LuxuryTheme.kPlatinum.withOpacity(0.6)
                            : LuxuryTheme.kDeepNavy.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      "${cartManager.currencySymbol}${cartManager.totalAmount.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontFamily: 'Didot',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.1),
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 20,
                                  color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: Text(
                                      "CONTINUE TO CHECKOUT",
                                      style: TextStyle(
                                        fontFamily: 'TenorSans',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? LuxuryTheme.kPlatinum
                                            : LuxuryTheme.kDeepNavy,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
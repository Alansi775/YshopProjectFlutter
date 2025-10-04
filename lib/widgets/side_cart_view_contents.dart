// lib/widgets/side_cart_view_contents.dart (الكود النهائي المصحح)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; 
import '../state_management/cart_manager.dart';
import '../screens/checkout_screen.dart';
import 'cart_item_widget.dart';

class SideCartViewContents extends StatelessWidget {
  const SideCartViewContents({Key? key}) : super(key: key); 

  // 💡 تم تعديل الدالة لتقبل context وتستخدم primaryColor افتراضيًا
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return TextStyle(
      fontFamily: 'TenorSans', 
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor, // 💡 استخدام primaryColor افتراضيًا
    );
  }

  @override
  Widget build(BuildContext context) {
    // 💡 جلب الألوان الأساسية هنا
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color scaffoldColor = Theme.of(context).scaffoldBackgroundColor;

    return Consumer<CartManager>(
      builder: (context, cartManager, child) {
        final items = cartManager.items;
        final totalAmount = cartManager.totalAmount;

        return Scaffold(
          // 💡 استخدام scaffoldColor
          backgroundColor: scaffoldColor,
          appBar: AppBar(
            // 💡 استخدام لون خلفية AppBar الديناميكي
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            // 💡 استخدام primaryColor للأيقونات والتكست
            foregroundColor: primaryColor,
            title: Text(
              "Shopping Cart (${cartManager.totalItems})",
              style: _getTenorSansStyle(context, 18), // 💡 تمرير context
            ),
            centerTitle: true,
            automaticallyImplyLeading: false, 
            actions: [
              IconButton(
                // 💡 استخدام primaryColor
                icon: Icon(Icons.close, color: primaryColor),
                onPressed: () => Navigator.pop(context), 
              ),
            ],
          ),
          
          body: items.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          // يجب أن تكون CartItemWidget نفسها قد تم تكييفها للثيم الديناميكي
                          return CartItemWidget(item: item); 
                        },
                      ),
                    ),
                    _buildCheckoutBottomBar(context, totalAmount),
                  ],
                ),
        );
      },
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 💡 استخدام secondaryColor
            Icon(Icons.shopping_cart_outlined, size: 80, color: secondaryColor.withOpacity(0.5)),
            const SizedBox(height: 20),
            Text(
              "Your cart is empty.",
              style: _getTenorSansStyle(context, 20), // 💡 تمرير context
            ),
            const SizedBox(height: 10),
            Text(
              "Add items to your cart to see them here.",
              // 💡 استخدام secondaryColor
              style: _getTenorSansStyle(context, 16).copyWith(color: secondaryColor.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // دالة بناء الشريط السفلي لعملية الدفع
  Widget _buildCheckoutBottomBar(BuildContext context, double totalAmount) {
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    final Color cardColor = Theme.of(context).cardColor;
    final Color accentGreen = Colors.green.shade700; // يبقى ثابتًا للأسعار المميزة

    final String totalPriceString = NumberFormat.currency(
        symbol: '\$',
        decimalDigits: 2 
    ).format(totalAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // 💡 استخدام cardColor
        color: cardColor,
        boxShadow: [
          // 💡 استخدام primaryColor للظل (بشفافية عالية لتجنب الظل القوي في الثيم الداكن)
          BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)), 
        ],
      ),
      child: SafeArea( 
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            
            // 1. Total Price Column
            Expanded( 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Total",
                    // 💡 استخدام secondaryColor
                    style: _getTenorSansStyle(context, 16).copyWith(color: secondaryColor.withOpacity(0.7)),
                  ),
                  Text(
                    totalPriceString,
                    style: _getTenorSansStyle(context, 24, color: accentGreen), // اللون الأخضر ثابت للسعر
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16), 

            // 2. Checkout Button
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => CheckoutScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                // 💡 استخدام primaryColor كخلفية للزر
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                minimumSize: const Size(140, 50), 
              ),
              child: Text(
                "Checkout",
                style: _getTenorSansStyle(context, 18, weight: FontWeight.w600)
                    // 💡 استخدام اللون المعاكس لـ primaryColor (المناسب للنص داخل الزر)
                    .copyWith(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
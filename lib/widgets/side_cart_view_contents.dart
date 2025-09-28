// lib/widgets/side_cart_view_contents.dart (الكود الكامل والنهائي)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; 
import '../state_management/cart_manager.dart';
import '../screens/checkout_screen.dart';
import 'cart_item_widget.dart';

class SideCartViewContents extends StatelessWidget {
  const SideCartViewContents({Key? key}) : super(key: key); 

  // دالة مساعدة لخط "TenorSans"
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
    return Consumer<CartManager>(
      builder: (context, cartManager, child) {
        final items = cartManager.items;
        final totalAmount = cartManager.totalAmount;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              "Shopping Cart (${cartManager.totalItems})",
              style: _getTenorSansStyle(18),
            ),
            centerTitle: true,
            automaticallyImplyLeading: false, 
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              "Your cart is empty.",
              style: _getTenorSansStyle(20),
            ),
            const SizedBox(height: 10),
            Text(
              "Add items to your cart to see them here.",
              style: _getTenorSansStyle(16).copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // دالة بناء الشريط السفلي لعملية الدفع (الحل الأمثل لـ Overflow)
  Widget _buildCheckoutBottomBar(BuildContext context, double totalAmount) {
    // التعديل 1: تنسيق العملة مع تحديد عدد الأرقام العشرية (2)
    final String totalPriceString = NumberFormat.currency(
        symbol: '\$',
        decimalDigits: 2 // لضمان ظهور .00 أو أي أرقام عشرية
    ).format(totalAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5)), 
        ],
      ),
      child: SafeArea( 
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            
            // 1. Total Price Column (استخدام Expanded مع قيود للنص)
            Expanded( 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Total",
                    style: _getTenorSansStyle(16).copyWith(color: Colors.grey.shade600),
                  ),
                  Text(
                    totalPriceString,
                    style: _getTenorSansStyle(24, color: Colors.green.shade700),
                    maxLines: 1, // يجب أن يبقى سطر واحد
                    overflow: TextOverflow.ellipsis, // لضمان عدم التجاوز إذا كان الرقم فلكياً
                  ),
                ],
              ),
            ),
            
            // مسافة ثابتة أنيقة
            const SizedBox(width: 16), 

            // 2. Checkout Button
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => CheckoutScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // التعديل 2: تقليل الـ padding لتقليل العرض الإجمالي للزر
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                minimumSize: const Size(140, 50), // تقليل الحد الأدنى للعرض
              ),
              child: Text(
                "Checkout",
                style: _getTenorSansStyle(18, weight: FontWeight.w600).copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
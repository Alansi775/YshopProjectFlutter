// lib/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../state_management/cart_manager.dart';
import 'dart:math';
import '../../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/checkout_item_widget.dart';
import '../../models/cart_item_model.dart';
import '../../models/product.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPaymentMethod = "**** 4242";
  String _deliveryOption = "Standard";

  TextStyle _getTenorSansStyle(BuildContext context, double size,
      {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return TextStyle(
      fontFamily: 'TenorSans',
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor,
    );
  }

  String _formatCurrency(double amount, {String? currencySymbol}) {
    // Use provided symbol or default to ₺ (TRY)
    final symbol = currencySymbol ?? '₺';
    // For currency formatting, we just need the symbol and amount
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  // Build complete address without N/A
  String _buildFullAddress(Map<String, dynamic> customerData) {
    final streetAddress = customerData['address'] as String? ?? '';
    final buildingInfo = customerData['buildingInfo'] as String? ?? customerData['building_info'] as String? ?? '';
    final apartmentNumber = customerData['apartmentNumber'] as String? ?? customerData['apartment_number'] as String? ?? '';

    List<String> parts = [];

    if (streetAddress.isNotEmpty) {
      parts.add(streetAddress);
    }

    if (buildingInfo.isNotEmpty) {
      parts.add('Building: $buildingInfo');
    }

    if (apartmentNumber.isNotEmpty) {
      parts.add('Apt: $apartmentNumber');
    }

    return parts.isNotEmpty ? parts.join(', ') : 'No address provided';
  }

  Future<void> _placeOrder(CartManager cartManager) async {
    // 1. Fetch user profile from backend
    Map<String, dynamic> customerData = {};
    try {
      final profile = await ApiService.getUserProfile();
      if (profile != null) customerData = Map<String, dynamic>.from(profile);
    } catch (e) {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        customerData = {
          'name': authUser.displayName ?? '',
          'email': authUser.email ?? '',
          'contactNumber': authUser.phoneNumber ?? '',
        };
      }
    }

    // Build full address without N/A
    final fullAddress = _buildFullAddress(customerData);

    // Normalize cart items
    final List<CartItemModel> normalizedItems = cartManager.items.map((raw) {
      if (raw is CartItemModel) return raw;
      if (raw is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
        final productJson = {
          'id': map['product_id']?.toString() ?? map['id']?.toString() ?? '',
          'name': map['name'] ?? map['product_name'] ?? 'Item',
          'description': map['description'] ?? '',
          'price': map['price'] ?? 0,
          'store_id': map['store_id']?.toString() ?? map['storeId']?.toString() ?? '',
          'stock': map['stock'] ?? 0,
          'image_url': map['image_url'] ?? map['imageUrl'] ?? '',
          'video_url': map['video_url'] ?? map['videoUrl'],
          'image_urls': map['image_urls'] ?? map['images'] ?? [],
          'store_name': map['store_name'] ?? map['storeName'],
          'store_phone': map['store_phone'] ?? map['storePhone'],
          'store_owner_email': map['store_owner_email'] ?? map['storeOwnerEmail'],
          'category_id': map['category_id'] ?? map['categoryId'],
        };
        final product = Product.fromJson(productJson);
        final qty = (map['quantity'] is num)
            ? (map['quantity'] as num).toInt()
            : int.tryParse('${map['quantity'] ?? 1}') ?? 1;
        return CartItemModel(product: product, quantity: qty);
      }
      final product = Product(
        id: raw?.toString() ?? '',
        name: raw?.toString() ?? 'Item',
        description: '',
        price: 0.0,
        storeId: '',
        stock: 0,
        imageUrl: '',
      );
      return CartItemModel(product: product, quantity: 1);
    }).toList();

    // Group items by storeId
    final Map<String, List<CartItemModel>> byStore = {};
    for (final item in normalizedItems) {
      final sid = item.product.storeId ?? '';
      byStore.putIfAbsent(sid, () => []).add(item);
    }

    final createdOrderIds = <String>[];

    try {
      for (final entry in byStore.entries) {
        final storeId = entry.key;
        final itemsForStore = entry.value;
        final double totalPrice =
            itemsForStore.fold(0.0, (sum, it) => sum + (it.product.price * it.quantity));

        final apiItems = itemsForStore
            .map((it) => {
                  'productId': it.product.id,
                  'price': it.product.price,
                  'quantity': it.quantity,
                })
            .toList();

        final response = await ApiService.createOrder(
          storeId: storeId,
          totalPrice: totalPrice,
          shippingAddress: fullAddress, // Clean address without N/A
          items: apiItems,
          paymentMethod: _selectedPaymentMethod,
          deliveryOption: _deliveryOption,
        );

        final createdId = response != null && response['id'] != null ? response['id'].toString() : null;
        if (createdId != null) createdOrderIds.add(createdId);
      }

      if (createdOrderIds.isNotEmpty) {
        final lastOrderId = createdOrderIds.last;
        cartManager.setLastOrderId(lastOrderId);
        await cartManager.clearCart();
        _showConfirmationSheet(context, lastOrderId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No orders were created.')),
        );
      }
    } catch (e) {
      print("Error placing order via backend: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    final Color scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    
    // Detect if it's a wide screen (tablet/laptop)
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;
    final double maxWidth = isWideScreen ? 1200 : double.infinity;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: primaryColor,
        title: Text("Checkout", style: _getTenorSansStyle(context, 20)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20, bottom: 100),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isWideScreen
                    ? _buildWideLayout(context, cartManager, primaryColor)
                    : _buildMobileLayout(context, cartManager),
              ),
            ),
          ),

          // Confirm Order Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildConfirmButton(context, cartManager),
            ),
          ),
        ],
      ),
    );
  }

  /// Wide layout: 2-column (left: products, right: delivery/payment/total)
  Widget _buildWideLayout(BuildContext context, CartManager cartManager, Color primaryColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Order Summary
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildOrderSummarySection(context, cartManager),
          ),
        ),
        
        // Right Column: Delivery, Payment, Total
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDeliverySection(context),
                const SizedBox(height: 16),
                _buildPaymentSection(context),
                const SizedBox(height: 16),
                _buildTotalSection(context, cartManager.totalAmount, cartManager.currencySymbol),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile layout: Single column (vertical stack)
  Widget _buildMobileLayout(BuildContext context, CartManager cartManager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOrderSummarySection(context, cartManager),
        _buildDeliverySection(context),
        _buildPaymentSection(context),
        _buildTotalSection(context, cartManager.totalAmount, cartManager.currencySymbol),
      ],
    );
  }

  /// Order Summary Section (reusable for both layouts)
  Widget _buildOrderSummarySection(BuildContext context, CartManager cartManager) {
    return _buildSection(
      context,
      child: Column(
        children: [
          ...cartManager.items.map((raw) {
            CartItemModel cartItem;
            if (raw is CartItemModel) {
              cartItem = raw;
            } else if (raw is Map) {
              final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
              final productJson = {
                'id': map['product_id']?.toString() ?? map['id']?.toString() ?? '',
                'name': map['name'] ?? map['product_name'] ?? 'Item',
                'description': map['description'] ?? '',
                'price': map['price'] ?? 0,
                'currency': map['currency'] ?? 'TRY',
                'store_id': map['store_id']?.toString() ?? map['storeId']?.toString() ?? '',
                'stock': map['stock'] ?? 0,
                'image_url': map['image_url'] ?? map['imageUrl'] ?? '',
                'video_url': map['video_url'] ?? map['videoUrl'],
                'image_urls': map['image_urls'] ?? map['images'] ?? [],
                'store_name': map['store_name'] ?? map['storeName'],
                'store_phone': map['store_phone'] ?? map['storePhone'],
                'store_owner_email': map['store_owner_email'] ?? map['storeOwnerEmail'],
                'category_id': map['category_id'] ?? map['categoryId'],
              };
              final product = Product.fromJson(productJson);
              final qty = (map['quantity'] is num)
                  ? (map['quantity'] as num).toInt()
                  : int.tryParse('${map['quantity'] ?? 1}') ?? 1;
              cartItem = CartItemModel(product: product, quantity: qty);
            } else {
              final product = Product(
                id: raw?.toString() ?? '',
                name: raw?.toString() ?? 'Item',
                description: '',
                price: 0.0,
                storeId: '',
                stock: 0,
                imageUrl: '',
              );
              cartItem = CartItemModel(product: product, quantity: 1);
            }

            final isLast = cartItem.product.id ==
                (cartManager.items.isNotEmpty
                    ? (cartManager.items.last is Map
                        ? (cartManager.items.last['product_id']?.toString() ??
                            cartManager.items.last['id']?.toString())
                        : (cartManager.items.last is CartItemModel
                            ? (cartManager.items.last as CartItemModel).product.id
                            : null))
                    : null);

            return Column(
              children: [
                CheckoutItemWidget(item: cartItem),
                if (!isLast)
                  Divider(indent: 80, height: 1, color: Theme.of(context).dividerColor),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required Widget child}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(isDark ? 0.15 : 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
        child: child,
      ),
    );
  }

  Widget _buildDeliverySection(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    
    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("Delivery Method", style: _getTenorSansStyle(context, 18)),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDeliveryOption(context, "Standard", Icons.local_shipping)),
              const SizedBox(width: 12),
              Expanded(child: _buildDeliveryOption(context, "Drone", Icons.airplanemode_active)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDeliveryOption(BuildContext context, String title, IconData icon) {
    final bool isSelected = _deliveryOption == title;
    final Color secondaryBg = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade200
        : Colors.grey.shade800;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _deliveryOption = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: secondaryBg,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.green, width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.green.shade700 : primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: _getTenorSansStyle(context, 16,
                  weight: isSelected ? FontWeight.bold : FontWeight.normal),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Text("Payment Method", style: _getTenorSansStyle(context, 18)),
                const Spacer(),
                TextButton(
                  onPressed: () => _showPaymentSheet(context),
                  child: Text("Change",
                      style: _getTenorSansStyle(context, 14)
                          .copyWith(color: Theme.of(context).colorScheme.secondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade200
                  : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                    _selectedPaymentMethod == "Pay at Door" ? Icons.money : Icons.credit_card,
                    size: 30,
                    color: primaryColor),
                const SizedBox(width: 12),
                Text(_selectedPaymentMethod, style: _getTenorSansStyle(context, 16)),
                const Spacer(),
                const Icon(Icons.check_circle_sharp, color: Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showPaymentSheet(BuildContext context) {
    final Color cardColor = Theme.of(context).cardColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25.0),
              topRight: Radius.circular(25.0),
            ),
          ),
          padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                "Choose Payment Method",
                style: _getTenorSansStyle(context, 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildPaymentOptionSheet(context, "Pay at Door", Icons.money),
              const SizedBox(height: 10),
              _buildPaymentOptionSheet(context, "**** 4242", Icons.credit_card),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: onPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "Cancel",
                  style: _getTenorSansStyle(context, 16).copyWith(color: onPrimaryColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentOptionSheet(BuildContext context, String method, IconData icon) {
    final bool isSelected = _selectedPaymentMethod == method;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.withOpacity(0.1)
              : (Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade100
                  : Colors.grey.shade800),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.green.shade700, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.green.shade700 : primaryColor),
            const SizedBox(width: 12),
            Text(
              method,
              style: _getTenorSansStyle(context, 16,
                  weight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection(BuildContext context, double subtotal, String currencySymbol) {
    final Color dividerColor = Theme.of(context).dividerColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return _buildSection(
      context,
      child: Column(
        children: [
          Row(
            children: [
              Text("Order Summary", style: _getTenorSansStyle(context, 18)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTotalRow(context, "Subtotal", _formatCurrency(subtotal, currencySymbol: currencySymbol), isBold: false),
          const SizedBox(height: 12),
          _buildTotalRow(context, "Delivery", "Free", isBold: false),
          const SizedBox(height: 12),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 12),
          _buildTotalRow(context, "Total", _formatCurrency(subtotal, currencySymbol: currencySymbol),
              isBold: true, color: Colors.green.shade700),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, String label, String value,
      {bool isBold = false, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Text(
          label,
          style: _getTenorSansStyle(context, isBold ? 20 : 16,
              weight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
        const Spacer(),
        Text(
          value,
          style: _getTenorSansStyle(context, isBold ? 20 : 16,
                  weight: isBold ? FontWeight.bold : FontWeight.normal)
              .copyWith(color: color ?? primaryColor),
        ),
      ],
    );
  }

  Widget _buildConfirmButton(BuildContext context, CartManager cartManager) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 56,
      width: 450,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: cartManager.items.isEmpty
            ? null
            : () {
                _placeOrder(cartManager);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, color: onPrimaryColor, size: 22),
            const SizedBox(width: 12),
            Text("Confirm Order",
                style: _getTenorSansStyle(context, 16, weight: FontWeight.bold)
                    .copyWith(color: onPrimaryColor, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showConfirmationSheet(BuildContext context, String orderId) {
    final Color cardColor = Theme.of(context).cardColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;

    Navigator.of(context).pop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25.0),
              topRight: Radius.circular(25.0),
            ),
          ),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              Text(
                "Order Placed Successfully!",
                style: _getTenorSansStyle(context, 24),
              ),
              const SizedBox(height: 10),
              Text(
                "Order ID: #$orderId",
                textAlign: TextAlign.center,
                style: _getTenorSansStyle(context, 18)
                    .copyWith(color: primaryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Your order has been successfully placed via $_deliveryOption delivery. We will notify you when it's ready.\nThank you!",
                textAlign: TextAlign.center,
                style:
                    _getTenorSansStyle(context, 16).copyWith(color: secondaryColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Continue Shopping",
                      style: _getTenorSansStyle(context, 16).copyWith(color: onPrimaryColor)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
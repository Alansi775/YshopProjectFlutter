// lib/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state_management/cart_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';  
import '../widgets/checkout_item_widget.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // @State variables في Flutter
  String _selectedPaymentMethod = "**** 4242";
  String _deliveryOption = "Standard";
  
  // دالة مساعدة لخط "TenorSans"
  TextStyle _getTenorSansStyle(double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    return TextStyle(
      fontFamily: 'TenorSans', 
      fontSize: size,
      fontWeight: weight,
      color: color ?? Colors.black,
    );
  }

  // Helper function to format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _placeOrder(CartManager cartManager) async {
    final user = _auth.currentUser;

    if (user == null) {
      print("User not logged in. Cannit place order.");
      return;
    }

    // 💡 1. جلب بيانات المستخدم من كوليكشن 'customers'
    // ----------------------------------------------------
    Map<String, dynamic> customerData = {};
    try {
      final customerDoc = await _firestore.collection('customers').doc(user.uid).get();
      if (customerDoc.exists) {
        customerData = customerDoc.data() as Map<String, dynamic>;
      } else {
        print("Customer data not found in 'customers' collection.");
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
    
    // تحديد حقول المستخدم الأساسية (مع استخدام قيم بديلة إذا لم يتم الجلب)
    final firstName = customerData['name'] as String? ?? 'N/A';
    final lastName = customerData['surname'] as String? ?? '';
    final contactPhone = customerData['contactNumber'] as String? ?? 'No Phone';

    // حقول العنوان والتوصيل
    final streetAddress = customerData['address'] as String? ?? 'N/A';
    final buildingInfo = customerData['buildingInfo'] as String? ?? 'N/A';
    // ✅ الحقول الجديدة
    final apartmentNumber = customerData['apartmentNumber'] as String? ?? 'N/A';
    final deliveryInstructions = customerData['deliveryInstructions'] as String? ?? 'No Instructions';

    // حقول الموقع الجغرافي (يجب أن تكون من نوع double)
    final latitude = customerData['latitude'] is num ? (customerData['latitude'] as num).toDouble() : null;
    final longitude = customerData['longitude'] is num ? (customerData['longitude'] as num).toDouble() : null;
    
    // تجميع العنوان الكامل للعرض السريع
    final fullAddress = '$streetAddress, $buildingInfo, Apt: $apartmentNumber';
    // ----------------------------------------------------

    List<Map<String, dynamic>> orderItems = cartManager.items.map((cartItem) {
      return {
        'productId': cartItem.product.id,
        'name': cartItem.product.name,
        'price': cartItem.product.price,
        'quantity': cartItem.quantity,
        'imageUrl': cartItem.product.imageUrl,
        'storeName': cartItem.product.storeName,
        'storeOwnerEmail': cartItem.product.storeOwnerEmail,
        'storePhone': cartItem.product.storePhone,
      };
    }).toList();

    final orderData = {
      'userId': user.uid,
      'userEmail': user.email,
      
      // بيانات المستخدم الأساسية
      'userName': "$firstName $lastName", 
      'userPhone': contactPhone, 

      // ✅ تفاصيل العنوان اللوجستية
      'address_Full': fullAddress, // العنوان الكامل المدمج
      'address_Street': streetAddress,
      'address_Building': buildingInfo,
      'address_Apartment': apartmentNumber,
      'address_DeliveryInstructions': deliveryInstructions,

      // ✅ إحداثيات الموقع
      'location_Latitude': latitude,
      'location_Longitude': longitude,

      'items': orderItems,
      'subtotal': cartManager.totalAmount, // يُفترض أن cartManager.subtotalAmount تم تصحيحها
      'total': cartManager.totalAmount, 
      'deliveryFee': 0.0,
      
      'paymentMethod': _selectedPaymentMethod,
      'deliveryOption': _deliveryOption,
      'status': 'Pending', 
      'createdAt': FieldValue.serverTimestamp(),
      'involvedStores': cartManager.items.map((i) => i.product.storeOwnerEmail).toSet().toList(),
    };

    try {
      // 3. إرسال الطلب إلى Firestore في كوليكشن "orders"
      final docRef = await _firestore.collection('orders').add(orderData);
      
      // 4. حفظ رقم الطلب لتتبعه
      final orderId = docRef.id;
      // 💡 بما أننا نستخدم CartManager لحفظ حالة مؤقتة للـ orderId
      cartManager.setLastOrderId(orderId); 
      
      // 5. مسح السلة بعد نجاح الطلب
      cartManager.clearCart();

      // 6. عرض رسالة التأكيد
      _showConfirmationSheet(orderId);
      
    } catch (e) {
      print("Error placing order: $e");
      // عرض رسالة خطأ للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    
    final Color backgroundColor = Theme.of(context).brightness == Brightness.light 
        ? const Color(0xFFF0F0F0) 
        : Colors.grey.shade900;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Checkout", style: _getTenorSansStyle(20)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(), 
        ),
      ),
      
      body: Stack(
        children: [
          // ScrollView
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 20, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // 1. Order Summary (ملخص الطلب)
                _buildSection(
                  context,
                  child: Column(
                    children: [
                      ...cartManager.items.map((item) {
                        final isLast = item.product.id == cartManager.items.last?.product.id;
                        return Column(
                          children: [
                            CheckoutItemWidget(item: item),
                            if (!isLast)
                              const Divider(indent: 80, height: 1),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),

                // 2. Delivery Method (طريقة التسليم)
                _buildDeliverySection(),

                // 3. Payment Method (طريقة الدفع)
                _buildPaymentSection(context),

                // 4. Total Section (الإجمالي)
                _buildTotalSection(context, cartManager.totalAmount),

              ],
            ),
          ),
          
          // Confirm Order Button (زر تأكيد الطلب)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildConfirmButton(cartManager),
            ),
          ),
        ],
      ),
    );
  }

  // --- دوال بناء أقسام الشاشة ---

  // دالة مساعدة لبناء الأقسام ذات الخلفية والظل
  Widget _buildSection(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          // تم التصحيح: استخدام .withOpacity و blurRadius
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: child,
      ),
    );
  }

  // التعديل: وضع خيارات التسليم جنبًا إلى جنب
  Widget _buildDeliverySection() {
    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text("Delivery Method", style: _getTenorSansStyle(18)),
          ),
          const SizedBox(height: 16),
          // استخدام Row لوضع الخيارين جنبًا إلى جنب
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDeliveryOption("Standard", Icons.local_shipping)),
              const SizedBox(width: 12), // مسافة بين الخيارين
              Expanded(child: _buildDeliveryOption("Drone", Icons.airplanemode_active)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // التعديل: تصميم كل خيار تسليم
  Widget _buildDeliveryOption(String title, IconData icon) {
    final bool isSelected = _deliveryOption == title;
    final Color secondaryBg = Theme.of(context).brightness == Brightness.light 
        ? Colors.grey.shade200 
        : Colors.grey.shade800;

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
          border: isSelected ? Border.all(color: Colors.green, width: 2) : null, // إطار أخضر عند الاختيار
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.green.shade700 : Colors.black),
            const SizedBox(height: 8),
            Text(
              title, 
              style: _getTenorSansStyle(16, weight: isSelected ? FontWeight.bold : FontWeight.normal),
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
    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Payment Method + Change Button)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Text("Payment Method", style: _getTenorSansStyle(18)),
                const Spacer(),
                TextButton(
                  // تم التعديل هنا لاستدعاء الورقة السفلية الأنيقة
                  onPressed: () => _showPaymentSheet(context), 
                  child: Text("Change", style: _getTenorSansStyle(14).copyWith(color: Colors.blue)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // Selected Payment Method Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade200 : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_selectedPaymentMethod == "Pay at Door" ? Icons.money : Icons.credit_card, size: 30),
                const SizedBox(width: 12),
                
                Text(_selectedPaymentMethod, style: _getTenorSansStyle(16)),
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
  
  // دالة لعرض الورقة السفلية لاختيار طريقة الدفع (استبدال AlertDialog)
  void _showPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
              // مقبض السحب (Handle)
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
                style: _getTenorSansStyle(20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // خيار الدفع عند الاستلام
              _buildPaymentOptionSheet("Pay at Door", Icons.money),
              const SizedBox(height: 10),
              
              // خيار البطاقة
              _buildPaymentOptionSheet("**** 4242", Icons.credit_card),
              
              const SizedBox(height: 20),
              
              // زر الإلغاء
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                    "Cancel",
                    style: _getTenorSansStyle(16).copyWith(color: Colors.white),
                ),
            ),
            ],
          ),
        );
      },
    );
  }

  // دالة مخصصة لبناء كل خيار في الورقة السفلية
  Widget _buildPaymentOptionSheet(String method, IconData icon) {
    final bool isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
        Navigator.of(context).pop(); // إغلاق الورقة بعد الاختيار
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.1) : (Theme.of(context).brightness == Brightness.light ? Colors.grey.shade100 : Colors.grey.shade800),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.green.shade700, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.green.shade700 : Colors.black),
            const SizedBox(width: 12),
            Text(
              method,
              style: _getTenorSansStyle(16, weight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection(BuildContext context, double subtotal) {
    return _buildSection(
      context,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildTotalRow("Subtotal", _formatCurrency(subtotal), isBold: false),
          const SizedBox(height: 12),
          _buildTotalRow("Delivery", "Free", isBold: false),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildTotalRow("Total", _formatCurrency(subtotal), isBold: true, color: Colors.green),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      children: [
        Text(
          label,
          style: _getTenorSansStyle(isBold ? 20 : 16, weight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
        const Spacer(),
        Text(
          value,
          style: _getTenorSansStyle(isBold ? 20 : 16, weight: isBold ? FontWeight.bold : FontWeight.normal).copyWith(color: color),
        ),
      ],
    );
  }

  // التعديل: زر التأكيد موضوع في الأسفل مع مسافة مناسبة
  Widget _buildConfirmButton(CartManager cartManager) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0), 
      height: 56,
      width: 450, // يمتد ليملأ العرض المتاح
      child: ElevatedButton(
        onPressed: cartManager.items.isEmpty ? null : () {
          _placeOrder(cartManager); // استدعاء دالة وضع الطلب
        },// استخدام ورقة التأكيد السفلية
        
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text("Confirm Order", style: _getTenorSansStyle(16).copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // التعديل: استخدام ورقة سفلية أنيقة للتأكيد
  void _showConfirmationSheet(String orderId) {
    // إغلاق شاشة الدفع الحالية (dismiss())
    Navigator.of(context).pop(); 

    // عرض الورقة السفلية في الشاشة التي ستظهر الآن (شاشة المنتجات)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
                style: _getTenorSansStyle(24),
              ),
              const SizedBox(height: 10),
              Text(
                "Order ID: #$orderId",
                textAlign: TextAlign.center,
                style: _getTenorSansStyle(18).copyWith(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Your order has been successfully placed via $_deliveryOption delivery. We will notify you when it's ready.\nThank you!",
                textAlign: TextAlign.center,
                style: _getTenorSansStyle(16).copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(), // إغلاق الورقة
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Continue Shopping", style: _getTenorSansStyle(16).copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
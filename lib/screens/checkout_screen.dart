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
  
  //  تم تعديل الدالة لتقبل context وتستخدم primaryColor افتراضيًا
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return TextStyle(
      fontFamily: 'TenorSans', 
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor,
    );
  }

  // Helper function to format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //  دالة _placeOrder لا تحتاج إلى تعديل لأنها تتعامل مع البيانات والمنطق
  Future<void> _placeOrder(CartManager cartManager) async {
    final user = _auth.currentUser;

    if (user == null) {
      print("User not logged in. Cannit place order.");
      return;
    }

    //  1. جلب بيانات المستخدم من كوليكشن 'customers'
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
      'subtotal': cartManager.totalAmount, 
      'total': cartManager.totalAmount, 
      'deliveryFee': 0.0,
      
      'paymentMethod': _selectedPaymentMethod,
      'deliveryOption': _deliveryOption,
      'status': 'Pending', 
      'createdAt': FieldValue.serverTimestamp(),
      'involvedStores': cartManager.items.map((i) => i.product.storeOwnerEmail).toSet().toList(),
    };

    try {
      final docRef = await _firestore.collection('orders').add(orderData);
      final orderId = docRef.id;
      cartManager.setLastOrderId(orderId); 
      cartManager.clearCart();

      //  تمرير context إلى دالة التأكيد
      _showConfirmationSheet(context, orderId); 
      
    } catch (e) {
      print("Error placing order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    
    //  استخدام لون خلفية النظام (scaffoldBackgroundColor) الذي يتكيف تلقائياً
    final Color scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      //  استخدام لون الخلفية الديناميكي
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        //  استخدام لون خلفية AppBar الديناميكي
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        //  استخدام primaryColor للأيقونات والتكست
        foregroundColor: primaryColor,
        title: Text("Checkout", style: _getTenorSansStyle(context, 20)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: primaryColor), //  استخدام primaryColor
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
                              //  استخدام Divider يتكيف مع الثيم
                              Divider(indent: 80, height: 1, color: Theme.of(context).dividerColor),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),

                // 2. Delivery Method (طريقة التسليم)
                _buildDeliverySection(context), //  تمرير context

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
              child: _buildConfirmButton(context, cartManager), //  تمرير context
            ),
          ),
        ],
      ),
    );
  }

  // --- دوال بناء أقسام الشاشة ---

  // دالة مساعدة لبناء الأقسام ذات الخلفية والظل
  Widget _buildSection(BuildContext context, {required Widget child}) {
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          //  استخدام primaryColor للظل (بشفافية عالية لتجنب الظل القوي في الثيم الداكن)
          BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: child,
      ),
    );
  }

  // التعديل: وضع خيارات التسليم جنبًا إلى جنب
  Widget _buildDeliverySection(BuildContext context) {
    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text("Delivery Method", style: _getTenorSansStyle(context, 18)), //  تمرير context
          ),
          const SizedBox(height: 16),
          // استخدام Row لوضع الخيارين جنبًا إلى جنب
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDeliveryOption(context, "Standard", Icons.local_shipping)), //  تمرير context
              const SizedBox(width: 12),
              Expanded(child: _buildDeliveryOption(context, "Drone", Icons.airplanemode_active)), //  تمرير context
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // التعديل: تصميم كل خيار تسليم
  Widget _buildDeliveryOption(BuildContext context, String title, IconData icon) {
    final bool isSelected = _deliveryOption == title;
    //  استخدام الألوان الديناميكية للخلفية الثانوية
    final Color secondaryBg = Theme.of(context).brightness == Brightness.light 
        ? Colors.grey.shade200 
        : Colors.grey.shade800;
    //  استخدام primaryColor لأيقونات النص
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
          //  إطار أخضر ثابت (للتأكيد البصري)
          border: isSelected ? Border.all(color: Colors.green, width: 2) : null, 
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //  استخدام primaryColor عند عدم الاختيار
            Icon(icon, size: 24, color: isSelected ? Colors.green.shade700 : primaryColor),
            const SizedBox(height: 8),
            Text(
              title, 
              style: _getTenorSansStyle(context, 16, weight: isSelected ? FontWeight.bold : FontWeight.normal), //  تمرير context
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
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 

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
                Text("Payment Method", style: _getTenorSansStyle(context, 18)), //  تمرير context
                const Spacer(),
                TextButton(
                  onPressed: () => _showPaymentSheet(context), 
                  //  استخدام اللون الثانوي (accent color) للزر
                  child: Text("Change", style: _getTenorSansStyle(context, 14).copyWith(color: Theme.of(context).colorScheme.secondary)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // Selected Payment Method Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              //  استخدام الألوان الديناميكية للخلفية الثانوية
              color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade200 : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedPaymentMethod == "Pay at Door" ? Icons.money : Icons.credit_card, 
                  size: 30, 
                  color: primaryColor //  استخدام primaryColor
                ),
                const SizedBox(width: 12),
                
                Text(_selectedPaymentMethod, style: _getTenorSansStyle(context, 16)), //  تمرير context
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
  
  // دالة لعرض الورقة السفلية لاختيار طريقة الدفع
  void _showPaymentSheet(BuildContext context) {
    //  جلب الألوان الديناميكية
    final Color cardColor = Theme.of(context).cardColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor, //  استخدام cardColor
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
                style: _getTenorSansStyle(context, 20), //  تمرير context
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // خيار الدفع عند الاستلام
              _buildPaymentOptionSheet(context, "Pay at Door", Icons.money), //  تمرير context
              const SizedBox(height: 10),
              
              // خيار البطاقة
              _buildPaymentOptionSheet(context, "**** 4242", Icons.credit_card), //  تمرير context
              
              const SizedBox(height: 20),
              
              // زر الإلغاء
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, //  استخدام primaryColor
                    foregroundColor: onPrimaryColor, //  استخدام onPrimaryColor
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                    "Cancel",
                    style: _getTenorSansStyle(context, 16).copyWith(color: onPrimaryColor), //  استخدام onPrimaryColor
                ),
            ),
            ],
          ),
        );
      },
    );
  }

  // دالة مخصصة لبناء كل خيار في الورقة السفلية
  Widget _buildPaymentOptionSheet(BuildContext context, String method, IconData icon) {
    final bool isSelected = _selectedPaymentMethod == method;
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    
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
          //  استخدام cardColor أو لون ثانوي معتم
          color: isSelected ? Colors.green.withOpacity(0.1) : (Theme.of(context).brightness == Brightness.light ? Colors.grey.shade100 : Colors.grey.shade800),
          borderRadius: BorderRadius.circular(12),
          //  إطار أخضر ثابت (للتأكيد البصري)
          border: isSelected ? Border.all(color: Colors.green.shade700, width: 1.5) : null,
        ),
        child: Row(
          children: [
            //  استخدام primaryColor عند عدم الاختيار
            Icon(icon, size: 24, color: isSelected ? Colors.green.shade700 : primaryColor),
            const SizedBox(width: 12),
            Text(
              method,
              style: _getTenorSansStyle(context, 16, weight: isSelected ? FontWeight.bold : FontWeight.normal), //  تمرير context
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
    //  استخدام Divider يتكيف مع الثيم
    final Color dividerColor = Theme.of(context).dividerColor;
    
    return _buildSection(
      context,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildTotalRow(context, "Subtotal", _formatCurrency(subtotal), isBold: false), //  تمرير context
          const SizedBox(height: 12),
          _buildTotalRow(context, "Delivery", "Free", isBold: false), //  تمرير context
          const SizedBox(height: 12),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 12),
          _buildTotalRow(context, "Total", _formatCurrency(subtotal), isBold: true, color: Colors.green.shade700), //  تمرير context
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, String label, String value, {bool isBold = false, Color? color}) {
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Text(
          label,
          style: _getTenorSansStyle(context, isBold ? 20 : 16, weight: isBold ? FontWeight.bold : FontWeight.normal), //  تمرير context
        ),
        const Spacer(),
        Text(
          value,
          //  استخدام primaryColor إذا لم يتم تحديد لون مميز (مثل الأخضر)
          style: _getTenorSansStyle(context, isBold ? 20 : 16, weight: isBold ? FontWeight.bold : FontWeight.normal).copyWith(color: color ?? primaryColor),
        ),
      ],
    );
  }

  // التعديل: زر التأكيد موضوع في الأسفل مع مسافة مناسبة
  Widget _buildConfirmButton(BuildContext context, CartManager cartManager) {
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0), 
      height: 56,
      width: 450, 
      child: ElevatedButton(
        onPressed: cartManager.items.isEmpty ? null : () {
          _placeOrder(cartManager);
        },
        
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor, //  استخدام primaryColor
          foregroundColor: onPrimaryColor, //  استخدام onPrimaryColor
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, color: onPrimaryColor, size: 20), //  استخدام onPrimaryColor
            const SizedBox(width: 8),
            Text("Confirm Order", style: _getTenorSansStyle(context, 16).copyWith(color: onPrimaryColor)), //  استخدام onPrimaryColor
          ],
        ),
      ),
    );
  }

  // التعديل: استخدام ورقة سفلية أنيقة للتأكيد
  void _showConfirmationSheet(BuildContext context, String orderId) {
    //  جلب الألوان الديناميكية
    final Color cardColor = Theme.of(context).cardColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    // إغلاق شاشة الدفع الحالية (dismiss())
    Navigator.of(context).pop(); 

    // عرض الورقة السفلية في الشاشة التي ستظهر الآن (شاشة المنتجات)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor, //  استخدام cardColor
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
                style: _getTenorSansStyle(context, 24), //  تمرير context
              ),
              const SizedBox(height: 10),
              Text(
                "Order ID: #$orderId",
                textAlign: TextAlign.center,
                //  استخدام primaryColor
                style: _getTenorSansStyle(context, 18).copyWith(color: primaryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Your order has been successfully placed via $_deliveryOption delivery. We will notify you when it's ready.\nThank you!",
                textAlign: TextAlign.center,
                //  استخدام secondaryColor
                style: _getTenorSansStyle(context, 16).copyWith(color: secondaryColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(), // إغلاق الورقة
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, //  استخدام primaryColor
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Continue Shopping", style: _getTenorSansStyle(context, 16).copyWith(color: onPrimaryColor)), //  استخدام onPrimaryColor
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
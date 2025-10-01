import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import '../state_management/cart_manager.dart'; 
// import '../models/product.dart'; 
// import '../models/cart_item_model.dart'; 


// دالة مساعدة لخط "TenorSans" (موجودة في ملف CheckoutScreen)
TextStyle _getTenorSansStyle(double size, {FontWeight weight = FontWeight.normal, Color? color}) {
  return TextStyle(
    fontFamily: 'TenorSans', 
    fontSize: size,
    fontWeight: weight,
    color: color ?? Colors.black,
  );
}

class OrderTrackerWidget extends StatelessWidget {
  const OrderTrackerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    final orderId = cartManager.lastOrderId;

    if (orderId == null) {
      return const SizedBox.shrink();
    }
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final orderData = snapshot.data!.data() as Map<String, dynamic>?;
        final status = orderData?['status'] as String? ?? 'Pending';
        
        return _buildTrackerIndicator(context, orderId, status);
      },
    );
  }

  // بناء مؤشر الحالة المتحرك
  Widget _buildTrackerIndicator(BuildContext context, String orderId, String status) {
    
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Pending':
        // ⭐️ تم تغيير اللون الأساسي لـ Pending إلى الأزرق الفاتح
        statusColor = Colors.lightBlue.shade600; 
        statusIcon = Icons.hourglass_top;
        break;
      case 'Processing':
        statusColor = Colors.blue.shade600;
        statusIcon = Icons.kitchen_rounded;
        break;
      case 'Out for Delivery':
        statusColor = Colors.green.shade600;
        statusIcon = Icons.delivery_dining;
        break;
      case 'Delivered':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<CartManager>(context, listen: false).setLastOrderId(null);
        });
        return const SizedBox.shrink();

      default:
        statusColor = Colors.red.shade600;
        statusIcon = Icons.error_outline;
    }

    return Positioned(
      bottom: 20,
      right: 20,
      child: GestureDetector(
        onTap: () => _showOrderDetailsSheet(context, orderId, status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          width: 55, 
          height: 55, 
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.4),
                blurRadius: 12, 
                spreadRadius: 3, 
              ),
            ],
          ),
          child: Center(
            child: Icon(statusIcon, color: Colors.white, size: 28), 
          ),
        ),
      ),
    );
  }

  // عرض الورقة السفلية لتفاصيل الطلب
  void _showOrderDetailsSheet(BuildContext context, String orderId, String currentStatus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8, 
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30.0), 
              topRight: Radius.circular(30.0), 
            ),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text("Order: $orderId Not Found", style: _getTenorSansStyle(18)));
              }

              final orderData = snapshot.data!.data() as Map<String, dynamic>;
              final documentId = snapshot.data!.id; 
              
              final dataWithId = {
                  ...orderData,
                  'documentId': documentId, 
              };

              final involvedStores = orderData['involvedStores'] as List<dynamic>?;
              final storeEmail = involvedStores?.isNotEmpty == true ? involvedStores!.first.toString() : null;

              return FutureBuilder<String?>(
                future: storeEmail != null ? _fetchStoreType(storeEmail) : Future.value(null),
                builder: (context, storeTypeSnapshot) {
                  final storeType = storeTypeSnapshot.data ?? 'Food'; 
                  
                  if (storeTypeSnapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
                  }
              
                  return _buildOrderDetailsContent(context, dataWithId, storeType); 
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _fetchStoreType(String storeEmail) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('storeRequests')
        .where('email', isEqualTo: storeEmail)
        .limit(1)
        .get();
        
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data()['storeType'] as String?;
    }
    return null;
  } catch (e) {
    //print("Error fetching store type: $e");
    return null;
  }
}

// 2. تعيين أيقونة التحضير بناءً على نوع المتجر
IconData _getPreparationIcon(String storeType) {
  switch (storeType.toLowerCase()) {
    case 'market':
      return Icons.shopping_basket_outlined; 
    case 'clothes':
      return Icons.checkroom_outlined; 
    case 'pharmacy':
      return Icons.medical_services_outlined; 
    case 'food':
    case 'restaurants':
      return Icons.restaurant_menu_outlined; 
    default:
      return Icons.build; 
  }
}

  // ⭐️ ودجت المنتج لعرض قائمة الطلبات بشكل أنيق
  Widget _buildProductItem(BuildContext context, Map<String, dynamic> item) {
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final quantity = item['quantity'] as int? ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐️ صورة المنتج (حاوية أنيقة)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
              image: item['imageUrl'] != null
                  ? DecorationImage(
                      image: NetworkImage(item['imageUrl'] as String),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item['imageUrl'] == null ? const Icon(Icons.image_not_supported, color: Colors.grey) : null,
          ),
          const SizedBox(width: 15),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⭐️ اسم المنتج
                Text(
                  item['name'] as String? ?? 'Unknown Product',
                  style: _getTenorSansStyle(16, weight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // ⭐️ السعر والكمية
                Text(
                  'Qty: $quantity x \$${price.toStringAsFixed(2)}',
                  style: _getTenorSansStyle(14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          
          // ⭐️ الإجمالي الفرعي (لون برتقالي غير مُخيف)
          Text(
            '\$${(price * quantity).toStringAsFixed(2)}',
            style: _getTenorSansStyle(16, weight: FontWeight.bold, color: Colors.deepOrange),
          ),
        ],
      ),
    );
  }

  // ⭐️ ودجت أيقونة التوصيل المخصصة
  IconData _getDeliveryIcon(String deliveryOption) {
    if (deliveryOption.toLowerCase().contains('drone')) {
      return Icons.flight; 
    } else if (deliveryOption.toLowerCase().contains('express')) {
      return Icons.flash_on; 
    } else {
      return Icons.two_wheeler; 
    }
  }

  // 💡 المحتوى الرئيسي للورقة السفلية (تم تحسينه)
  Widget _buildOrderDetailsContent(BuildContext context, Map<String, dynamic> orderData, String storeType) {
    final status = orderData['status'] as String? ?? 'Pending';
    final total = orderData['total'] ?? 0;
    final createdAtTimestamp = orderData['createdAt'] as Timestamp?;
    final date = createdAtTimestamp != null ? createdAtTimestamp.toDate() : DateTime.now();
    final documentId = orderData['documentId'] as String? ?? 'N/A'; 
    final deliveryOption = orderData['deliveryOption'] as String? ?? 'Standard';
    final items = orderData['items'] as List<dynamic>? ?? [];
    final storeName = (items.isNotEmpty) ? items.first['storeName'] : 'Unknown Store';
    
    // ⭐️ استخلاص طريقة الدفع
    final paymentMethod = orderData['paymentMethod'] as String? ?? 'Not Specified'; 
    
    final preparationIcon = _getPreparationIcon(storeType); 
    
    // ⭐️ تنسيق الوقت والتاريخ
    final timeFormat = DateFormat('h:mm a'); // 1:48 AM/PM
    final dateFormat = DateFormat('MMM d'); // Oct 1
    final formattedTime = '${timeFormat.format(date)} - ${dateFormat.format(date)}';

    final trackingSteps = [
      // 💡 تم تغيير الأيقونة
      {'title': 'Order Placed', 'status': 'Pending', 'icon': Icons.verified_user_outlined},
      {'title': 'Preparation', 'status': 'Processing', 'icon': preparationIcon}, 
      {'title': 'On Delivery', 'status': 'Out for Delivery', 'icon': _getDeliveryIcon(deliveryOption)}, 
      {'title': 'Delivered', 'status': 'Delivered', 'icon': Icons.home_outlined},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 30.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. العنوان ورقم الطلب (شريط أنيق ومرتب)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                "Order: $documentId",
                style: _getTenorSansStyle(14, weight: FontWeight.w600, color: Colors.grey.shade800), 
                textAlign: TextAlign.center, 
                softWrap: true, 
              ),
            ),
          ),
          const SizedBox(height: 25), 
          
          // 2. شريط التتبع الأفقي
          _buildTrackingTimeline(trackingSteps, status),
          
          const Divider(height: 30, thickness: 1.5, color: Colors.grey),

          // 3. تفاصيل الطلب السريعة واسم المتجر
          Text(
            "$storeName Order Summary", 
            style: _getTenorSansStyle(18, weight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          
          _buildDetailRow(context, "Order Time:", formattedTime, icon: Icons.access_time),
          _buildDetailRow(context, "Payment Method:", paymentMethod, icon: Icons.credit_card_outlined), // ⭐️ تم إضافة طريقة الدفع
          _buildDetailRow(context, "Total Amount:", "\$${total.toStringAsFixed(2)}", color: Colors.deepOrange),
          
          const Divider(height: 30, thickness: 0.8),
          
          // 4. قائمة المنتجات (أكثر تفصيلاً)
          Text(
            "Items Ordered (${items.length})", 
            style: _getTenorSansStyle(18, weight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          
          ...items.map((item) => _buildProductItem(context, item as Map<String, dynamic>)).toList(),
          
          const Divider(height: 30, thickness: 0.8),
          
          // 5. معلومات التوصيل (عنوان في المنتصف)
          Center(
            child: Text(
              "Delivery Info", 
              style: _getTenorSansStyle(18, weight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 15),
          
          _buildDetailRow(context, "Delivery Method:", deliveryOption, icon: _getDeliveryIcon(deliveryOption)),
          _buildDetailRow(context, "Address:", orderData['address_Full'], isAddress: true, icon: Icons.location_on_outlined),
          _buildDetailRow(context, "Instructions:", orderData['address_DeliveryInstructions'], icon: Icons.notes_outlined),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ودجت مساعد لبناء صفوف التفاصيل (مع دعم الأيقونات)
  Widget _buildDetailRow(BuildContext context, String label, dynamic value, {Color? color, IconData? icon, bool isAddress = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isAddress ? CrossAxisAlignment.start : CrossAxisAlignment.center, 
        children: [
          // ⭐️ أيقونة (إذا كانت موجودة)
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 10),
          ],
          
          // 1. Label
          SizedBox(
            width: 130, // عرض ثابت لـ Label (لتنظيم أفضل)
            child: Text(
              label, 
              style: _getTenorSansStyle(15).copyWith(color: Colors.grey.shade600),
            ),
          ),
          
          // 2. Value
          Expanded( 
            child: Text(
              value.toString(),
              style: _getTenorSansStyle(15, weight: FontWeight.w600).copyWith(color: color),
              textAlign: TextAlign.right, // محاذاة النص لليمين لجعله يبدو مرتباً
              maxLines: isAddress ? 4 : 2, // عدد أسطر أكبر للعنوان
              overflow: TextOverflow.ellipsis, 
            ),
          ),
        ],
      ),
    );
  }
  
  // ودجت بناء شريط التتبع (أيقونات واضحة)
  Widget _buildTrackingTimeline(List<Map<String, dynamic>> steps, String currentStatus) {
    return SizedBox(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, 
        children: steps.map((step) {
          final isCompleted = _isStepCompleted(step['status'] as String, currentStatus);
          
          // 💡 تغيير اللون بناءً على حالة الطلب
          Color statusColor;
          if (step['status'] == 'Pending') {
             // ⭐️ لون حيادي للمرحلة الأولى
             statusColor = Colors.lightBlue.shade600; 
          } else {
             statusColor = _getStatusColor(step['status']);
          }
          
          final color = isCompleted ? statusColor : Colors.grey.shade400; 
          final icon = step['icon'] as IconData;
          
          return Expanded( 
            child: Column(
              children: [
                // ⭐️ أيقونة الخطوة
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 5),
                // ⭐️ عنوان الخطوة
                Text(
                  step['title'] as String, 
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), 
                  textAlign: TextAlign.center, 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // دالة مساعدة لتحديد ما إذا كانت الخطوة قد اكتملت
  bool _isStepCompleted(String stepStatus, String currentStatus) {
    final statusOrder = ['Pending', 'Processing', 'Out for Delivery', 'Delivered'];
    final currentStatusIndex = statusOrder.indexOf(currentStatus);
    final stepStatusIndex = statusOrder.indexOf(stepStatus);
    return currentStatusIndex >= stepStatusIndex;
  }
  
  // دالة مساعدة للحصول على لون الحالة
  Color _getStatusColor(String status) {
    switch (status) {
      // 💡 تغيير لون Pending ليتناسب مع التتبع
      case 'Pending': return Colors.lightBlue.shade600; 
      case 'Processing': return Colors.blue.shade600;
      case 'Out for Delivery': return Colors.green.shade600;
      case 'Delivered': return Colors.green.shade700;
      default: return Colors.grey;
    }
  }
}
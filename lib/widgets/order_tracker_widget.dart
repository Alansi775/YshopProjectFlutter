// lib/widgets/order_tracker_widget.dart (مصحح للثيم الديناميكي)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import '../state_management/cart_manager.dart'; 

class OrderTrackerWidget extends StatelessWidget {
  const OrderTrackerWidget({Key? key}) : super(key: key);
  
  // 💡 تم تعديل الدالة لتقبل context وتستخدم primaryColor افتراضيًا
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return TextStyle(
      fontFamily: 'TenorSans', 
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor,
    );
  }

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
    
    Color statusColor = _getStatusColor(status); // 💡 استخدام دالة موحدة

    // 💡 إخفاء الودجت إذا تم التوصيل ومسح الـ orderId
    if (status == 'Delivered') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ننتظر قليلاً (اختياري) قبل المسح لإعطاء المستخدم وقتاً لرؤية الحالة
        Future.delayed(const Duration(seconds: 1), () {
            Provider.of<CartManager>(context, listen: false).setLastOrderId(null);
        });
      });
      return const SizedBox.shrink();
    }
    
    IconData statusIcon;
    switch (status) {
      case 'Pending': statusIcon = Icons.hourglass_top; break;
      case 'Processing': statusIcon = Icons.kitchen_rounded; break;
      case 'Out for Delivery': statusIcon = Icons.delivery_dining; break;
      default: statusIcon = Icons.error_outline;
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
            // 💡 لون الأيقونة يبقى أبيض ليتناقض مع ألوان الحالة
            child: Icon(statusIcon, color: Colors.white, size: 28), 
          ),
        ),
      ),
    );
  }

  // عرض الورقة السفلية لتفاصيل الطلب
  void _showOrderDetailsSheet(BuildContext context, String orderId, String currentStatus) {
    // 💡 جلب الألوان الديناميكية
    final Color cardColor = Theme.of(context).cardColor;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8, 
          decoration: BoxDecoration(
            color: cardColor, // 💡 استخدام cardColor
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30.0), 
              topRight: Radius.circular(30.0), 
            ),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // 💡 استخدام لون يتناسب مع الثيم (secondary)
                return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary)); 
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text("Order: $orderId Not Found", style: _getTenorSansStyle(context, 18))); // 💡 تمرير context
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
                     // 💡 استخدام لون يتناسب مع الثيم (secondary)
                     return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary));
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

  // دالة جلب نوع المتجر (تبقى كما هي)
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
      return null;
    }
  }

  // دالة تعيين أيقونة التحضير (تبقى كما هي)
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
    // 💡 جلب الألوان الديناميكية
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    final Color cardColor = Theme.of(context).cardColor;
    
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
              color: secondaryColor.withOpacity(0.1), // 💡 لون ديناميكي خفيف
              borderRadius: BorderRadius.circular(10),
              image: item['imageUrl'] != null
                  ? DecorationImage(
                      image: NetworkImage(item['imageUrl'] as String),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            // 💡 استخدام secondaryColor للأيقونة
            child: item['imageUrl'] == null ? Icon(Icons.image_not_supported, color: secondaryColor.withOpacity(0.5)) : null,
          ),
          const SizedBox(width: 15),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⭐️ اسم المنتج
                Text(
                  item['name'] as String? ?? 'Unknown Product',
                  style: _getTenorSansStyle(context, 16, weight: FontWeight.w600), // 💡 تمرير context
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // ⭐️ السعر والكمية
                Text(
                  'Qty: $quantity x \$${price.toStringAsFixed(2)}',
                  // 💡 استخدام secondaryColor
                  style: _getTenorSansStyle(context, 14).copyWith(color: secondaryColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          
          // ⭐️ الإجمالي الفرعي (لون برتقالي غير مُخيف)
          Text(
            '\$${(price * quantity).toStringAsFixed(2)}',
            style: _getTenorSansStyle(context, 16, weight: FontWeight.bold, color: Colors.deepOrange),
          ),
        ],
      ),
    );
  }

  // ⭐️ ودجت أيقونة التوصيل المخصصة (تبقى كما هي)
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
    final total = (orderData['total'] as num?)?.toDouble() ?? 0.0;
    final createdAtTimestamp = orderData['createdAt'] as Timestamp?;
    final date = createdAtTimestamp != null ? createdAtTimestamp.toDate() : DateTime.now();
    final documentId = orderData['documentId'] as String? ?? 'N/A'; 
    final deliveryOption = orderData['deliveryOption'] as String? ?? 'Standard';
    final items = orderData['items'] as List<dynamic>? ?? [];
    final storeName = (items.isNotEmpty) ? items.first['storeName'] : 'Unknown Store';
    
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    final paymentMethod = orderData['paymentMethod'] as String? ?? 'Not Specified'; 
    final preparationIcon = _getPreparationIcon(storeType); 
    
    final timeFormat = DateFormat('h:mm a'); 
    final dateFormat = DateFormat('MMM d'); 
    final formattedTime = '${timeFormat.format(date)} - ${dateFormat.format(date)}';

    final trackingSteps = [
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
          // 1. العنوان ورقم الطلب
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
              decoration: BoxDecoration(
                // 💡 استخدام لون ثانوي خفيف
                color: secondaryColor.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                "Order: $documentId",
                // 💡 استخدام primaryColor
                style: _getTenorSansStyle(context, 14, weight: FontWeight.w600, color: primaryColor), 
                textAlign: TextAlign.center, 
                softWrap: true, 
              ),
            ),
          ),
          const SizedBox(height: 25), 
          
          // 2. شريط التتبع الأفقي
          _buildTrackingTimeline(context, trackingSteps, status), // 💡 تمرير context
          
          // 💡 استخدام Divider يتكيف مع الثيم
          Divider(height: 30, thickness: 1.5, color: Theme.of(context).dividerColor),

          // 3. تفاصيل الطلب السريعة واسم المتجر
          Text(
            "$storeName Order Summary", 
            style: _getTenorSansStyle(context, 18, weight: FontWeight.bold), // 💡 تمرير context
          ),
          const SizedBox(height: 15),
          
          _buildDetailRow(context, "Order Time:", formattedTime, icon: Icons.access_time),
          _buildDetailRow(context, "Payment Method:", paymentMethod, icon: Icons.credit_card_outlined), 
          _buildDetailRow(context, "Total Amount:", "\$${total.toStringAsFixed(2)}", color: Colors.deepOrange),
          
          // 💡 استخدام Divider يتكيف مع الثيم
          Divider(height: 30, thickness: 0.8, color: Theme.of(context).dividerColor),
          
          // 4. قائمة المنتجات
          Text(
            "Items Ordered (${items.length})", 
            style: _getTenorSansStyle(context, 18, weight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          
          ...items.map((item) => _buildProductItem(context, item as Map<String, dynamic>)).toList(),
          
          // 💡 استخدام Divider يتكيف مع الثيم
          Divider(height: 30, thickness: 0.8, color: Theme.of(context).dividerColor),
          
          // 5. معلومات التوصيل
          Center(
            child: Text(
              "Delivery Info", 
              style: _getTenorSansStyle(context, 18, weight: FontWeight.bold),
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
    // 💡 جلب الألوان الديناميكية
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isAddress ? CrossAxisAlignment.start : CrossAxisAlignment.center, 
        children: [
          // ⭐️ أيقونة
          if (icon != null) ...[
            // 💡 استخدام secondaryColor
            Icon(icon, size: 20, color: secondaryColor.withOpacity(0.7)),
            const SizedBox(width: 10),
          ],
          
          // 1. Label
          SizedBox(
            width: 130, 
            child: Text(
              label, 
              // 💡 استخدام secondaryColor
              style: _getTenorSansStyle(context, 15).copyWith(color: secondaryColor.withOpacity(0.7)),
            ),
          ),
          
          // 2. Value
          Expanded( 
            child: Text(
              value.toString(),
              // 💡 استخدام primaryColor إذا لم يتم تحديد لون
              style: _getTenorSansStyle(context, 15, weight: FontWeight.w600).copyWith(color: color),
              textAlign: TextAlign.right, 
              maxLines: isAddress ? 4 : 2, 
              overflow: TextOverflow.ellipsis, 
            ),
          ),
        ],
      ),
    );
  }
  
  // ودجت بناء شريط التتبع (أيقونات واضحة)
  Widget _buildTrackingTimeline(BuildContext context, List<Map<String, dynamic>> steps, String currentStatus) {
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    
    return SizedBox(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, 
        children: steps.map((step) {
          final isCompleted = _isStepCompleted(step['status'] as String, currentStatus);
          
          Color statusColor = _getStatusColor(step['status']);
          
          final color = isCompleted ? statusColor : Theme.of(context).dividerColor; // 💡 استخدام لون الـ Divider للخطوات غير المكتملة
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
                  // 💡 استخدام لون الخطوة المكتملة أو primaryColor للخطوة غير المكتملة
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

  // دالة مساعدة لتحديد ما إذا كانت الخطوة قد اكتملت (تبقى كما هي)
  bool _isStepCompleted(String stepStatus, String currentStatus) {
    final statusOrder = ['Pending', 'Processing', 'Out for Delivery', 'Delivered'];
    final currentStatusIndex = statusOrder.indexOf(currentStatus);
    final stepStatusIndex = statusOrder.indexOf(stepStatus);
    return currentStatusIndex >= stepStatusIndex;
  }
  
  // دالة مساعدة للحصول على لون الحالة (تبقى كما هي)
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.lightBlue.shade600; 
      case 'Processing': return Colors.blue.shade600;
      case 'Out for Delivery': return Colors.green.shade600;
      case 'Delivered': return Colors.green.shade700;
      default: return Colors.red.shade600;
    }
  }
}
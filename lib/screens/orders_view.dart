import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // لاستخدام HapticFeedback
// يجب أن تضيف مكتبة masr_barcode_scan أو flutter_barcode_scanner
// لكن سنقوم بإنشاء الدالة مؤقتاً هنا
// import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart'; 
import 'package:qr_flutter/qr_flutter.dart';

class OrdersView extends StatefulWidget {
  final String storeEmail; 
  static const double APP_COMMISSION_RATE = 0.25; // 25%

  const OrdersView({super.key, required this.storeEmail});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        // البحث يركز على أول 10 أحرف من الـ ID أو اسم العميل
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // 💡 دالة لتغيير حالة الطلب في Firestore
  Future<void> _updateOrderStatus(String orderId, String newStatus, BuildContext context) async {
  
  // 1. تعريف خريطة بيانات التحديث
  Map<String, dynamic> updateData = {
    'status': newStatus,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  // ✅ الإضافة المطلوبة: إذا كانت الحالة الجديدة هي 'Processing' (قبول المتجر)
  if (newStatus == 'Processing') {
    // نضمن وجود هذه الحقول لكي تظهر الطلبية للسائقين الجدد
    updateData['driverAccepted'] = false; 
    updateData['driverId'] = null; 
  }

  try {
    // 2. تطبيق التحديث
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update(updateData);
    
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order $orderId status updated to $newStatus')),
        );
      }
    });
  } catch (e) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status: $e')),
        );
      }
    });
  }
}

  // 💡 دالة محاكاة لمسح الباركود/QR
  Future<void> _scanQRCode() async {
    try {
      // 🚀 عند استخدام مكتبة خارجية مثل flutter_barcode_scanner
      // final barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
      //     "#ff6666", "Cancel", true, ScanMode.QR);
      
      // هنا سنفترض أن نتيجة المسح هي Order ID
      const String fakeOrderId = 'ORDER_ID_FROM_SCANNER'; // يتم استبدالها بالنتيجة الحقيقية

      setState(() {
        _searchController.text = fakeOrderId; // وضع الـ ID في خانة البحث
        HapticFeedback.lightImpact(); // اهتزاز خفيف لتأكيد المسح
      });

      // إظهار تنبيه لطريقة العمل
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Scan completed! Searching by Order ID.')),
        );
      }

    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get platform version.')),
        );
      }
    }
  }

  // استايل بسيط مؤقت
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  // دالة موحدة لتحديد لون الحالة
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange.shade700; 
      case 'Processing': return Colors.blue.shade600;
      case 'Rejected': return Colors.red.shade700;
      case 'Out for Delivery': return Colors.green.shade500;
      case 'Delivered': return Colors.green.shade800;
      default: return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Store Orders", 
          style: _getTenorSansStyle(context, 20, weight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner_outlined, color: primaryColor, size: 28),
            onPressed: _scanQRCode, // تشغيل خاصية المسح
            tooltip: 'Scan Order QR Code',
          ),
          const SizedBox(width: 10),
        ],
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Order ID or Customer Name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
              ),
              onSubmitted: (_) {
                // قد تحتاج لتحديث قائمة الطلبيات هنا إذا لم يكن StreamBuilder كافياً
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('involvedStores', arrayContains: widget.storeEmail)
            .where('status', whereIn: ['Pending', 'Processing', 'Out for Delivery']) // إضافة Out for Delivery
            .orderBy('createdAt', descending: true)
            .snapshots(),
        
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: _getTenorSansStyle(context, 16)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No active orders found.",
                style: _getTenorSansStyle(context, 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
            );
          }

          final allOrders = snapshot.data!.docs;
          
          // 💡 تطبيق البحث الذكي بعد جلب البيانات (Search Filtering)
          final filteredOrders = allOrders.where((orderDoc) {
            final data = orderDoc.data() as Map<String, dynamic>;
            final orderId = orderDoc.id.toLowerCase();
            final userName = (data['userName'] as String? ?? '').toLowerCase();
            
            if (_searchQuery.isEmpty) return true;

            // البحث: ID كامل، أو أول 10 أحرف، أو اسم العميل
            return orderId.contains(_searchQuery) ||
                   orderId.startsWith(_searchQuery) ||
                   userName.contains(_searchQuery);
          }).toList();

          if (filteredOrders.isEmpty) {
            return Center(
              child: Text(
                "No orders match your search criteria.",
                style: _getTenorSansStyle(context, 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(15.0),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final orderDoc = filteredOrders[index];
              final orderData = orderDoc.data() as Map<String, dynamic>;
              
              return _buildOrderCard(context, orderDoc.id, orderData);
            },
          );
        },
      ),
    );
  }

  // 💡 تصميم بطاقة الطلب (Order Card)
  Widget _buildOrderCard(BuildContext context, String orderId, Map<String, dynamic> orderData) {
    // ... (نفس منطق الحسابات وتجهيز البيانات الذي كان موجودًا)
    final status = orderData['status'] as String? ?? 'Pending';
    final userName = orderData['userName'] as String? ?? 'Client';
    final createdAtTimestamp = orderData['createdAt'] as Timestamp?;
    final date = createdAtTimestamp != null ? createdAtTimestamp.toDate() : DateTime.now();
    final formattedTime = DateFormat('MMM d, h:mm a').format(date);
    
    final items = orderData['items'] as List<dynamic>? ?? [];
    
    final storeItems = items.where((item) => item['storeOwnerEmail'] == widget.storeEmail).toList();
    double storeSubtotal = storeItems.fold(0.0, (sum, item) => sum + ((item['price'] as num? ?? 0.0) * (item['quantity'] as int? ?? 0)));
    
    final commission = storeSubtotal * OrdersView.APP_COMMISSION_RATE;
    final netStoreProfit = storeSubtotal - commission;

    final cardColor = Theme.of(context).cardColor;
    final secondaryColor = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;

    Color statusColor = _getStatusColor(status);
    
    final firstItemImage = storeItems.isNotEmpty ? storeItems.first['imageUrl'] as String? : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: secondaryColor.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Header (ID, Time, Status)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // إظهار ID كامل مع قص لـ 10 أحرف
                Text(
                  "ORDER ID: #${orderId.substring(0, orderId.length > 10 ? 10 : orderId.length).toUpperCase()}...",
                  style: _getTenorSansStyle(context, 15, weight: FontWeight.bold, color: primaryColor),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    status,
                    style: _getTenorSansStyle(context, 13, weight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, thickness: 1, color: secondaryColor.withOpacity(0.08)),

          // 2. Body (Image, Customer, Items, Time)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Image (صورة الطلب)
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    image: firstItemImage != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(firstItemImage),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: firstItemImage == null ? Icon(Icons.receipt_long, size: 30, color: secondaryColor.withOpacity(0.5)) : null,
                ),
                
                const SizedBox(width: 15),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // العميل
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 18, color: secondaryColor.withOpacity(0.7)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              "Customer: $userName",
                              style: _getTenorSansStyle(context, 14, weight: FontWeight.w600, color: secondaryColor.withOpacity(0.9)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // الوقت
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 18, color: secondaryColor.withOpacity(0.7)),
                          const SizedBox(width: 5),
                          Text(
                            "Order Time: $formattedTime",
                            style: _getTenorSansStyle(context, 14, color: secondaryColor.withOpacity(0.7)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // قائمة المنتجات المختصرة
                      Text(
                        "Items from your store (${storeItems.length}):",
                        style: _getTenorSansStyle(context, 14, weight: FontWeight.bold, color: secondaryColor),
                      ),
                      const SizedBox(height: 6),
                      ...storeItems.take(2).map((item) {
                        final itemName = item['name'] as String? ?? 'N/A';
                        final quantity = item['quantity'] as int? ?? 1;
                        return Padding(
                          padding: const EdgeInsets.only(left: 10, top: 2),
                          child: Text(
                            "• $quantity x $itemName",
                            style: _getTenorSansStyle(context, 13, color: secondaryColor.withOpacity(0.8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      if (storeItems.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(left: 10, top: 4),
                          child: Text(
                            " + ${storeItems.length - 2} more items",
                            style: _getTenorSansStyle(context, 13, color: primaryColor, weight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Financial Summary (ملخص الأرباح)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(context, "Store Subtotal:", '\$${storeSubtotal.toStringAsFixed(2)}', secondaryColor),
                _buildSummaryRow(context, "App Commission (25%):", '-\$${commission.toStringAsFixed(2)}', Colors.red.shade400),
                Divider(height: 20, thickness: 1.5, color: secondaryColor.withOpacity(0.1)),
                _buildSummaryRow(context, "Net Profit (To You):", '\$${netStoreProfit.toStringAsFixed(2)}', Colors.green.shade600, isBold: true, size: 17),
                
                // 💡 إضافة زر تفاصيل ورؤية QR فقط عندما يكون الطلب قيد التجهيز
                if (status == 'Processing')
                  _buildReadyToHandoverSection(context, orderId, primaryColor)
                else if (status == 'Pending')
                  _buildActionButtons(context, orderId, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ودجت بناء صف الملخص المالي
  Widget _buildSummaryRow(BuildContext context, String label, String value, Color valueColor, {bool isBold = false, double size = 14}) {
    final secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: _getTenorSansStyle(context, size, weight: isBold ? FontWeight.bold : FontWeight.normal, color: secondaryColor.withOpacity(isBold ? 1.0 : 0.8)),
          ),
          Text(
            value,
            style: _getTenorSansStyle(context, size, weight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
  
  // ودجت بناء أزرار القبول/الرفض
  Widget _buildActionButtons(BuildContext context, String orderId, Color primaryColor) {
    final buttonContentColor = Theme.of(context).colorScheme.onPrimary; 
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateOrderStatus(orderId, 'Processing', context),

              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: Text("Accept Order", style: _getTenorSansStyle(context, 16, color: buttonContentColor, weight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _updateOrderStatus(orderId, 'Rejected', context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.red.shade600, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Reject", style: _getTenorSansStyle(context, 16, color: Colors.red.shade600, weight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 💡 ودجت جديد لتسليم الطلب الجاهز
  // 💡 ودجت جديد لتسليم الطلب الجاهز
  Widget _buildReadyToHandoverSection(BuildContext context, String orderId, Color primaryColor) {
    // 💡 تحديد الألوان المتكيفة
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // لون الحالة: أخضر فاتح في Dark Mode وأخضر داكن في Light Mode
    final readyMessageColor = isDarkMode ? Colors.green.shade400 : Colors.green.shade700;
    
    // لون الزر: ثابت على الأخضر القوي (لون أكشن)
    final buttonBackgroundColor = Colors.green.shade700; 
    
    // لون النص على الزر: أبيض عادةً لأن لون الزر داكن بما فيه الكفاية في كلتا الحالتين
    // لكن يمكن جعله متكيفاً لضمان أفضل نتيجة (نستخدم onPrimary لأنه عادة أبيض)
    final buttonContentColor = Theme.of(context).colorScheme.onPrimary; 
    
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🚀 التعديل الأول: جعل لون النص متكيفاً
          Text(
            "Order is ready for pickup! 🛵",
            textAlign: TextAlign.center,
            style: _getTenorSansStyle(context, 15, weight: FontWeight.bold, color: primaryColor),
          ),
          const SizedBox(height: 12),
          // 🚀 التعديل الثاني: جعل أيقونة ونصوص الزر تستخدم اللون المتكيف
          ElevatedButton.icon(
            icon: Icon(Icons.qr_code_2_outlined, color: buttonContentColor),
            label: Text(
              "Show QR Code for Delivery", 
              style: _getTenorSansStyle(context, 16, color: buttonContentColor, weight: FontWeight.bold)
            ),
            onPressed: () => _showQrCodeModal(context, orderId),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 5,
            ),
          ),
        ],
      ),
    );
  }

  // 💡 عرض نافذة الـ QR Code المنبثقة
  void _showQrCodeModal(BuildContext context, String orderId) {
    // 💡 1. تحديد وضعية المظهر واللون المناسب للـ QR
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // إذا كان الوضع داكن (خلفية سوداء)، يكون لون الـ QR أبيض.
    // إذا كان الوضع فاتح (خلفية بيضاء)، يكون لون الـ QR أسود.
    final qrColor = isDarkMode ? Colors.white : Colors.black;
    final modalBackgroundColor = Theme.of(context).cardColor; // لون خلفية النافذة المنبثقة
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      backgroundColor: modalBackgroundColor, // تعيين لون خلفية النافذة
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                "Scan to Confirm Pickup",
                style: _getTenorSansStyle(context, 20, weight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 20),
              
              // 💡 2. استخدام QrImageView مع اللون المحدد
              QrImageView(
                data: orderId, 
                version: QrVersions.auto,
                size: 200.0,
                gapless: false, 
                // تحديد لون الكود بناءً على وضعية المظهر
                eyeStyle: QrEyeStyle( 
                  eyeShape: QrEyeShape.square,
                  color: qrColor, // اللون المتكيف
                ),
                dataModuleStyle: QrDataModuleStyle( 
                  dataModuleShape: QrDataModuleShape.square,
                  color: qrColor, // اللون المتكيف
                ),
                // إذا كنت في وضعية Dark Mode، يجب أن تكون منطقة الـ QR واضحة،
                // لذلك نحدد لون الخلفية للمنطقة كـ عكس لون الكود لضمان التباين.
                // هذه خطوة اختيارية لكنها مفيدة جداً في Dark Mode.
                // *ملاحظة*: يتم بشكل عام الاعتماد على لون خلفية الـ Modal كخلفية لـ QR.
              ),
              
              const SizedBox(height: 20),
              Text(
                "Order ID: #${orderId.substring(0, orderId.length > 10 ? 10 : orderId.length).toUpperCase()}...",
                style: _getTenorSansStyle(context, 16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                "The delivery driver will scan this code to change the order status to 'Out for Delivery' automatically.",
                textAlign: TextAlign.center,
                style: _getTenorSansStyle(context, 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "Close", 
                  style: _getTenorSansStyle(context, 16, color: onPrimaryColor, weight: FontWeight.bold)
                ),
              ),
            ],
          ),
        );
      },
    );
}
}
// lib/screens/delivery_qr_scanner_view.dart
// --------------------------------------------------
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// 🚀 الاستيراد المصحح: استخدام "dm" كاسم مستعار لنموذج Order و DetailRow
import 'delivery_home_view.dart' as dm show Order, DetailRow, OrderItem;

// 💡 استيراد شاشة الخريطة الجديدة
import 'map_of_delivery_man.dart'; 

// --------------------------------------------------
// MARK: - Order Details and QR Scanner Logic
// --------------------------------------------------

class OrderDetailsView extends StatefulWidget {
// ✅ استخدام dm.Order
  final dm.Order order;
  final String driverId;
  final Color kDarkBackground;
  final Color kCardBackground;
  final Color kAppBarBackground;
  final Color kPrimaryTextColor;
  final Color kSecondaryTextColor;
  final Color kSeparatorColor;
  final Color kAccentBlue;


  const OrderDetailsView({
    super.key,
    required this.order,
    required this.driverId,
    required this.kDarkBackground,
    required this.kCardBackground,
    required this.kAppBarBackground,
    required this.kPrimaryTextColor,
    required this.kSecondaryTextColor,
    required this.kSeparatorColor,
    required this.kAccentBlue,
  });

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  final _firestore = FirebaseFirestore.instance;
  // ✅ استخدام dm.Order
  late dm.Order _currentOrder;
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    if (_currentOrder.driverAccepted && _currentOrder.driverId == widget.driverId) {
      _isAccepted = true;
    }
  }

  void _acceptOrder() async {
    try {
      await _firestore.collection("orders").doc(_currentOrder.id).update({
        'driverAccepted': true,
        'driverId': widget.driverId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final updatedDoc = await _firestore.collection("orders").doc(_currentOrder.id).get();
      setState(() {
        _isAccepted = true;
        // ✅ استخدام dm.Order
        _currentOrder = dm.Order.fromFirestore(updatedDoc);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted! Please head to the store to pick it up.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept order: $e')),
      );
    }
  }
// --------------------------------------------------
// 1. دالة المساعدة: عرض رسالة النجاح والانتقال للخريطة
// --------------------------------------------------

  void _showSuccessAndNavigateToMap(BuildContext context, dm.Order updatedOrder) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.kCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            Text(
              "Order Picked Up!",
              style: TextStyle(color: widget.kPrimaryTextColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Great! The order is now 'Out for Delivery'. Proceed to the map to deliver it to the customer.",
              textAlign: TextAlign.center,
              style: TextStyle(color: widget.kSecondaryTextColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // إغلاق رسالة النجاح
              // الانتقال إلى شاشة الخريطة الجديدة (DeliveryMapView) واستبدال الشاشة الحالية
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => DeliveryMapView(
                    order: updatedOrder,
                    kDarkBackground: widget.kDarkBackground,
                    kCardBackground: widget.kCardBackground,
                    kAppBarBackground: widget.kAppBarBackground,
                    kPrimaryTextColor: widget.kPrimaryTextColor,
                    kSecondaryTextColor: widget.kSecondaryTextColor,
                    kSeparatorColor: widget.kSeparatorColor,
                    kAccentBlue: widget.kAccentBlue,
                  ),
                ),
              );
            },
            child: Text("Go to Map", style: TextStyle(color: widget.kAccentBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


// --------------------------------------------------
// 2. دالة: _scanQRCode (آلية مسح الكود)
// --------------------------------------------------

  void _scanQRCode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerView(
          orderId: _currentOrder.id,
          // تمرير الثوابت
          kDarkBackground: widget.kDarkBackground,
          kCardBackground: widget.kCardBackground,
          kAppBarBackground: widget.kAppBarBackground,
          kPrimaryTextColor: widget.kPrimaryTextColor,
          kSecondaryTextColor: widget.kSecondaryTextColor,
          kAccentBlue: widget.kAccentBlue,
          onScanSuccess: () async {
            // 1. تحديث الحالة في Firestore
            await _firestore.collection("orders").doc(_currentOrder.id).update({
              'status': 'Out for Delivery',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            // 2. قراءة نسخة محدثة من الطلب من Firestore
            final updatedDoc = await _firestore.collection("orders").doc(_currentOrder.id).get();
            final updatedOrder = dm.Order.fromFirestore(updatedDoc);
            // 3. تحديث حالة الـ State ثم إغلاق شاشة الماسح
            if (mounted) {
              setState(() {
                _currentOrder = updatedOrder;
              });
              Navigator.pop(context); // إغلاق شاشة الماسح
              // 4. عرض رسالة النجاح والانتقال إلى شاشة الخريطة
              _showSuccessAndNavigateToMap(context, updatedOrder);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 💡 إذا كانت الحالة 'Out for Delivery'، انتقل مباشرة إلى شاشة الخريطة الجديدة
    if (_currentOrder.status == 'Out for Delivery') {
      return DeliveryMapView(
        order: _currentOrder,
        kDarkBackground: widget.kDarkBackground,
        kCardBackground: widget.kCardBackground,
        kAppBarBackground: widget.kAppBarBackground,
        kPrimaryTextColor: widget.kPrimaryTextColor,
        kSecondaryTextColor: widget.kSecondaryTextColor,
        kSeparatorColor: widget.kSeparatorColor,
        kAccentBlue: widget.kAccentBlue,
      );
    }
    final isAccepted = _isAccepted || _currentOrder.driverAccepted;
    final primaryStore = _currentOrder.items.first;

    return Scaffold(
      backgroundColor: widget.kDarkBackground,
      appBar: AppBar(
        title: Text("Order: ${_currentOrder.id.substring(0, 8)}", style: TextStyle(color: widget.kPrimaryTextColor)),
        backgroundColor: widget.kAppBarBackground,
        iconTheme: IconThemeData(color: widget.kPrimaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailSection( // 💡 استخدام DetailSection (عام)
              title: "Restaurant Info",
              kCardBackground: widget.kCardBackground,
              kAccentBlue: widget.kAccentBlue,
              kSeparatorColor: widget.kSeparatorColor,
              // ✅ استخدام dm.DetailRow
              children: [
                dm.DetailRow(label: "Store Name", value: primaryStore.storeName, valueAlignment: TextAlign.start),
                dm.DetailRow(label: "Store Phone", value: primaryStore.storePhone, valueAlignment: TextAlign.start),
                dm.DetailRow(label: "Store Email", value: primaryStore.storeOwnerEmail, valueAlignment: TextAlign.start),
              ],
            ),
            const SizedBox(height: 20),
            DetailSection( // 💡 استخدام DetailSection (عام)
              title: "Customer Info",
              kCardBackground: widget.kCardBackground,
              kAccentBlue: widget.kAccentBlue,
              kSeparatorColor: widget.kSeparatorColor,
              // ✅ استخدام dm.DetailRow
              children: [
                dm.DetailRow(label: "Customer Name", value: _currentOrder.userName, valueAlignment: TextAlign.start),
                dm.DetailRow(label: "Customer Phone", value: _currentOrder.userPhone, valueAlignment: TextAlign.start),
                dm.DetailRow(label: "Order Total", value: "\$${_currentOrder.total.toStringAsFixed(2)}", valueAlignment: TextAlign.start),
              ],
            ),
            const SizedBox(height: 20),

            DetailSection( // 💡 استخدام DetailSection (عام)
              title: "Delivery Address",
              kCardBackground: widget.kCardBackground,
              kAccentBlue: widget.kAccentBlue,
              kSeparatorColor: widget.kSeparatorColor,
              // ✅ استخدام dm.DetailRow
              children: [
                dm.DetailRow(label: "Full Address", value: _currentOrder.addressFull, isMultiline: true, valueAlignment: TextAlign.start),
                dm.DetailRow(label: "Building", value: _currentOrder.addressBuilding, valueAlignment: TextAlign.start),
                dm.DetailRow(label: "Apartment", value: _currentOrder.addressApartment, valueAlignment: TextAlign.start),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text("Delivery Instructions:", style: TextStyle(color: widget.kSecondaryTextColor, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellow.shade700.withOpacity(0.5)),
                  ),
                  width: double.infinity,
                  child: Text(
                    _currentOrder.addressDeliveryInstructions.isEmpty ? "No special instructions." : _currentOrder.addressDeliveryInstructions,
                    style: const TextStyle(color: Colors.yellow, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            if (!isAccepted)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ActionButton( // 💡 استخدام ActionButton (عام)
                      label: "Accept Order",
                      color: Colors.green,
                      kPrimaryTextColor: widget.kPrimaryTextColor,
                      onPressed: _acceptOrder,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ActionButton( // 💡 استخدام ActionButton (عام)
                      label: "Reject",
                      color: Colors.red,
                      kPrimaryTextColor: widget.kPrimaryTextColor,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            if (isAccepted && _currentOrder.status == 'Processing')
              ActionButton( // 💡 استخدام ActionButton (عام)
                label: "Scan QR Code for Pickup",
                color: widget.kAccentBlue,
                kPrimaryTextColor: widget.kPrimaryTextColor,
                onPressed: () => _scanQRCode(context),
              ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// MARK: - QR Scanner View (Fullscreen, Animated)
// --------------------------------------------------

class QRScannerView extends StatefulWidget {
  final String orderId;
  final VoidCallback onScanSuccess;
  final Color kDarkBackground;
  final Color kCardBackground;
  final Color kAppBarBackground;
  final Color kPrimaryTextColor;
  final Color kSecondaryTextColor;
  final Color kAccentBlue;

  const QRScannerView({
    super.key,
    required this.orderId,
    required this.onScanSuccess,
    required this.kDarkBackground,
    required this.kCardBackground,
    required this.kAppBarBackground,
    required this.kPrimaryTextColor,
    required this.kSecondaryTextColor,
    required this.kAccentBlue,
  });

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
// لضمان أن المسح يتم لمرة واحدة فقط
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // مدة التحول
    );

// التحول من الأسود الخافت إلى الأبيض الناصع عند النجاح
    _colorAnimation = ColorTween(
      begin: Colors.black.withOpacity(0.4),
      end: Colors.white,
    ).animate(_controller);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
// دالة تشغيل الأنميشن
  void _playSuccessAnimation() {
    _controller.forward().then((_) {
// إرجاع اللون للوضع الطبيعي بعد فترة قصيرة
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _controller.reverse();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
// لجعل الشاشة كاملة بدون شريط حالة iOS شفاف
    return Scaffold(
      backgroundColor: Colors.black, // خلفية سوداء للكاميرا
      body: Stack(
        children: <Widget>[
// 1. طبقة الكاميرا (ملء الشاشة)
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              facing: CameraFacing.back,
            ),
            onDetect: (capture) {
              if (_isScanned) return; // منع المسح المتعدد

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? scannedCode = barcodes.first.rawValue;
                if (scannedCode != null) {
                  if (scannedCode == widget.orderId) {
                    setState(() { _isScanned = true; });
                    _playSuccessAnimation();
// تأخير بسيط لانتهاء الأنميشن قبل إطلاق دالة النجاح
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) widget.onScanSuccess();
                    });

// SnackBar سيتم إخفاؤه بـ Navigator.pop الذي يحدث في onScanSuccess
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order successfully picked up!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid QR Code for this order.')),
                    );
                  }
                }
              }
            },
// تحديد منطقة المسح (Scan Window) يتم رسمها بواسطة CustomPainter
            scanWindow: Rect.fromCenter(
              center: Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2),
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
            ),
          ),
// 2. مربع التحديد الأنيق المتحرك (Custom Painter Overlay)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: ScannerOverlay(
                  scanWindow: Rect.fromCenter(
                    center: Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2),
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                  ),
                  color: _colorAnimation.value!, // اللون المتغير
                ),
                child: Container(),
              );
            },
          ),
// 3. النص العلوي و زر الإغلاق
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: widget.kPrimaryTextColor, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Scan QR Code',
                  style: TextStyle(color: widget.kPrimaryTextColor, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'Align the QR code with the frame to confirm pickup',
                  style: TextStyle(color: widget.kSecondaryTextColor.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),

// 4. النص السفلي
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Order ID: ${widget.orderId.substring(0, 8)}',
                style: TextStyle(color: widget.kSecondaryTextColor, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// MARK: - Scanner Overlay Custom Painter
// --------------------------------------------------

class ScannerOverlay extends CustomPainter {
  final Rect scanWindow;
  final Color color; // اللون الذي سيتم تحريكه

  ScannerOverlay({
    required this.scanWindow,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
// 1. رسم المنطقة المظللة حول المربع
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.6);
    final backgroundPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addRect(scanWindow),
    );
    canvas.drawPath(backgroundPath, backgroundPaint);

// 2. إعدادات خطوط الحواف الأنيقة
    final borderPaint = Paint()
      ..color = color // استخدام اللون المتحرك
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round; // حواف مستديرة

    const double cornerLength = 40.0; // طول حافة القوس
// رسم الحواف الأربع بشكل أنيق (قوس [ ])
// أعلى يسار
    canvas.drawLine(scanWindow.topLeft, Offset(scanWindow.left + cornerLength, scanWindow.top), borderPaint);
    canvas.drawLine(scanWindow.topLeft, Offset(scanWindow.left, scanWindow.top + cornerLength), borderPaint);

// أعلى يمين
    canvas.drawLine(scanWindow.topRight, Offset(scanWindow.right - cornerLength, scanWindow.top), borderPaint);
    canvas.drawLine(scanWindow.topRight, Offset(scanWindow.right, scanWindow.top + cornerLength), borderPaint);

// أسفل يسار
    canvas.drawLine(scanWindow.bottomLeft, Offset(scanWindow.left + cornerLength, scanWindow.bottom), borderPaint);
    canvas.drawLine(scanWindow.bottomLeft, Offset(scanWindow.left, scanWindow.bottom - cornerLength), borderPaint);

// أسفل يمين
    canvas.drawLine(scanWindow.bottomRight, Offset(scanWindow.right - cornerLength, scanWindow.bottom), borderPaint);
    canvas.drawLine(scanWindow.bottomRight, Offset(scanWindow.right, scanWindow.bottom - cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) {
    return oldDelegate.color != color; // إعادة الرسم عند تغير اللون فقط
  }
}

// --------------------------------------------------
// MARK: - Helper Widgets (تمت إزالة الـ _ لتمكين الاستخدام الخارجي)
// --------------------------------------------------

class DetailSection extends StatelessWidget { // 💡 عام
  final String title;
  final List<Widget> children;
  final Color kCardBackground;
  final Color kAccentBlue;
  final Color kSeparatorColor;

  const DetailSection({
    required this.title,
    required this.children,
    required this.kCardBackground,
    required this.kAccentBlue,
    required this.kSeparatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kAccentBlue,
            ),
          ),
          Divider(color: kSeparatorColor, height: 20),
          ...children,
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget { // 💡 عام
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final Color kPrimaryTextColor;


  const ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
    required this.kPrimaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: TextStyle(color: kPrimaryTextColor, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
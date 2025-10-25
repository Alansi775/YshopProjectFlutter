import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import '../state_management/cart_manager.dart'; 

// 🚀 الاستيرادات الجديدة للمتطلبات الجغرافية والخريطة
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
// --------------------------------------------------

class OrderTrackerWidget extends StatelessWidget {
  const OrderTrackerWidget({Key? key}) : super(key: key);
  
  // دالة مساعدة
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
    
    Color statusColor = _getStatusColor(status);

    if (status == 'Delivered') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
            child: Icon(statusIcon, color: Colors.white, size: 28), 
          ),
        ),
      ),
    );
  }

  // عرض الورقة السفلية لتفاصيل الطلب
  void _showOrderDetailsSheet(BuildContext context, String orderId, String currentStatus) {
    final Color cardColor = Theme.of(context).cardColor;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8, 
          decoration: BoxDecoration(
            color: cardColor, 
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30.0), 
              topRight: Radius.circular(30.0), 
            ),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary)); 
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text("Order: $orderId Not Found", style: _getTenorSansStyle(context, 18))); 
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

  // دالة جلب نوع المتجر 
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

  // دالة تعيين أيقونة التحضير
  IconData _getPreparationIcon(String storeType) {
    switch (storeType.toLowerCase()) {
      case 'market': return Icons.shopping_basket_outlined; 
      case 'clothes': return Icons.checkroom_outlined; 
      case 'pharmacy': return Icons.medical_services_outlined; 
      case 'food':
      case 'restaurants': return Icons.restaurant_menu_outlined; 
      default: return Icons.build; 
    }
  }

  // ودجت المنتج
  Widget _buildProductItem(BuildContext context, Map<String, dynamic> item) {
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final quantity = item['quantity'] as int? ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(10),
              image: item['imageUrl'] != null
                  ? DecorationImage(
                      image: NetworkImage(item['imageUrl'] as String),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item['imageUrl'] == null ? Icon(Icons.image_not_supported, color: secondaryColor.withOpacity(0.5)) : null,
          ),
          const SizedBox(width: 15),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String? ?? 'Unknown Product',
                  style: _getTenorSansStyle(context, 16, weight: FontWeight.w600), 
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: $quantity x \$${price.toStringAsFixed(2)}',
                  style: _getTenorSansStyle(context, 14).copyWith(color: secondaryColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          
          Text(
            '\$${(price * quantity).toStringAsFixed(2)}',
            style: _getTenorSansStyle(context, 16, weight: FontWeight.bold, color: Colors.deepOrange),
          ),
        ],
      ),
    );
  }

  // ودجت أيقونة التوصيل المخصصة
  IconData _getDeliveryIcon(String deliveryOption) {
    if (deliveryOption.toLowerCase().contains('drone')) {
      return Icons.flight; 
    } else if (deliveryOption.toLowerCase().contains('express')) {
      return Icons.flash_on; 
    } else {
      return Icons.two_wheeler; 
    }
  }

  // المحتوى الرئيسي للورقة السفلية
  Widget _buildOrderDetailsContent(BuildContext context, Map<String, dynamic> orderData, String storeType) {
    final status = orderData['status'] as String? ?? 'Pending';
    final total = (orderData['total'] as num?)?.toDouble() ?? 0.0;
    final createdAtTimestamp = orderData['createdAt'] as Timestamp?;
    final date = createdAtTimestamp != null ? createdAtTimestamp.toDate() : DateTime.now();
    final documentId = orderData['documentId'] as String? ?? 'N/A'; 
    final deliveryOption = orderData['deliveryOption'] as String? ?? 'Standard';
    final items = orderData['items'] as List<dynamic>? ?? [];
    final storeName = (items.isNotEmpty) ? items.first['storeName'] : 'Unknown Store';
    
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final timeFormat = DateFormat('h:mm a'); 
    final dateFormat = DateFormat('MMM d'); 
    final formattedTime = '${timeFormat.format(date)} - ${dateFormat.format(date)}';
    final paymentMethod = orderData['paymentMethod'] as String? ?? 'Not Specified'; 
    final preparationIcon = _getPreparationIcon(storeType); 
    
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                "Order: $documentId",
                style: _getTenorSansStyle(context, 14, weight: FontWeight.w600, color: primaryColor), 
                textAlign: TextAlign.center, 
                softWrap: true, 
              ),
            ),
          ),
          const SizedBox(height: 25), 
          
          // 2. شريط التتبع الأفقي
          _buildTrackingTimeline(context, trackingSteps, status), 
          
          // 💡 إضافة خريطة التتبع المباشر
          if (status == 'Out for Delivery') ...[
            Divider(height: 30, thickness: 1.5, color: Theme.of(context).dividerColor),
            Center(
              child: Text(
                "Driver Location (Live)", 
                style: _getTenorSansStyle(context, 18, weight: FontWeight.bold).copyWith(color: _getStatusColor(status)),
              ),
            ),
            const SizedBox(height: 15),
            // 💡 استخدام ودجت جديد Stateful لإدارة التحديثات
            DeliveryMapStatefulWidget(orderData: orderData, getTenorSansStyle: _getTenorSansStyle), 
          ],

          Divider(height: 30, thickness: 1.5, color: Theme.of(context).dividerColor),

          // 3. تفاصيل الطلب السريعة واسم المتجر
          Text(
            "$storeName Order Summary", 
            style: _getTenorSansStyle(context, 18, weight: FontWeight.bold), 
          ),
          const SizedBox(height: 15),
          
          _buildDetailRow(context, "Order Time:", formattedTime, icon: Icons.access_time),
          _buildDetailRow(context, "Payment Method:", paymentMethod, icon: Icons.credit_card_outlined), 
          _buildDetailRow(context, "Total Amount:", "\$${total.toStringAsFixed(2)}", color: Colors.deepOrange),
          
          Divider(height: 30, thickness: 0.8, color: Theme.of(context).dividerColor),
          
          // 4. قائمة المنتجات
          Text(
            "Items Ordered (${items.length})", 
            style: _getTenorSansStyle(context, 18, weight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          
          ...items.map((item) => _buildProductItem(context, item as Map<String, dynamic>)).toList(),
          
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

  // ودجت مساعد لبناء صفوف التفاصيل
  Widget _buildDetailRow(BuildContext context, String label, dynamic value, {Color? color, IconData? icon, bool isAddress = false}) {
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isAddress ? CrossAxisAlignment.start : CrossAxisAlignment.center, 
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: secondaryColor.withOpacity(0.7)),
            const SizedBox(width: 10),
          ],
          
          SizedBox(
            width: 130, 
            child: Text(
              label, 
              style: _getTenorSansStyle(context, 15).copyWith(color: secondaryColor.withOpacity(0.7)),
            ),
          ),
          
          Expanded( 
            child: Text(
              value.toString(),
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
  
  // ودجت بناء شريط التتبع
  Widget _buildTrackingTimeline(BuildContext context, List<Map<String, dynamic>> steps, String currentStatus) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    
    return SizedBox(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, 
        children: steps.map((step) {
          final isCompleted = _isStepCompleted(step['status'] as String, currentStatus);
          
          Color statusColor = _getStatusColor(step['status']);
          
          final color = isCompleted ? statusColor : Theme.of(context).dividerColor; 
          final icon = step['icon'] as IconData;
          
          return Expanded( 
            child: Column(
              children: [
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
      case 'Pending': return Colors.lightBlue.shade600; 
      case 'Processing': return Colors.blue.shade600;
      case 'Out for Delivery': return Colors.green.shade600;
      case 'Delivered': return Colors.green.shade700;
      default: return Colors.red.shade600;
    }
  }
}

// --------------------------------------------------
// 🚀 الودجت Stateful الجديد لإدارة تحديث الخريطة والـ ETA
// --------------------------------------------------
class DeliveryMapStatefulWidget extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final TextStyle Function(BuildContext, double, {FontWeight weight, Color? color}) getTenorSansStyle;

  const DeliveryMapStatefulWidget({
    Key? key,
    required this.orderData,
    required this.getTenorSansStyle,
  }) : super(key: key);

  @override
  State<DeliveryMapStatefulWidget> createState() => _DeliveryMapStatefulWidgetState();
}

class _DeliveryMapStatefulWidgetState extends State<DeliveryMapStatefulWidget> {
  // 🚨 استبدل هذا المفتاح بمفتاح Mapbox Access Token الخاص بك.
  static const String MAPBOX_ACCESS_TOKEN = 'pk.eyJ1IjoibW9oYW1tZWRhbGFuc2kiLCJhIjoiY21ncGF5OTI0MGU2azJpczloZjI0YXRtZCJ9.W9tMyxkXcai-sHajAwp8NQ';
  
  List<LatLng> _routePoints = [];
  String _eta = 'Calculating ETA...';
  Timer? _updateTimer;
  MapController _mapController = MapController();
  
  bool _boundsAdjusted = false; 

  // متغيرات تستخرج من الـ orderData
  late LatLng customerLocation;
  GeoPoint? driverLocationGeo;
  LatLng? driverLocation;

  @override
  void initState() {
    super.initState();
    _initializeLocations();
    _startPeriodicUpdate();
  }

  @override
  void didUpdateWidget(covariant DeliveryMapStatefulWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orderData != oldWidget.orderData) {
      _initializeLocations();
      _fetchRouteAndEta(); 
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  void _initializeLocations() {
    final double customerLat = (widget.orderData['location_Latitude'] as num?)?.toDouble() ?? 0.0;
    final double customerLon = (widget.orderData['location_Longitude'] as num?)?.toDouble() ?? 0.0;
    customerLocation = LatLng(customerLat, customerLon);
    
    driverLocationGeo = widget.orderData['driverLocation'] as GeoPoint?;
    driverLocation = driverLocationGeo != null
        ? LatLng(driverLocationGeo!.latitude, driverLocationGeo!.longitude)
        : null;
  }

  void _startPeriodicUpdate() {
    _updateTimer?.cancel(); 
    _updateTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderData['documentId'] as String)
          .get()
          .then((snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final newDriverGeo = snapshot.data()!['driverLocation'] as GeoPoint?;
              if (newDriverGeo != null) {
                driverLocationGeo = newDriverGeo;
                driverLocation = LatLng(newDriverGeo.latitude, newDriverGeo.longitude);
                _fetchRouteAndEta();
              }
            }
          });
    });
    _fetchRouteAndEta();
  }

  void _fetchRouteAndEta() async {
    if (driverLocation == null) {
      if (mounted) {
        setState(() {
          _eta = 'Waiting for driver location...';
          _routePoints = [];
        });
      }
      return;
    }
    
    final coordinates = 
        '${driverLocation!.longitude},${driverLocation!.latitude};${customerLocation.longitude},${customerLocation.latitude}';
        
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/$coordinates?geometries=geojson&overview=full'
    );

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          final durationInSeconds = route['duration'] as double;
          final minutes = (durationInSeconds / 60).ceil();
          final newEta = '$minutes min';
          
          final List<dynamic> coords = route['geometry']['coordinates'];
          final List<LatLng> newRoutePoints = coords.map<LatLng>((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          if (mounted) {
            setState(() {
              _routePoints = newRoutePoints;
              _eta = newEta;
            });
            
            if (!_boundsAdjusted) {
               _adjustMapBounds();
               _boundsAdjusted = true;
            }
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _eta = 'No route found';
          _routePoints = [];
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _eta = 'Error calculating ETA';
          _routePoints = [];
        });
      }
    }
  }
  
  void _adjustMapBounds() {
    if (driverLocation == null) return;
    
    // لضمان رؤية النقطتين
    final points = [driverLocation!, customerLocation];
    final bounds = LatLngBounds.fromPoints(points);
    
    _mapController.move(
      LatLng(
        (driverLocation!.latitude + customerLocation.latitude) / 2,
        (driverLocation!.longitude + customerLocation.longitude) / 2,
      ), 
      14.0 // زوم مناسب لرؤية الطريق
    );
  }


  @override
  Widget build(BuildContext context) {
    
    LatLng mapCenter = driverLocation != null
        ? LatLng(
            (driverLocation!.latitude + customerLocation.latitude) / 2,
            (driverLocation!.longitude + customerLocation.longitude) / 2,
          )
        : customerLocation;
        
    double initialZoom = driverLocation != null ? 14.0 : 12.0;

    return Column(
      children: [
        // شريط ETA في الأعلى
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade600.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade600),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Estimated Arrival: $_eta',
                style: widget.getTenorSansStyle(context, 15, weight: FontWeight.bold).copyWith(color: Colors.green.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        
        // الخريطة
        Container(
          height: 300, 
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: initialZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              // 💡 طبقة الخريطة المظلمة (Mapbox Dark/Night Mode)
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$MAPBOX_ACCESS_TOKEN',
                userAgentPackageName: 'com.yshop.customer.app',
              ),
              
              // 💡 خط سير الموصل (لون أزرق) - يظهر الطريق بين السائق والزبون
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.shade600, // اللون الأزرق المطلوب للطريق
                      strokeWidth: 6.0,
                    ),
                ],
              ),
              
              // طبقة العلامات
              MarkerLayer(
                markers: [
                  // 1. علامة موقع الزبون (YOU)
                  Marker(
                    point: customerLocation,
                    width: 50,
                    height: 50,
                    // 💡 أيقونة الزبون: دائرة بيضاء بداخلها YOU بالأسود
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // دائرة بيضاء
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'YOU', // الأحرف المطلوبة
                          style: widget.getTenorSansStyle(context, 14, weight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  
                  // 2. علامة موقع الموصل (YS)
                  if (driverLocation != null)
                    Marker(
                      point: driverLocation!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black, // دائرة سوداء
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.7),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'YS', // الأحرف المطلوبة
                            style: widget.getTenorSansStyle(context, 16, weight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
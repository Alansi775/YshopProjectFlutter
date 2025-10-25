import 'dart:async';
import 'dart:convert';
import 'dart:math'; 
import 'package:flutter/foundation.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'delivery_home_view.dart' as dm;
import 'delivery_qr_scanner_view.dart' show ActionButton; 

// --------------------------------------------------
// 1. ودجت المقبض المتحرك (Handle)
// --------------------------------------------------
class BouncingHandle extends StatefulWidget {
  final Color color;
  const BouncingHandle({super.key, required this.color});

  @override
  State<BouncingHandle> createState() => _BouncingHandleState();
}

class _BouncingHandleState extends State<BouncingHandle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: -5.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value), 
          child: Container(
            width: 55,
            height: 5,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------
// 2. الكلاس الأساسي DeliveryMapView
// --------------------------------------------------
class DeliveryMapView extends StatefulWidget {
  final dm.Order order;
  final Color kDarkBackground;
  final Color kCardBackground;
  final Color kAppBarBackground;
  final Color kPrimaryTextColor;
  final Color kSecondaryTextColor;
  final Color kSeparatorColor;
  final Color kAccentBlue;

  const DeliveryMapView({
    super.key,
    required this.order,
    required this.kDarkBackground,
    required this.kCardBackground,
    required this.kAppBarBackground,
    required this.kPrimaryTextColor,
    required this.kSecondaryTextColor,
    required this.kSeparatorColor,
    required this.kAccentBlue,
  });

  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  static const String MAPBOX_ACCESS_TOKEN = 'pk.eyJ1IjoibW9oYW1tZWRhbGFuc2kiLCJhIjoiY21ncGF5OTI0MGU2azJpczloZjI0YXRtZCJ9.W9tMyxkXcai-sHajAwp8NQ';
  
  LatLng get customerLocation =>
      LatLng(widget.order.locationLatitude, widget.order.locationLongitude);
      
  LatLng? driverLocation;
  double _driverBearing = 0.0;
  StreamSubscription<Position>? _positionStreamSubscription;
  List<LatLng> _routePoints = [];
  String _eta = 'Calculating...'; 
  bool _isConnected = true; 
  bool _isDriving = false; 
  final MapController _mapController = MapController();
  
  // متغيرات التحكم بالارتفاع اليدوي 
  static const double _minHeight = 0.05; 
  static const double _initialHeight = 0.20; 
  static const double _maxHeight = 0.55; 
  double _currentSheetHeight = _initialHeight; 
  double _dragStartOffset = 0.0; 

  @override
  void initState() {
    super.initState();
    _startTrackingDriver();
    _startConnectivityListener(); 
    
    if (widget.order.status == 'Out for Delivery') {
       _isDriving = true;
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
  
  void _startConnectivityListener() {}
  void _updateDriverLocationInFirestore(double lat, double lon) { /* ... */ }
  void _fetchRouteAndEta(LatLng origin, LatLng destination) async { /* ... */ }
  void _startTrackingDriver() async { /* ... */ }
  void _launchGoogleMaps() async { /* ... */ }
  void _callCustomer() async { /* ... */ }
  Future<void> _markAsDelivered(BuildContext context) async { /* ... */ }

  // 💡 وظيفة التمركز فقط
  void _centerMapOnDriver() {
    if (driverLocation != null) {
      _mapController.move(driverLocation!, _mapController.camera.zoom);
      _mapController.rotate(_driverBearing); 
    }
  }

  // 💡 وظيفة بدء القيادة (مع رسالة تظهر مرة واحدة)
  Future<void> _startDriving() async {
    // 💡 إذا كان يقود بالفعل، سنتر فقط ثم اخرج (هذا يمنع تحديث Firestore والرسالة)
    if (_isDriving && driverLocation != null) {
       _centerMapOnDriver();
       return; 
    }

    try {
      await FirebaseFirestore.instance
          .collection("orders")
          .doc(widget.order.id)
          .update({'status': 'Out for Delivery','updatedAt': FieldValue.serverTimestamp(),});
      
      if (mounted) {
        setState(() {
          _isDriving = true;
          _currentSheetHeight = _initialHeight; 
        });
        _centerMapOnDriver(); // سنتر الشاشة بعد بدء القيادة
        
        // // 💡 رسالة بدء التتبع تظهر هنا فقط
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Delivery started! Tracking is live for customer.')),
        // );
      }
      
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start delivery: $e')),
        );
      }
    }
  }
  
  // 💡 منطق السحب والتحريك اليدوي
  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartOffset = details.globalPosition.dy;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final double deltaY = details.globalPosition.dy - _dragStartOffset;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    double newHeightFraction = _currentSheetHeight - (deltaY / screenHeight);

    setState(() {
      _currentSheetHeight = newHeightFraction.clamp(_minHeight, _maxHeight);
      _dragStartOffset = details.globalPosition.dy; 
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    const double snappedMinHeight = _minHeight; 
    const double snappedMaxHeight = _maxHeight; 
    
    final double midPointMin = (_initialHeight + snappedMinHeight) / 2;
    final double midPointMax = (_initialHeight + snappedMaxHeight) / 2;

    double targetHeight = _initialHeight; 

    if (details.velocity.pixelsPerSecond.dy < -500) {
        targetHeight = snappedMaxHeight;
    } else if (details.velocity.pixelsPerSecond.dy > 500) {
        targetHeight = snappedMinHeight;
    } else {
        if (_currentSheetHeight > midPointMax) {
            targetHeight = snappedMaxHeight;
        } else if (_currentSheetHeight < midPointMin) {
            targetHeight = snappedMinHeight;
        } else {
            targetHeight = _initialHeight;
        }
    }
    
    _animateToHeight(targetHeight);
  }
  
  void _animateToHeight(double targetHeight) {
    final double start = _currentSheetHeight;
    final double end = targetHeight;
    
    const Duration duration = Duration(milliseconds: 250);
    const int frames = 30; 
    
    Timer.periodic(duration ~/ frames, (timer) {
      final double progress = timer.tick / frames;
      
      if (progress >= 1.0) {
        timer.cancel();
        setState(() {
          _currentSheetHeight = end;
        });
      } else {
        setState(() {
          _currentSheetHeight = start + (end - start) * Curves.easeOutCubic.transform(progress);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialCenter = driverLocation ?? customerLocation;
    final String deliveryInstructions = widget.order.addressDeliveryInstructions ?? '';
    final double paddingHorizontal = 20.0; 
    
    double currentHeightInPixels = MediaQuery.of(context).size.height * _currentSheetHeight;

    return Scaffold(
      backgroundColor: widget.kDarkBackground,
      body: Stack(
        children: [
          // 1. الخريطة
          FlutterMap(
            mapController: _mapController, 
            options: MapOptions(
              initialCenter: initialCenter, 
              initialZoom: driverLocation != null ? 18.0 : 15.0, 
              minZoom: 5.0,
              maxZoom: 19.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isDriving) {
                  setState(() {
                    _isDriving = false; 
                  });
                  _mapController.rotate(0);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$MAPBOX_ACCESS_TOKEN',
                userAgentPackageName: 'com.yshop.delivery.app',
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      color: widget.kAccentBlue, 
                      strokeWidth: 6.0,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: customerLocation,
                    width: 80,
                    height: 80,
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.grey.shade800,
                      size: 45.0,
                    ),
                  ),
                  if (driverLocation != null) 
                    Marker(
                      point: driverLocation!,
                      width: 50, 
                      height: 50, 
                      child: Transform.rotate(
                        angle: _driverBearing * (pi / 180), 
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.kAccentBlue, 
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3), 
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.navigation, 
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // 2. تراكب الاتصال (Connection Overlay)
          if (!_isConnected)
            Positioned.fill(
              child: Container( 
                color: Colors.black.withOpacity(0.9),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.redAccent, size: 80),
                      SizedBox(height: 20),
                      Text(
                        'Connection Lost!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // 3. Header المخصص 
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.transparent,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: paddingHorizontal,
                right: paddingHorizontal,
                bottom: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircularButton(
                    icon: Icons.arrow_back,
                    color: Colors.white.withOpacity(0.95),
                    iconColor: Colors.black87,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Delivery to: ${widget.order.userName}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (driverLocation != null)
                          Text(
                            "ETA: $_eta",
                            style: TextStyle(
                              color: widget.kAccentBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildCircularButton(
                    icon: Icons.call,
                    color: Colors.black87,
                    iconColor: Colors.white,
                    onTap: _callCustomer,
                  ),
                ],
              ),
            ),
          ),

          // 4. زر Recenter
          if (driverLocation != null)
             Positioned(
               bottom: currentHeightInPixels + 20, 
               right: paddingHorizontal,
               child: FloatingActionButton(
                 heroTag: 'centerMap',
                 backgroundColor: widget.kAccentBlue,
                 // 💡 التعديل هنا: يسنتر فقط إذا كان يقود، ويبدأ القيادة إذا لم يكن
                 onPressed: _isDriving 
                    ? _centerMapOnDriver
                    : _startDriving,
                 child: Icon(
                     _isDriving ? Icons.location_searching : Icons.gps_fixed, 
                     color: Colors.white
                 ),
               ),
             ),
            
          // 5. الكرت المتحرك
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: paddingHorizontal,
            right: paddingHorizontal,
            bottom: 0, 
            height: currentHeightInPixels, 
            child: GestureDetector(
                onVerticalDragStart: _onVerticalDragStart,
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                child: Container(
                    decoration: BoxDecoration(
                        color: widget.kCardBackground,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 25,
                                spreadRadius: 5,
                            ),
                        ],
                    ),
                    child: SingleChildScrollView(
                        // منع التمرير الداخلي إذا كان الكرت مرفوعاً جزئياً فقط
                        physics: _currentSheetHeight > _initialHeight ? null : const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                // مقبض السحب (Handle)
                                Padding(
                                    padding: const EdgeInsets.only(top: 14.0, bottom: 12.0),
                                    child: Center(
                                        child: BouncingHandle(color: Colors.grey.shade500),
                                    ),
                                ),
                                
                                // المحتوى
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          "Destination Details",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: widget.kAccentBlue,
                                          ),
                                        ),
                                        
                                        Divider(color: widget.kSeparatorColor, height: 16),
                                        
                                        dm.DetailRow(
                                            label: "Address",
                                            value: widget.order.addressFull, 
                                            isMultiline: true,
                                            valueAlignment: TextAlign.start),

                                        const SizedBox(height: 12),

                                        // تعليمات التوصيل
                                        if (deliveryInstructions.isNotEmpty)
                                            Container(
                                                padding: const EdgeInsets.all(11.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(11.0),
                                                  border: Border.all(color: Colors.orange.shade600, width: 1.2),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "📍 Delivery Instructions",
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.orange.shade700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 7),
                                                    Text(
                                                      deliveryInstructions,
                                                      style: TextStyle(
                                                        color: widget.kPrimaryTextColor,
                                                        fontSize: 13,
                                                        height: 1.5,
                                                      ),
                                                      textAlign: TextAlign.start,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                        
                                        const SizedBox(height: 20),
                                        
                                        // صف الأزرار 
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildSecondaryActionButton(
                                                label: 'Open in Maps',
                                                icon: Icons.directions,
                                                onTap: _launchGoogleMaps,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            
                                            Expanded(
                                              flex: 2,
                                              child: ActionButton(
                                                label: _isDriving ? "Mark as Delivered ✓" : "Start Driving",
                                                color: _isDriving
                                                    ? Colors.green.shade600
                                                    : widget.kAccentBlue,
                                                kPrimaryTextColor: Colors.white,
                                                onPressed: _isDriving
                                                    ? () => _markAsDelivered(context)
                                                    : _startDriving,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 30), 
                                      ],
                                    ),
                                ),
                            ],
                        ),
                    ),
                ),
            ),
          ),
        ],
      ),
    );
  }

  // الدوال المساعدة (_buildCircularButton و _buildSecondaryActionButton)
  Widget _buildCircularButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200, 
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
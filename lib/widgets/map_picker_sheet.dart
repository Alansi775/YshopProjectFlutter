// lib/widgets/map_picker_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'package:geocoding/geocoding.dart'; 

// دالة مساعدة للخط
TextStyle _getTenorSansStyle(double size, {FontWeight weight = FontWeight.normal, Color? color}) {
  return TextStyle(
    fontFamily: 'TenorSans', 
    fontSize: size,
    fontWeight: weight,
    color: color ?? Colors.black,
  );
}

class MapPickerSheet extends StatefulWidget {
  final LatLng initialCoordinate; 
  
  static const double maxWebWidth = 600.0;

  const MapPickerSheet({
    Key? key,
    required this.initialCoordinate,
  }) : super(key: key);

  @override
  State<MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<MapPickerSheet> {
  final MapController _mapController = MapController(); 
  late LatLng _selectedLocation;
  String _currentAddress = "Loading address...";
  bool _isLoading = true; 
  String _mapError = "";
  
  // خاصية للتأكد من أن العنوان صالح قبل التأكيد
  bool get _isAddressValid => 
      _currentAddress.isNotEmpty && 
      !_currentAddress.contains("Loading") && 
      !_currentAddress.contains("Error") &&
      !_isLoading;


  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialCoordinate;
    // 1. محاولة جلب العنوان الأولي (إذا كانت الإحداثيات معلومة)
    _getAddressFromLatLng(_selectedLocation);
    // 2. التحقق من الأذونات ومحاولة جلب الموقع الحالي (إذا كانت الإحداثيات 0.0)
    _checkLocationPermissions(); 
  }

  // MARK: - Location/Map Logic 

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) setState(() => _mapError = "Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted) setState(() => _mapError = "Location permissions are denied.");
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if(mounted) setState(() => _mapError = "Location permissions are permanently denied. Please enable them in settings.");
      return;
    }
    
    _getInitialCurrentLocation();
  }

  //  هذه الدالة هي المسؤولة عن تحديد الموقع التلقائي
  Future<void> _getInitialCurrentLocation() async {
    // التحقق مما إذا كنا نبدأ من إحداثيات فارغة (0.0، 0.0)
    if (widget.initialCoordinate.latitude == 0.0 && widget.initialCoordinate.longitude == 0.0) {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        LatLng newLocation = LatLng(position.latitude, position.longitude);
        
        if (mounted) {
          setState(() {
            _selectedLocation = newLocation;
          });
          //  تحريك الخريطة إلى الموقع الجديد
          _mapController.move(newLocation, 15); 
          // جلب العنوان وتفعيل زر التأكيد
          _getAddressFromLatLng(newLocation);
        }
      } catch (e) {
        if(mounted) setState(() {
          _mapError = "Could not get current location. Please manually move the map.";
          _isLoading = false; //  تمكين الزر رغم الخطأ (إذا كان العنوان صالحا)
        });
        print("Error getting current location: $e");
      }
    } else {
        // إذا كان الموقع الأولي محددًا، قم فقط بإيقاف حالة التحميل
        if(mounted) setState(() => _isLoading = false);
    }
  }

  // تحويل الإحداثيات إلى عنوان نصي
  Future<void> _getAddressFromLatLng(LatLng latLng) async {
  try {
    if(mounted) setState(() => _currentAddress = "Fetching address...");
    
    // تأخير بسيط للمساعدة في حل مشكلة السباق (Race condition)
    await Future.delayed(const Duration(milliseconds: 100)); 
    
    // جلب العنوان
    List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
    
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      
      //  تحسين طريقة بناء العنوان لمعالجة القيم الفارغة بشكل آمن
      String address = [
        place.street,
        place.subLocality,
        place.locality,
        place.country,
      ].where((e) => e != null && e.isNotEmpty).join(', ');
      
      if (mounted) {
        setState(() {
          // إذا كان العنوان فارغًا بعد البناء (في حالة فشل Geocoding)، نضع رسالة افتراضية
          _currentAddress = address.isNotEmpty ? address : "Address determined, but details unavailable.";
          _isLoading = false; 
        });
      }
    } else {
      if(mounted) setState(() {
        _currentAddress = "Address not found for this location.";
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        // إذا فشلت العملية، نضع رسالة خطأ واضحة ونوقف حالة التحميل لتفعيل الزر
        _currentAddress = "Error fetching address. Please try moving the map.";
        _isLoading = false; 
      });
    }
    print("Error in geocoding: $e");
  }
}
  
  // دالة عند تحريك الخريطة
  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      _selectedLocation = event.camera.center;
      _getAddressFromLatLng(_selectedLocation);
    } else if (event is MapEventMove) {
      _selectedLocation = event.camera.center;
    }
  }

  // MARK: - Build Helper for OSM Map

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _selectedLocation,
        initialZoom: 15,
        onMapEvent: _onMapEvent, 
        interactionOptions: InteractionOptions(
          //  تم إصلاح هذا الخطأ
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate, 
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > MapPickerSheet.maxWebWidth;
    
    final content = SizedBox(
      width: isLargeScreen ? MapPickerSheet.maxWebWidth : screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Select Location",
                  style: _getTenorSansStyle(18, weight: FontWeight.w600),
                ),
                TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Cancel",
                style: _getTenorSansStyle(16, color: Colors.grey),
              ),
            ),
              ],
            ),
          ),
          
          // 2. Map Area
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildMap(),
                
                // أيقونة الدبوس الثابتة في المنتصف
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Icon(Icons.location_on, size: 40, color: Colors.red),
                ),
                
                // رسالة الخطأ للمستخدم
                if (_mapError.isNotEmpty)
                  Positioned(
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Text(_mapError, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          
          // 3. Selected Address & Confirmation Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -5),
                )
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // عرض حالة العنوان
                Text(
                  _isAddressValid ? _currentAddress : (_isLoading ? "Fetching address..." : "Invalid Location. Please try again."),
                  style: _getTenorSansStyle(16, weight: FontWeight.w600).copyWith(
                    color: _isAddressValid ? Colors.black : Colors.red,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                
                // زر التأكيد (يتم تفعيله عبر خاصية _isAddressValid)
                ElevatedButton(
                  onPressed: _isAddressValid ? () {
                    Navigator.of(context).pop({
                      'address': _currentAddress,
                      'latitude': _selectedLocation.latitude,
                      'longitude': _selectedLocation.longitude,
                    });
                  } : null, 
                  
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                  child: Text(
                    _isLoading ? "Loading..." : "Confirm Location",
                    style: _getTenorSansStyle(16, weight: FontWeight.w600).copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    
    return FractionallySizedBox(
        heightFactor: 0.9, 
        child: Center( 
          child: content,
        ),
    );
  }
}
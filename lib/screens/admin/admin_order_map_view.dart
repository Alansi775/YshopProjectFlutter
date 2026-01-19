// lib/screens/admin/admin_order_map_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../delivery/map_of_delivery_man.dart' show MAPBOX_ACCESS_TOKEN;

class AdminOrderMapView extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const AdminOrderMapView({super.key, required this.orderData});

  @override
  State<AdminOrderMapView> createState() => _AdminOrderMapViewState();
}

class _AdminOrderMapViewState extends State<AdminOrderMapView> {
  final MapController _mapController = MapController();

  LatLng? _driverLoc;
  LatLng? _storeLoc;
  LatLng? _customerLoc;

  List<LatLng> _routeDriverToStore = [];
  List<LatLng> _routeStoreToCustomer = [];

  String _etaDriverToStore = '...';
  String _distDriverToStore = '...';
  String _etaStoreToCustomer = '...';
  String _distStoreToCustomer = '...';

  Timer? _pollTimer;

  String? _driverUid;
  String? _orderId;

  @override
  void initState() {
    super.initState();
    _orderId = widget.orderData['id']?.toString() ?? widget.orderData['order_id']?.toString();
    _driverUid = widget.orderData['driver_id']?.toString() ?? widget.orderData['driverId']?.toString();

    // initialize store and customer locations from orderData if available
    final storeLat = _parseDouble(widget.orderData['store_latitude'] ?? widget.orderData['storeLatitude']);
    final storeLng = _parseDouble(widget.orderData['store_longitude'] ?? widget.orderData['storeLongitude']);
    if (storeLat != null && storeLng != null) _storeLoc = LatLng(storeLat, storeLng);

    final custLat = _parseDouble(widget.orderData['location_Latitude'] ?? widget.orderData['customer']?['latitude'] ?? widget.orderData['locationLatitude']);
    List<LatLng> _routeDriverToCustomer = [];
    final custLng = _parseDouble(widget.orderData['location_Longitude'] ?? widget.orderData['customer']?['longitude'] ?? widget.orderData['locationLongitude']);
    if (custLat != null && custLng != null) _customerLoc = LatLng(custLat, custLng);

    // If driver location was embedded on order, use it
    final dloc = widget.orderData['driver_location'];
    String _etaDriverToCustomer = '...';
    String _distDriverToCustomer = '...';

    double? _drvToStoreMeters;
    double? _drvToCustomerMeters;
    double? _storeToCustomerMeters;
    if (dloc is Map) {
      final lat = _parseDouble(dloc['latitude'] ?? dloc['lat']);
      final lng = _parseDouble(dloc['longitude'] ?? dloc['lng']);
      if (lat != null && lng != null) _driverLoc = LatLng(lat, lng);
    }

    // If store/customer lat/lng missing, try to fetch store info
    _ensureLocations().then((_) {
      // initial route fetch
      _refreshRoutes();
    });

    // start polling driver position if we have a driver uid
    if (_driverUid != null && _driverUid!.isNotEmpty) {
      _startPollingDriver();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureLocations() async {
    try {
      if (_storeLoc == null && widget.orderData['store_id'] != null) {
        final store = await ApiService.getStoreById(widget.orderData['store_id'].toString());
        if (store != null) {
          final lat = _parseDouble(store['latitude']);
          final lng = _parseDouble(store['longitude']);
          if (lat != null && lng != null) setState(() => _storeLoc = LatLng(lat, lng));
        }
      }

      if (_customerLoc == null) {
        // sometimes order payload includes customer object
        final customer = widget.orderData['customer'] as Map<String, dynamic>?;
        if (customer != null) {
          final lat = _parseDouble(customer['latitude']);
          final lng = _parseDouble(customer['longitude']);
          if (lat != null && lng != null) setState(() => _customerLoc = LatLng(lat, lng));
        }
      }
    } catch (e) {
      debugPrint('Failed to ensure locations: $e');
    }
  }

  void _startPollingDriver() {
    // immediate fetch
    _fetchDriverLocation();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _fetchDriverLocation());
  }

  Future<void> _fetchDriverLocation() async {
    try {
      Map<String, dynamic>? data;

      // Try direct helper first
      try {
        data = await ApiService.getDeliveryRequestByUid(_driverUid!);
      } catch (_) {
        data = null;
      }

      // If helper didn't find it (common for admin lookup), search admin lists
      if (data == null) {
        try {
          final lists = <dynamic>[];
          final active = await ApiService.getActiveDeliveryRequests();
          lists.addAll(active);
          final approved = await ApiService.getApprovedDeliveryRequests();
          lists.addAll(approved);
          final pending = await ApiService.getPendingDeliveryRequests();
          lists.addAll(pending);

          final found = lists.cast<dynamic?>().firstWhere((e) => (e?['uid'] ?? e?['UID'] ?? '') == _driverUid, orElse: () => null);
          if (found != null) data = Map<String, dynamic>.from(found as Map);
        } catch (e) {
          debugPrint('Fallback driver lookup failed: $e');
        }
      }

      if (data == null) return;
      final lat = _parseDouble(data['latitude'] ?? data['lat']);
      final lng = _parseDouble(data['longitude'] ?? data['lng'] ?? data['long']);
      if (lat != null && lng != null) {
        final newLoc = LatLng(lat, lng);
        setState(() => _driverLoc = newLoc);
        // refresh route driver->store
        _refreshRoutes();
        // center map on driver a bit on first fetch
        try {
          _mapController.move(newLoc, 15);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Failed to fetch driver location: $e');
    }
  }

  Future<void> _refreshRoutes() async {
    try {
      if (_driverLoc != null && _storeLoc != null) {
        final drv = await _fetchRoute(_driverLoc!, _storeLoc!);
        if (drv != null) {
          setState(() {
            _routeDriverToStore = drv['points'];
            _etaDriverToStore = drv['eta'];
            _distDriverToStore = drv['distance'];
          });
        }
      }

      if (_storeLoc != null && _customerLoc != null) {
        final sc = await _fetchRoute(_storeLoc!, _customerLoc!);
        if (sc != null) {
          setState(() {
            _routeStoreToCustomer = sc['points'];
            _etaStoreToCustomer = sc['eta'];
            _distStoreToCustomer = sc['distance'];
          });
        }
      }
    } catch (e) {
      debugPrint('Route refresh failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchRoute(LatLng a, LatLng b) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/${a.longitude},${a.latitude};${b.longitude},${b.latitude}?geometries=geojson&overview=full&access_token=$MAPBOX_ACCESS_TOKEN'
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes[0];
      final coords = route['geometry']['coordinates'] as List<dynamic>;
      final points = coords.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
      final duration = (route['duration'] as num).toDouble();
      final distance = (route['distance'] as num).toDouble();

      return {
        'points': points,
        'eta': _formatDuration(duration),
        'distance': _formatDistance(distance),
      };
    } catch (e) {
      debugPrint('Mapbox route fetch error: $e');
      return null;
    }
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    try {
      return double.tryParse(v.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Map'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black12,
            child: Row(
              children: [
                Expanded(child: Text('Driver → Store: $_etaDriverToStore • $_distDriverToStore')),
                Expanded(child: Text('Store → Customer: $_etaStoreToCustomer • $_distStoreToCustomer')),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverLoc ?? _storeLoc ?? _customerLoc ?? LatLng(0,0),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$MAPBOX_ACCESS_TOKEN',
                  userAgentPackageName: 'com.yshop.admin',
                ),

                if (_routeDriverToStore.isNotEmpty)
                  PolylineLayer(polylines: [Polyline(points: _routeDriverToStore, color: Colors.yellow, strokeWidth: 5)]),

                if (_routeStoreToCustomer.isNotEmpty)
                  PolylineLayer(polylines: [Polyline(points: _routeStoreToCustomer, color: Colors.blueAccent, strokeWidth: 5)]),

                MarkerLayer(markers: [
                  if (_storeLoc != null)
                    Marker(
                      point: _storeLoc!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.store, color: Colors.white, size: 22),
                      ),
                    ),
                  if (_customerLoc != null)
                    Marker(
                      point: _customerLoc!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.person_pin, color: Colors.white, size: 20),
                      ),
                    ),
                  if (_driverLoc != null)
                    Marker(
                      point: _driverLoc!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueGrey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.navigation, color: Colors.white, size: 24),
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

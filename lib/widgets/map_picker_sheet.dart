import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum MapStyle { light, dark, satellite }

class MapPickerSheet extends StatefulWidget {
  final LatLng initialCoordinate;
  final Stream<LatLng>? locationStream; // optional external location updates
  final bool inline; // render as an inline widget without scaffold/confirm button
  final LatLng? storeLocation; // optional store marker to show
  final List<LatLng>? routePoints; // optional polyline points to draw
  static const double maxWebWidth = 600.0;

  const MapPickerSheet({
    Key? key,
    required this.initialCoordinate,
    this.locationStream,
    this.inline = false,
    this.storeLocation,
    this.routePoints,
  }) : super(key: key);

  @override
  State<MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<MapPickerSheet> {
  final MapController _mapController = MapController();
  late LatLng _selectedLocation;
  String _currentAddress = "Searching for location...";
  bool _isLoading = true;
  String _mapError = "";
  final TextEditingController _addressController = TextEditingController();

  MapStyle _mapStyle = MapStyle.light;
  bool _mapStyleInitialized = false;
  StreamSubscription<LatLng>? _externalLocSub;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialCoordinate;
    _getAddressFromLatLng(_selectedLocation);
    _checkLocationPermissions();

    if (widget.locationStream != null) {
      _externalLocSub = widget.locationStream!.listen((loc) async {
        if (loc == null) return;
        if (mounted) {
          setState(() {
            _selectedLocation = loc;
            _isLoading = true;
          });
        }
        try {
          _mapController.move(loc, 15);
        } catch (_) {}
        await _getAddressFromLatLng(loc);
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _externalLocSub?.cancel();
    super.dispose();
  }

  // --- Logic Methods ---

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _mapError = "Location services are disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _mapError = "Permission denied");
        return;
      }
    }
    _getInitialCurrentLocation();
  }

  Future<void> _getInitialCurrentLocation() async {
    // Always attempt to obtain the current device location when the picker opens.
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 8));
      LatLng newLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _selectedLocation = newLoc;
          _isLoading = true;
        });
        _mapController.move(newLoc, 15);
        await _getAddressFromLatLng(newLoc);
      }
    } catch (e) {
      // If we couldn't get the device position, fall back to the provided initialCoordinate
      if (mounted) {
        setState(() {
          _selectedLocation = widget.initialCoordinate;
        });
        // still try to reverse-geocode the initial coordinate
        await _getAddressFromLatLng(_selectedLocation);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      if (mounted) setState(() => _isLoading = true);

      // 1) Try platform geocoding first
      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      } catch (_) {
        // ignore and fallback
      }

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final addrParts = [p.street, p.subLocality, p.locality, p.country];
        final addr = addrParts.where((e) => e != null && e.isNotEmpty).join(', ');
        if (mounted) {
          setState(() {
            _currentAddress = addr;
            _addressController.text = addr;
            _isLoading = false;
          });
        }
        return;
      }

      // 2) Fallback to OpenStreetMap Nominatim reverse geocoding
      try {
        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latLng.latitude}&lon=${latLng.longitude}&accept-language=en');
        final resp = await http.get(url, headers: {'User-Agent': 'YShopApp/1.0'}).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200 && resp.body.isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(resp.body) as Map<String, dynamic>;
          final display = (data['display_name'] as String?) ?? '';
          if (display.isNotEmpty) {
            if (mounted) setState(() {
              _currentAddress = display;
              _addressController.text = display;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (_) {
        // ignore
      }

      // 3) Final fallback: use coordinates string so user can confirm
      if (mounted) setState(() {
        final coords = 'Lat: ${latLng.latitude.toStringAsFixed(6)}, Lon: ${latLng.longitude.toStringAsFixed(6)}';
        _currentAddress = coords;
        _addressController.text = coords;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        final coords = 'Lat: ${latLng.latitude.toStringAsFixed(6)}, Lon: ${latLng.longitude.toStringAsFixed(6)}';
        _currentAddress = coords;
        _addressController.text = coords;
        _isLoading = false;
      });
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      _getAddressFromLatLng(event.camera.center);
    }
    if (event is MapEventMove) {
      setState(() => _selectedLocation = event.camera.center);
    }
  }

  String _getTileUrl() {
    switch (_mapStyle) {
      case MapStyle.dark: return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case MapStyle.satellite: return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      default: return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (!_mapStyleInitialized) {
      _mapStyle = isDark ? MapStyle.dark : MapStyle.light;
      _mapStyleInitialized = true;
    }

    Widget stack = Stack(
      children: [
        // 1. الخريطة كخلفية كاملة
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _selectedLocation,
            initialZoom: 15,
            onMapEvent: _onMapEvent,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(urlTemplate: _getTileUrl(), subdomains: const ['a', 'b', 'c']),
            if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
              PolylineLayer(
                polylines: [Polyline(points: widget.routePoints!, color: Colors.white, strokeWidth: 4.0)],
              ),
            if (widget.storeLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.storeLocation!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.store, color: Colors.white, size: 28),
                  ),
                ],
              ),
          ],
        ),

        // 2. مؤشر الموقع (Center Marker)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(builder: (ctx) {
                  final bool isDarkStyle = _mapStyle == MapStyle.dark;
                  final circleColor = isDarkStyle ? Colors.white : Colors.black;
                  final textColor = isDarkStyle ? Colors.black : Colors.white;
                  return Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                    ),
                    child: Text('YOU', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.6)),
                  );
                }),
                Container(
                  width: 6,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _mapStyle == MapStyle.dark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),

        // optional header (only when not inline)
        if (!widget.inline)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      const Spacer(),
                      Text("Pick Location", style: TextStyle(fontFamily: 'TenorSans', fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // optional side controls (only when not inline)
        if (!widget.inline)
          Positioned(
            right: 20,
            top: MediaQuery.of(context).size.height * 0.2,
            child: Column(
              children: [
                _buildMapActionBtn(Icons.layers_outlined, () => _showStylePicker()),
                const SizedBox(height: 10),
                _buildMapActionBtn(Icons.my_location, () => _getInitialCurrentLocation()),
              ],
            ),
          ),

        // Bottom address card
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: MapPickerSheet.maxWebWidth),
              child: Builder(builder: (ctx) {
                final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
                final base = theme.cardColor;
                final Color cardBg = isDark
                    ? Color.lerp(base, Colors.white, 0.06)!.withOpacity(0.92)
                    : base.withOpacity(0.85);

                return ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_mapError.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                              child: Text(_mapError, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, color: theme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              Text("DELIVERY ADDRESS", style: TextStyle(letterSpacing: 1.2, fontSize: 10, fontWeight: FontWeight.bold, color: theme.hintColor)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoading)
                            const LinearProgressIndicator(minHeight: 2)
                          else if (widget.inline)
                            Text(
                              _currentAddress,
                              style: const TextStyle(fontFamily: 'TenorSans', fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            TextField(
                              controller: _addressController,
                              style: const TextStyle(fontFamily: 'TenorSans', fontSize: 16),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (!widget.inline)
                            Column(
                              children: [
                                const Divider(height: 30),
                                ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.pop(context, {
                                            'address': _addressController.text,
                                            'latitude': _selectedLocation.latitude,
                                            'longitude': _selectedLocation.longitude,
                                          });
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _mapStyle == MapStyle.dark ? Colors.black : Colors.white,
                                    foregroundColor: _mapStyle == MapStyle.dark ? Colors.white : Colors.black,
                                    minimumSize: const Size(double.infinity, 55),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    elevation: 0,
                                    side: BorderSide(color: theme.dividerColor.withOpacity(0.12)),
                                  ),
                                  child: Text(
                                    _isLoading ? 'Loading...' : 'CONFIRM LOCATION',
                                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: _mapStyle == MapStyle.dark ? Colors.white : Colors.black),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );

    if (widget.inline) {
      return ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(12)), child: SizedBox(height: 220, child: stack));
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Scaffold(body: stack),
      ),
    );
  }

  Widget _buildMapActionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }

  void _showStylePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Map Style", style: TextStyle(fontFamily: 'TenorSans', fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _styleOption(MapStyle.light, Icons.wb_sunny_outlined, "Light"),
                _styleOption(MapStyle.dark, Icons.nightlight_round_outlined, "Dark"),
                _styleOption(MapStyle.satellite, Icons.public, "Satellite"),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _styleOption(MapStyle style, IconData icon, String label) {
    bool isSelected = _mapStyle == style;
    return GestureDetector(
      onTap: () {
        setState(() => _mapStyle = style);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.2)),
            ),
            child: Icon(icon, color: isSelected ? Colors.white : null),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
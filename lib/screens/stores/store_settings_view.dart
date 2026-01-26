import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../state_management/auth_manager.dart';
import '../../widgets/map_picker_sheet.dart';
import 'package:latlong2/latlong.dart';
import '../../models/store.dart';

class StoreSettingsView extends StatefulWidget {
  const StoreSettingsView({super.key});

  @override
  State<StoreSettingsView> createState() => _StoreSettingsViewState();
}

class _StoreSettingsViewState extends State<StoreSettingsView> {
  //  Base URL موحد - نفس اللي في ApiService
  static const String _baseUrl = 'http://localhost:3000/api/v1';

  // حالات الأيقونة
  String? _storeIconUrl;
  File? _pickedImage;
  XFile? _pickedXFile;

  double _latitude = 0.0;
  double _longitude = 0.0;

  // حالات التحميل
  bool _isLoading = false;
  bool _isFetching = true;
  
  // Store ID
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  void _showMapPicker() async {
    final defaultLat = 24.7136;
    final defaultLng = 46.6753;
    final initialCoordinate = LatLng(
      _latitude != 0.0 ? _latitude : defaultLat,
      _longitude != 0.0 ? _longitude : defaultLng,
    );

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MapPickerSheet(initialCoordinate: initialCoordinate),
      ),
    );

    if (result != null && _storeId != null) {
      try {
        final lat = result['latitude'] as double;
        final lng = result['longitude'] as double;
        setState(() {
          _latitude = lat;
          _longitude = lng;
        });
        await ApiService.updateStoreLocation(_storeId!, latitude: lat, longitude: lng);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store location saved successfully')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save location: $e')));
      }
    }
  }

  // MARK: - 1. Fetch Store Data
  Future<void> _fetchStoreData() async {
    setState(() => _isFetching = true);
    try {
      // ستحقق من المستخدم عبر ApiService - لا توجد حاجة لـ Firebase
      final storeData = await ApiService.getUserStore();
      if (storeData != null) {
        final store = Store.fromJson(storeData);
        setState(() {
          _storeId = store.id;
          _storeIconUrl = store.storeIconUrl.isNotEmpty ? store.storeIconUrl : null;
          // read latitude/longitude if provided by API
          try {
            final lat = storeData['latitude'];
            final lng = storeData['longitude'];
            if (lat != null) _latitude = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0;
            if (lng != null) _longitude = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0;
          } catch (_) {}
        });
        debugPrint(' Store loaded: id=${store.id}, icon=${store.storeIconUrl}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching store: $e');
      setState(() {
        _storeIconUrl = null;
      });
    } finally {
      setState(() => _isFetching = false);
    }
  }

  // MARK: - 2. Image Picker
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 500,
      maxHeight: 500,
    );

    if (pickedFile != null) {
      setState(() {
        _pickedXFile = pickedFile;
        if (!kIsWeb) {
          _pickedImage = File(pickedFile.path);
        }
      });
    }
  }

  // MARK: - 3. Upload Image to Backend
  Future<String?> _uploadImageToBackend() async {
    if (_storeId == null) {
      debugPrint('❌ Store ID is null');
      return null;
    }

    if (_pickedImage == null && _pickedXFile == null) {
      debugPrint('❌ No image selected');
      return null;
    }

    try {
      final fileBytes = kIsWeb
          ? await _pickedXFile!.readAsBytes()
          : await _pickedImage!.readAsBytes();

      final fileName = 'store_icon_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint(' Uploading icon to: $_baseUrl/stores/$_storeId');

      //  استخدم الـ Base URL الموحد
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$_baseUrl/stores/$_storeId'),
      );

      //  أضف JWT Token للـ Authentication من AuthManager
      final authManager = Provider.of<AuthManager>(context, listen: false);
      final token = authManager.token;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'icon',
          fileBytes,
          filename: fileName,
        ),
      );

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final iconUrl = data['data']?['icon_url'] as String?;
        
        if (iconUrl != null && iconUrl.isNotEmpty) {
          //  تحويل المسار النسبي إلى URL كامل
          final fullUrl = iconUrl.startsWith('http') 
              ? iconUrl 
              : 'http://localhost:3000$iconUrl';
          debugPrint(' Icon uploaded: $fullUrl');
          return fullUrl;
        }
      } else {
        debugPrint('❌ Upload failed: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Upload exception: $e');
      return null;
    }
  }

  // MARK: - 4. Save Store Icon
  Future<void> _saveStoreIcon() async {
    final isNewImageSelected = _pickedImage != null || _pickedXFile != null;
    if (!isNewImageSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a new icon to save.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newIconUrl = await _uploadImageToBackend();

      if (newIconUrl == null) {
        throw Exception("Failed to upload image to backend.");
      }

      setState(() {
        _storeIconUrl = newIconUrl;
        _pickedImage = null;
        _pickedXFile = null;
      });

      // Success!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store icon saved successfully')));
      }
    } catch (e) {
      debugPrint('❌ Error saving store icon: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save icon: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // MARK: - Build Widget
  @override
  Widget build(BuildContext context) {
    const double maxWidth = 400.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Store Settings"),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Icon Display
                _buildStoreIconDisplay(),
                const SizedBox(height: 32),

                // 2. Upload Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickImage,
                  icon: const Icon(Icons.photo_camera, size: 20),
                  label: const Text("Upload Store Icon"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Save Button
                ElevatedButton.icon(
                  onPressed: (_pickedImage == null && _pickedXFile == null) || _isLoading
                      ? null
                        : _saveStoreIcon,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? "Saving..." : "Save Store Icon"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 24),

                // 4. Optional: Store Location Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Store Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _latitude == 0.0 && _longitude == 0.0
                            ? 'No location set yet'
                            : 'Latitude: $_latitude, Longitude: $_longitude',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _showMapPicker,
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('Set Store Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreIconDisplay() {
    final Widget imageWidget;
    const double size = 120;

    if (_isFetching) {
      imageWidget = const ProgressView(size: size);
    } else if (_pickedImage != null || _pickedXFile != null) {
      // عرض الصورة المختارة
      imageWidget = kIsWeb
          ? Image.network(
              _pickedXFile!.path,
              fit: BoxFit.cover,
              width: size,
              height: size,
            )
          : Image.file(
              _pickedImage!,
              fit: BoxFit.cover,
              width: size,
              height: size,
            );
    } else if (_storeIconUrl != null && _storeIconUrl!.isNotEmpty) {
      // عرض الصورة من الـ Backend
      imageWidget = CachedNetworkImage(
        imageUrl: _storeIconUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: (context, url) => const ProgressView(size: size),
        errorWidget: (context, url, error) {
          debugPrint('❌ Error loading icon: $error');
          return Icon(
            Icons.storefront,
            size: size * 0.8,
            color: Colors.grey.shade400,
          );
        },
      );
    } else {
      // لا توجد صورة
      imageWidget = Icon(
        Icons.storefront,
        size: size * 0.8,
        color: Colors.grey.shade400,
      );
    }

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue.shade200, width: 3),
        ),
        child: ClipOval(
          child: imageWidget,
        ),
      ),
    );
  }
}

// مساعد لـ ProgressView
class ProgressView extends StatelessWidget {
  final double size;
  const ProgressView({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade200,
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
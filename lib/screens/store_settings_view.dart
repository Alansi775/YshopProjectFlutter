import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; //  لعرض الأيقونة

//  إعدادات Cloudinary يجب أن تكون متطابقة مع المستخدمة في AddProductView
const CLOUDINARY_CLOUD_NAME = 'drckarr2l'; 
const CLOUDINARY_UPLOAD_PRESET = 'ml_default'; 

class StoreSettingsView extends StatefulWidget {
  const StoreSettingsView({super.key});

  @override
  State<StoreSettingsView> createState() => _StoreSettingsViewState();
}

class _StoreSettingsViewState extends State<StoreSettingsView> {
  // حالات الأيقونة
  String? _storeIconUrl; // الرابط الحالي للأيقونة من Firestore
  File? _pickedImage;    // ملف الصورة الملتقطة (للموبايل)
  XFile? _pickedXFile;   // ملف الصورة الملتقطة (للويب)
  
  // حالات التحميل
  bool _isLoading = false;
  bool _isFetching = true; // حالة جلب البيانات عند onAppear

  @override
  void initState() {
    super.initState();
    _fetchStoreIcon();
  }

  // MARK: - 1. Fetch Store Icon
  Future<void> _fetchStoreIcon() async {
    setState(() => _isFetching = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      setState(() => _isFetching = false);
      return;
    }
    final userEmail = user.email!;

    try {
      final storeSnapshot = await FirebaseFirestore.instance
          .collection("storeRequests")
          .where("email", isEqualTo: userEmail)
          .limit(1)
          .get();
      
      if (storeSnapshot.docs.isNotEmpty) {
        final storeData = storeSnapshot.docs.first.data();
        setState(() {
          _storeIconUrl = storeData['storeIconUrl'] as String?;
        });
      }
    } catch (e) {
      print("Error fetching store icon: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  // MARK: - 2. Image Picker & Upload
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _pickedXFile = pickedFile; 
        if (!kIsWeb) {
          _pickedImage = File(pickedFile.path); 
        }
      });
    }
  }
  
  Future<String?> _uploadImageToCloudinary() async {
    // ... (نستخدم نفس دالة الرفع من AddProductView)
    if (_pickedImage == null && _pickedXFile == null) return null;

    try {
      final fileBytes = kIsWeb 
          ? await _pickedXFile!.readAsBytes()
          : await _pickedImage!.readAsBytes();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload'),
      );

      request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          fileBytes,
          filename: 'store_icon_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['secure_url'] as String?;
      } else {
        print("❌ Cloudinary Upload Error: Status ${response.statusCode}, Body: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Cloudinary Upload Exception: $e");
      return null;
    }
  }

  // MARK: - 3. Update Firestore
  Future<void> _saveStoreIcon() async {
    // التحقق من وجود صورة جديدة أو قديمة
    final isNewImageSelected = _pickedImage != null || _pickedXFile != null;
    if (!isNewImageSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a new icon to save.")),
      );
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail == null) throw Exception("User email not found.");

      // 1. Upload Image
      final newIconUrl = await _uploadImageToCloudinary();
      if (newIconUrl == null) {
        throw Exception("Failed to upload image to Cloudinary.");
      }

      // 2. Find Store Document (باستخدام الإيميل كما في كود Swift)
      final storeQuery = await FirebaseFirestore.instance
          .collection("storeRequests")
          .where("email", isEqualTo: userEmail)
          .limit(1)
          .get();
      
      if (storeQuery.docs.isEmpty) {
        throw Exception("No store document found for this user.");
      }
      
      final docID = storeQuery.docs.first.id;
      
      // 3. Update Firestore
      await FirebaseFirestore.instance.collection("storeRequests").doc(docID).update({
        "storeIconUrl": newIconUrl,
      });

      setState(() {
        _storeIconUrl = newIconUrl;
        _pickedImage = null; // إزالة الصورة المؤقتة بعد الحفظ
        _pickedXFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Store icon updated successfully!")),
      );

    } catch (e) {
      print("Error saving store icon: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save icon: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  // MARK: - Build Widget
  @override
  Widget build(BuildContext context) {
    const double _maxWidth = 400.0; // عرض أصغر مناسب للإعدادات

    return Scaffold(
      appBar: AppBar(
        title: const Text("Store Settings"),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Icon Display (Icon / Picked Image / Network Image)
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
                  onPressed: (_pickedImage == null && _pickedXFile == null) || _isLoading ? null : _saveStoreIcon,
                  icon: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? "Saving..." : "Save Store Icon"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
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
    //  يتم إعطاء الأولوية للصورة الملتقطة حديثًا
    final Widget imageWidget;
    const double size = 120;
    
    if (_isFetching) {
      // حالة تحميل بيانات الأيقونة القديمة
      imageWidget = const ProgressView(size: size);
    } else if (_pickedImage != null || _pickedXFile != null) {
      // حالة الصورة الملتقطة حديثًا
      imageWidget = kIsWeb
          ? Image.network(_pickedXFile!.path, fit: BoxFit.cover, width: size, height: size)
          : Image.file(_pickedImage!, fit: BoxFit.cover, width: size, height: size);
    } else if (_storeIconUrl != null) {
      // حالة الأيقونة المحفوظة حاليًا
      imageWidget = CachedNetworkImage(
        imageUrl: _storeIconUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: (context, url) => const ProgressView(size: size),
        errorWidget: (context, url, error) => const Icon(Icons.storefront, size: size * 0.8, color: Colors.red),
      );
    } else {
      // حالة عدم وجود أيقونة
      imageWidget = Icon(Icons.storefront, size: size * 0.8, color: Colors.grey.shade400);
    }
    
    // تغليف الصورة بـ ClipRRect (دائري)
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

//  مساعد لـ ProgressView (لأن ProgressView لا يوجد في Flutter)
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
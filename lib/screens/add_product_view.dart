import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert'; // مطلوب لفك تشفير استجابة Cloudinary
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // مطلوب لرفع Cloudinary
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// إعدادات Cloudinary الخاصة بك
const CLOUDINARY_CLOUD_NAME = 'drckarr2l'; 
const CLOUDINARY_UPLOAD_PRESET = 'ml_default'; 

class AddProductView extends StatefulWidget {
  const AddProductView({super.key});

  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  File? _pickedImage;
  XFile? _pickedXFile; 
  bool _isLoading = false; // حالة التحميل الرئيسية (رفع + حفظ)
  bool _isPickingImage = false; // حالة تحميل مؤشر الكاميرا

  // MARK: - Image Picker
  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true); 

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70); // جودة أقل لسرعة الرفع

      if (pickedFile != null) {
        setState(() {
          _pickedXFile = pickedFile; 
          if (!kIsWeb) {
            _pickedImage = File(pickedFile.path); 
          }
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      // لا نحتاج SnackBar هنا لأنه سيتم عرضه في _saveProduct
    } finally {
      setState(() => _isPickingImage = false); 
    }
  }

  //  MARK: - Cloudinary Upload Function
  Future<String?> _uploadImageToCloudinary() async {
    if (_pickedImage == null && _pickedXFile == null) return null;

    try {
      // قراءة البيانات بالبايت
      final fileBytes = kIsWeb 
          ? await _pickedXFile!.readAsBytes()
          : await _pickedImage!.readAsBytes();
      
      // بناء طلب الـ Multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload'),
      );

      // إضافة الـ Upload Preset والملف
      request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          fileBytes,
          filename: 'product_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      // إرسال الطلب
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['secure_url'] as String?;
        if (imageUrl == null) {
             print("Cloudinary response is missing 'secure_url'. Response: ${response.body}");
        }
        return imageUrl;
      } else {
        print("Cloudinary Upload Error: Status ${response.statusCode}, Body: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Cloudinary Upload Exception: $e");
      return null;
    }
  }

  // MARK: - Product Submission Logic
  Future<void> _saveProduct() async {
    final isImageSelected = _pickedImage != null || _pickedXFile != null;
    
    if (!_formKey.currentState!.validate() || !isImageSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and select an image.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception("User not logged in or email unavailable.");
      }
      final userEmail = user.email!;

      // 1. Fetch Store Details
      final storeSnapshot = await FirebaseFirestore.instance
          .collection("storeRequests")
          .where("email", isEqualTo: userEmail)
          .limit(1)
          .get();
      
      if (storeSnapshot.docs.isEmpty) {
        throw Exception("No store found associated with this email.");
      }

      final storeData = storeSnapshot.docs.first.data();
      final storeName = storeData['storeName'] as String? ?? "Unknown Store";
      final storePhone = storeData['phoneNumber'] as String? ?? "No Phone";

      // 2. استدعاء دالة Cloudinary للرفع
      final imageUrl = await _uploadImageToCloudinary();
      
      if (imageUrl == null) {
        throw Exception("Image upload failed. Check console for Cloudinary error.");
      }
      
      // 3. Save Product to Firestore
      final productData = {
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "price": _priceController.text.trim(), 
        "imageUrl": imageUrl,
        "approved": false, 
        "status": "Pending", 
        "storeOwnerEmail": userEmail,
        "storeName": storeName,
        "storePhone": storePhone,
        "createdAt": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection("products").add(productData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product added successfully! Waiting for approval.")),
      );
      
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      print("Error saving product: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save product: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // MARK: - Layout Builder
  @override
  Widget build(BuildContext context) {
    const double _maxWidth = 600.0; 
    final isImageSelected = _pickedImage != null || _pickedXFile != null; 

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Product"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 24),

                      // ... (بقية حقول النموذج)
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Product Name", border: OutlineInputBorder()),
                        validator: (value) => value!.isEmpty ? 'Enter product name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: "Product Description", border: OutlineInputBorder()),
                        maxLines: 3,
                        validator: (value) => value!.isEmpty ? 'Enter description' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildPriceField(),
                      const SizedBox(height: 32),

                      // 5. Submit Button
                      ElevatedButton.icon(
                        onPressed: (_isLoading || _isPickingImage || !isImageSelected) ? null : _saveProduct,
                        icon: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                            : const Icon(Icons.cloud_upload),
                        label: Text(_isLoading ? "Uploading & Saving..." : "Upload & Save Product"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final imageIsPicked = _pickedImage != null || _pickedXFile != null; 

    return GestureDetector(
      onTap: _isPickingImage ? null : _pickImage, 
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: _isPickingImage 
            ? const Center(child: CircularProgressIndicator())
            : imageIsPicked
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: kIsWeb
                        ? Image.network(
                            _pickedXFile!.path, 
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Image.file(
                            _pickedImage!, 
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 40, color: Colors.blue.shade400),
                      const SizedBox(height: 8),
                      Text(
                        "Select Product Image",
                        style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPriceField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = Theme.of(context).platform == TargetPlatform.android ||
                         Theme.of(context).platform == TargetPlatform.iOS;
        
        return TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: "Product Price (\$)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          keyboardType: isMobile 
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: (value) {
            if (value!.isEmpty) return 'Enter price';
            if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return 'Enter valid price (e.g., 19.99)';
            return null;
          },
        );
      },
    );
  }
  
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5), 
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CircularProgressIndicator(),
      ),
    );
  }
}
// lib/models/product.dart

import '../services/api_service.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String storeId;
  final String? storeName;
  final String? storeOwnerEmail;
  final String? storePhone;
  final String? categoryId;
  final int stock;
  final String imageUrl;
  final String? videoUrl;
  final List<String> imageUrls; //  قائمة الصور المتعددة
  final bool isActive;
  final String status;
  final String? currency; //  حقل العملة

  // use ApiService.baseUrl for platform-aware host

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.storeId,
    this.storeName,
    this.storePhone,
    this.categoryId,
    required this.stock,
    required this.imageUrl,
    this.videoUrl,
    this.imageUrls = const [],
    this.isActive = true,
    this.status = 'approved',
    this.storeOwnerEmail,
    this.currency,
  });

  // Factory for backend API (MySQL)
  factory Product.fromJson(Map<String, dynamic> json) {
    // تحويل المسار النسبي إلى URL كامل
    String imageUrl = json['image_url'] as String? ?? '';
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = '${ApiService.baseHost}$imageUrl';
    }

    // تحويل الفيديو
    String? videoUrl = json['video_url'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty && !videoUrl.startsWith('http')) {
      videoUrl = '${ApiService.baseHost}$videoUrl';
    }

    //  معالجة قائمة الصور المتعددة
    List<String> imageUrls = [];
    if (json['image_urls'] != null) {
      imageUrls = (json['image_urls'] as List).map((url) {
        if (url is String && url.isNotEmpty && !url.startsWith('http')) {
          return '${ApiService.baseHost}$url';
        }
        return url.toString();
      }).toList();
    }
    
    // إذا لم تكن هناك قائمة صور، استخدم الصورة الرئيسية
    if (imageUrls.isEmpty && imageUrl.isNotEmpty) {
      imageUrls = [imageUrl];
    }

    double parsedPrice = 0.0;
    if (json['price'] is String) {
      parsedPrice = double.tryParse(json['price']) ?? 0.0;
    } else if (json['price'] != null) {
      parsedPrice = (json['price']).toDouble();
    }
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Product',
      description: json['description'] ?? '',
      price: parsedPrice,
      storeId: json['store_id']?.toString() ?? '',
      storeName: json['store_name'],
      storePhone: json['store_phone'],
      categoryId: json['category_id']?.toString(),
      stock: json['stock'] ?? 0,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      imageUrls: imageUrls,
      isActive: json['status'] == 'approved',
      status: json['status'] ?? 'pending',
      storeOwnerEmail: json['store_owner_email'] ?? json['storeOwnerEmail'],
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  // Returns true if product is approved
  bool get approved => status == 'approved';

  // Returns storeName or 'N/A' if null
  String get storeNameOrNA => storeName ?? 'N/A';

  //  Helper method لتحويل أي مسار نسبي إلى URL كامل
  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiService.baseHost}$path';
  }

  //  Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'store_id': storeId,
      'store_name': storeName,
      'store_phone': storePhone,
      'category_id': categoryId,
      'stock': stock,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'image_urls': imageUrls,
      'is_active': isActive,
      'status': status,
      'storeOwnerEmail': storeOwnerEmail,
      'currency': currency,
    };
  }
}
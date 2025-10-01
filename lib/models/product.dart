// lib/models/product.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  // الخصائص
  final String? id;
  final String name;
  final double price; // نستخدم double للعمليات الحسابية
  final String description;
  final String imageUrl;
  final String storeOwnerEmail;
  final String storeName;
  final bool approved;
  final String status;
  final String? storePhone;

  // الباني
  Product({
    this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.storeOwnerEmail,
    required this.storeName,
    required this.approved,
    required this.status,
    this.storePhone,
  });

  // MARK: - Firestore Conversion (من وإلى Firestore)

  // القراءة من Firestore
  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    double parsedPrice;
    try {
      // تحويل السعر من String (كما في Swift/Firestore) إلى Double في Dart
      final priceString = data['price'] as String;
      parsedPrice = double.tryParse(priceString.replaceAll('\$', '')) ?? 0.0;
    } catch (e) {
      parsedPrice = 0.0;
    }

    return Product(
      id: doc.id,
      name: data['name'] as String,
      price: parsedPrice,
      description: data['description'] as String,
      imageUrl: data['imageUrl'] as String,
      storeOwnerEmail: data['storeOwnerEmail'] as String,
      storeName: data['storeName'] as String,
      approved: data['approved'] as bool,
      status: data['status'] as String,
      storePhone: data['storePhone'] as String?, 
    );
  }
  
  // دالة التحويل إلى Firestore (للحفظ في قاعدة البيانات)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      // عند الحفظ، نحوله مرة أخرى إلى String ليتطابق مع تخزين SwiftUI
      'price': "\$${price.toStringAsFixed(2)}", 
      'description': description,
      'imageUrl': imageUrl,
      'storeOwnerEmail': storeOwnerEmail,
      'storeName': storeName,
      'approved': approved,
      'status': status,
      'storePhone': storePhone,
    };
  }
  
  // MARK: - JSON Conversion (للحفظ في SharedPreferences)
  
  // القراءة من JSON (لتحميل السلة من SharedPreferences)
  factory Product.fromJson(Map<String, dynamic> json) {
    // هنا لا نحتاج إلى التحويل من String لأننا حفظناه كـ Double في الـ JSON
    return Product(
      id: json['id'] as String?,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(), // يجب أن يكون double
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      storeOwnerEmail: json['storeOwnerEmail'] as String,
      storeName: json['storeName'] as String,
      approved: json['approved'] as bool,
      status: json['status'] as String,
      storePhone: json['storePhone'] as String?,
    );
  }

  // التحويل إلى JSON (لحفظ السلة في SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price, // حفظه كـ double مباشرة
      'description': description,
      'imageUrl': imageUrl,
      'storeOwnerEmail': storeOwnerEmail,
      'storeName': storeName,
      'approved': approved,
      'status': status,
      'storePhone': storePhone,
    };
  }
}
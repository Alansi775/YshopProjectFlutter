// lib/models/admin_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class StoreRequest {
  final String id;
  final String storeName;
  final String storeType;
  final String address;
  final String email;
  final String storeIconUrl;
  final String storePhone;
  final String status;

  StoreRequest({
    required this.id,
    required this.storeName,
    required this.storeType,
    required this.address,
    required this.email,
    required this.storeIconUrl,
    required this.storePhone,
    required this.status,
  });
  
  factory StoreRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreRequest(
      id: doc.id,
      storeName: data["storeName"] as String? ?? "",
      storeType: data["storeType"] as String? ?? "",
      address: data["address"] as String? ?? "",
      email: data["email"] as String? ?? "",
      // لا يجب جلب كلمة المرور
      storeIconUrl: data["storeIconUrl"] as String? ?? "",
      storePhone: data["storePhoneNumber"] as String? ?? "",
      status: data["status"] as String? ?? "Pending",
    );
  }
}

class ProductSS {
    final String id;
    final String storeName;
    final String name;
    final String price;
    final String description;
    final String? imageUrl;
    final String storeOwnerEmail;
    final String storePhone;
    final String status;
    final bool approved;

    ProductSS({
      required this.id,
      required this.storeName,
      required this.name,
      required this.price,
      required this.description,
      this.imageUrl,
      required this.storeOwnerEmail,
      required this.storePhone,
      required this.status,
      required this.approved,
    });
    
    factory ProductSS.fromFirestore(DocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;
      return ProductSS(
        id: doc.id,
        storeName: data["storeName"] as String? ?? "",
        name: data["name"] as String? ?? "",
        price: (data["price"] is num) ? data["price"].toStringAsFixed(2) : data["price"] as String? ?? "0.00",
        description: data["description"] as String? ?? "",
        imageUrl: data["imageUrl"] as String?,
        storeOwnerEmail: data["storeOwnerEmail"] as String? ?? "",
        storePhone: data["storePhone"] as String? ?? "No Phone",
        status: data["status"] as String? ?? "Pending",
        approved: data["approved"] as bool? ?? false,
      );
    }
}
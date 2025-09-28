// lib/models/store.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Store {
  final String id;
  final String storeName;
  final String storeType;
  final String storeIconUrl;
  final String? address;
  final String? storePhoneNumber;
  final String? status;
  // يمكنك إضافة حقول أخرى مثل rating إذا كانت موجودة في Firestore

  Store({
    required this.id,
    required this.storeName,
    required this.storeType,
    required this.storeIconUrl,
    this.address,
    this.storePhoneNumber,
    this.status,
  });

  // مكافئ لـ try? doc.data(as: Store.self)
  factory Store.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Store(
      id: doc.id,
      storeName: data['storeName'] ?? 'Unknown Store',
      storeType: data['storeType'] ?? '',
      // تأكد أن هذا الحقل موجود في Firestore باسم 'storeIconUrl'
      storeIconUrl: data['storeIconUrl'] ?? 'https://via.placeholder.com/150', 
      address: data['address'],
      storePhoneNumber: data['storePhoneNumber'],
      status: data['status'],
    );
  }
}
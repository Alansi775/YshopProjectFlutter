// lib/models/store.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';

class Store {
  final String id;
  final String storeName;
  final String storeType;
  final String storeIconUrl;
  final String? address;
  final String? storePhoneNumber;
  final String? status;
  final String? email;
  final String? ownerUid;

  // use ApiService.baseUrl for platform-aware host

  Store({
    required this.id,
    required this.storeName,
    required this.storeType,
    required this.storeIconUrl,
    this.address,
    this.storePhoneNumber,
    this.status,
    this.email,
    this.ownerUid,
  });

  // Factory for Firestore (legacy)
  factory Store.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Store(
      id: doc.id,
      storeName: data['storeName'] ?? 'Unknown Store',
      storeType: data['storeType'] ?? '',
      storeIconUrl: data['storeIconUrl'] ?? '',
      address: data['address'],
      storePhoneNumber: data['storePhoneNumber'] ?? data['phone'],
      status: data['status'],
      email: data['email'] ?? data['ownerEmail'],
      ownerUid: data['ownerUid'],
    );
  }

  //  Factory for backend API (MySQL)
  factory Store.fromJson(Map<String, dynamic> json) {
    // تحويل المسار النسبي إلى URL كامل
    String iconUrl = json['icon_url'] as String? ?? '';
    if (iconUrl.isNotEmpty && !iconUrl.startsWith('http')) {
      iconUrl = '${ApiService.baseHost}$iconUrl';
    }

    //  تحديد الـ status من قاعدة البيانات مباشرة
    String status = json['status'] ?? 'Pending';

    return Store(
      id: json['id']?.toString() ?? '',
      storeName: json['name'] ?? 'Unknown Store',
      storeType: json['store_type'] ?? json['storeType'] ?? '', //  تصحيح
      storeIconUrl: iconUrl,
      address: json['address'],
      storePhoneNumber: json['phone']?.toString(),
      status: status,
      email: json['email'],
      ownerUid: json['owner_uid'] ?? json['ownerUid'],
    );
  }

  //  Helper method لتحويل أي مسار نسبي إلى URL كامل
  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiService.baseHost}$path';
  }

  //  Convert to JSON (للإرسال للـ API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': storeName,
      'store_type': storeType,
      'icon_url': storeIconUrl,
      'address': address,
      'phone': storePhoneNumber,
      'status': status,
      'email': email,
      'owner_uid': ownerUid,
    };
  }
}
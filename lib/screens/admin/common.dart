// lib/screens/admin/common.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🎨 YSHOP BRAND DESIGN SYSTEM - Matching Current App Style
// ═══════════════════════════════════════════════════════════════════════════════

// Primary Background Colors - Matching your app
const Color kDarkBackground = Color(0xFF1A1A1E);      // الخلفية الرئيسية
const Color kDeepBackground = Color(0xFF141417);      // أغمق قليلاً للـ sidebar

// Surface Colors - Cards & Containers
const Color kSurfaceColor = Color(0xFF252529);        // لون البطاقات
const Color kSurfaceLight = Color(0xFF2D2D32);        // بطاقة أفتح
const Color kSurfaceDark = Color(0xFF1E1E22);         // بطاقة أغمق

// Glass Effect - Subtle
const Color kGlassBackground = Color(0xFF252529);     // خلفية زجاجية
const Color kGlassBorder = Color(0xFF3A3A3F);         // حدود خفيفة
const Color kGlassHighlight = Color(0xFF2F2F34);      // لمعة

// Card Colors
const Color kCardBackground = Color(0xFF252529);      // خلفية البطاقة
const Color kCardBackgroundHover = Color(0xFF2D2D32); // عند التحويم
const Color kCardBorder = Color(0xFF3A3A3F);          // حدود البطاقة

// App Bar
const Color kAppBarBackground = Color(0xFF1A1A1E);

// Text Colors - Clean Hierarchy
const Color kPrimaryTextColor = Color(0xFFFFFFFF);    // أبيض للعناوين
const Color kSecondaryTextColor = Color(0xFF9A9A9F);  // رمادي للنص الثانوي
const Color kTertiaryTextColor = Color(0xFF6B6B70);   // رمادي أغمق
const Color kMutedTextColor = Color(0xFF505055);      // رمادي خافت

// Primary Accent - Blue (للأزرار والعناصر المحددة فقط)
const Color kAccentBlue = Color(0xFF3B82F6);          // الأزرق الرئيسي
const Color kAccentBlueLight = Color(0xFF60A5FA);     // أزرق فاتح
const Color kAccentBlueDark = Color(0xFF2563EB);      // أزرق غامق

// Status/Icon Colors - للأيقونات فقط
const Color kAccentGreen = Color(0xFF22C55E);         // أخضر
const Color kAccentOrange = Color(0xFFF97316);        // برتقالي
const Color kAccentRed = Color(0xFFEF4444);           // أحمر
const Color kAccentPurple = Color(0xFF3A3A3F);        // بنفسجي
const Color kAccentYellow = Color(0xFFEAB308);        // أصفر
const Color kAccentCyan = Color(0xFF06B6D4);          // سماوي
const Color kAccentPink = Color(0xFFEC4899);          // وردي

// Status Colors
const Color kStatusApproved = Color(0xFF22C55E);
const Color kStatusPending = Color(0xFFF97316);
const Color kStatusRejected = Color(0xFFEF4444);

// Borders & Separators
const Color kSeparatorColor = Color(0xFF2D2D32);
const Color kBorderColor = Color(0xFF3A3A3F);

// Sidebar specific
const Color kSidebarBackground = Color(0xFF141417);
const Color kSidebarItemHover = Color(0xFF252529);
const Color kSidebarItemActive = Color(0xFF2D2D32);

// ═══════════════════════════════════════════════════════════════════════════════
// 🎯 GRADIENT DEFINITIONS - Minimal & Clean
// ═══════════════════════════════════════════════════════════════════════════════

class AppGradients {
  // Primary Blue - للأزرار فقط
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Surface Gradients - للبطاقات
  static const LinearGradient surface = LinearGradient(
    colors: [Color(0xFF2D2D32), Color(0xFF252529)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient dark = LinearGradient(
    colors: [Color(0xFF252529), Color(0xFF1E1E22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient glass = LinearGradient(
    colors: [Color(0xFF2D2D32), Color(0xFF252529)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Status Gradients - للأيقونات فقط
  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warning = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient danger = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient purple = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cyan = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient pink = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class ProductSS {
  final String id;
  final String storeName;
  final String storeId;
  final String name;
  final String price;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final int? stock;
  final String storeOwnerEmail;
  final String storePhone;
  final String status;
  final bool approved;
  final String? currency;

  ProductSS({
    required this.id,
    required this.storeName,
    this.storeId = '',
    required this.name,
    required this.price,
    required this.description,
    this.imageUrl,
    this.videoUrl,
    this.stock,
    required this.storeOwnerEmail,
    required this.storePhone,
    required this.status,
    required this.approved,
    this.currency,
  });

  factory ProductSS.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductSS(
      id: doc.id,
      storeName: data["storeName"] as String? ?? "",
      storeId: data["storeId"] as String? ?? "",
      name: data["name"] as String? ?? "",
      price: (data["price"] is num) ? data["price"].toString() : data["price"] as String? ?? "0.00",
      description: data["description"] as String? ?? "",
      imageUrl: data["imageUrl"] as String?,
      storeOwnerEmail: data["storeOwnerEmail"] as String? ?? "",
      storePhone: data["storePhone"] as String? ?? "No Phone",
      status: data["status"] as String? ?? "Pending",
      approved: data["approved"] as bool? ?? false,
      currency: data["currency"] as String? ?? "USD",
    );
  }

  factory ProductSS.fromMap(Map<String, dynamic> m) {
    return ProductSS(
      id: (m['id'] ?? '').toString(),
      storeName: m['store_name'] as String? ?? m['storeName'] as String? ?? 'Unknown Store',
      storeId: (m['store_id'] ?? m['storeId'] ?? '').toString(),
      name: m['name'] as String? ?? '',
      price: (m['price'] ?? '0.00').toString(),
      description: m['description'] as String? ?? '',
      imageUrl: m['image_url'] as String? ?? m['imageUrl'] as String?,
      videoUrl: m['video_url'] as String?,
      stock: m['stock'] is int ? m['stock'] : int.tryParse((m['stock'] ?? '').toString()),
      storeOwnerEmail: m['owner_email'] as String? ?? m['storeOwnerEmail'] as String? ?? '',
      storePhone: (m['store_phone'] ?? m['storePhone'] ?? '').toString(),
      status: m['status'] as String? ?? 'Pending',
      currency: m['currency'] as String? ?? 'USD',
      approved: m['status']?.toString().toLowerCase() == 'approved',
    );
  }
}

class StoreRequest {
  final String id;
  final String ownerUid;
  final String storeName;
  final String storeType;
  final String address;
  final String email;
  final String storeIconUrl;
  final String storePhone;
  final String status;

  StoreRequest({
    required this.id,
    required this.ownerUid,
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
      id: '',
      ownerUid: doc.id,
      storeName: data["storeName"] as String? ?? "",
      storeType: data["storeType"] as String? ?? "",
      address: data["address"] as String? ?? "",
      email: data["email"] as String? ?? "",
      storeIconUrl: data["storeIconUrl"] as String? ?? "",
      storePhone: data["storePhoneNumber"] as String? ?? "",
      status: data["status"] as String? ?? "Pending",
    );
  }

  factory StoreRequest.fromMap(Map<String, dynamic> m) {
    return StoreRequest(
      id: (m['id'] ?? '').toString(),
      ownerUid: m['owner_uid'] as String? ?? '',
      storeName: m['name'] as String? ?? m['storeName'] as String? ?? '',
      storeType: m['store_type'] as String? ?? m['storeType'] as String? ?? '',
      address: m['address'] as String? ?? '',
      email: m['email'] as String? ?? '',
      storeIconUrl: m['icon_url'] as String? ?? m['storeIconUrl'] as String? ?? '',
      storePhone: (m['phone'] ?? m['storePhone'] ?? '').toString(),
      status: m['status'] as String? ?? 'Pending',
    );
  }
}

class DeliveryRequest {
  final String id;
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final String nationalID;
  final String address;
  final String status;
  final bool isWorking;
  final DateTime? createdAt;

  DeliveryRequest({
    required this.id,
    this.uid = '',
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.nationalID,
    required this.address,
    required this.status,
    this.isWorking = false,
    this.createdAt,
  });

  factory DeliveryRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeliveryRequest(
      id: doc.id,
      name: data["name"] as String? ?? "",
      email: data["email"] as String? ?? "",
      phoneNumber: data["phoneNumber"] as String? ?? "N/A",
      nationalID: data["nationalID"] as String? ?? "N/A",
      address: data["address"] as String? ?? "N/A",
      status: data["status"] as String? ?? "Pending",
    );
  }

  factory DeliveryRequest.fromMap(Map<String, dynamic> m) {
    return DeliveryRequest(
      id: (m['id'] ?? m['ID'] ?? m['Id'] ?? '').toString(),
      uid: m['uid'] as String? ?? '',
      name: m['name'] as String? ?? m['full_name'] as String? ?? '',
      email: m['email'] as String? ?? '',
      phoneNumber: m['phone'] as String? ?? m['phoneNumber'] as String? ?? 'N/A',
      nationalID: m['national_id'] as String? ?? m['nationalID'] as String? ?? 'N/A',
      address: m['address'] as String? ?? '',
      status: m['status'] as String? ?? 'Pending',
      isWorking: m['is_working'] == 1 || m['is_working'] == true,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
    );
  }
}

class OrderModel {
  final String id;
  final String oderId;
  final String storeId;
  final String storeName;
  final double totalPrice;
  final String status;
  final String shippingAddress;
  final String paymentMethod;
  final String deliveryOption;
  final String? driverLocation;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.oderId,
    required this.storeId,
    this.storeName = '',
    required this.totalPrice,
    required this.status,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.deliveryOption,
    this.driverLocation,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory OrderModel.fromMap(Map<String, dynamic> m) {
    List<OrderItem> orderItems = [];
    if (m['items'] != null && m['items'] is List) {
      orderItems = (m['items'] as List).map((item) => OrderItem.fromMap(item)).toList();
    }
    
    return OrderModel(
      id: (m['id'] ?? '').toString(),
      oderId: (m['user_id'] ?? '').toString(),
      storeId: (m['store_id'] ?? '').toString(),
      storeName: m['store_name'] as String? ?? '',
      totalPrice: double.tryParse((m['total_price'] ?? '0').toString()) ?? 0.0,
      status: m['status'] as String? ?? 'pending',
      shippingAddress: m['shipping_address'] as String? ?? '',
      paymentMethod: m['payment_method'] as String? ?? '',
      deliveryOption: m['delivery_option'] as String? ?? 'Standard',
      driverLocation: m['driver_location'] as String?,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'].toString()) : null,
      items: orderItems,
    );
  }
}

class OrderItem {
  final String id;
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String? imageUrl;

  OrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.imageUrl,
  });

  factory OrderItem.fromMap(Map<String, dynamic> m) {
    return OrderItem(
      id: (m['id'] ?? '').toString(),
      productId: (m['product_id'] ?? '').toString(),
      name: m['name'] as String? ?? 'Product',
      quantity: int.tryParse((m['quantity'] ?? '1').toString()) ?? 1,
      price: double.tryParse((m['price'] ?? '0').toString()) ?? 0.0,
      imageUrl: m['image_url'] as String?,
    );
  }
}

class AdminModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String status;
  final DateTime? createdAt;

  AdminModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.status = 'active',
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory AdminModel.fromMap(Map<String, dynamic> m) {
    return AdminModel(
      id: (m['id'] ?? '').toString(),
      email: m['email'] as String? ?? '',
      firstName: m['first_name'] as String? ?? '',
      lastName: m['last_name'] as String? ?? '',
      role: m['role'] as String? ?? 'admin',
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
    );
  }
}

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String adminId;
  final String role;
  final String status;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.adminId,
    required this.role,
    this.status = 'active',
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserModel.fromMap(Map<String, dynamic> m) {
    return UserModel(
      id: (m['id'] ?? '').toString(),
      email: m['email'] as String? ?? '',
      firstName: m['first_name'] as String? ?? '',
      lastName: m['last_name'] as String? ?? '',
      adminId: (m['admin_id'] ?? '').toString(),
      role: m['role'] as String? ?? 'user',
      status: (() {
        // Support different backend representations
        if (m.containsKey('status') && m['status'] != null) return m['status'].toString();
        if (m.containsKey('is_banned')) {
          final v = m['is_banned'];
          if (v is bool) return v ? 'banned' : 'active';
          if (v is int) return v == 1 ? 'banned' : 'active';
        }
        return 'active';
      })(),
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 💰 REVENUE CALCULATOR
// ═══════════════════════════════════════════════════════════════════════════════

class RevenueCalculator {
  static const double APP_COMMISSION_RATE = 0.25;
  static const double STORE_OWNER_RATE = 0.75;

  static double calculateAppRevenue(double totalPrice) {
    return totalPrice * APP_COMMISSION_RATE;
  }

  static double calculateStoreOwnerRevenue(double totalPrice) {
    return totalPrice * STORE_OWNER_RATE;
  }

  static Map<String, double> calculateOrderRevenue(double totalPrice) {
    return {
      'app': calculateAppRevenue(totalPrice),
      'store': calculateStoreOwnerRevenue(totalPrice),
      'total': totalPrice,
    };
  }

  static Map<String, double> calculateTotalRevenue(List<OrderModel> orders) {
    double totalOrdersValue = 0.0;
    double totalAppRevenue = 0.0;
    double totalStoreRevenue = 0.0;

    for (final order in orders) {
      totalOrdersValue += order.totalPrice;
      totalAppRevenue += calculateAppRevenue(order.totalPrice);
      totalStoreRevenue += calculateStoreOwnerRevenue(order.totalPrice);
    }

    return {
      'totalOrders': totalOrdersValue,
      'appRevenue': totalAppRevenue,
      'storeRevenue': totalStoreRevenue,
    };
  }
}
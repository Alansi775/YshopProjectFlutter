// lib/models/admin_models.dart

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

  //  Factory for backend API (MySQL)
  factory StoreRequest.fromJson(Map<String, dynamic> json) {
    return StoreRequest(
      id: json["id"]?.toString() ?? "",
      storeName: json["name"] as String? ?? "",
      storeType: json["store_type"] as String? ?? "",
      address: json["address"] as String? ?? "",
      email: json["email"] as String? ?? "",
      storeIconUrl: json["icon_url"] as String? ?? "",
      storePhone: json["phone"] as String? ?? "",
      status: json["status"] as String? ?? "Pending",
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
    final int? categoryId;
    final String? categoryName;

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
      this.categoryId,
      this.categoryName,
    });
    
    //  Factory for backend API (MySQL)
    factory ProductSS.fromJson(Map<String, dynamic> json) {
      return ProductSS(
        id: json["id"]?.toString() ?? "",
        storeName: json["store_name"] as String? ?? "",
        name: json["name"] as String? ?? "",
        price: (json["price"] is num) ? json["price"].toStringAsFixed(2) : json["price"] as String? ?? "0.00",
        description: json["description"] as String? ?? "",
        imageUrl: json["image_url"] as String?,
        storeOwnerEmail: json["store_owner_email"] as String? ?? "",
        storePhone: json["store_phone"] as String? ?? "No Phone",
        status: json["status"] as String? ?? "Pending",
        approved: json["approved"] as bool? ?? false,
        categoryId: json["category_id"] as int?,
        categoryName: json["category_name"] as String?,
      );
    }
}
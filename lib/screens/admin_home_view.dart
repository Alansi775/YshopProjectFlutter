// lib/screens/admin_home_view.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_login_view.dart'; // لاستخدام الدخول الثابت والتصاميم الداكنة

//  تعريف الألوان الداكنة
const Color kDarkBackground = Color(0xFF1C1C1E); // خلفية الشاشة
const Color kCardBackground = Color(0xFF2C2C2E); // خلفية البطاقات والأقسام
const Color kAppBarBackground = Color(0xFF1C1C1E); // خلفية شريط التطبيق
const Color kPrimaryTextColor = Colors.white; // النص الأساسي
const Color kSecondaryTextColor = Colors.white70; // النص الثانوي/الرمادي
const Color kSeparatorColor = Color(0xFF48484A); // لون الفاصل/الحدود

//  النماذج (يجب أن تكون في ملف منفصل في بيئة الإنتاج)
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
        price: (data["price"] is num) ? data["price"].toString() : data["price"] as String? ?? "0.00",
        description: data["description"] as String? ?? "",
        imageUrl: data["imageUrl"] as String?,
        storeOwnerEmail: data["storeOwnerEmail"] as String? ?? "",
        storePhone: data["storePhone"] as String? ?? "No Phone",
        status: data["status"] as String? ?? "Pending",
        approved: data["approved"] as bool? ?? false,
      );
    }
}

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
      storeIconUrl: data["storeIconUrl"] as String? ?? "",
      storePhone: data["storePhoneNumber"] as String? ?? "",
      status: data["status"] as String? ?? "Pending",
    );
  }
}
// نهاية النماذج المؤقتة

// --------------------------------------------------
// MARK: - Admin Home View
// --------------------------------------------------

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({super.key});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  // مفاتيح لتحديث محتوى الـ StreamBuilders
  Key _productKey = UniqueKey();
  Key _requestKey = UniqueKey();

  void _refreshData() {
    setState(() {
      _productKey = UniqueKey();
      _requestKey = UniqueKey();
    });
  }
  
  void _logout() async {
    // تجاهل Firebase Auth واستخدام الدخول الثابت
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminLoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int getCrossAxisCount(double width) {
      if (width > 1200) return 5;
      if (width > 800) return 4;
      if (width > 600) return 3;
      return 2;
    }

    return Scaffold(
      backgroundColor: kDarkBackground,
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: kPrimaryTextColor)),
        backgroundColor: kAppBarBackground,
        foregroundColor: kPrimaryTextColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = getCrossAxisCount(constraints.maxWidth);

          return RefreshIndicator(
            onRefresh: () async {
              _refreshData();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. المنتجات المعلقة (Pending Products)
                  _buildProductStream(context, crossAxisCount, approved: false, key: _productKey),
                  const SizedBox(height: 30),

                  // 2. طلبات المتاجر (Store Requests - Pending)
                  _buildRequestStream(context, crossAxisCount, status: "Pending", key: _requestKey),
                  const SizedBox(height: 30),

                  // 3. المتاجر المعتمدة (Approved Stores)
                  _buildRequestStream(context, crossAxisCount, status: "Approved"),
                  const SizedBox(height: 30),
                  
                  // 4. زر تسجيل الخروج السفلي
                  _bottomActionButtons(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // MARK: - Firebase Streams
  // --------------------------------------------------

  Widget _buildProductStream(BuildContext context, int crossAxisCount, {required bool approved, Key? key}) {
    return StreamBuilder<QuerySnapshot>(
      key: key, 
      stream: FirebaseFirestore.instance
          .collection("products")
          .where("approved", isEqualTo: approved)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(color: Colors.blue),
          ));
        }
        if (snapshot.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline,
            title: "Error",
            message: "Failed to load products: ${snapshot.error}",
          );
        }

        final products = snapshot.data?.docs.map(ProductSS.fromFirestore).toList() ?? [];
        final title = approved ? "Approved Products" : "Pending Products";
        
        return _buildSectionView(
          title: title,
          count: products.length,
          content: products.isEmpty
              ? EmptyStateView(
                  icon: approved ? Icons.check_circle_outline : Icons.inventory_2,
                  title: "No $title",
                  message: approved ? "All products are live." : "All products are reviewed.",
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductCardView(
                      key: ValueKey(product.id), 
                      product: product,
                      onTap: () => _showProductDetails(context, product),
                      onApprove: () => _updateProductStatus(product, approved: true),
                      onReject: () => _deleteProduct(product),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildRequestStream(BuildContext context, int crossAxisCount, {required String status, Key? key}) {
    final bool isApproved = status == "Approved";
    return StreamBuilder<QuerySnapshot>(
      key: key,
      stream: FirebaseFirestore.instance
          .collection("storeRequests")
          .where("status", isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(color: Colors.blue),
          ));
        }
        if (snapshot.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline,
            title: "Error",
            message: "Failed to load requests: ${snapshot.error}",
          );
        }

        final requests = snapshot.data?.docs.map(StoreRequest.fromFirestore).toList() ?? [];
        final title = isApproved ? "Approved Stores" : "Pending Store Requests";
        
        return _buildSectionView(
          title: title,
          count: requests.length,
          content: requests.isEmpty
              ? EmptyStateView(
                  icon: isApproved ? Icons.check_circle_outline : Icons.storefront,
                  title: "No $title",
                  message: isApproved ? "No stores approved yet." : "All requests are processed.",
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _StoreRequestCardView(
                      key: ValueKey(request.id),
                      request: request,
                      onTap: () => _showRequestDetails(context, request),
                      onApprove: () => _updateRequestStatus(request, "Approved"),
                      onReject: () => _updateRequestStatus(request, "Rejected"),
                    );
                  },
                ),
        );
      },
    );
  }

  // --------------------------------------------------
  // MARK: - Actions
  // --------------------------------------------------

  void _updateProductStatus(ProductSS product, {required bool approved}) async {
    await FirebaseFirestore.instance.collection("products").doc(product.id).update({
      "approved": approved,
      "status": approved ? "Approved" : "Rejected",
    });
    _refreshData();
  }

  void _deleteProduct(ProductSS product) async {
    await FirebaseFirestore.instance.collection("products").doc(product.id).delete();
    _refreshData();
  }

  void _updateRequestStatus(StoreRequest request, String status) async {
    await FirebaseFirestore.instance.collection("storeRequests").doc(request.id).update({
      "status": status,
    });
    _refreshData();
  }

  void _showProductDetails(BuildContext context, ProductSS product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailView(
        product: product,
        onApprove: () => _updateProductStatus(product, approved: true),
        onReject: () => _deleteProduct(product),
        onDismiss: _refreshData,
      ),
    );
  }

  void _showRequestDetails(BuildContext context, StoreRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoreRequestDetailView(
        request: request,
        onUpdateStatus: _updateRequestStatus,
        onDismiss: _refreshData,
      ),
    );
  }
  
  // --------------------------------------------------
  // MARK: - UI Components
  // --------------------------------------------------

  Widget _buildSectionView({required String title, required int count, required Widget content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "($count)",
                style: const TextStyle(fontSize: 16, color: kSecondaryTextColor),
              ),
              // Spacer to push the count to the right
              if (count > 0) const SizedBox.shrink() else const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
        content,
      ],
    );
  }
  
  Widget _bottomActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text("Logout", style: TextStyle(color: Colors.red, fontSize: 18)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------
// MARK: - Nested Components (Private Widgets)
// --------------------------------------------------

class _ProductCardView extends StatelessWidget {
  final ProductSS product;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ProductCardView({
    super.key, 
    required this.product,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kCardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          _showContextMenu(context);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl ?? '',
                fit: BoxFit.cover,
                height: 120,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  height: 120,
                  color: kSecondaryTextColor.withOpacity(0.1),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  color: kSecondaryTextColor.withOpacity(0.1),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: kSecondaryTextColor),
                  ),
                ),
              ),
            ),
            
            // Details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.storeName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: kSecondaryTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${product.price}',
                    style: const TextStyle(fontSize: 12, color: kSecondaryTextColor),
                  ),
                  const SizedBox(height: 8),
                  _StatusBadgeView(status: product.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showContextMenu(BuildContext context) {
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        const Rect.fromLTWH(0, 0, 0, 0), 
        Offset.zero & MediaQuery.of(context).size,
      ),
      items: [
        PopupMenuItem(
          onTap: onApprove,
          child: const Text('Approve', style: TextStyle(color: Colors.green)),
        ),
        PopupMenuItem(
          onTap: onReject,
          child: const Text('Reject', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

class _StoreRequestCardView extends StatelessWidget {
  final StoreRequest request;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _StoreRequestCardView({
    super.key,
    required this.request,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = request.status == "Approved";
    return Card(
      color: kCardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        onLongPress: isApproved ? null : () => _showContextMenu(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon/Image
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: isApproved && request.storeIconUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: request.storeIconUrl,
                      fit: BoxFit.cover,
                      height: 50,
                      width: 50,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.storefront, 
                        color: Colors.green, 
                        size: 50
                      ),
                    )
                  : Icon(
                      Icons.storefront,
                      size: 50,
                      color: isApproved ? Colors.green : Colors.blue,
                    ),
            ),
            
            // Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.storeName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: kSecondaryTextColor),
                      const SizedBox(width: 4),
                      Text(
                        request.storePhone.isEmpty ? "N/A" : request.storePhone,
                        style: const TextStyle(fontSize: 12, color: kSecondaryTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.storeType,
                    style: const TextStyle(fontSize: 12, color: kSecondaryTextColor),
                  ),
                  const SizedBox(height: 8),
                  _StatusBadgeView(status: request.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showContextMenu(BuildContext context) {
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        const Rect.fromLTWH(0, 0, 0, 0),
        Offset.zero & MediaQuery.of(context).size,
      ),
      items: [
        PopupMenuItem(
          onTap: onApprove,
          child: const Text('Approve', style: TextStyle(color: Colors.green)),
        ),
        PopupMenuItem(
          onTap: onReject,
          child: const Text('Reject', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

class _StatusBadgeView extends StatelessWidget {
  final String status;

  const _StatusBadgeView({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;

    switch (status) {
      case "Pending":
        color = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.2);
        break;
      case "Approved":
        color = Colors.green;
        bgColor = Colors.green.withOpacity(0.2);
        break;
      case "Rejected":
        color = Colors.red;
        bgColor = Colors.red.withOpacity(0.2);
        break;
      default:
        color = kSecondaryTextColor;
        bgColor = kSecondaryTextColor.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      // خلفية داكنة للأقسام الفارغة
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: kSecondaryTextColor,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: kPrimaryTextColor),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: kSecondaryTextColor),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// MARK: - Detail Screens (Sheets)
// --------------------------------------------------

class _ProductDetailView extends StatelessWidget {
  final ProductSS product;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDismiss;

  const _ProductDetailView({
    super.key,
    required this.product,
    required this.onApprove,
    required this.onReject,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: kDarkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // لجعل الخلفية شفافة لرؤية الـ Container
        appBar: AppBar(
          title: const Text('Product Review', style: TextStyle(color: kPrimaryTextColor)),
          backgroundColor: kAppBarBackground,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDismiss();
              },
              child: const Text("Done", style: TextStyle(color: Colors.blue, fontSize: 18)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Center(
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl ?? '',
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: kSecondaryTextColor.withOpacity(0.1),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: kSecondaryTextColor.withOpacity(0.1),
                      child: const Center(child: Icon(Icons.image, size: 50, color: kSecondaryTextColor)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Product Details Section
              _DetailSection(
                title: "Product Details",
                children: [
                  _DetailRow(label: "Store Name", value: product.storeName),
                  _DetailRow(label: "Name", value: product.name),
                  _DetailRow(label: "Price", value: "\$${product.price}"),
                  //  التعديل هنا لطلبك: valueAlignment: TextAlign.center
                  _DetailRow(
                    label: "Description", 
                    value: product.description, 
                    isMultiline: true,
                    valueAlignment: TextAlign.center,
                  ),
                  _DetailRow(label: "Store Email", value: product.storeOwnerEmail),
                  _DetailRow(label: "Store Phone", value: product.storePhone),
                ],
              ),
              const SizedBox(height: 30),

              // Actions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: "Accept",
                      color: Colors.green,
                      onPressed: () {
                        onApprove();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionButton(
                      label: "Remove",
                      color: Colors.red,
                      onPressed: () {
                        onReject();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreRequestDetailView extends StatelessWidget {
  final StoreRequest request;
  final Function(StoreRequest, String) onUpdateStatus;
  final VoidCallback onDismiss;

  const _StoreRequestDetailView({
    super.key,
    required this.request,
    required this.onUpdateStatus,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: kDarkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Store Request', style: TextStyle(color: kPrimaryTextColor)),
          backgroundColor: kAppBarBackground,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDismiss();
              },
              child: const Text("Done", style: TextStyle(color: Colors.blue, fontSize: 18)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store Icon/Image
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: kCardBackground,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: kSecondaryTextColor.withOpacity(0.5), width: 1),
                  ),
                  child: ClipOval(
                    child: request.storeIconUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: request.storeIconUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => const Icon(Icons.storefront, size: 50, color: kSecondaryTextColor),
                          )
                        : const Icon(Icons.storefront, size: 50, color: kSecondaryTextColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Store Details Section
              _DetailSection(
                title: "Store Details",
                children: [
                  _DetailRow(label: "Store Name", value: request.storeName),
                  _DetailRow(label: "Phone", value: request.storePhone),
                  _DetailRow(label: "Store Type", value: request.storeType),
                  _DetailRow(label: "Address", value: request.address, isMultiline: true),
                  _DetailRow(label: "Email", value: request.email),
                  _DetailRow(label: "Status", value: request.status),
                ],
              ),
              const SizedBox(height: 30),

              // Actions Section
              _DetailSection(
                title: "Actions",
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: "Accept",
                          color: Colors.green,
                          onPressed: () {
                            onUpdateStatus(request, "Approved");
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ActionButton(
                          label: "Reject",
                          color: Colors.red,
                          onPressed: () {
                            onUpdateStatus(request, "Rejected");
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ActionButton(
                          label: "Pending",
                          color: Colors.orange,
                          onPressed: () {
                            onUpdateStatus(request, "Pending");
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ودجت لمطابقة شكل الـ Form Section في SwiftUI
class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kSecondaryTextColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;
  // الخاصية الجديدة
  final TextAlign valueAlignment;

  const _DetailRow({
    super.key, 
    required this.label, 
    required this.value, 
    this.isMultiline = false,
    // تعيين قيمة افتراضية
    this.valueAlignment = TextAlign.end, 
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryTextColor),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              // استخدام الخاصية
              textAlign: valueAlignment,
              style: const TextStyle(color: kSecondaryTextColor),
              maxLines: isMultiline ? null : 1, 
              overflow: isMultiline ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({super.key, required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: kPrimaryTextColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
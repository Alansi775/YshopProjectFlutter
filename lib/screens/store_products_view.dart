// lib/screens/store_products_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'admin_login_view.dart'; // لاستخدام الدخول الثابت والتصاميم الداكن



//  النموذج (ننسخ تعريف ProductSS للحاجة إليه)
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

// --------------------------------------------------
// MARK: - Store Products View
// --------------------------------------------------

class StoreProductsView extends StatefulWidget {
  final String storeOwnerEmail;
  final String storeName;

  const StoreProductsView({
    super.key,
    required this.storeOwnerEmail,
    required this.storeName,
  });

  @override
  State<StoreProductsView> createState() => _StoreProductsViewState();
}

class _StoreProductsViewState extends State<StoreProductsView> {
  String _searchQuery = "";
  Key _streamKey = UniqueKey();
  
  // دالة لتحديث عرض المنتجات
  void _refreshData() {
    setState(() {
      _streamKey = UniqueKey();
    });
  }

  // --------------------------------------------------
  // MARK: - Actions
  // --------------------------------------------------

  void _updateProductStatus(ProductSS product, {required bool approved}) async {
    final newStatus = approved ? "Approved" : "Pending";
    await FirebaseFirestore.instance.collection("products").doc(product.id).update({
      "approved": approved,
      "status": newStatus,
    });
    _refreshData();
  }

  void _deleteProduct(ProductSS product) async {
    await FirebaseFirestore.instance.collection("products").doc(product.id).delete();
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
        onPending: () => _updateProductStatus(product, approved: false), // لإرجاعها إلى Pending
        onDismiss: _refreshData,
      ),
    );
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
        title: Text('${widget.storeName} Products', style: const TextStyle(color: kPrimaryTextColor)),
        backgroundColor: kAppBarBackground,
        foregroundColor: kPrimaryTextColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // أضف هذا السطر
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = getCrossAxisCount(constraints.maxWidth);

          return Column(
            children: [
              // 💡 شريط البحث
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  style: const TextStyle(color: kPrimaryTextColor),
                  decoration: InputDecoration(
                    hintText: "Search product name...",
                    hintStyle: TextStyle(color: kSecondaryTextColor.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.search, color: kSecondaryTextColor),
                    filled: true,
                    fillColor: kCardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),

              // 💡 قائمة المنتجات (StreamBuilder)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refreshData(),
                  child: StreamBuilder<QuerySnapshot>(
                    key: _streamKey,
                    stream: FirebaseFirestore.instance
                        .collection("products")
                        .where("storeOwnerEmail", isEqualTo: widget.storeOwnerEmail)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: kAccentBlue));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                      }

                      final allProducts = snapshot.data?.docs.map(ProductSS.fromFirestore).toList() ?? [];
                      
                      // 💡 تطبيق فلتر البحث
                      final filteredProducts = allProducts.where((product) {
                        return product.name.toLowerCase().contains(_searchQuery);
                      }).toList();

                      if (filteredProducts.isEmpty && allProducts.isNotEmpty) {
                        // 💡 إصلاح خطأ السلسلة النصية: استخدام ${} لمتغير _searchQuery
                        return Center(child: Text("No products found matching '${_searchQuery}'", style: const
                        TextStyle(color: kSecondaryTextColor)));
                      }
                      
                      if (filteredProducts.isEmpty && allProducts.isEmpty) {
                         return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(30.0),
                            child: Text(
                              "This store has no products yet.", 
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: kSecondaryTextColor),
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16.0),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16.0,
                          mainAxisSpacing: 16.0,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _ProductCardView(
                            product: product,
                            onTap: () => _showProductDetails(context, product),
                            onApprove: () => _updateProductStatus(product, approved: true),
                            onReject: () => _deleteProduct(product),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --------------------------------------------------
// MARK: - Nested Components (Private Widgets)
// --------------------------------------------------

// (ننسخ Product Card View و Status Badge View من admin_home_view.dart)

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
          child: const Text('Reject (Delete)', style: TextStyle(color: Colors.red)),
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


class _ActionTextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionTextButton({super.key, required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        // لون شفاف للخلفية
        backgroundColor: color.withOpacity(0.1),
        // لون النص هو اللون الأساسي
        foregroundColor: color, 
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          // إضافة حد رفيع بنفس لون النص لتمييزه
          side: BorderSide(color: color.withOpacity(0.5), width: 1), 
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}


// --------------------------------------------------
// MARK: - Detail Screen (Sheet) - نسخة مُعدلة لإدارة المنتج من شاشة المتجر
// --------------------------------------------------

// ودجت لمطابقة شكل الـ Form Section في SwiftUI (ننسخها أيضاً)
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

// ودجت للصف التفصيلي (ننسخها أيضاً)
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;
  final TextAlign valueAlignment;

  const _DetailRow({
    super.key, 
    required this.label, 
    required this.value, 
    this.isMultiline = false,
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

// ودجت زر الإجراءات (ننسخها أيضاً)
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

class _ProductDetailView extends StatelessWidget {
  final ProductSS product;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPending; // 💡 لإرجاع المنتج إلى Pending
  final VoidCallback onDismiss;

  const _ProductDetailView({
    super.key,
    required this.product,
    required this.onApprove,
    required this.onReject,
    required this.onPending,
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
              child: const Text("Done", style: TextStyle(color: kAccentBlue, fontSize: 18)),
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
                  _DetailRow(
                    label: "Description", 
                    value: product.description, 
                    isMultiline: true,
                    valueAlignment: TextAlign.start, // تعديل المحاذاة ليكون طبيعياً في الوصف
                  ),
                  _DetailRow(label: "Store Email", value: product.storeOwnerEmail),
                  _DetailRow(label: "Status", value: product.status),
                ],
              ),
              const SizedBox(height: 30),

              // Actions Section - تحديث الإجراءات لتشمل Pending أيضاً
              _DetailSection(
                title: "Actions",
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        // 💡 استخدام _ActionTextButton (Accept)
                        child: _ActionTextButton(
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
                        // 💡 استخدام _ActionTextButton (Pending)
                        child: _ActionTextButton(
                          label: "Pending",
                          color: Colors.orange,
                          onPressed: () {
                            onPending();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                       const SizedBox(width: 16),
                      Expanded(
                        // 💡 استخدام _ActionTextButton (Delete)
                        child: _ActionTextButton(
                          label: "Delete",
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
            ],
          ),
        ),
      ),
    );
  }
}
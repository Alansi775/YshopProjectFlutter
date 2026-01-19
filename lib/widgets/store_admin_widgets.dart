
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/currency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

// دالة مساعدة لتحويل الرابط النسبي إلى رابط كامل
// ⚠️ Replace with your actual local IP address below (e.g., 192.168.1.70)
const String kBackendIp = '192.168.1.70';

// دالة للحصول على رمز العملة الصحيح
String getCurrencySymbol(String? currencyCode) {
  if (currencyCode == null || currencyCode.isEmpty) return '';
  final currency = Currency.fromCode(currencyCode);
  return currency?.symbol ?? '';
}
String getFullImageUrl(String? url, {String? cacheBuster}) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) {
    // Add cache buster to HTTP URLs too
    if (cacheBuster != null && !url.contains('?')) {
      return '$url?cb=$cacheBuster';
    }
    return url;
  }
  final baseUrl = 'http://$kBackendIp:3000$url';
  if (cacheBuster != null) {
    return '$baseUrl?cb=$cacheBuster';
  }
  return baseUrl;
}


// ----------------------------------------------------------------------
// MARK: - 0. Model: ProductS
// ----------------------------------------------------------------------
class ProductS {
  final String id;
  final String name;
  final String description;
  final String price;
  final String imageUrl;
  final bool approved;
  final String status;
  final String storeOwnerEmail;
  final String storeName;
  final String storePhone;
  final String customerID;
  final int? stock;
  final String? currency;

  ProductS({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.approved,
    required this.status,
    required this.storeOwnerEmail,
    required this.storeName,
    required this.storePhone,
    required this.customerID,
    this.stock,
    this.currency,
  });

  //  Factory من API Response
  factory ProductS.fromApi(Map<String, dynamic> data) {
    return ProductS(
      id: data['id'].toString(),
      name: data['name'] as String? ?? 'N/A',
      description: data['description'] as String? ?? 'No description',
      price: data['price']?.toString() ?? '0',
      imageUrl: data['image_url'] as String? ?? '',
      approved: data['status'] == 'approved',
      status: data['status'] as String? ?? 'pending',
      storeOwnerEmail: data['owner_email'] as String? ?? 'unknown@store.com',
      storeName: data['store_name'] as String? ?? 'Unknown Store',
      storePhone: data['store_phone']?.toString() ?? 'N/A', //  المفتاح الصحيح
      customerID: '',
      stock: data['stock'] as int?,
      currency: data['currency'] as String? ?? 'USD',
    );
  }

  //  دالة التحويل من Product إلى ProductS (الحل لمشكلة تعارض الأنواع)
  factory ProductS.fromProduct(Product p) {
    return ProductS(
      id: p.id,
      name: p.name,
      description: p.description,
      price: p.price.toStringAsFixed(2),
      imageUrl: p.imageUrl,
      approved: p.approved,
      status: p.status,
      storeOwnerEmail: p.storeOwnerEmail ?? 'N/A',
      storeName: p.storeName ?? 'N/A',
      storePhone: p.storePhone ?? 'N/A',
      customerID: FirebaseAuth.instance.currentUser?.uid ?? 'Unknown_Customer_ID',
      stock: p.stock,
      currency: p.currency,
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 1. ActionButton (مكافئ Swift ActionButton)
// ----------------------------------------------------------------------
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback action;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 2. StatusBadge (مكافئ Swift StatusBadge)
// ----------------------------------------------------------------------
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == "Approved";
    final badgeColor = isApproved ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 3. ProductCardView (مكافئ Swift ProductCardView)
// ----------------------------------------------------------------------
class ProductCardView extends StatelessWidget {
  final ProductS product;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onAssignCategory; //  زر نقل للفئة

  const ProductCardView({
    super.key,
    required this.product,
    required this.onDelete,
    required this.onTap,
    this.onEdit,
    this.onAssignCategory,
  });

  @override
  Widget build(BuildContext context) {
    //  استخدام Material و InkWell بشكل منفصل للتحكم الكامل في التأثيرات
    return Material(
      color: const Color(0xFF1E1E1E), // 🔘 نفس لون البطاقات
      borderRadius: BorderRadius.circular(15),
      elevation: 3, // إضافة ارتفاع خفيف للبطاقة
      shadowColor: Colors.black.withOpacity(0.05),
      
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(15),
        //  تحديد لون التظليل ليكون أسود خفيفا أو أزرق داكن لتمييز أنيق
        hoverColor: Colors.blue.withOpacity(0.1), 
        splashColor: Colors.blue.withOpacity(0.2), // عند الضغط

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: Theme.of(context).dividerColor.withOpacity(0.5), 
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: Colors.red.withOpacity(0.1),
                      child: const Icon(Icons.error_outline, color: Colors.red),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: StatusBadge(status: product.approved ? "Approved" : "Pending"),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${getCurrencySymbol(product.currency)}${product.price}",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (ApiService.cachedAdminRole?.toLowerCase() != 'user')
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: onDelete,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      
                      //  زر نقل المنتج للفئة
                      if (onAssignCategory != null && ApiService.cachedAdminRole?.toLowerCase() != 'user')
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.orange),
                          onPressed: onAssignCategory,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      
                      if (ApiService.cachedAdminRole?.toLowerCase() != 'user')
                        TextButton(
                          onPressed: onEdit,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          ),
                          child: const Text(
                            "Edit",
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 4. SectionHeader (مكافئ Swift SectionHeader)
// ----------------------------------------------------------------------
class SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const SectionHeader({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            "$count items",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 5. EmptyStateView (مكافئ Swift EmptyStateView)
// ----------------------------------------------------------------------
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_rounded,
            size: 48,
            color: Colors.blue.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            "No Products Found",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            "Start by adding your first product",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 6. HeaderSection (المكون الأكبر لأعلى الصفحة)
// ----------------------------------------------------------------------
class HeaderSection extends StatelessWidget {
  final String storeName;
  final String storeIconUrl;
  final String storeOwnerUid;

  const HeaderSection({super.key, required this.storeName, required this.storeIconUrl, required this.storeOwnerUid});

  @override
  Widget build(BuildContext context) {
    final hasIcon = storeIconUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          hasIcon
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: getFullImageUrl(storeIconUrl, cacheBuster: storeOwnerUid),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => _DefaultIcon(),
                  ),
                )
              : _DefaultIcon(),
          const SizedBox(height: 16),
          Text(
            storeName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _DefaultIcon() {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.storefront_sharp, size: 80, color: Colors.blue),
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 7. QuickActionGrid (شبكة الإجراءات السريعة)
// ----------------------------------------------------------------------
class QuickActionGrid extends StatelessWidget {
  final VoidCallback onAddProduct;
  final VoidCallback onOrders;
  final VoidCallback onMessages;
  final VoidCallback onAnalytics; 
  final VoidCallback onNotifications; 

  const QuickActionGrid({
    super.key,
    required this.onAddProduct,
    required this.onOrders,
    required this.onMessages,
    required this.onAnalytics, 
    required this.onNotifications, 
  });

  @override
  Widget build(BuildContext context) {
    //  استخدام LayoutBuilder لجعلها Responsive
    return LayoutBuilder(
      builder: (context, constraints) {
        // إذا كان العرض كبيرًا، استخدم 5 أعمدة، وإلا عمودين
        final crossAxisCount = constraints.maxWidth > 600 ? 5 : 2; 

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: GridView.count(
            crossAxisCount: crossAxisCount, //  استخدام عدد الأعمدة التكييفي
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.0, // جعل بطاقات الإجراءات مربعة
            children: [
              ActionButton(
                  icon: Icons.add_circle,
                  label: "Add Product",
                  color: Colors.green,
                  action: onAddProduct),
              ActionButton(
                  icon: Icons.shopping_cart,
                  label: "Orders",
                  color: Colors.orange,
                  action: onOrders),
              ActionButton(
                  icon: Icons.bar_chart,
                  label: "Analytics",
                  color: Colors.purple,
                  action: onAnalytics), //  تم ربطها
              ActionButton(
                  icon: Icons.notifications,
                  label: "Notifications",
                  color: Colors.red,
                  action: onNotifications), //  تم ربطها
              ActionButton(
                  icon: Icons.message,
                  label: "Messages",
                  color: Colors.blue,
                  action: onMessages),
            ],
          ),
        );
      }
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 8. ProductsSection (قسم عرض المنتجات)
// ----------------------------------------------------------------------
class ProductsSection extends StatelessWidget {
  final List<ProductS> products;
  final Function(String) onDelete;
  final int crossAxisCount;
  final Function(ProductS) onProductTap;
  final Function(ProductS)? onEdit;
  final Function(ProductS)? onAssignCategory; //  Callback للفئات
  final String searchQuery; // للتحقق من وجود نتائج بحث
  final int totalProductsCount; // إجمالي المنتجات

  const ProductsSection({
    super.key,
    required this.products,
    required this.onDelete,
    required this.onProductTap,
    this.onEdit,
    this.onAssignCategory,
    this.crossAxisCount = 2,
    this.searchQuery = '',
    this.totalProductsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: "Your Products", count: products.length),
          const SizedBox(height: 20),
          if (products.isEmpty && totalProductsCount == 0)
            const EmptyStateView()
          else if (products.isEmpty && searchQuery.isNotEmpty)
            // لا توجد نتائج بحث
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No products match your search',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (products.isEmpty)
            // المنتجات في فئات، لا توجد بدون فئات
            SizedBox.shrink()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount, 
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.75, // حجم بطاقة مناسب
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCardView(
                  product: product,
                  onDelete: () => onDelete(product.id),
                  onTap: () => onProductTap(product),
                  onEdit: onEdit != null ? () => onEdit!(product) : null,
                  onAssignCategory: onAssignCategory != null ? () => onAssignCategory!(product) : null,
                );
              },
            ),
        ],
      ),
    );
  }
}


// ----------------------------------------------------------------------
// MARK: - 9. BottomActionButtons (زر تسجيل الخروج)
// ----------------------------------------------------------------------
class BottomActionButtons extends StatelessWidget {
  final VoidCallback onLogout;

  const BottomActionButtons({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text("Logout", style: TextStyle(color: Colors.red, fontSize: 16)),
        style: TextButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.1),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// MARK: - 10. LoadingOverlay
// ----------------------------------------------------------------------
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.2),
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
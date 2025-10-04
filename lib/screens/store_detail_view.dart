// lib/screens/store_detail_view.dart (الكود النهائي المصحح)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../state_management/cart_manager.dart'; 
import '../models/store.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
// ⚠️ تم حذف استيراد custom_form_widgets.dart لأنه غير مستخدم
// import '../widgets/custom_form_widgets.dart'; // للألوان
import '../widgets/side_cart_view_contents.dart'; 

// !!! الاستيراد الحقيقي لشاشة تفاصيل المنتج !!!
import 'product_detail_view.dart'; 

// ----------------------------------------------------------------------
// MARK: - StoreDetailView
// ----------------------------------------------------------------------


class StoreDetailView extends StatefulWidget {
  final Store store;
  const StoreDetailView({Key? key, required this.store}) : super(key: key);

  @override
  State<StoreDetailView> createState() => _StoreDetailViewState();
}

class _StoreDetailViewState extends State<StoreDetailView> {
  // MARK: - State Variables
  List<Product> _products = [];
  bool _isLoading = false;
  String _errorMessage = "";
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ⚠️ تم حذف تعريفات الألوان الثابتة هنا:
  // final Color primaryText = Colors.black;
  // final Color secondaryText = Colors.grey;
  // final Color accentBlue = Colors.blue;

  // MARK: - Lifecycle
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  // MARK: - Data Loading (loadProducts)
  void _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("products")
          .where("storeName", isEqualTo: widget.store.storeName)
          .where("approved", isEqualTo: true)
          .where("status", isEqualTo: "Approved")
          .get();

      setState(() {
        _products = snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading products: ${error.toString()}";
      });
    }
  }

  // MARK: - View Components

  // مكافئ لـ StoreHeaderSection()
  Widget _buildStoreHeaderSection(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
      child: Column(
        children: [
          // Store Icon (AsyncImage)
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 💡 استخدام لون يتغير مع الثيم (مثلاً: لون البطاقة مع تقليل الشفافية)
              color: Theme.of(context).cardColor.withOpacity(0.8),
              boxShadow: [
                BoxShadow(color: primaryColor.withOpacity(0.1), blurRadius: 8),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.store.storeIconUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator(
                  strokeWidth: 2, 
                  color: secondaryColor.withOpacity(0.6), // 💡 استخدام لون ثانوي
                )),
                errorWidget: (context, url, error) => Center(
                  child: Icon(Icons.storefront, size: 60, color: secondaryColor.withOpacity(0.6)), // 💡 استخدام لون ثانوي
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Store Info
          Text(
            widget.store.storeName,
            style: TextStyle( // ⚠️ إزالة const
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: primaryColor, // 💡 استخدام primaryColor
            ),
          ),
          const SizedBox(height: 12),
          
          // Address
          if (widget.store.address != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 18, color: secondaryColor), // 💡 استخدام secondaryColor
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.store.address!,
                      style: TextStyle(fontSize: 15, color: secondaryColor), // 💡 استخدام secondaryColor
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          
          // Phone
          if (widget.store.storePhoneNumber != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 18, color: secondaryColor), // 💡 استخدام secondaryColor
                const SizedBox(width: 8),
                Text(
                  widget.store.storePhoneNumber!,
                  style: TextStyle(fontSize: 15, color: secondaryColor), // 💡 استخدام secondaryColor
                ),
              ],
            ),
        ],
      ),
    );
  }

  // مكافئ لـ ProductsGridSection()
  Widget _buildProductsGridSection() {
    if (_products.isEmpty && !_isLoading) {
      return _buildEmptyStateView(context); // 💡 تمرير context
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250, 
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 0.7, 
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return ProductCard(
            product: product,
            onTap: () {
              _showProductDetailSheet(product);
            },
          );
        },
      ),
    );
  }

  // مكافئ لـ EmptyStateView()
  Widget _buildEmptyStateView(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: secondaryColor.withOpacity(0.5), // 💡 استخدام secondaryColor
            ),
            const SizedBox(height: 20),
            Text(
              "No Products Available",
              style: TextStyle( // ⚠️ إزالة const
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor, // 💡 استخدام primaryColor
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "This store hasn't added any products yet.",
              style: TextStyle( // ⚠️ إزالة const
                fontSize: 14,
                color: secondaryColor, // 💡 استخدام secondaryColor
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // مكافئ لـ ErrorMessageView
  Widget _buildErrorMessageView(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color cardColor = Theme.of(context).cardColor;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor, // 💡 استخدام لون البطاقة
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade300)
          ),
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      ),
    );
  }

  // لعرض تفاصيل المنتج في أسفل الشاشة (BottomSheet)
  void _showProductDetailSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          // 💡 استخدام لون الخلفية الديناميكي
          color: Theme.of(context).scaffoldBackgroundColor, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ProductDetailView(product: product), 
      ),
    );
  }

  // ويدجت مساعدة لتطبيق العرض الأقصى على المحتوى
  Widget _buildWebContainer({required Widget child}) {
    if (MediaQuery.of(context).size.width > 600) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1000, 
          ),
          child: child,
        ),
      );
    }
    return child;
  }
  
  // مكافئ لـ LoadingIndicator()
  Widget _buildLoadingIndicator(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color accentColor = Theme.of(context).colorScheme.secondary;
    final Color cardColor = Theme.of(context).cardColor;
    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          // 💡 استخدام لون البطاقة بشفافية
          color: cardColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: CircularProgressIndicator(
          color: accentColor, // 💡 استخدام accentColor
          strokeWidth: 3,
        ),
      ),
    );
  }

  // MARK: - Main Build Method
 @override
Widget build(BuildContext context) {
  // 💡 جلب الألوان الأساسية هنا
  final Color primaryColor = Theme.of(context).colorScheme.primary;
  final Color scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
  
  return Scaffold(
    key: _scaffoldKey,
    // 💡 استخدام لون الخلفية الديناميكي
    backgroundColor: scaffoldColor,
    // نستخدم AppBar عادي هنا مع زر السلة في الـ actions
    appBar: AppBar(
      title: Text(widget.store.storeName, style: TextStyle(color: primaryColor)),
      // 💡 استخدام لون الخلفية الديناميكي
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      // 💡 استخدام primaryColor للأيقونات والتكست
      foregroundColor: primaryColor,
      
      // ⭐️⭐️ هذا هو التصحيح: وضع Consumer داخل مصفوفة actions ⭐️⭐️
      actions: [
                  // ⚠️ سنقلل Padding الخارجي جداً، ونتحمل الاقتطاع الطفيف للحفاظ على الموقع الأصلي
                  Padding(
                    padding: const EdgeInsets.only(right: 5.0), // هامش بسيط لمنع القص الحاد
                    child: Consumer<CartManager>(
                      builder: (context, cartManager, child) {
                        final totalItems = cartManager.totalItems;
                        final primaryIconColor = Theme.of(context).colorScheme.onSurface;
                        
                        // ⭐️ نستخدم InkWell لتغليف الـ Stack بالكامل وجعل المنطقة قابلة للضغط ⭐️
                        return InkWell(
                          onTap: () => Scaffold.of(context).openEndDrawer(), 
                          borderRadius: BorderRadius.circular(100), 
                          
                          child: Stack( 
                            alignment: Alignment.center, 
                            children: [
                              // 1. أيقونة سلة المشتريات (Icon)
                              // نستخدم Icon بدلاً من IconButton لأن الـ onTap في InkWell الخارجي
                              Icon(Icons.shopping_cart, color: primaryIconColor, size: 28),
                              
                              // 2. الـ Badge (الموقع والتصميم الذي تفضله)
                              if (totalItems > 0)
                                Positioned(
                                  right: 5, // الموقع الأصلي الذي طلبته
                                  top: 0,   // الموقع الأصلي الذي طلبته
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade700, 
                                      shape: BoxShape.circle, // الشكل الدائري الكلاسيكي
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Center(
                                      child: Text(
                                        totalItems > 99 ? '99+' : totalItems.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ], // ⭐️⭐️ يجب أن تكون مصفوفة الـ actions مغلقة هنا ⭐️⭐️
    ),
    endDrawer: const Drawer(child: SideCartViewContents()),
    
    body: Stack(
      children: [
        SingleChildScrollView(
          // 💡 محاكاة لـ systemGroupedBackground باستخدام لون الخلفية الأساسي
          child: Container(
            color: scaffoldColor, 
            child: _buildWebContainer(
              child: Column(
                children: [
                  _buildStoreHeaderSection(context), // 💡 تمرير context
                  _buildProductsGridSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
        
        // عرض حالة الخطأ أو التحميل
        if (_errorMessage.isNotEmpty) _buildErrorMessageView(context), // 💡 تمرير context
        if (_isLoading) _buildLoadingIndicator(context), // 💡 تمرير context
      ],
    ),
  );
}
}

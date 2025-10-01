// lib/screens/store_detail_view.dart (الكود النهائي المصحح)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/store.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/custom_form_widgets.dart'; // للألوان
import '../widgets/side_cart_view_contents.dart'; // لزر السلة

// !!! الاستيراد الحقيقي لشاشة تفاصيل المنتج !!!
import 'product_detail_view.dart'; 

// ----------------------------------------------------------------------
// MARK: - تم إزالة Placeholder for ProductDetailView (Sheet)
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
  
  // لفتح الـ Drawers (القوائم الجانبية)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // لافتراض وجود المتغيرات
  final Color primaryText = Colors.black;
  final Color secondaryText = Colors.grey;
  final Color accentBlue = Colors.blue;

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
  Widget _buildStoreHeaderSection() {
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
              color: Colors.grey.shade300,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.store.storeIconUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (context, url, error) => const Center(child: Icon(Icons.storefront, size: 60, color: Colors.grey)),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Store Info
          Text(
            widget.store.storeName,
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: primaryText,
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
                  Icon(Icons.location_on, size: 18, color: secondaryText),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.store.address!,
                      style: TextStyle(fontSize: 15, color: secondaryText),
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
                Icon(Icons.phone, size: 18, color: secondaryText),
                const SizedBox(width: 8),
                Text(
                  widget.store.storePhoneNumber!,
                  style: TextStyle(fontSize: 15, color: secondaryText),
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
      return _buildEmptyStateView();
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
              // محاكاة لـ .sheet(item: $selectedProduct)
              _showProductDetailSheet(product);
            },
          );
        },
      ),
    );
  }

  // مكافئ لـ EmptyStateView()
  Widget _buildEmptyStateView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: secondaryText.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "No Products Available",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "This store hasn't added any products yet.",
              style: TextStyle(
                fontSize: 14,
                color: secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // مكافئ لـ ErrorMessageView
  Widget _buildErrorMessageView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
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
      // نستخدم Container لتحديد ارتفاع الشاشة (إذا لم تحدد، يأخذ ارتفاع الشاشة)
      // ونستخدم isScrollControlled: true لجعلها ملء الشاشة تقريباً
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.95, // تجعلها 95% من ارتفاع الشاشة
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ProductDetailView(product: product), // استخدام الكلاس الحقيقي
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
  Widget get _loadingIndicator {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: CircularProgressIndicator(
          color: accentBlue,
          strokeWidth: 3,
        ),
      ),
    );
  }

  // MARK: - Main Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      // نستخدم AppBar عادي هنا مع زر السلة في الـ actions
      appBar: AppBar(
        title: Text(widget.store.storeName),
        actions: [
          // زر سلة المشتريات (Side Cart)
          IconButton(
            icon: Icon(Icons.shopping_cart, color: primaryText),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      // تم إزالة const لتجنب خطأ "Not a constant expression"
      endDrawer: Drawer(child: SideCartViewContents()),
      
      body: Stack(
        children: [
          SingleChildScrollView(
            // اللون الرمادي الفاتح (systemGroupedBackground) يتم محاكاته بمسافة حول المحتوى
            child: Container(
              color: Colors.grey.shade50, // محاكاة لـ systemGroupedBackground
              child: _buildWebContainer(
                child: Column(
                  children: [
                    _buildStoreHeaderSection(),
                    _buildProductsGridSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
          
          // عرض حالة الخطأ أو التحميل
          if (_errorMessage.isNotEmpty) _buildErrorMessageView(),
          if (_isLoading) _loadingIndicator,
        ],
      ),
    );
  }
}
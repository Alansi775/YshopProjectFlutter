// lib/screens/store_admin_view.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// استيراد جميع الشاشات الجديدة
import '../screens/sign_in_view.dart'; 
import '../screens/add_product_view.dart';
import '../screens/orders_view.dart'; // 💡 تم استيرادها
import '../screens/chat_list_view.dart';
import '../screens/store_settings_view.dart';
import '../screens/product_details_view.dart';
// Widgets and ProductS
import '../widgets/store_admin_widgets.dart'; 

class StoreAdminView extends StatefulWidget {
  final String initialStoreName;
  
  const StoreAdminView({super.key, required this.initialStoreName});

  @override
  State<StoreAdminView> createState() => _StoreAdminViewState();
}

class _StoreAdminViewState extends State<StoreAdminView> {
  // MARK: - State Variables
  String _storeName = "";
  String _storeIconUrl = "";
  List<ProductS> _products = []; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _storeName = widget.initialStoreName;
    _fetchStoreNameAndProducts();
  }

  // MARK: - Data Methods (كود جلب وحذف البيانات كما هو)

  Future<void> _fetchStoreNameAndProducts() async {
    // ... (كود جلب بيانات المتجر)
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection("storeRequests").doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _storeName = data['storeName'] as String? ?? "Unknown Store";
          _storeIconUrl = data['storeIconUrl'] as String? ?? "";
        });
        await _fetchProducts();
      }
    } catch (e) {
      print("Error fetching store data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProducts() async {
    // ... (كود جلب المنتجات)
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance.collection("products")
          .where("storeOwnerEmail", isEqualTo: email)
          .where("approved", isEqualTo: true)
          .get();

      setState(() {
        _products = snapshot.docs
            .map((doc) => ProductS.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      });
    } catch (e) {
      print("Error fetching products: $e");
    }
  }

  Future<void> _deleteProduct(String productId) async {
    // ... (كود حذف المنتج)
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection("products").doc(productId).delete();
      await _fetchProducts();
    } catch (e) {
      print("Error deleting product: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SignInView()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // MARK: - Navigation Methods (التصحيح هنا)

  void _onAddProduct() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const AddProductView(),
    ));
  }

  // ⭐️⭐️ التصحيح: جلب البريد الإلكتروني وتمريره إلى OrdersView ⭐️⭐️
  void _onOrders() {
    final storeEmail = FirebaseAuth.instance.currentUser?.email;

    if (storeEmail != null) {
      Navigator.of(context).push(MaterialPageRoute(
        // 💡 تمرير المعامل المطلوب
        builder: (context) => OrdersView(storeEmail: storeEmail),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Store owner email not found."))
      );
    }
  }

  void _onMessages() {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ChatListView(storeOwnerID: email),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: User email not found."))
      );
    }
  }

  void _onSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const StoreSettingsView(),
    ));
  }
  
  void _onProductTap(ProductS product) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProductDetailsView(product: product),
    ));
  }

  // MARK: - Build Method
  @override
  Widget build(BuildContext context) {
    const double _maxWidth = 1100.0; 
    
    final screenWidth = MediaQuery.of(context).size.width;
    int productCrossAxisCount;

    if (screenWidth > 1000) {
      productCrossAxisCount = 4;
    } else if (screenWidth > 600) {
      productCrossAxisCount = 3;
    } else {
      productCrossAxisCount = 2;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Store Dashboard"),
        centerTitle: true,
        actions: [
          //  ربط زر الإعدادات بالدالة الجديدة
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _onSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(color: Theme.of(context).colorScheme.surfaceVariant),
          
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: RefreshIndicator(
                onRefresh: _fetchStoreNameAndProducts,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      HeaderSection(storeName: _storeName, storeIconUrl: _storeIconUrl),
                      QuickActionGrid(
                        //  ربط الإجراءات بأحدث الدوال
                        onAddProduct: _onAddProduct,
                        onOrders: _onOrders, // 💡 تم تحديث دالة _onOrders
                        onMessages: _onMessages,
                        // الإجراءات الأخرى في QuickActionGrid لم يتم تحديد توجيه لها في Swift، سنتركها مؤقتًا كما هي
                        onAnalytics: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analytics View"))); },
                        onNotifications: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications View"))); },
                      ),
                      ProductsSection(
                        products: _products, 
                        onDelete: _deleteProduct,
                        onProductTap: _onProductTap, //  تمرير دالة النقر على المنتج
                        crossAxisCount: productCrossAxisCount,
                      ),
                      BottomActionButtons(onLogout: _logout),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          if (_isLoading) const LoadingOverlay(), 
        ],
      ),
    );
  }
}
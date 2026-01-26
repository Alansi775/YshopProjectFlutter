// lib/screens/stores/store_admin_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
// استيراد جميع الشاشات الجديدة
import '../auth/sign_in_view.dart';
import './add_product_view.dart';
import './edit_product_view.dart';
import './orders_view.dart'; //  تم استيرادها
import './chat_list_view.dart';
import 'store_settings_view.dart';
import './product_details_view.dart';
import 'category_sheet_view.dart';
import 'category_products_view.dart';
import 'category_selector_sheet.dart';
// Widgets and ProductS

import '../../widgets/store_admin_widgets.dart'; 
import '../../models/store.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import '../../state_management/auth_manager.dart';

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
  String _storeType = ""; //  متغير نوع المتجر
  String _storeOwnerUid = "";  //  Track the actual store owner UID
  int _storeId = 0; //  Store ID for categories
  List<ProductS> _products = []; 
  List<ProductS> _filteredProducts = [];
  List<Category> _categories = []; //  الفئات
  int _totalProductsCount = 0; //  إجمالي المنتجات (مع وبدون categories)
  bool _isLoading = false;
  String _searchQuery = ""; //  متغير البحث
  Timer? _pollingTimer; //  تحديث تلقائي

  @override
  void initState() {
    super.initState();
    //  COMPLETE RESET - clear everything
    _storeName = "";
    _storeIconUrl = "";
    _storeType = "";
    _storeOwnerUid = "";
    _storeId = 0;
    _products = [];
    _filteredProducts = [];
    _categories = [];
    _totalProductsCount = 0;
    _searchQuery = "";
    
    // Clear any cached requests AND the entire cache
    ApiService.clearCache();
    
    // Fetch FRESH data immediately
    _fetchStoreNameAndProducts();
    
    //  Start polling: تحديث البيانات كل 5 ثانية
    _startPolling();
  }
  
  @override
  void dispose() {
    //  إيقاف الـ polling عند الخروج
    _pollingTimer?.cancel();
    super.dispose();
  }
  
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _storeOwnerUid.isNotEmpty) {
        _fetchProductsQuietly();
      }
    });
  }
  
  ///  دالة البحث والتصفية
  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          return product.name.toLowerCase().contains(_searchQuery) ||
              product.description.toLowerCase().contains(_searchQuery) ||
              product.price.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }
  
  /// جلب المنتجات بدون إظهار Loading (للـ polling)
  Future<void> _fetchProductsQuietly() async {
    try {
      final response = await ApiService.getStoreProducts(_storeOwnerUid, bypassCache: true);
      
      if (response is List && mounted) {
        // حفظ الإجمالي الكلي
        _totalProductsCount = response.length;
        
        // تصفية المنتجات التي ليس لها فئة فقط (category_id == null أو 0)
        final productsWithoutCategory = response.where((item) {
          final categoryId = item['category_id'];
          return categoryId == null || categoryId == 0 || categoryId == '';
        }).toList();
        
        // Compare with current products to detect changes
        final newProductData = productsWithoutCategory
            .map((p) => '${p['id']}_${p['name']}_${p['price']}_${p['currency']}')
            .toList();
        final oldProductData = _products
            .map((p) => '${p.id}_${p.name}_${p.price}_${p.currency}')
            .toList();
        
        final hasChanges = newProductData.join('|') != oldProductData.join('|');
        
        // فقط طبع وحدّث عند حدوث تغييرات
        if (hasChanges) {
          debugPrint(' CHANGE DETECTED: Old=${oldProductData.length}, New=${newProductData.length}');
        }
        
        // تحديث الـ state بدون إظهار مؤشر التحميل
        setState(() {
          _products = productsWithoutCategory.map((item) {
            return ProductS(
              id: item['id'].toString(),
              storeName: _storeName,
              name: item['name'] ?? '',
              price: item['price'].toString(),
              description: item['description'] ?? '',
              imageUrl: Store.getFullImageUrl(item['image_url']),
              approved: item['status'] == 'approved',
              status: item['status'] ?? 'pending',
              storeOwnerEmail: item['owner_email'] ?? '',
              storePhone: '',
              customerID: _storeOwnerUid,
              stock: item['stock'],
              currency: item['currency'] ?? 'USD',
            );
          }).toList();
          
          // تحديث الـ filtered list
          if (_searchQuery.isEmpty) {
            _filteredProducts = _products;
          } else {
            _filteredProducts = _products.where((product) {
              return product.name.toLowerCase().contains(_searchQuery) ||
                  product.description.toLowerCase().contains(_searchQuery) ||
                  product.price.toLowerCase().contains(_searchQuery);
            }).toList();
          }
        });
      }
    } catch (e, stack) {
      debugPrint('❌ Polling error: $e\n$stack');
    }
  }

  // MARK: - Data Methods (كود جلب وحذف البيانات كما هو)

  Future<void> _fetchStoreNameAndProducts() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      // First, try to get UID from AuthManager (already logged in)
      final authManager = Provider.of<AuthManager>(context, listen: false);
      final uidFromAuth = authManager.userProfile?['uid'] as String? ?? '';
      final userProfile = authManager.userProfile;
      
      debugPrint(' Loading store for UID: $uidFromAuth');
      
      // Try to fetch store data from API
      dynamic storeData;
      try {
        storeData = await ApiService.getUserStore(uid: uidFromAuth);
      } catch (e) {
        debugPrint('⚠️ API getUserStore failed: $e');
        storeData = null;
      }
      
      if (storeData != null && storeData is Map && storeData.isNotEmpty) {
        // Store data from API - cast to Map<String, dynamic>
        final storeDataMap = Map<String, dynamic>.from(storeData);
        final store = Store.fromJson(storeDataMap);
        final ownerUid = (store.uid ?? storeDataMap['uid']?.toString() ?? storeDataMap['owner_uid']?.toString() ?? uidFromAuth).trim();
        final storeId = storeDataMap['id'] as int? ?? 0;
        final storeType = storeDataMap['store_type'] as String? ?? '';
        
        setState(() {
          _storeName = store.storeName.isNotEmpty ? store.storeName : widget.initialStoreName;
          _storeIconUrl = store.storeIconUrl;
          _storeOwnerUid = ownerUid;
          _storeId = storeId;
          _storeType = storeType;
        });
        
        debugPrint(' ✅ Store loaded from API: ${store.storeName} | UID: $ownerUid');
        
        // Fetch products and categories
        if (ownerUid.isNotEmpty) {
          await _fetchProducts(ownerUid);
        }
        if (storeId > 0) {
          await _fetchCategories(storeId);
        }
      } else {
        // Fallback: Use data from AuthManager (userProfile)
        debugPrint('⚠️ No store data from API, using AuthManager fallback');
        
        final storeName = userProfile?['name'] as String? ?? widget.initialStoreName;
        final storeIcon = userProfile?['store_icon'] as String? ?? '';
        
        setState(() {
          _storeName = storeName.isNotEmpty ? storeName : widget.initialStoreName;
          _storeIconUrl = storeIcon;
          _storeOwnerUid = uidFromAuth;
          _storeType = userProfile?['store_type'] as String? ?? '';
          _storeId = 0;
          _products = [];
          _categories = [];
        });
        
        debugPrint(' Using fallback store name: $_storeName | UID: $uidFromAuth');
        
        // Try to fetch products anyway
        if (uidFromAuth.isNotEmpty) {
          await _fetchProducts(uidFromAuth);
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Critical error in _fetchStoreNameAndProducts: $e\n$stackTrace");
      
      // Ultimate fallback - use initial store name
      setState(() {
        _storeName = widget.initialStoreName;
        _storeIconUrl = "";
        _storeOwnerUid = "";
        _storeType = "";
        _storeId = 0;
        _products = [];
        _categories = [];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchProducts([String? ownerUidParam]) async {
    //  Use parameter first, then state (to handle both refresh and initial load)
    final uidToFetch = ownerUidParam ?? _storeOwnerUid;
    
    if (uidToFetch.isEmpty) {
      debugPrint('❌ No store owner UID');
      return;
    }

    debugPrint(' Fetching products for Store Owner UID: $uidToFetch');

    try {
      // Fetch products from MySQL API using the store owner UID
      final response = await ApiService.getStoreProducts(uidToFetch, bypassCache: true);
      debugPrint(' API Response: $response');
      
      if (response is List) {
        // حفظ الإجمالي الكلي
        _totalProductsCount = response.length;
        debugPrint(' Total products: $_totalProductsCount');
        
        // تصفية المنتجات التي ليس لها فئة فقط (category_id == null أو 0)
        final productsWithoutCategory = response.where((item) {
          final categoryId = item['category_id'];
          return categoryId == null || categoryId == 0 || categoryId == '';
        }).toList();
        
        debugPrint(' Got ${productsWithoutCategory.length} products without category');
        setState(() {
          _products = productsWithoutCategory.map((item) {
            debugPrint('Processing product: ${item['name']} - Status: ${item['status']}');
            return ProductS(
              id: item['id'].toString(),
              storeName: _storeName,
              name: item['name'] ?? '',
              price: item['price'].toString(),
              description: item['description'] ?? '',
              imageUrl: Store.getFullImageUrl(item['image_url']),
              approved: item['status'] == 'approved',
              status: item['status'] ?? 'pending',
              storeOwnerEmail: item['owner_email'] ?? '',
              storePhone: '',
              customerID: uidToFetch,
              stock: item['stock'],
              currency: item['currency'] ?? 'USD',
            );
          }).toList();
          
          // تحديث الـ filtered list
          if (_searchQuery.isEmpty) {
            _filteredProducts = _products;
          } else {
            _filteredProducts = _products.where((product) {
              return product.name.toLowerCase().contains(_searchQuery) ||
                  product.description.toLowerCase().contains(_searchQuery) ||
                  product.price.toLowerCase().contains(_searchQuery);
            }).toList();
          }
        });
      } else {
        debugPrint('⚠️ Response is not a list: $response');
      }
    } catch (e) {
      debugPrint("❌ Error fetching products: $e");
    }
  }

  /// جلب الفئات للمتجر
  Future<void> _fetchCategories(int storeId) async {
    try {
      // حمل الفئات من قاعدة البيانات فقط
      final response = await ApiService.getStoreCategories(storeId, bypassCache: true);
      if (mounted) {
        setState(() {
          _categories = response.map((item) => Category.fromJson(item)).toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching categories: $e');
    }
  }

  List<Category> _getRestaurantCategories() {
    return [
      Category(id: 100, name: 'Burgers', displayName: 'Burgers', storeId: _storeId),
      Category(id: 101, name: 'Pizzas', displayName: 'Pizzas', storeId: _storeId),
      Category(id: 102, name: 'Sandwiches', displayName: 'Sandwiches', storeId: _storeId),
      Category(id: 103, name: 'Pasta', displayName: 'Pasta', storeId: _storeId),
      Category(id: 104, name: 'Rice Dishes', displayName: 'Rice Dishes', storeId: _storeId),
      Category(id: 105, name: 'Fries', displayName: 'Fries', storeId: _storeId),
      Category(id: 106, name: 'Chicken', displayName: 'Chicken', storeId: _storeId),
      Category(id: 107, name: 'Meat', displayName: 'Meat', storeId: _storeId),
      Category(id: 108, name: 'Seafood', displayName: 'Seafood', storeId: _storeId),
      Category(id: 109, name: 'Salads', displayName: 'Salads', storeId: _storeId),
      Category(id: 110, name: 'Soups', displayName: 'Soups', storeId: _storeId),
      Category(id: 111, name: 'Appetizers', displayName: 'Appetizers', storeId: _storeId),
      Category(id: 112, name: 'Sides', displayName: 'Sides', storeId: _storeId),
      Category(id: 113, name: 'Sauces', displayName: 'Sauces', storeId: _storeId),
      Category(id: 114, name: 'Desserts', displayName: 'Desserts', storeId: _storeId),
      Category(id: 115, name: 'Drinks', displayName: 'Drinks', storeId: _storeId),
      Category(id: 116, name: 'Juices', displayName: 'Juices', storeId: _storeId),
      Category(id: 117, name: 'Coffee', displayName: 'Coffee', storeId: _storeId),
      Category(id: 118, name: 'Smoothies', displayName: 'Smoothies', storeId: _storeId),
      Category(id: 119, name: 'Milkshakes', displayName: 'Milkshakes', storeId: _storeId),
    ];
  }

  List<Category> _getPharmacyCategories() {
    return [
      Category(id: 200, name: 'Medicines', displayName: 'Medicines', storeId: _storeId),
      Category(id: 201, name: 'Supplements', displayName: 'Supplements', storeId: _storeId),
      Category(id: 202, name: 'First Aid', displayName: 'First Aid', storeId: _storeId),
      Category(id: 203, name: 'Medical Devices', displayName: 'Medical Devices', storeId: _storeId),
      Category(id: 204, name: 'Personal Care', displayName: 'Personal Care', storeId: _storeId),
      Category(id: 205, name: 'Vitamins', displayName: 'Vitamins', storeId: _storeId),
    ];
  }

  List<Category> _getClothingCategories() {
    return [
      Category(id: 300, name: 'Men', displayName: 'Men', storeId: _storeId),
      Category(id: 301, name: 'Women', displayName: 'Women', storeId: _storeId),
      Category(id: 302, name: 'Kids', displayName: 'Kids', storeId: _storeId),
      Category(id: 303, name: 'Accessories', displayName: 'Accessories', storeId: _storeId),
      Category(id: 304, name: 'Shoes', displayName: 'Shoes', storeId: _storeId),
      Category(id: 305, name: 'Sports', displayName: 'Sports', storeId: _storeId),
    ];
  }

  /// عرض شاشة اختيار الفئة
  void _showCreateCategorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      isScrollControlled: true,
      builder: (context) => CategorySheetView(
        storeId: _storeId,
        existingCategories: _categories,
        storeType: _storeType,
      ),
    ).then((result) {
      if (result is Category && mounted) {
        setState(() {
          _categories.add(result);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category created: ${result.displayName}')),
        );
      }
    });
  }

  /// عرض منتجات الفئة
  void _showCategoryProducts(Category category) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => CategoryProductsView(
        category: category,
        storeId: _storeId,
        storeName: _storeName,
        storeOwnerEmail: _storeOwnerUid,
        storePhone: '',
        onCategoryDeleted: () {
          // إعادة تحميل الفئات والمنتجات بعد حذف الفئة
          _fetchCategories(_storeId);
          _fetchProducts();
        },
        onProductRemoved: (productId) {
          // إضافة المنتج مرة أخرى عند إزالته من الفئة
          _fetchProducts();
        },
      ),
    ));
  }

  /// نقل المنتج للفئة
  void _assignProductToCategory(ProductS product) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CategorySelectorSheet(
        categories: _categories,
        onCategorySelected: (category) async {
          Navigator.pop(context);
          
          final success = await ApiService.assignProductToCategory(
            int.parse(product.id),
            category.id!,
          );
          
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${product.name} added to ${category.displayName}',
                ),
              ),
            );
            // إزالة المنتج من قائمة "Products without category"
            setState(() {
              _products.removeWhere((p) => p.id == product.id);
              _filteredProducts.removeWhere((p) => p.id == product.id);
            });
          }
        },
      ),
    );
  }
          

  Future<void> _deleteProduct(String productId) async {
    setState(() => _isLoading = true);
    try {
      await ApiService.deleteProduct(productId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
      await _fetchProducts();
    } catch (e) {
      print("Error deleting product: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _logout() async {
    //  Clear admin role when logging out
    ApiService.setAdminRole(null);
    ApiService.setAdminProfile(null);
    
    final authManager = Provider.of<AuthManager>(context, listen: false);
    await authManager.signOut();
    
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
    )).then((_) {
      // تحديث البيانات عند الرجوع من AddProductView
      _fetchStoreNameAndProducts();
    });
  }

  //  التصحيح: جلب البريد الإلكتروني وتمريره إلى OrdersView 
  void _onOrders() {
    final authManager = Provider.of<AuthManager>(context, listen: false);
    final storeEmail = authManager.userProfile?['email'] as String?;

    if (storeEmail != null) {
      Navigator.of(context).push(MaterialPageRoute(
        //  تمرير المعامل المطلوب
        builder: (context) => OrdersView(storeEmail: storeEmail),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Store owner email not found."))
      );
    }
  }

  void _onMessages() {
    final authManager = Provider.of<AuthManager>(context, listen: false);
    final email = authManager.userProfile?['email'] as String?;
    
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

  void _onEditProduct(ProductS product) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => EditProductView(product: product),
    )).then((result) {
      // تحديث البيانات عند الرجوع من EditProductView
      if (result == true) {
        // Product was updated, refresh with cache bypass
        _fetchStoreNameAndProducts();
      }
    });
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          //  ربط زر الإعدادات بالدالة الجديدة
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _onSettings,
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F).withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF0F0F0F)), //  أسود أغمق
          
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: RefreshIndicator(
                onRefresh: _fetchStoreNameAndProducts,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      HeaderSection(
                        storeName: _storeName,
                        storeIconUrl: _storeIconUrl,
                        storeOwnerUid: Provider.of<AuthManager>(context, listen: false).userProfile?['uid'] as String? ?? '',
                      ),
                      
                      QuickActionGrid(
                        //  ربط الإجراءات بأحدث الدوال
                        onAddProduct: _onAddProduct,
                        onOrders: _onOrders, //  تم تحديث دالة _onOrders
                        onMessages: _onMessages,
                        // الإجراءات الأخرى في QuickActionGrid لم يتم تحديد توجيه لها في Swift، سنتركها مؤقتًا كما هي
                        onAnalytics: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analytics View"))); },
                        onNotifications: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications View"))); },
                      ),
                      
                      //  عرض زر إضافة الفئات لجميع الأنواع ما عدا الـ market
                      if (_storeType.isNotEmpty && _storeType.toLowerCase() != 'market') ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showCreateCategorySheet,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Category'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2979FF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // عرض الفئات في Grid
                        if (_categories.isNotEmpty) ...[
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: CategoryCard(
                                    category: category,
                                    onTap: () => _showCategoryProducts(category),
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          Center(
                            child: Text(
                              'No categories yet. Create one to organize your products!',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                      
                      //  حقل البحث
                      const SizedBox(height: 20),
                      SearchBar(
                        query: _searchQuery,
                        onChanged: _filterProducts,
                      ),
                      const SizedBox(height: 20),
                      
                      // عنوان للمنتجات بدون فئات
                      if (_storeType.toLowerCase() == 'market' && _categories.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Products without category',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // عرض المنتجات أو رسالة "لا توجد منتجات"
                      if (_totalProductsCount == 0)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 80,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No Products Yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start by adding your first product',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ProductsSection(
                          products: _filteredProducts,
                          onDelete: _deleteProduct,
                          onProductTap: _onProductTap,
                          onEdit: _onEditProduct,
                          onAssignCategory: _assignProductToCategory,
                          crossAxisCount: productCrossAxisCount,
                          searchQuery: _searchQuery,
                          totalProductsCount: _totalProductsCount,
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

//  Widget البحث
class SearchBar extends StatelessWidget {
  final String query;
  final Function(String) onChanged;

  const SearchBar({
    Key? key,
    required this.query,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // 🔘 نفس لون البطاقات
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search products (name, description, price...)',
          hintStyle: TextStyle(
            color: Colors.grey[500],
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[400],
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[400],
                  ),
                  onPressed: () => onChanged(''),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
    );
  }
}

//  Category Card Widget - with last product image and delete button on hover/long press
class CategoryCard extends StatefulWidget {
  final Category category;
  final VoidCallback onTap;

  const CategoryCard({
    Key? key,
    required this.category,
    required this.onTap,
  }) : super(key: key);

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  String? _lastProductImage;
  bool _isLoading = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _loadLastProductImage();
  }

  Future<void> _loadLastProductImage() async {
    try {
      if (widget.category.id != null) {
        final products = await ApiService.getCategoryProducts(widget.category.id!);
        if (products.isNotEmpty && mounted) {
          final lastProduct = products.last;
          final imageUrl = lastProduct['image_url'] as String? ?? '';
          setState(() {
            _lastProductImage = imageUrl.isNotEmpty
                ? Store.getFullImageUrl(imageUrl)
                : null;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading category image: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCategory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Category?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All products in this category will be returned to "Products without category"',
              style: TextStyle(color: Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red[400],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success =
            await ApiService.deleteCategory(widget.category.storeId ?? 0, widget.category.id!);
        if (success && mounted) {
          // Refresh the store admin view
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.category.displayName} deleted')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting category: $e');
      }
    }
  }

  void _showDeleteMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Category',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteCategory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emoji = widget.category.displayName.split(' ').last;
    final categoryName = widget.category.displayName.replaceAll(RegExp(r' [^\s]*$'), '');
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: isDesktop ? null : _showDeleteMenu,
      child: MouseRegion(
        onEnter: (_) => isDesktop ? setState(() => _isHovering = true) : null,
        onExit: (_) => isDesktop ? setState(() => _isHovering = false) : null,
        child: Container(
          width: 160,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              // Image or Emoji with delete button on hover
              SizedBox(
                height: 140,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[800],
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _lastProductImage != null
                                ? Image.network(
                                    _lastProductImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                      ),
                    ),
                    // Delete button on hover (desktop only)
                    if (isDesktop && _isHovering)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Tooltip(
                          message: 'Delete category',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white, size: 16),
                              onPressed: _deleteCategory,
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Category name
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  categoryName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

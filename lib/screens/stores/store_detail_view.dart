// lib/screens/stores/store_detail_view.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:async';
import '../../state_management/cart_manager.dart';
import '../../models/store.dart';
import '../../models/product.dart';
import '../../models/currency.dart';
import '../../models/category.dart';
import '../../widgets/side_cart_view_contents.dart';
import '../../services/api_service.dart';
import '../customers/product_detail_view.dart';
import '../auth/sign_in_ui.dart';

String getCurrencySymbol(String? currencyCode) {
  if (currencyCode == null || currencyCode.isEmpty) return '';
  final currency = Currency.fromCode(currencyCode);
  return currency?.symbol ?? '';
}

class StoreDetailView extends StatefulWidget {
  final Store store;
  const StoreDetailView({Key? key, required this.store}) : super(key: key);

  @override
  State<StoreDetailView> createState() => _StoreDetailViewState();
}

class _StoreDetailViewState extends State<StoreDetailView> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  int? _selectedCategoryId; // null means "All"
  String _searchQuery = "";
  bool _categoriesLoaded = false;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (_categoriesLoaded) return; // لا تحمل مرتين
    
    try {
      final storeId = int.tryParse(widget.store.id) ?? 0;
      List<Category> loadedCategories = [];
      
      // إذا كان المتجر مطعم، حمل الفئات الافتراضية للمطاعم
      if (widget.store.storeType?.toLowerCase() == 'restaurant') {
        loadedCategories = _getRestaurantCategories();
      } else {
        // خلاف ذلك، حمل الفئات من قاعدة البيانات مع تأخير لتجنب rate limiting
        await Future.delayed(const Duration(milliseconds: 300));
        final categoriesData = await ApiService.getStoreCategories(storeId);
        loadedCategories = categoriesData.map((data) => Category.fromJson(data)).toList();
      }
      
      // ترتيب الفئات أبجديا حسب displayName
      loadedCategories.sort((a, b) => a.displayName.compareTo(b.displayName));
      
      if (mounted) {
        setState(() {
          _categories = loadedCategories;
          _categoriesLoaded = true;
        });
      }
    } catch (error) {
      debugPrint('Error loading categories: $error');
      // تحميل الفئات الافتراضية في حالة الخطأ
      if (widget.store.storeType?.toLowerCase() == 'restaurant' && mounted) {
        setState(() {
          _categories = _getRestaurantCategories();
          _categoriesLoaded = true;
        });
      }
    }
  }

  List<Category> _getRestaurantCategories() {
    // فئات افتراضية للمطاعم - مرتبة أبجديا
    return [
      Category(id: 100, name: 'Burgers', displayName: 'Burgers 🍔', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 105, name: 'Chicken', displayName: 'Chicken 🍗', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 108, name: 'Desserts', displayName: 'Desserts 🍰', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 103, name: 'Drinks', displayName: 'Drinks 🥤', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 102, name: 'Fries', displayName: 'Fries 🍟', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 104, name: 'Juices', displayName: 'Juices 🧃', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 106, name: 'Meat', displayName: 'Meat 🥩', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 101, name: 'Pizzas', displayName: 'Pizzas 🍕', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 107, name: 'Salads', displayName: 'Salads 🥗', storeId: int.tryParse(widget.store.id) ?? 0),
    ];
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final productsData = await ApiService.getStoreProductsById(widget.store.id);
      if (mounted) {
        setState(() {
          _products = productsData.map((data) => Product.fromJson(data)).toList();
          _filteredProducts = _products;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProducts(String query) {
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      List<Product> filtered = _products;

      // فلتر حسب الفئة
      if (_selectedCategoryId != null) {
        filtered = filtered.where((p) {
          final productCategoryId = int.tryParse(p.categoryId ?? '') ?? 0;
          return productCategoryId == _selectedCategoryId;
        }).toList();
      }

      // فلتر حسب البحث
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((product) {
          return product.name.toLowerCase().contains(query) ||
                 product.description.toLowerCase().contains(query) ||
                 product.price.toString().contains(query);
        }).toList();
      }

      _filteredProducts = filtered;
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.toLowerCase();
      });
      _applyFilters();
    });
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _applyFilters();
  }

  // --- الإبداع هنا: بطاقة المنتج بنظام "الفلويد" (Fluid Design) ---
  Widget _buildCreativeProductCard(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailView(product: product))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // زوايا ناعمة
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Theme-aware image & overlay
              Hero(
                tag: 'product_${product.id}',
                child: Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final imageBg = isDark ? Colors.black : Colors.grey[200]!.withOpacity(0.35);
                  final overlayTop = Colors.transparent;
                  final overlayMiddle = isDark ? Colors.black.withOpacity(0.02) : Colors.white.withOpacity(0.02);
                  final overlayBottom = isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.6);

                  return Container(
                    color: imageBg,
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                            child: CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(color: Colors.transparent),
                              errorWidget: (context, url, error) => Container(color: Colors.transparent),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [overlayTop, overlayMiddle, overlayBottom],
                                stops: const [0.5, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),

              // 3. المحتوى المعلوماتي (انسيابي) - نصوص تعتمد على الـ theme
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final titleColor = isDark ? Colors.white : Colors.black87;
                  final priceColor = isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${getCurrencySymbol(product.currency)} ${product.price}",
                        style: TextStyle(
                          color: priceColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  );
                }),
              ),

              // 4. زر الإضافة (أيقونة سوداء دائماً)
              Positioned(
                top: 15,
                right: 15,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
                        onPressed: () => Provider.of<CartManager>(context, listen: false).addToCart(product: product, quantity: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? LuxuryTheme.kDarkBackground : LuxuryTheme.kLightBackground,
      endDrawer: const Drawer(child: SideCartViewContents()),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // رأس الصفحة المتفاعل
          SliverAppBar(
            expandedHeight: 280.0,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? LuxuryTheme.kDarkBackground : LuxuryTheme.kLightBackground,
            foregroundColor: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // صورة المتجر في الخلفية
                  if (widget.store.storeIconUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.store.storeIconUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Theme.of(context).primaryColor.withOpacity(0.6)),
                      errorWidget: (context, url, error) => Container(color: Theme.of(context).primaryColor.withOpacity(0.6)),
                    )
                  else
                    Container(color: Theme.of(context).primaryColor),
                  
                  // طبقة Glassmorphism
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.6),
                    ),
                  ),
                  
                  // محتوى الهيدر
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // أيقونة المتجر
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                            boxShadow: [
                               BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                            ],
                          ),
                          child: widget.store.storeIconUrl.isEmpty
                              ? const Icon(Icons.store, size: 50)
                              : ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: widget.store.storeIconUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                                    errorWidget: (context, url, error) => Container(
                                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                                      child: const Icon(Icons.store, size: 50),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          widget.store.storeName,
                          style: const TextStyle(
                            fontFamily: 'TenorSans',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.store.address != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on, size: 14, color: Theme.of(context).primaryColor),
                                const SizedBox(width: 4),
                                Text(widget.store.address!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Consumer<CartManager>(
                builder: (context, cart, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.shopping_bag_outlined, color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                      ),
                      if (cart.totalItems > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '${cart.totalItems}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),

          // شريط البحث
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(
                    fontFamily: 'TenorSans',
                    color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.4) : LuxuryTheme.kDeepNavy.withOpacity(0.4),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.6) : LuxuryTheme.kDeepNavy.withOpacity(0.6),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _onSearchChanged('');
                          },
                          child: Icon(
                            Icons.clear,
                            color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.6) : LuxuryTheme.kDeepNavy.withOpacity(0.6),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.2) : LuxuryTheme.kDeepNavy.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.2) : LuxuryTheme.kDeepNavy.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? LuxuryTheme.kDarkSurface.withOpacity(0.5)
                      : LuxuryTheme.kLightSurface.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                style: TextStyle(
                  fontFamily: 'TenorSans',
                  color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                ),
              ),
            ),
          ),

          // فلتر التصنيفات من قاعدة البيانات
          SliverToBoxAdapter(
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    bool isSelected = _selectedCategoryId == null;
                    return GestureDetector(
                      onTap: () => _onCategorySelected(null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark
                                    ? LuxuryTheme.kPlatinum.withOpacity(0.2)
                                    : LuxuryTheme.kDeepNavy.withOpacity(0.2)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'All',
                            style: TextStyle(
                              fontFamily: 'TenorSans',
                              color: isSelected
                                  ? (isDark ? LuxuryTheme.kDeepNavy : LuxuryTheme.kPlatinum)
                                  : (isDark
                                      ? LuxuryTheme.kPlatinum.withOpacity(0.6)
                                      : LuxuryTheme.kDeepNavy.withOpacity(0.6)),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    final category = _categories[index - 1];
                    final categoryName = category.displayName.replaceAll(RegExp(r'\s*[^\w\s]+\s*$'), '').trim();
                    bool isSelected = _selectedCategoryId == category.id;

                    return GestureDetector(
                      onTap: () => _onCategorySelected(category.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark
                                    ? LuxuryTheme.kPlatinum.withOpacity(0.2)
                                    : LuxuryTheme.kDeepNavy.withOpacity(0.2)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              fontFamily: 'TenorSans',
                              color: isSelected
                                  ? (isDark ? LuxuryTheme.kDeepNavy : LuxuryTheme.kPlatinum)
                                  : (isDark
                                      ? LuxuryTheme.kPlatinum.withOpacity(0.6)
                                      : LuxuryTheme.kDeepNavy.withOpacity(0.6)),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),

          // المحتوى - إما Grid عادي أو مجمع حسب Category
          _isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : _selectedCategoryId == null
                  ? _buildGroupedProductsView(isDark)  // عرض مجمع حسب Category
                  : _buildSingleCategoryView(isDark)    // عرض فئة واحدة
        ],
      ),
    );
  }

  // عرض المنتجات مجمعة حسب الفئات (عندما يكون All مختار)
  Widget _buildGroupedProductsView(bool isDark) {
    if (_filteredProducts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(30.0),
            child: Text(
              "No products found",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // تجميع المنتجات حسب categoryId
    final Map<int?, List<Product>> groupedByCategory = {};
    for (final product in _filteredProducts) {
      final categoryId = int.tryParse(product.categoryId ?? '') ?? 0;
      groupedByCategory.putIfAbsent(categoryId, () => []);
      groupedByCategory[categoryId]!.add(product);
    }

    // البحث عن اسم الفئة من _categories
    String getCategoryName(int? categoryId) {
      if (categoryId == null || categoryId == 0) return 'Uncategorized';
      final category = _categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => Category(id: categoryId, name: 'Unknown', displayName: 'Unknown', storeId: 0),
      );
      return category.displayName.replaceAll(RegExp(r'\s*[^\w\s]+\s*$'), '').trim();
    }

    // ترتيب الفئات أبجديا
    final sortedCategoryIds = groupedByCategory.keys.toList()
      ..sort((a, b) => getCategoryName(a).compareTo(getCategoryName(b)));

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          sortedCategoryIds.map((categoryId) {
            final categoryName = getCategoryName(categoryId);
            final productsInCategory = groupedByCategory[categoryId]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header - أنيق
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900]!.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF42A5F5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        color: Color(0xFF42A5F5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                // GridView للمنتجات في هذه الفئة - نفس طريقة single category
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12.0,
                    mainAxisSpacing: 12.0,
                    
                  ),
                  itemCount: productsInCategory.length,
                  itemBuilder: (context, index) {
                    return AspectRatio(
                      aspectRatio: index % 20 == 0 ? 1.9 : 1.8,
                      child: _buildCreativeProductCard(productsInCategory[index]),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // عرض منتجات فئة واحدة (عندما يكون فئة محددة)
  Widget _buildSingleCategoryView(bool isDark) {
    if (_filteredProducts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(30.0),
            child: Text(
              "No products in this category",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Use same GridView.builder layout as the grouped "All" view
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12.0,
              mainAxisSpacing: 12.0,
            ),
            itemCount: _filteredProducts.length,
            itemBuilder: (context, index) {
              return AspectRatio(
                aspectRatio: index % 20 == 0 ? 1.9 : 1.8,
                child: _buildCreativeProductCard(_filteredProducts[index]),
              );
            },
          ),
        ]),
      ),
    );
  }
}
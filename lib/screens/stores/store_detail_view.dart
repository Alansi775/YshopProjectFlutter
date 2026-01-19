// lib/screens/stores/store_detail_view.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../state_management/cart_manager.dart';
import '../../models/store.dart';
import '../../models/product.dart';
import '../../models/currency.dart';
import '../../models/category.dart';
import '../../widgets/side_cart_view_contents.dart';
import '../../services/api_service.dart';
import '../customers/product_detail_view.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  Future<void> _loadCategories() async {
    try {
      final storeId = int.tryParse(widget.store.id) ?? 0;
      
      // إذا كان المتجر مطعم، حمل الفئات الافتراضية للمطاعم
      if (widget.store.storeType?.toLowerCase() == 'restaurant') {
        setState(() {
          _categories = _getRestaurantCategories();
        });
      } else {
        // خلاف ذلك، حمل الفئات من قاعدة البيانات
        final categoriesData = await ApiService.getStoreCategories(storeId);
        if (mounted) {
          setState(() {
            _categories = categoriesData.map((data) => Category.fromJson(data)).toList();
          });
        }
      }
    } catch (error) {
      debugPrint('Error loading categories: $error');
    }
  }

  List<Category> _getRestaurantCategories() {
    // فئات افتراضية للمطاعم
    return [
      Category(id: 100, name: 'Burgers', displayName: 'Burgers 🍔', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 101, name: 'Pizzas', displayName: 'Pizzas 🍕', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 102, name: 'Fries', displayName: 'Fries 🍟', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 103, name: 'Drinks', displayName: 'Drinks 🥤', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 104, name: 'Juices', displayName: 'Juices 🧃', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 105, name: 'Chicken', displayName: 'Chicken 🍗', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 106, name: 'Meat', displayName: 'Meat 🥩', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 107, name: 'Salads', displayName: 'Salads 🥗', storeId: int.tryParse(widget.store.id) ?? 0),
      Category(id: 108, name: 'Desserts', displayName: 'Desserts 🍰', storeId: int.tryParse(widget.store.id) ?? 0),
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
    setState(() {
      _searchQuery = query.toLowerCase();
    });
    _applyFilters();
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
              // 1. عرض الصورة بنظام "Full Bleed"
              Hero(
                tag: 'product_${product.id}',
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  width: double.infinity,
                ),
              ),

              // 2. تدرج ذكي لإبراز النص (Gradient Overlay)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.02),
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.5, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. المحتوى المعلوماتي (انسيابي)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${getCurrencySymbol(product.currency)} ${product.price}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: isDark ? Colors.white : Colors.black,
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
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _onSearchChanged('');
                          },
                          child: Icon(Icons.clear, color: Colors.grey),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey.withOpacity(0.1) 
                      : Colors.grey.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                itemCount: _categories.length + 1, // +1 للزر "All"
                itemBuilder: (context, index) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  
                  if (index == 0) {
                    // زر "All"
                    bool isSelected = _selectedCategoryId == null;
                    return GestureDetector(
                      onTap: () => _onCategorySelected(null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(
                            'All',
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : Colors.grey,
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
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : Colors.grey,
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

          // الشبكة الحديثة (Masonry Layout)
          _isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      // حجم أصغر وأنيق
                      return AspectRatio(
                        aspectRatio: index % 20 == 0 ? 1.9 : 1.8, 
                        child: _buildCreativeProductCard(_filteredProducts[index]),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
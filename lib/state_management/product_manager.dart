import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Product Manager - Handles product data and caching
class ProductManager with ChangeNotifier {
  List<dynamic> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreProducts = true;

  // Filters
  String? _storeIdFilter;
  String? _categoryIdFilter;
  String? _searchQuery;

  // Getters
  List<dynamic> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMoreProducts => _hasMoreProducts;

  /// Fetch all products (with pagination)
  Future<void> fetchProducts({
    int page = 1,
    String? storeId,
    String? categoryId,
    String? search,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _storeIdFilter = storeId;
      _categoryIdFilter = categoryId;
      _searchQuery = search;
      _currentPage = page;

      final newProducts = await ApiService.getProducts(
        page: page,
        limit: _pageSize,
        storeId: storeId,
        categoryId: categoryId,
        search: search,
      );

      if (page == 1) {
        _products = newProducts;
      } else {
        _products.addAll(newProducts);
      }

      _hasMoreProducts = newProducts.length == _pageSize;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more products (pagination)
  Future<void> loadMoreProducts() async {
    if (_isLoading || !_hasMoreProducts) return;

    await fetchProducts(
      page: _currentPage + 1,
      storeId: _storeIdFilter,
      categoryId: _categoryIdFilter,
      search: _searchQuery,
    );
  }

  /// Get product details
  Future<dynamic> getProductDetails(String productId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final product = await ApiService.getProductById(productId);

      _isLoading = false;
      notifyListeners();
      return product;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Create new product
  Future<dynamic> createProduct({
    required String name,
    required String description,
    required double price,
    required String storeId,
    String? categoryId,
    required int stock,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final product = await ApiService.createProduct(
        name: name,
        description: description,
        price: price,
        storeId: storeId,
        categoryId: categoryId,
        stock: stock,
      );

      _products.insert(0, product);
      _isLoading = false;
      notifyListeners();
      return product;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update product
  Future<dynamic> updateProduct(
    String productId, {
    String? name,
    String? description,
    double? price,
    int? stock,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final product = await ApiService.updateProduct(
        productId,
        name: name,
        description: description,
        price: price,
        stock: stock,
      );

      // Update in local list
      final index = _products.indexWhere((p) => p['id'].toString() == productId);
      if (index != -1) {
        _products[index] = product;
      }

      _isLoading = false;
      notifyListeners();
      return product;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete product
  Future<bool> deleteProduct(String productId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await ApiService.deleteProduct(productId);

      if (success) {
        _products.removeWhere((p) => p['id'].toString() == productId);
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Search products
  Future<void> searchProducts(String query) async {
    await fetchProducts(search: query);
  }

  /// Filter by store
  Future<void> filterByStore(String storeId) async {
    await fetchProducts(storeId: storeId);
  }

  /// Filter by category
  Future<void> filterByCategory(String categoryId) async {
    await fetchProducts(categoryId: categoryId);
  }

  /// Clear filters
  Future<void> clearFilters() async {
    await fetchProducts();
  }
}

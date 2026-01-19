import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Order Manager - Handles order operations
class OrderManager with ChangeNotifier {
  List<dynamic> _userOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreOrders = true;

  // Getters
  List<dynamic> get userOrders => _userOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMoreOrders => _hasMoreOrders;

  /// Fetch user orders
  Future<void> fetchUserOrders({int page = 1}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _currentPage = page;

      final newOrders = await ApiService.getUserOrders(
        page: page,
        limit: _pageSize,
      );

      if (page == 1) {
        _userOrders = newOrders;
      } else {
        _userOrders.addAll(newOrders);
      }

      _hasMoreOrders = newOrders.length == _pageSize;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more orders
  Future<void> loadMoreOrders() async {
    if (_isLoading || !_hasMoreOrders) return;
    await fetchUserOrders(page: _currentPage + 1);
  }

  /// Get order details
  Future<dynamic> getOrderDetails(String orderId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final order = await ApiService.getOrderById(orderId);

      _isLoading = false;
      notifyListeners();
      return order;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Create new order
  Future<dynamic> createOrder({
    required String storeId,
    required double totalPrice,
    required String shippingAddress,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final order = await ApiService.createOrder(
        storeId: storeId,
        totalPrice: totalPrice,
        shippingAddress: shippingAddress,
        items: items,
      );

      _userOrders.insert(0, order);
      _isLoading = false;
      notifyListeners();
      return order;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await ApiService.updateOrderStatus(orderId, status);

      if (success) {
        // Update local order
        final index = _userOrders
            .indexWhere((o) => o['id'].toString() == orderId);
        if (index != -1) {
          _userOrders[index]['status'] = status;
        }
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

  /// Get order count
  int get orderCount => _userOrders.length;

  /// Get pending orders count
  int get pendingOrdersCount => _userOrders
      .where((o) => o['status'] == 'pending')
      .length;
}

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Store Manager - Handles store data
class StoreManager with ChangeNotifier {
  List<dynamic> _stores = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreStores = true;

  // Getters
  List<dynamic> get stores => _stores;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMoreStores => _hasMoreStores;

  /// Fetch all stores
  Future<void> fetchStores({int page = 1}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _currentPage = page;

      final newStores = await ApiService.getStores(
        page: page,
        limit: _pageSize,
      );

      if (page == 1) {
        _stores = newStores;
      } else {
        _stores.addAll(newStores);
      }

      _hasMoreStores = newStores.length == _pageSize;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more stores
  Future<void> loadMoreStores() async {
    if (_isLoading || !_hasMoreStores) return;
    await fetchStores(page: _currentPage + 1);
  }

  /// Get store details with products
  Future<dynamic> getStoreDetails(String storeId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final store = await ApiService.getStoreById(storeId);

      _isLoading = false;
      notifyListeners();
      return store;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Create new store
  Future<dynamic> createStore({
    required String name,
    String? description,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final currentUser = FirebaseAuth.instance.currentUser;
      final ownerUid = currentUser?.uid;
      if (ownerUid == null) {
        throw Exception('Unauthorized: cannot create store without authenticated user.');
      }

      final store = await ApiService.createStore(
        name: name,
        description: description,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
        ownerUid: ownerUid,
      );

      _stores.insert(0, store);
      _isLoading = false;
      notifyListeners();
      return store;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update store
  Future<dynamic> updateStore(
    String storeId, {
    String? name,
    String? description,
    String? phone,
    String? address,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final store = await ApiService.updateStore(
        storeId,
        name: name,
        description: description,
        phone: phone,
        address: address,
      );

      // Update in local list
      final index = _stores.indexWhere((s) => s['id'].toString() == storeId);
      if (index != -1) {
        _stores[index] = store;
      }

      _isLoading = false;
      notifyListeners();
      return store;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete store
  Future<bool> deleteStore(String storeId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await ApiService.deleteStore(storeId);

      if (success) {
        _stores.removeWhere((s) => s['id'].toString() == storeId);
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
}

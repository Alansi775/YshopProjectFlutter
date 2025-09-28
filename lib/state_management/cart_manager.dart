// lib/state_management/cart_manager.dart (تم تصحيحه)

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/cart_item_model.dart'; 

class CartManager with ChangeNotifier {
  List<CartItemModel> _items = [];
  final String _storageKey = 'savedCartItems';
  bool _initialized = false;
  
  CartManager() {
    _loadCart();
  }

  // Getters المفقودة:
  List<CartItemModel> get items => _items;
  
  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
  }
  
  int get totalItems {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }
  // -----------------------

  // MARK: - Persistence 

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_storageKey);

    if (cartData != null) {
      final List<dynamic> decodedData = json.decode(cartData);
      _items = decodedData
          .map((itemJson) => CartItemModel.fromJson(itemJson as Map<String, dynamic>))
          .toList();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveCart() async {
    if (!_initialized) return; 
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> itemsJson = 
        _items.map((item) => item.toJson()).toList();
    
    final String cartData = json.encode(itemsJson);
    prefs.setString(_storageKey, cartData);
  }

  // MARK: - Cart Operations 
  
  void addToCart({required Product product, required int quantity}) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != -1) {
      _items[existingIndex].quantity += quantity;
      
      // إذا أصبحت الكمية صفر أو أقل، نحذف العنصر
      if (_items[existingIndex].quantity <= 0) {
        _items.removeAt(existingIndex);
      }
    } else if (quantity > 0) {
      // إضافة عنصر جديد فقط إذا كانت الكمية موجبة
      _items.add(CartItemModel(product: product, quantity: quantity));
    }
    
    _saveCart(); 
    notifyListeners();
  }
  
  // تصحيح دالة الإزالة لتطابق الاستدعاء: removeFromCart(item.product)
  void removeFromCart(Product product) { 
    _items.removeWhere((item) => item.product.id == product.id);
    _saveCart(); 
    notifyListeners();
  }
  
  void clearCart() {
    _items.clear();
    _saveCart(); 
    notifyListeners();
  }
}
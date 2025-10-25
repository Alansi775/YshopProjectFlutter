import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

//  تأكد من وجود ملفات الـ Models هذه في مسارها الصحيح (models/)
import '../models/product.dart'; 
import '../models/cart_item_model.dart'; 

class CartManager with ChangeNotifier {
  //  الآن تم تعريف الأنواع بشكل صحيح
  List<CartItemModel> _items = []; 
  final String _storageKey = 'savedCartItems';
  bool _initialized = false;
  
  //  متغيرات تخزين حالة الطلب
  String? _lastOrderId; 
  static const String _orderIdKey = 'last_active_order_id';
  bool _orderIdLoaded = false;
  
  String? get lastOrderId => _lastOrderId;
  bool get orderIdLoaded => _orderIdLoaded;

  //  التعديل هنا: استدعاء دوال التحميل في الـ Constructor
  CartManager() {
    _loadCart();
    _loadLastOrderId(); // يبدأ بتحميل رقم الطلب فور إنشاء الكائن
  }

  //  دالة تحميل رقم الطلب من التخزين الدائم
  Future<void> _loadLastOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    _lastOrderId = prefs.getString(_orderIdKey);
    _orderIdLoaded = true;
    notifyListeners(); 
  }
  
  //  دالة تعيين وحفظ رقم الطلب في التخزين الدائم
  void setLastOrderId(String? id) async {
    _lastOrderId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_orderIdKey); // حذف عند وصول الطلب
    } else {
      await prefs.setString(_orderIdKey, id); // حفظ رقم الطلب
    }
    notifyListeners();
  }

  double get subtotalAmount {
    return totalAmount; 
  }
  
  // Getters:
  List<CartItemModel> get items => _items;
  
  double get totalAmount {
    //  الآن product و quantity معرفتان
    return _items.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
  }
  
  int get totalItems {
    //  الآن quantity معرفة
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
          //  CartItemModel الآن معرفة
          .map((itemJson) => CartItemModel.fromJson(itemJson as Map<String, dynamic>)) 
          .toList();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveCart() async {
    if (!_initialized) return; 
    final prefs = await SharedPreferences.getInstance();
    
    //  تم تصحيح نوع الإخراج
    final List<Map<String, dynamic>> itemsJson = 
        _items.map((item) => item.toJson()).toList();
    
    final String cartData = json.encode(itemsJson);
    prefs.setString(_storageKey, cartData);
  }

  // MARK: - Cart Operations 
  
  //  Product الآن معرفة
  void addToCart({required Product product, required int quantity}) { 
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != -1) {
      _items[existingIndex].quantity += quantity;
      
      if (_items[existingIndex].quantity <= 0) {
        _items.removeAt(existingIndex);
      }
    } else if (quantity > 0) {
      //  CartItemModel الآن معرفة
      _items.add(CartItemModel(product: product, quantity: quantity)); 
    }
    
    _saveCart(); 
    notifyListeners();
  }
  
  //  Product الآن معرفة
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
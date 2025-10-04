// lib/screens/product_detail_view.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart'; 
import 'package:firebase_auth/firebase_auth.dart';

// نماذج البيانات
import '../models/product.dart';

//  استيراد ProductS من ملف الـ widgets
import '../widgets/store_admin_widgets.dart'; 

// إدارة الحالة (سلة المشتريات)
import '../state_management/cart_manager.dart'; 

// شاشة الدردشة
import 'chat_view.dart'; 

class ProductDetailView extends StatefulWidget {
  final Product product;
  const ProductDetailView({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  // MARK: - State Variables
  int _quantity = 1;
  
  // ⚠️ تم حذف تعريفات الألوان الثابتة هنا
  // final Color primaryText = Colors.black;
  // final Color secondaryText = Colors.grey;
  // final Color greenColor = Colors.green.shade700;
  
  final String fontTenor = 'TenorSans'; // يبقى ثابتًا كاسم خط

  // MARK: - Helper Methods

  // 💡 تم تعديل الدالة لتقبل اللون الأساسي الديناميكي
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return TextStyle(
      fontFamily: fontTenor,
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor, // 💡 استخدام primaryColor افتراضياً
    );
  }

  // MARK: - View Components

  Widget _buildQuantitySelector(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color cardColor = Theme.of(context).cardColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary; 

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        // 💡 استخدام cardColor
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Text(
            "Quantity:",
            style: _getTenorSansStyle(context, 18), // 💡 تمرير context
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // زر Minus
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_quantity > 1) {
                      _quantity--;
                    }
                  });
                },
                child: const Icon(
                  Icons.remove_circle,
                  color: Colors.red,
                  size: 30,
                ),
              ),
              const SizedBox(width: 20),
              
              Text(
                "$_quantity",
                style: _getTenorSansStyle(context, 24), // 💡 تمرير context
              ),
              
              const SizedBox(width: 20),
              // زر Plus
              GestureDetector(
                onTap: () {
                  setState(() {
                    _quantity++;
                  });
                },
                child: Icon(
                  Icons.add_circle,
                  color: Colors.green.shade700, // اللون الأخضر ثابت للـ +
                  size: 30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // دالة بناء معلومات المتجر
  Widget _buildStoreInfo(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color cardColor = Theme.of(context).cardColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface; 
    
    final storePhone = widget.product.storePhone;
    final bool isPhoneAvailable = storePhone != null && storePhone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        // 💡 استخدام cardColor
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront, size: 20, color: secondaryColor), // 💡 استخدام secondaryColor
              const SizedBox(width: 10),
              Text(
                widget.product.storeName,
                style: _getTenorSansStyle(context, 16), // 💡 تمرير context
              ),
              const Spacer(),
            ],
          ),
          
          if (isPhoneAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.phone, size: 20, color: secondaryColor), // 💡 استخدام secondaryColor
                  const SizedBox(width: 10),
                  Text(
                    storePhone!, 
                    style: _getTenorSansStyle(context, 16), // 💡 تمرير context
                  ),
                  const Spacer(),
                ],
              ),
            ),
        ],
      ),
    );
  }


  void _showAddedToCartNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
            const SizedBox(width: 12),
            Text(
              "${widget.product.name} Added to Cart!",
              style: _getTenorSansStyle(context, 16).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        // يمكنك استخدام لون داكن للخلفية ليتناسب مع أي ثيم
        backgroundColor: Colors.black87, 
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating, // يجعلها عائمة وأنيقة
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
      ),
    );
  }
  
  Widget _buildStickyBottomBar(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context, listen: false);
    
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface; 
    final Color cardColor = Theme.of(context).cardColor;
    
    final double totalPrice = widget.product.price * _quantity;
    final String totalPriceString = "\$${totalPrice.toStringAsFixed(2)}";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 💡 استخدام secondaryColor للفاصل
        Divider(height: 1, color: secondaryColor.withOpacity(0.3)),
        Container(
          // 💡 استخدام cardColor
          color: cardColor,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Total Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Price",
                    // 💡 استخدام secondaryColor
                    style: _getTenorSansStyle(context, 14).copyWith(color: secondaryColor),
                  ),
                  Text(
                    totalPriceString,
                    style: _getTenorSansStyle(context, 20, weight: FontWeight.bold),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Add to Cart Button
              ElevatedButton(
                onPressed: () {
                  cartManager.addToCart(product: widget.product, quantity: _quantity);
                  _showAddedToCartNotification(context);
                  Navigator.of(context).pop(); 
                },
                style: ElevatedButton.styleFrom(
                  // 💡 استخدام primaryColor كخلفية للزر (سيكون داكناً في الثيم الفاتح)
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(180, 50),
                ),
                child: Row(
                  children: [
                    // 💡 استخدام لون يتناقض مع primaryColor (يجب أن يكون اللون المعكوس)
                    Icon(Icons.shopping_cart, color: Theme.of(context).colorScheme.onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      "Add to Cart",
                      style: _getTenorSansStyle(context, 16, weight: FontWeight.w600)
                              // 💡 استخدام لون يتناقض مع primaryColor
                              .copyWith(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 🚀 دالة الدردشة (تبقى كما هي)
  void _startChat() {
    final String? currentUserID = FirebaseAuth.instance.currentUser?.uid; 
    if (currentUserID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to start a chat.')),
      );
      return;
    }
    
    final ProductS chatProduct = ProductS.fromProduct(widget.product);
    
    final String customerOrUID = currentUserID;
    final String storeOwnerEmail = widget.product.storeOwnerEmail;
    
    final List<String> participants = [customerOrUID, storeOwnerEmail];
    participants.sort();

    final String chatID = '${participants[0]}_${participants[1]}_${widget.product.id}';


    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatView(
          chatID: chatID,
          product: chatProduct, 
          currentUserID: currentUserID, 
          isStoreOwner: false, 
        ),
      ),
    );
  }


  // MARK: - Main Build Method
  @override
  Widget build(BuildContext context) {
    // 💡 جلب الألوان الأساسية هنا
    final Color scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface; 
    final Color greenColor = Colors.green.shade700; // اللون الأخضر للمنتج يبقى ثابتًا

    return Scaffold(
      // 💡 استخدام scaffoldColor
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text("Product Details", style: TextStyle(color: primaryColor)),
        centerTitle: true,
        // 💡 استخدام لون خلفية AppBar الديناميكي
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        automaticallyImplyLeading: false, 
        
        // تعيين زر المراسلة في أقصى اليسار (Leading)
        leading: IconButton( 
            icon: Icon(Icons.message, color: primaryColor), // 💡 استخدام primaryColor
            onPressed: _startChat,
        ),
        
        // زر الإغلاق (X) في أقصى اليمين (Actions)
        actions: [
          // زر الإغلاق (xmark)
          IconButton(
            icon: Icon(Icons.close, color: primaryColor), // 💡 استخدام primaryColor
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Carousel
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: CachedNetworkImage(
                    imageUrl: widget.product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(child: CircularProgressIndicator(color: secondaryColor)), // 💡 استخدام secondaryColor
                    errorWidget: (context, url, error) => Center(child: Icon(Icons.image_not_supported, color: secondaryColor)), // 💡 استخدام secondaryColor
                  ),
                ),
                
                // Product Details
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      // Name and Price
                      Column(
                        children: [
                          Text(
                            widget.product.name,
                            style: _getTenorSansStyle(context, 24), // 💡 تمرير context
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "\$${widget.product.price.toStringAsFixed(2)}",
                            style: _getTenorSansStyle(context, 20, weight: FontWeight.bold).copyWith(color: greenColor),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      // Divider
                      Center(
                        child: Divider(
                          thickness: 1, 
                          indent: MediaQuery.of(context).size.width * 0.3,
                          endIndent: MediaQuery.of(context).size.width * 0.3,
                          color: secondaryColor.withOpacity(0.3), // 💡 استخدام secondaryColor
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          widget.product.description,
                          // 💡 استخدام secondaryColor
                          style: _getTenorSansStyle(context, 16).copyWith(color: secondaryColor), 
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Quantity Selector
                      _buildQuantitySelector(context), // 💡 تمرير context
                      
                      const SizedBox(height: 20),
                      
                      // Store Info
                      _buildStoreInfo(context), // 💡 تمرير context
                      
                      // مساحة إضافية لتجنب تداخل شريط السلة الثابت
                      const SizedBox(height: 100), 
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Sticky Bottom Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildStickyBottomBar(context),
          ),
        ],
      ),
    );
  }
}
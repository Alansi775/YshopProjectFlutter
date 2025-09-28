import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; // لاستخدام معلومات المستخدم في الدردشة

// نماذج البيانات
import '../models/product.dart';

// 🚀 استيراد ProductS من ملف الـ widgets
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
  
  // لافتراض وجود الألوان
  final Color primaryText = Colors.black;
  final Color secondaryText = Colors.grey;
  final Color greenColor = Colors.green.shade700;
  final String fontTenor = 'TenorSans'; 

  // MARK: - Helper Methods

  TextStyle _getTenorSansStyle(double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    return TextStyle(
      fontFamily: fontTenor,
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryText,
    );
  }

  // MARK: - View Components

  Widget _buildQuantitySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Text(
            "Quantity:",
            style: _getTenorSansStyle(18),
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
                child: Icon(
                  Icons.remove_circle,
                  color: Colors.red,
                  size: 30,
                ),
              ),
              const SizedBox(width: 20),
              
              Text(
                "$_quantity",
                style: _getTenorSansStyle(24),
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
                  color: greenColor,
                  size: 30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // دالة بناء معلومات المتجر (مصححة للتعامل مع String? storePhone)
  Widget _buildStoreInfo() {
    // نحصل على قيمة storePhone بأمان
    final storePhone = widget.product.storePhone;
    
    // نتحقق من أن قيمة الهاتف ليست null وليست فارغة
    final bool isPhoneAvailable = storePhone != null && storePhone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, size: 20, color: Colors.grey),
              const SizedBox(width: 10),
              Text(
                widget.product.storeName,
                style: _getTenorSansStyle(16),
              ),
              const Spacer(),
            ],
          ),
          
          // استخدام الشرط المصحح isPhoneAvailable
          if (isPhoneAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    // استخدام storePhone! لضمان أن القيمة String غير قابلة للـ null (الشرط if يضمن ذلك)
                    storePhone!, 
                    style: _getTenorSansStyle(16),
                  ),
                  const Spacer(),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStickyBottomBar(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context, listen: false);
    
    // ملاحظة: يُفترض أن widget.product.price هي double
    final double totalPrice = widget.product.price * _quantity;
    final String totalPriceString = "\$${totalPrice.toStringAsFixed(2)}";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: Colors.grey.shade300),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Total Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Price",
                    style: _getTenorSansStyle(14).copyWith(color: secondaryText),
                  ),
                  Text(
                    totalPriceString,
                    style: _getTenorSansStyle(20, weight: FontWeight.bold),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Add to Cart Button
              ElevatedButton(
                onPressed: () {
                  // استخدام CartManager
                  cartManager.addToCart(product: widget.product, quantity: _quantity);
                  Navigator.of(context).pop(); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(180, 50),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      "Add to Cart",
                      style: _getTenorSansStyle(16, weight: FontWeight.w600).copyWith(color: Colors.white),
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
  
  void _startChat() {
    // جلب المستخدم الحالي
    final String? currentUserID = FirebaseAuth.instance.currentUser?.uid; 
    if (currentUserID == null) {
      // يمكنك إضافة تنبيه يطالب المستخدم بتسجيل الدخول
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to start a chat.')),
      );
      return;
    }
    
    // 🚀 التحويل من Product إلى ProductS قبل التمرير
    final ProductS chatProduct = ProductS.fromProduct(widget.product);
    
    // محاكاة لـ ChatManager.shared.startChat
    final String chatID = 'CHAT_${widget.product.id}_$currentUserID';
    
    // فتح شاشة الدردشة
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatView(
          chatID: chatID,
          product: chatProduct, // 🚀 تم تمرير النوع الصحيح (ProductS)
          currentUserID: currentUserID,
          isStoreOwner: false, 
        ),
      ),
    );
  }


  // MARK: - Main Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Product Details"),
        centerTitle: true,
        // منع ظهور زر الرجوع التلقائي
        automaticallyImplyLeading: false, 
        
        // تعيين زر المراسلة في أقصى اليسار (Leading)
        leading: IconButton( 
            icon: Icon(Icons.message, color: primaryText),
            onPressed: _startChat,
        ),
        
        // زر الإغلاق (X) في أقصى اليمين (Actions)
        actions: [
          // زر الإغلاق (xmark)
          IconButton(
            icon: Icon(Icons.close, color: primaryText),
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
                    placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.image_not_supported)),
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
                            style: _getTenorSansStyle(24),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "\$${widget.product.price.toStringAsFixed(2)}",
                            style: _getTenorSansStyle(20, weight: FontWeight.bold).copyWith(color: greenColor),
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
                          color: Colors.grey.shade300,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          widget.product.description,
                          style: _getTenorSansStyle(16).copyWith(color: secondaryText),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Quantity Selector
                      _buildQuantitySelector(),
                      
                      const SizedBox(height: 20),
                      
                      // Store Info
                      _buildStoreInfo(),
                      
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
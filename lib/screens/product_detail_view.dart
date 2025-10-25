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
  final GlobalKey _cartIconKey = GlobalKey(); 
  
  final String fontTenor = 'TenorSans'; // يبقى ثابتًا كاسم خط

  // MARK: - Helper Methods

  //  تم تعديل الدالة لتقبل اللون الأساسي الديناميكي
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return TextStyle(
      fontFamily: fontTenor,
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor, //  استخدام primaryColor افتراضياً
    );
  }

  // MARK: - View Components

  Widget _buildQuantitySelector(BuildContext context) {
    //  جلب الألوان الديناميكية
    final Color cardColor = Theme.of(context).cardColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary; 

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        //  استخدام cardColor
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
            style: _getTenorSansStyle(context, 18), //  تمرير context
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
                style: _getTenorSansStyle(context, 24), //  تمرير context
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
    //  جلب الألوان الديناميكية
    final Color cardColor = Theme.of(context).cardColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface; 
    
    final storePhone = widget.product.storePhone;
    final bool isPhoneAvailable = storePhone != null && storePhone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        //  استخدام cardColor
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
              Icon(Icons.storefront, size: 20, color: secondaryColor), //  استخدام secondaryColor
              const SizedBox(width: 10),
              Text(
                widget.product.storeName,
                style: _getTenorSansStyle(context, 16), //  تمرير context
              ),
              const Spacer(),
            ],
          ),
          
          if (isPhoneAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.phone, size: 20, color: secondaryColor), //  استخدام secondaryColor
                  const SizedBox(width: 10),
                  Text(
                    storePhone!, 
                    style: _getTenorSansStyle(context, 16), //  تمرير context
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
  // 1. تحديد موقع الأيقونة على الشاشة
  final RenderBox? renderBox = _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) {
    // في حال فشل تحديد الموقع، نعود للإشعار التقليدي أو نلغي العملية
    // يمكنك هنا وضع الإشعار التقليدي باستخدام ScaffoldMessenger.of(context).showSnackBar
    return;
  }
  
  // 2. حساب الموضع الإحداثي لأيقونة السلة
  final Offset iconPosition = renderBox.localToGlobal(Offset.zero);
  final Size iconSize = renderBox.size;

  final String productName = widget.product.name;
  
  OverlayEntry? overlayEntry;

  // تعريف الـ OverlayEntry
  overlayEntry = OverlayEntry(
    builder: (context) => FocusTransitionOverlay( // 🚨 استخدام الـ Widget الجديد
      productName: productName,
      startPosition: iconPosition, // موقع البداية
      startSize: iconSize, // حجم البداية
      // موقع النهاية (منتصف الشاشة)
      endPosition: Offset(
        MediaQuery.of(context).size.width / 2, 
        MediaQuery.of(context).size.height / 2,
      ),
      // تمرير دالة لإزالة الـ Overlay
      onDismiss: () {
        overlayEntry?.remove();
        overlayEntry = null;
      },
      getTenorSansStyle: _getTenorSansStyle,
    ),
  );

  // إضافة الـ OverlayEntry إلى الـ Overlay
  Overlay.of(context).insert(overlayEntry!);
}
  
  Widget _buildStickyBottomBar(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context, listen: false);
    
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface; 
    final Color cardColor = Theme.of(context).cardColor;
    
    final double totalPrice = widget.product.price * _quantity;
    final String totalPriceString = "\$${totalPrice.toStringAsFixed(2)}";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        //  استخدام secondaryColor للفاصل
        Divider(height: 1, color: secondaryColor.withOpacity(0.3)),
        Container(
          //  استخدام cardColor
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
                    //  استخدام secondaryColor
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
                  //  استخدام primaryColor كخلفية للزر (سيكون داكناً في الثيم الفاتح)
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(180, 50),
                ),
                child: Row(
                  children: [
                    //  استخدام لون يتناقض مع primaryColor (يجب أن يكون اللون المعكوس)
                    Icon(Icons.shopping_cart, 
                      key: _cartIconKey, // 🚨 المفتاح الجديد
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Add to Cart",
                      style: _getTenorSansStyle(context, 16, weight: FontWeight.w600)
                              //  استخدام لون يتناقض مع primaryColor
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
    //  جلب الألوان الأساسية هنا
    final Color scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface; 
    final Color greenColor = Colors.green.shade700; // اللون الأخضر للمنتج يبقى ثابتًا

    return Scaffold(
      //  استخدام scaffoldColor
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text("Product Details", style: TextStyle(color: primaryColor)),
        centerTitle: true,
        //  استخدام لون خلفية AppBar الديناميكي
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        automaticallyImplyLeading: false, 
        
        // تعيين زر المراسلة في أقصى اليسار (Leading)
        leading: IconButton( 
            icon: Icon(Icons.message, color: primaryColor), //  استخدام primaryColor
            onPressed: _startChat,
        ),
        
        // زر الإغلاق (X) في أقصى اليمين (Actions)
        actions: [
          // زر الإغلاق (xmark)
          IconButton(
            icon: Icon(Icons.close, color: primaryColor), //  استخدام primaryColor
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
                    placeholder: (context, url) => Center(child: CircularProgressIndicator(color: secondaryColor)), //  استخدام secondaryColor
                    errorWidget: (context, url, error) => Center(child: Icon(Icons.image_not_supported, color: secondaryColor)), //  استخدام secondaryColor
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
                            style: _getTenorSansStyle(context, 24), //  تمرير context
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
                          color: secondaryColor.withOpacity(0.3), //  استخدام secondaryColor
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          widget.product.description,
                          //  استخدام secondaryColor
                          style: _getTenorSansStyle(context, 16).copyWith(color: secondaryColor), 
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Quantity Selector
                      _buildQuantitySelector(context), //  تمرير context
                      
                      const SizedBox(height: 20),
                      
                      // Store Info
                      _buildStoreInfo(context), //  تمرير context
                      
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



// Widget مخصص لعرض إشعار "تمت الإضافة إلى السلة"
//  Widget الإشعار المخصص مع الأنيميشن

class FocusTransitionOverlay extends StatefulWidget {
  final String productName;
  final Offset startPosition;
  final Size startSize;
  final Offset endPosition; // End position is center of screen
  final VoidCallback onDismiss;
  final TextStyle Function(BuildContext, double, {FontWeight weight, Color? color}) getTenorSansStyle;

  const FocusTransitionOverlay({
    Key? key,
    required this.productName,
    required this.startPosition,
    required this.startSize,
    required this.endPosition,
    required this.onDismiss,
    required this.getTenorSansStyle,
  }) : super(key: key);

  @override
  State<FocusTransitionOverlay> createState() => _FocusTransitionOverlayState();
}

class _FocusTransitionOverlayState extends State<FocusTransitionOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // 1. 🚨 المدة الكلية أصبحت 3 ثوانٍ (كافية للحركة + القراءة + الاختفاء)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), // 3 ثواني للعرض الكلي
    );

    final double finalNotificationWidth = 250; 
    final double finalNotificationHeight = 50; 
    
    final Offset startOffset = widget.startPosition + Offset(widget.startSize.width / 2, widget.startSize.height / 2);
    final Offset endOffset = widget.endPosition - Offset(finalNotificationWidth / 2, finalNotificationHeight / 2);
    
    // الحركة ستتم خلال أول 30% من المدة (3000ms * 0.3 = 900ms)
    const double entryEndInterval = 0.3; 
    
    // 1. أنيميشن الموقع (حركة سريعة في أول 900ms)
    _positionAnimation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, entryEndInterval, curve: Curves.easeOutCubic), 
    ));

    // 2. أنيميشن التحول (Scale)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.1), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 40),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, entryEndInterval, curve: Curves.decelerate)),
    );
    
    // 3. 🚨 أنيميشن ظهور النص (يظهر بسرعة في نهاية الحركة)
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, entryEndInterval, curve: Curves.easeIn)), // يكتمل ظهوره عند 900ms
    );
    
    // 4. 🚨 أنيميشن الـ Fade (يبدأ في آخر 20% من المدة)
    const double fadeStartInterval = 0.8; // يبدأ الاختفاء عند 3000ms * 0.8 = 2400ms (بعد 1.5 ثانية من الثبات)
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(fadeStartInterval, 1.0, curve: Curves.easeOut)),
    );

    // ابدأ الأنيميشن، وعندما ينتهي (بعد 3 ثوانٍ)، قم بالإزالة
    _controller.forward().then((_) {
      widget.onDismiss();
    });

    // 🛑 تم حذف الـ Future.delayed السابق، لأن الـ controller هو من يتحكم بالمدة الآن
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color elegantGreen = Color(0xFF8BC34A); 
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value, 
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.black87, 
                  borderRadius: BorderRadius.circular(30.0), 
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _controller.value < 0.3 ? Icons.shopping_cart : Icons.check_circle_rounded, // التحول عند انتهاء الحركة
                      color: elegantGreen, 
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    // النص يظهر تدريجياً
                    Opacity(
                      opacity: _textOpacityAnimation.value,
                      // 🚨 استخدام الـ RichText لفصل الألوان والخطوط
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          // 💡 اللون المستخدم لـ "Added" هو الأبيض (اللون الافتراضي)
                          style: widget.getTenorSansStyle(context, 16).copyWith(
                            color: Colors.white, 
                            fontWeight: FontWeight.w400, // أرق قليلاً لتقليل التكتل
                            decoration: TextDecoration.none, 
                          ),
                          children: [
                            // 1. اسم المنتج (بلون أخضر هادئ وأكثر جرأة)
                            TextSpan(
                              text: widget.productName,
                              style: widget.getTenorSansStyle(context, 16).copyWith(
                                color: Color(0xFF8BC34A), // Elegant Green
                                fontWeight: FontWeight.w700, // غامق ليبرز
                                decoration: TextDecoration.none,
                              ),
                            ),
                            // 2. كلمة الإضافة (بلون أبيض تقليدي)
                            TextSpan(
                              text: " Added to Cart", 
                              style: widget.getTenorSansStyle(context, 16).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w400, // رقيق لتمييز الاسم عنه
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
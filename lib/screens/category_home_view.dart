// lib/screens/category_home_view.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/category_widgets.dart'; // افترض وجود هذا الملف لـ CategoriesGridView و BrandShowcaseView
import '../widgets/custom_form_widgets.dart'; // للوصول إلى primaryText (افترض وجوده)
import '../widgets/side_menu_view_contents.dart'; 
//  الإضافة المطلوبة: استيراد ملف سلة المشتريات الجانبية الجاهز
import '../widgets/side_cart_view_contents.dart'; 
import '../widgets/order_tracker_widget.dart'; //  استيراد ودجت تتبع الطلب
import 'package:provider/provider.dart'; 
import '../state_management/cart_manager.dart'; 

class CategoryHomeView extends StatefulWidget {
  const CategoryHomeView({Key? key}) : super(key: key); 

  @override
  State<CategoryHomeView> createState() => _CategoryHomeViewState();
}

class _CategoryHomeViewState extends State<CategoryHomeView> {
  // MARK: - State Variables
  final List<String> heroImages = ["Hero.png", "0.png", "1.png", "2.png", "3.png", "4.png", "5.png", "6.png", "7.png"];
  final List<String> categories = ["Food", "Pharmacy", "Clothes", "Market", "Restaurants"];
  
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  // MARK: - Lifecycle
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (Timer timer) {
      if (_pageController.hasClients) {
        _currentPage = (_pageController.page?.round() ?? 0);
        int nextPage = (_currentPage + 1) % heroImages.length;
        
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // MARK: - Widgets

  Widget _buildHeroImageCarousel(BuildContext context) {
    // !!! التعديل هنا: زيادة الارتفاع لجعله أكبر وأكثر تأثيراً !!!
    return SizedBox(
      height: MediaQuery.of(context).size.width > 600 
          ? 600 // ارتفاع أكبر للويب (مثلاً 600 بكسل)
          : MediaQuery.of(context).size.height * 0.7, // 70% من ارتفاع الشاشة للهاتف
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: heroImages.length,
            itemBuilder: (context, index) {
              return Image.asset(
                'assets/images/${heroImages[index]}',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              );
            },
          ),
          
          // التدرج الأسود (يبقى ممتدًا)
          Container(
            // يجب أن يكون ارتفاع الحاوية متطابقاً مع ارتفاع SizedBox
            height: MediaQuery.of(context).size.width > 600 ? 600 : MediaQuery.of(context).size.height * 0.7, 
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.4)],
              ),
            ),
          ),

          // النص الترحيبي 
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 40, right: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Welcome to YShop",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Curated Excellence, Delivered",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت مساعدة لتطبيق العرض الأقصى على المحتوى
  Widget _buildWebContainer({required Widget child}) {
    if (MediaQuery.of(context).size.width > 600) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1000, // عرض أقصى مناسب للويب
          ),
          child: child,
        ),
      );
    }
    return child;
  }


  // MARK: - Main Build Method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Drawer(child: SideMenuViewContents()),
      endDrawer: Drawer(child: SideCartViewContents()), 
      
      //  التعديل الرئيسي: استخدام Stack لوضع OrderTrackerWidget فوق CustomScrollView
      body: Stack(
        children: [
          CustomScrollView(
            slivers: <Widget>[
              // Header Overlay (SliverAppBar)
              SliverAppBar(
                pinned: true,
                expandedHeight: MediaQuery.of(context).size.width > 600
                    ? 600 
                    : MediaQuery.of(context).size.height * 0.7,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor, // استخدام لون الخلفية
                // زر القائمة الجانبية (Side Menu)
                leading: Builder(
                  builder: (context) => IconButton(
                    // افترضنا أن onSurface هو اللون الأساسي للنص والأيقونات
                    icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onSurface), 
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                // زر سلة المشتريات (Side Cart)
                actions: [
                  //  سنقلل Padding الخارجي جداً، ونتحمل الاقتطاع الطفيف للحفاظ على الموقع الأصلي
                  Padding(
                    padding: const EdgeInsets.only(right: 5.0), // هامش بسيط لمنع القص الحاد
                    child: Consumer<CartManager>(
                      builder: (context, cartManager, child) {
                        final totalItems = cartManager.totalItems;
                        final primaryIconColor = Theme.of(context).colorScheme.onSurface;
                        
                        //  نستخدم InkWell لتغليف الـ Stack بالكامل وجعل المنطقة قابلة للضغط 
                        return InkWell(
                          onTap: () => Scaffold.of(context).openEndDrawer(), 
                          borderRadius: BorderRadius.circular(100), 
                          
                          child: Stack( 
                            alignment: Alignment.center, 
                            children: [
                              // 1. أيقونة سلة المشتريات (Icon)
                              // نستخدم Icon بدلاً من IconButton لأن الـ onTap في InkWell الخارجي
                              Icon(Icons.shopping_cart, color: primaryIconColor, size: 28),
                              
                              // 2. الـ Badge (الموقع والتصميم الذي تفضله)
                              if (totalItems > 0)
                                Positioned(
                                  right: 5, // الموقع الأصلي الذي طلبته
                                  top: 0,   // الموقع الأصلي الذي طلبته
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade700, 
                                      shape: BoxShape.circle, // الشكل الدائري الكلاسيكي
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Center(
                                      child: Text(
                                        totalItems > 99 ? '99+' : totalItems.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                // Hero Image في المنطقة الموسعة
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeroImageCarousel(context),
                  titlePadding: EdgeInsets.zero,
                ),
              ),

              // محتوى الصفحة العادي (Brand Showcase و Categories Grid)
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // تطبيق الـ WebContainer هنا لتوسيط وتحديد العرض الأقصى للمحتوى الداخلي
                    _buildWebContainer(
                      child: Column(
                        children: [
                          // افترضنا وجود هذه الـ Widgets في category_widgets.dart
                          const BrandShowcaseView(),
                          CategoriesGridView(categories: categories),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          //  إضافة مؤشر تتبع الطلب هنا
          // سيتم وضعه فوق كل من CustomScrollView و SliverAppBar 
          const OrderTrackerWidget(), 
        ],
      ),
    );
  }
}
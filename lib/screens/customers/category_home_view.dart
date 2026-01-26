// lib/screens/category_home_view.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui'; // For blur effects and glassmorphism
import '../../widgets/category_widgets.dart'; // افترض وجود هذا الملف لـ CategoriesGridView و BrandShowcaseView
import '../../widgets/custom_form_widgets.dart'; // للوصول إلى primaryText (افترض وجوده)
import '../../widgets/side_menu_view_contents.dart'; 
import '../../widgets/side_cart_view_contents.dart'; 
import '../../widgets/cart_icon_with_badge.dart';
import '../../widgets/order_tracker_widget.dart';
import '../../screens/auth/sign_in_ui.dart'; // Import the luxury theme
import 'package:provider/provider.dart'; 
import '../../state_management/cart_manager.dart';
import '../../state_management/theme_manager.dart'; // Import theme manager
import '../../constants/store_categories.dart';
import '../../services/api_service.dart'; 

class CategoryHomeView extends StatefulWidget {
  const CategoryHomeView({Key? key}) : super(key: key); 

  @override
  State<CategoryHomeView> createState() => _CategoryHomeViewState();
}

class _CategoryHomeViewState extends State<CategoryHomeView> {
  // MARK: - State Variables
  final List<String> heroImages = ["Hero.png", "0.png", "1.png", "2.png", "3.png", "4.png", "5.png", "6.png", "7.png", "8.png"];
  
  //  Use centralized store categories
  late final List<String> categories;
  
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    //  Clear all cache when entering customer home to prevent data mixing
    ApiService.clearCache();
    
    //  Initialize categories from centralized list
    categories = StoreCategories.all;
    // Slow down carousel timer to reduce background activity
    _timer = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
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

  Widget _buildHeroImageCarousel(BuildContext context, bool isDark) {
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
          
          // Luxury Gradient Overlay with glassmorphism effect
          Container(
            height: MediaQuery.of(context).size.width > 600 ? 600 : MediaQuery.of(context).size.height * 0.7, 
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.6)
                ],
              ),
            ),
          ),

          // Luxury text section with premium styling
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 40, right: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Premium Main Heading
                Text(
                  "Welcome to YShop",
                  style: TextStyle(
                    fontSize: 42,
                    fontFamily: 'Didot',
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Premium Subheading
                Text(
                  "Curated Excellence, Delivered",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.95),
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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

  // Build luxury glass card with glassmorphism effect
  Widget _buildLuxuryCard({
    required Widget child,
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  // Build luxury section header
  Widget _buildSectionHeader(String title, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: LuxuryTheme.kLightBlueAccent,
            letterSpacing: 3,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          width: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LuxuryTheme.kLightBlueAccent, LuxuryTheme.kLightBlueAccent.withOpacity(0.3)],
            ),
          ),
        ),
      ],
    );
  }


  // MARK: - Main Build Method
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.isDarkMode;
    
    // Define colors based on theme
    final backgroundColor = isDark 
        ? LuxuryTheme.kDarkBackground 
        : LuxuryTheme.kLightBackground;
    
    final surfaceColor = isDark 
        ? LuxuryTheme.kDarkSurface 
        : LuxuryTheme.kLightSurface;
    
    final textColor = isDark 
        ? LuxuryTheme.kPlatinum 
        : LuxuryTheme.kDeepNavy;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      drawer: const Drawer(child: SideMenuViewContents()),
      endDrawer: Drawer(child: SideCartViewContents()),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // زر القائمة الجانبية (Side Menu)
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: textColor), 
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        // زر سلة المشتريات (Side Cart)
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: CartIconWithBadge(),
          ),
        ],
      ),
      
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [const Color(0xFF0A0A0A), const Color(0xFF0A0A0A), const Color(0xFF1A1A1A)]
                : [const Color(0xFFF5F5F5), const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)],
            stops: const [0.0, 1.8, 1.1],
          ),
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            // Hero Carousel - No SliverAppBar, just content
            SliverToBoxAdapter(
              child: _buildHeroImageCarousel(context, isDark),
            ),

            // محتوى الصفحة مع تطبيق الـ Luxury Styling
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  // Luxury Glass Card Container
                  _buildWebContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      child: Column(
                        children: [
                          // Section Header with luxury styling
                          _buildSectionHeader("CURATED COLLECTIONS", isDark),
                          const SizedBox(height: 30),
                          
                          // Brand Showcase in luxury card
                          _buildLuxuryCard(
                            child: const BrandShowcaseView(),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 40),
                          
                          // Section Header for Categories
                          _buildSectionHeader("SHOP BY CATEGORY", isDark),
                          const SizedBox(height: 30),
                          
                          // Categories Grid in luxury card
                          _buildLuxuryCard(
                            child: CategoriesGridView(categories: categories),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
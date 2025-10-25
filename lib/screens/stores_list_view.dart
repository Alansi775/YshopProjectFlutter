// lib/screens/stores_list_view.dart (الكود النهائي المصحح)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../state_management/cart_manager.dart'; 

// استيراد الشاشات والمكونات الصحيحة
import 'store_detail_view.dart'; 
import '../widgets/side_menu_view_contents.dart'; 
import '../widgets/side_cart_view_contents.dart';

import '../models/store.dart';
import '../widgets/store_card.dart';


// ----------------------------------------------------------------------
// MARK: - StoresListView
// ----------------------------------------------------------------------

class StoresListView extends StatefulWidget {
  final String categoryName;
  const StoresListView({Key? key, required this.categoryName}) : super(key: key);

  @override
  State<StoresListView> createState() => _StoresListViewState();
}

class _StoresListViewState extends State<StoresListView> {
  // MARK: - State Variables
  List<Store> _stores = [];
  bool _isLoading = false;
  String _errorMessage = "";
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // MARK: - Lifecycle
  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  // MARK: - Firebase Actions (loadStores)
  void _loadStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("storeRequests")
          .where("storeType", isEqualTo: widget.categoryName)
          .where("status", isEqualTo: "Approved")
          .get();

      setState(() {
        _stores = snapshot.docs.map((doc) => Store.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading stores: ${error.toString()}";
      });
    }
  }

  // MARK: - Widgets

  Widget _buildLoadingIndicator(BuildContext context) {
    //  جلب لون التمييز الديناميكي
    final Color accentColor = Theme.of(context).colorScheme.secondary; 

    return Positioned.fill(
      child: Container(
        // لون شفاف خفيف يتبع الخلفية
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5), 
        child: Center(
          child: CircularProgressIndicator(
            color: accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateView(BuildContext context) {
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6); 

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.storefront,
              size: 60,
              color: secondaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              "No Stores Available",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                "We couldn't find any ${widget.categoryName.toLowerCase()} stores in your area.",
                style: TextStyle( 
                  fontSize: 14,
                  color: secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  التعديل: إضافة الدالة المساعدة المفقودة _buildWebContainer
  Widget _buildWebContainer({required Widget child}) {
    if (MediaQuery.of(context).size.width > 600) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1000, 
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
    //  جلب الألوان الأساسية هنا
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Scaffold(
      key: _scaffoldKey, 
      backgroundColor: scaffoldColor, 
      drawer: const Drawer(child: SideMenuViewContents()),
      endDrawer: const Drawer(child: SideCartViewContents()),
      
      //  التعديل 1: AppBar
      appBar: AppBar(
        // زر الرجوع (Leading) لليسار
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(), 
        ),
        
        // العنوان Tappable title "YSHOP" في المنتصف
        title: GestureDetector(
          onTap: () => Navigator.of(context).pop(), 
          child: Text(
            "YSHOP",
            style: TextStyle(
              fontFamily: 'CinzelDecorative', 
              fontSize: 28,
              color: primaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        // أيقونة السلة (Actions) لليمين
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
      ),
      
      //  التعديل 2: Body
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Content Header & Grid
                _buildWebContainer( //  الآن الدالة معرّفة ولن يحدث خطأ
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.categoryName,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${_stores.length} locations available",
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Store Grid
                      if (_stores.isEmpty && !_isLoading)
                        _buildEmptyStateView(context)
                      else if (_stores.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 250, 
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 0.8, 
                            ),
                            itemCount: _stores.length,
                            itemBuilder: (context, index) {
                              final store = _stores[index];
                              return StoreCard(
                                store: store,
                                onTap: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => StoreDetailView(store: store),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        return FadeTransition(
                                          opacity: animation.drive(Tween(begin: 0.0, end: 1.0)),
                                          child: child,
                                        );
                                      },
                                      transitionDuration: const Duration(milliseconds: 200),
                                    )
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Loading Indicator 
          if (_isLoading) _buildLoadingIndicator(context),
        ],
      ),
    );
  }
}
// lib/screens/stores_list_view.dart (الكود النهائي المصحح)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// استيراد الشاشات والمكونات الصحيحة
import 'store_detail_view.dart'; 
import '../widgets/side_menu_view_contents.dart'; 
import '../widgets/side_cart_view_contents.dart';

import '../models/store.dart';
import '../widgets/store_card.dart';
import '../widgets/custom_form_widgets.dart'; // للألوان

// ----------------------------------------------------------------------
// MARK: - تم حذف مكونات Placeholder.
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

  // لافتراض وجود المتغيرات
  final Color primaryText = Colors.black;
  final Color secondaryText = Colors.grey;
  final Color accentBlue = Colors.blue; 

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

  Widget get _loadingIndicator {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.1),
        child: Center(
          child: CircularProgressIndicator(
            color: accentBlue,
          ),
        ),
      ),
    );
  }

  Widget get _emptyStateView {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.storefront,
              size: 60,
              color: secondaryText.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              "No Stores Available",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                "We couldn't find any ${widget.categoryName.toLowerCase()} stores in your area.",
                // تم إزالة const
                style: TextStyle( 
                  fontSize: 14,
                  color: secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    
    return Scaffold(
      key: _scaffoldKey, 
      backgroundColor: Colors.white, 
      drawer: Drawer(child: SideMenuViewContents()),
      endDrawer: Drawer(child: SideCartViewContents()),
      
      //  التعديل 1: إضافة AppBar هنا
      appBar: AppBar(
        // زر الرجوع (Leading) لليسار
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
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
              color: primaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        // أيقونة السلة (Actions) لليمين
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart, color: primaryText),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
        // خصائص AppBar إضافية للتنسيق (ممكن أن تكون موروثة من Theme)
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      
      //  التعديل 2: إزالة SafeArea حول الـ body واستبدالها بالـ SingleChildScrollView مباشرة
      body: Stack(
        children: [
          SingleChildScrollView(
            // يجب تطبيق الـ Padding الأفقي خارج الـ buildWebContainer أو ضمنها
            // لإزالة الـ Row المخصص (Header) الذي كان موجوداً
            child: Column(
              children: [
                //  التعديل 3: تم حذف الـ Row المخصص للـ Header هنا
                // --------------------------------------------------------------------------------

                // Content Header & Grid
                _buildWebContainer(
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
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${_stores.length} locations available",
                              // تم إزالة const
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Store Grid
                      if (_stores.isEmpty && !_isLoading)
                        _emptyStateView
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
                                    MaterialPageRoute(
                                      builder: (context) => StoreDetailView(store: store),
                                    ),
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
          if (_isLoading) _loadingIndicator,
        ],
      ),
    );
  }
}
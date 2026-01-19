// lib/screens/stores_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state_management/cart_manager.dart';
import '../../services/api_service.dart'; //  استخدام API

// استيراد الشاشات والمكونات
import '../stores/store_detail_view.dart';
import '../../widgets/side_menu_view_contents.dart';
import '../../widgets/side_cart_view_contents.dart';
import '../../models/store.dart';
import '../../widgets/store_card.dart';
import '../../widgets/cart_icon_with_badge.dart';

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

  //  MARK: - Load Stores from API (MySQL)
  void _loadStores() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      //  استخدم API بدلاً من Firestore
      final storesData = await ApiService.getPublicStoresByType(widget.categoryName);

      debugPrint(' Loaded ${storesData.length} stores for ${widget.categoryName}');

      if (!mounted) return;
      setState(() {
        _stores = storesData.map((data) => Store.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('❌ Error loading stores: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading stores: ${error.toString()}";
      });
    }
  }

  // MARK: - Widgets

  Widget _buildLoadingIndicator(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Positioned.fill(
      child: Container(
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
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color scaffoldColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldColor,
      drawer: const Drawer(child: SideMenuViewContents()),
      endDrawer: const Drawer(child: SideCartViewContents()),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: CartIconWithBadge(),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
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
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          StoreDetailView(store: store),
                                      transitionsBuilder:
                                          (context, animation, secondaryAnimation, child) {
                                        return FadeTransition(
                                          opacity: animation.drive(Tween(begin: 0.0, end: 1.0)),
                                          child: child,
                                        );
                                      },
                                      transitionDuration: const Duration(milliseconds: 200),
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
          if (_isLoading) _buildLoadingIndicator(context),
        ],
      ),
    );
  }
}
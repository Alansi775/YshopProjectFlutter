import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Helper Widget for Animations ---
class SlideInItem extends StatefulWidget {
  final Widget child;
  final int index;
  const SlideInItem({super.key, required this.child, required this.index});

  @override
  State<SlideInItem> createState() => _SlideInItemState();
}

class _SlideInItemState extends State<SlideInItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Add delay based on index for staggered effect
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _offsetAnimation, child: widget.child),
    );
  }
}

// --- Main View ---

class OrdersView extends StatefulWidget {
  final String storeEmail;
  static const double APP_COMMISSION_RATE = 0.25; // 25%

  const OrdersView({super.key, required this.storeEmail});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Future<List<dynamic>>? _ordersFuture;
  Timer? _refreshTimer;
  
  // Responsive Max Width for Web/Tablet
  static const double kMaxWidth = 700.0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _ordersFuture = _loadOrders();
    
    // Refresh orders every 10 seconds to get real-time driver location updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {
          _ordersFuture = _loadOrders();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<dynamic>> _loadOrders() async {
    final store = await ApiService.getUserStore();
    final storeId = store?['id']?.toString();
    if (storeId == null) return [];
    final orders = await ApiService.getStoreOrders(storeId: storeId);
    return orders;
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus, BuildContext context) async {
    try {
      HapticFeedback.mediumImpact();
      await ApiService.updateOrderStatus(orderId, newStatus);
      setState(() {
        _ordersFuture = _loadOrders();
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$orderId marked as ${newStatus.toUpperCase()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: newStatus == 'cancelled' ? Colors.red : Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            width: kMaxWidth > MediaQuery.of(context).size.width ? null : kMaxWidth,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _scanQRCode() async {
    try {
      const String fakeOrderId = 'ORDER_ID_FROM_SCANNER';
      setState(() {
        _searchController.text = fakeOrderId;
        HapticFeedback.lightImpact();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Scan simulated! Filtering...')),
        );
      }
    } on PlatformException {
      // Handle error
    }
  }

  // --- Styles & Helpers ---

  TextStyle _getTenorSansStyle(BuildContext context, double size,
      {FontWeight weight = FontWeight.normal, Color? color}) {
    return TextStyle(
      fontFamily: 'TenorSans', // Assuming you have this font setup
      fontSize: size,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      letterSpacing: 0.5,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade700;
      case 'confirmed':
      case 'processing': return Colors.blue.shade600;
      case 'rejected':
      case 'cancelled': return Colors.red.shade700;
      case 'out for delivery':
      case 'shipped': return Colors.teal.shade600;
      case 'delivered': return Colors.green.shade700;
      default: return Colors.grey.shade600;
    }
  }

  DateTime _parseOrderDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw;
    if (raw is String) {
      // Handle standard SQL format
      final sqlTs = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})');
      final match = sqlTs.firstMatch(raw);
      if (match != null) {
        return DateTime(
          int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!),
          int.parse(match.group(4)!), int.parse(match.group(5)!), int.parse(match.group(6)!),
        );
      }
      final parsed = DateTime.tryParse(raw);
      return parsed ?? DateTime.now();
    }
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Using NestedScrollView to allow the AppBar to float nicely
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 2,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              title: Text(
                "Store Orders",
                style: _getTenorSansStyle(context, 18, weight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() => _ordersFuture = _loadOrders()),
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: _scanQRCode,
                tooltip: 'Scan QR',
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: Column(
          children: [
            // Search Bar Area
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Order #ID or Client Name...',
                      hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: primaryColor.withOpacity(0.7)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor.withOpacity(0.3), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ),
            ),

            // Orders List
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading orders', style: _getTenorSansStyle(context, 16)));
                  }
                  
                  final allOrders = snapshot.data ?? [];
                  final filteredOrders = allOrders.where((order) {
                    final orderId = (order['id'] ?? '').toString().toLowerCase();
                    final name = (order['customerName'] ?? order['userName'] ?? '').toString().toLowerCase();
                    if (_searchQuery.isEmpty) return true;
                    return orderId.contains(_searchQuery) || name.contains(_searchQuery);
                  }).toList();

                  if (filteredOrders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 60, color: theme.disabledColor.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            "No orders found",
                            style: _getTenorSansStyle(context, 16, color: theme.disabledColor),
                          ),
                        ],
                      ),
                    );
                  }

                  // Responsive List Container
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kMaxWidth),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index] as Map<String, dynamic>;
                          final orderId = (order['id'] ?? '').toString();
                          // Wrap in Animation Widget
                          return SlideInItem(
                            index: index,
                            child: _buildOrderCard(context, orderId, order),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, String orderId, Map<String, dynamic> orderData) {
    final theme = Theme.of(context);
    final status = (orderData['status'] as String?) ?? 'pending';
    final statusLower = status.toLowerCase();
    
    // Customer Name Logic
    final userName = (orderData['customerName'] as String?) ??
        (orderData['userName'] as String?) ??
        (orderData['customer']?['display_name'] as String?) ??
        (orderData['customer']?['name'] as String?) ??
        'Guest Client';

    // Date Logic
    final createdAt = orderData['created_at'] ?? orderData['createdAt'] ?? orderData['created'];
    final date = _parseOrderDate(createdAt);
    final formattedTime = DateFormat('MMM d, h:mm a').format(date);

    // Items & Price Logic
    final items = orderData['items'] as List<dynamic>? ?? [];
    double storeSubtotal = 0.0;
    
    for (var item in items) {
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 1;
      storeSubtotal += price * qty;
    }

    final commission = storeSubtotal * OrdersView.APP_COMMISSION_RATE;
    final netStoreProfit = storeSubtotal - commission;
    final statusColor = _getStatusColor(status);
    final firstItemImage = items.isNotEmpty ? (items.first['imageUrl'] ?? items.first['image_url'] ?? items.first['image'] ?? items.first['photo']) as String? : null;
    final String? resolvedFirstImage = firstItemImage != null && firstItemImage.isNotEmpty ? _resolveImageUrl(firstItemImage) : null;
    // Driver info (if assigned)
    final Map<String, dynamic>? driverMap = orderData['driver'] is Map<String, dynamic> ? Map<String, dynamic>.from(orderData['driver']) : null;
    final String? driverName = (driverMap?['name'] ?? driverMap?['display_name'] ?? orderData['driverName'] ?? orderData['driver_name'] ?? orderData['driver_full_name'])?.toString();
    final String? driverPhone = (driverMap?['phone'] ?? driverMap?['phoneNumber'] ?? orderData['driverPhone'] ?? orderData['driver_phone'])?.toString();
    // driver id + coordinates (if available)
    final driverId = (orderData['driver_id'] ?? orderData['driverId'] ?? orderData['driver_uid'] ?? orderData['driverUID'])?.toString();
    
    // Get driver location from either driver_location JSON or driver_latitude/longitude fields
    Map<String, dynamic>? driverLocationJson;
    if (orderData['driver_location'] != null) {
      try {
        final locData = orderData['driver_location'];
        if (locData is String) {
          driverLocationJson = jsonDecode(locData);
        } else if (locData is Map) {
          driverLocationJson = Map<String, dynamic>.from(locData);
        }
      } catch (e) {
        debugPrint('Error parsing driver_location: $e');
      }
    }
    
    final drvLatRaw = driverLocationJson?['latitude'] ?? driverMap?['latitude'] ?? driverMap?['lat'] ?? orderData['driverLatitude'] ?? orderData['driver_latitude'] ?? orderData['driver_lat'];
    final drvLngRaw = driverLocationJson?['longitude'] ?? driverMap?['longitude'] ?? driverMap?['lng'] ?? orderData['driverLongitude'] ?? orderData['driver_longitude'] ?? orderData['driver_lng'];
    final double? driverLat = drvLatRaw != null ? (drvLatRaw is num ? drvLatRaw.toDouble() : double.tryParse(drvLatRaw.toString())) : null;
    final double? driverLng = drvLngRaw != null ? (drvLngRaw is num ? drvLngRaw.toDouble() : double.tryParse(drvLngRaw.toString())) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showOrderDetailsSheet(context, orderData, resolvedFirstImage, driverName, driverPhone, driverLat, driverLng, driverId),
          child: Column(
            children: [
          // 1. Header Section (ID + Status)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order #$orderId", style: _getTenorSansStyle(context, 16, weight: FontWeight.bold)),
                    Text(formattedTime, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.8),
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, thickness: 1, color: theme.dividerColor.withOpacity(0.05)),

          // 2. Content Section (Image + Details)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 70, height: 70,
                    color: theme.disabledColor.withOpacity(0.1),
                      child: resolvedFirstImage != null
                      ? CachedNetworkImage(imageUrl: resolvedFirstImage, fit: BoxFit.cover)
                      : Icon(Icons.shopping_bag_outlined, color: theme.disabledColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: _getTenorSansStyle(context, 15, weight: FontWeight.w600)),
                      if (driverName != null && driverName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade200, child: Text(driverName[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 12))),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Driver: $driverName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            if (driverPhone != null && driverPhone.isNotEmpty)
                              IconButton(onPressed: () => _callPhone(driverPhone), icon: const Icon(Icons.phone, color: Colors.green)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        "${items.length} Items • Total: \$${storeSubtotal.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 13, color: theme.hintColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items.take(2).map((e) {
                          final itemName = (e['name'] ?? e['product_name'] ?? e['productName'] ?? e['title'])?.toString() ?? 'item';
                          final qty = (e['quantity'] ?? e['qty'] ?? e['quantity']?.toString())?.toString() ?? '1';
                          return '${qty}x ${itemName}';
                        }).join(", ") + (items.length > 2 ? "..." : ""),
                        style: TextStyle(fontSize: 12, color: theme.hintColor.withOpacity(0.7)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Footer Section (Profit + Actions)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Net Profit Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Net Profit", style: _getTenorSansStyle(context, 13, color: theme.hintColor)),
                    Text(
                      "\$${netStoreProfit.toStringAsFixed(2)}",
                      style: _getTenorSansStyle(context, 16, weight: FontWeight.bold, color: Colors.green.shade700),
                    ),
                  ],
                ),
                
                // Dynamic Actions
                if (statusLower == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context, "Reject", Colors.red.withOpacity(0.1), Colors.red,
                          () => _updateOrderStatus(orderId, 'cancelled', context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          context, "Accept Order", theme.primaryColor, Colors.white,
                          () => _updateOrderStatus(orderId, 'confirmed', context),
                          isFilled: true,
                        ),
                      ),
                    ],
                  ),
                ] else if (statusLower == 'confirmed' || statusLower == 'processing') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(
                      context, "Show Handover QR", theme.primaryColor, Colors.white,
                      () => _showQrCodeModal(context, orderId),
                      icon: Icons.qr_code_2_rounded,
                      isFilled: true,
                    ),
                  ),
                ]
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String label, Color bg, Color fg, VoidCallback onTap,
      {bool isFilled = false, IconData? icon}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Compute effective colors using theme when caller passed generic colors
    final Color effectiveBg = bg;
    Color effectiveFg = fg;

    if (isFilled) {
      // For filled buttons prefer theme's onPrimary if caller used a generic white/black
      if (effectiveFg == Colors.white || effectiveFg == Colors.black) {
        effectiveFg = theme.colorScheme.onPrimary;
      }
    } else {
      if (effectiveFg == Colors.white || effectiveFg == Colors.black) {
        effectiveFg = theme.colorScheme.primary;
      }
    }

    final borderColor = isFilled ? Colors.transparent : effectiveFg.withOpacity(0.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: effectiveFg, size: 20), const SizedBox(width: 8)],
            Text(label, style: _getTenorSansStyle(context, 14, weight: FontWeight.bold, color: effectiveFg)),
          ],
        ),
      ),
    );
  }

  void _showQrCodeModal(BuildContext context, String orderId) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 30, spreadRadius: 5)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 50, height: 5,
                  margin: const EdgeInsets.only(bottom: 25),
                  decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(10)),
                ),
                Text("Ready for Handover", style: _getTenorSansStyle(context, 22, weight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Let the driver scan this code", style: TextStyle(color: theme.hintColor)),
                const SizedBox(height: 30),
                
                // QR Code Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                  ),
                  child: Builder(builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final bgColor = isDark ? Colors.black : Colors.white;
                    final qrColor = isDark ? Colors.white : Colors.black;
                    return Container(
                      color: bgColor,
                      padding: const EdgeInsets.all(6),
                      child: QrImageView(
                        data: orderId,
                        version: QrVersions.auto,
                        size: 200.0,
                        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: qrColor),
                        dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: qrColor),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 30),
                Text("#$orderId", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: theme.disabledColor)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderDetailsSheet(BuildContext context, Map<String, dynamic> orderData, String? imageUrl, String? driverName, String? driverPhone, double? driverLat, double? driverLng, String? driverId) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (a,b,c)=> Container(width:80,height:80,color:theme.cardColor,child: const Icon(Icons.store)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(orderData['storeName'] ?? orderData['store_name'] ?? 'Store', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(orderData['address'] ?? orderData['addressFull'] ?? orderData['address_full'] ?? '', style: TextStyle(color: theme.hintColor)),
                  ])),
                ]),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                FutureBuilder<List<dynamic>>(
                  future: ApiService.getApprovedDeliveryRequests(),
                  builder: (context, snap) {
                    String? dName = driverName;
                    String? dPhone = driverPhone;
                    double? dLat = driverLat;
                    double? dLng = driverLng;
                    if (snap.hasData && snap.data != null && driverId != null) {
                      final list = snap.data!;
                      final found = list.firstWhere((e) => (e['uid'] ?? e['id']?.toString()) == driverId, orElse: () => null);
                      if (found != null) {
                        dName = (found['name'] ?? found['display_name'] ?? found['fullName'])?.toString() ?? dName;
                        dPhone = (found['phone'] ?? found['phoneNumber'])?.toString() ?? dPhone;
                        final latRaw = found['latitude'] ?? found['lat'];
                        final lngRaw = found['longitude'] ?? found['lng'];
                        dLat = latRaw != null ? (latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw.toString())) : dLat;
                        dLng = lngRaw != null ? (lngRaw is num ? lngRaw.toDouble() : double.tryParse(lngRaw.toString())) : dLng;
                      }
                    }

                    return Column(
                      children: [
                        Row(children: [
                          CircleAvatar(radius: 26, backgroundColor: theme.cardColor, child: Text(dName?.isNotEmpty == true ? dName![0].toUpperCase() : '?', style: const TextStyle(color: Colors.blue))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(dName ?? 'No driver assigned', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(dPhone ?? 'N/A', style: TextStyle(color: theme.hintColor)),
                          ])),
                          if ((dPhone ?? '').isNotEmpty)
                            IconButton(onPressed: () => _callPhone(dPhone), icon: const Icon(Icons.phone, color: Colors.green)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: OutlinedButton.icon(onPressed: () {
                            Navigator.pop(ctx);
                            if (dLat != null && dLng != null) {
                              final mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${dLat},${dLng}');
                              launchUrl(mapUrl);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver location not available')));
                            }
                          }, icon: const Icon(Icons.map), label: const Text('Open Map'))),
                          const SizedBox(width: 8),
                          Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _callPhone(dPhone); }, icon: const Icon(Icons.phone), label: const Text('Call Driver'))),
                        ]),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      debugPrint('Could not launch phone: $e');
    }
  }

  String _resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final host = ApiService.baseHost;
    if (u.startsWith('/')) return '$host$u';
    return '$host/$u';
  }
}
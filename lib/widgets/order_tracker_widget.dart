import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../state_management/cart_manager.dart';
import '../services/navigation_service.dart';
import '../state_management/auth_manager.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../screens/auth/sign_in_ui.dart';
import 'dart:ui' as ui;

/// Optimized Order Tracker - Fast loading, smooth UX
class OrderTrackerWidget extends StatefulWidget {
  const OrderTrackerWidget({Key? key}) : super(key: key);

  @override
  State<OrderTrackerWidget> createState() => _OrderTrackerWidgetState();
}

class _OrderTrackerWidgetState extends State<OrderTrackerWidget> {
  // Cached order data to prevent repeated fetches
  Map<String, dynamic>? _cachedOrder;
  String? _currentOrderId;
  Timer? _pollingTimer;
  bool _isLoading = false;
  bool _isCheckingLatestOrder = false;
  String? _lastCheckedUserId;
  DateTime? _lastClearTime;
  DateTime? _lastCheckTime; // 🔥 Track when we last checked for orders
  int _consecutiveAuthErrors = 0; // 🔥 Track consecutive 401 errors to stop infinite retries

  @override
  void initState() {
    super.initState();
    // 🔥 CRITICAL FIX: Don't call _checkForLatestOrder() here!
    // The token may not be loaded yet. Wait for didChangeDependencies instead.
    // didChangeDependencies will trigger once AuthManager is ready.
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Check auth changes via AuthManager
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authManager = Provider.of<AuthManager>(context, listen: true);
    
    // If user logged out, clear everything
    if (!authManager.isAuthenticated && _lastCheckedUserId != null) {
      _clearOrderData();
      _lastCheckedUserId = null;
      _consecutiveAuthErrors = 0; // Reset error counter
      return;
    }
    
    // If user is authenticated and has a profile, check for orders
    if (authManager.isAuthenticated && authManager.userProfile != null) {
      final newUserId = authManager.userProfile?['uid']?.toString();
      
      // 🔥 Only check if:
      // 1. User ID changed (new login)
      // 2. AND at least 5 seconds have passed
      // 3. AND no recent 401 errors (wait for user to manually retry)
      if (newUserId != _lastCheckedUserId && newUserId != null) {
        _lastCheckedUserId = newUserId;
        _consecutiveAuthErrors = 0; // Reset counter for new user
        
        final now = DateTime.now();
        if (_lastCheckTime == null || now.difference(_lastCheckTime!).inSeconds >= 5) {
          _lastCheckTime = now;
          _checkForLatestOrder();
        }
      }
    }
  }

  // Clear all cached order data
  void _clearOrderData() {
    _pollingTimer?.cancel();
    // 🔥 CRITICAL: Check if mounted before setState to avoid "setState after dispose" errors
    if (mounted) {
      setState(() {
        _cachedOrder = null;
        _currentOrderId = null;
        _isLoading = false;
        _isCheckingLatestOrder = false;
      });
    }
    // Also clear from CartManager using Future.microtask to avoid setState during build
    Future.microtask(() {
      if (mounted) {
        try {
          Provider.of<CartManager>(context, listen: false).setLastOrderId(null);
        } catch (e) {
          // Silent fail - user is logging out anyway
        }
      }
    });
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0.0;
    return 0.0;
  }

  // Parse date from various formats
  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();

    // If already DateTime, check if it needs timezone adjustment
    if (raw is DateTime) {
      if (raw.isUtc) {
        return DateTime(
          raw.year,
          raw.month,
          raw.day,
          raw.hour,
          raw.minute,
          raw.second,
        );
      }
      return raw;
    }

    if (raw is String) {
      // Handle MySQL format: "2025-12-23 02:38:01" or with T: "2025-12-23T02:38:01"
      final sqlTs = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})');
      final match = sqlTs.firstMatch(raw);
      if (match != null) {
        return DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
          int.parse(match.group(6)!),
        );
      }

      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
        );
      }
      return DateTime.now();
    }

    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    if (raw is Map && raw.containsKey('seconds')) {
      final secs = raw['seconds'];
      if (secs is int) return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
    }

    return DateTime.now();
  }

  // NEW: Fetch the latest undelivered order for current user
  Future<void> _checkForLatestOrder() async {
    // 🔥 CRITICAL: Check if already checking or if still authenticated
    if (_isCheckingLatestOrder) return;
    
    // 🔥 NEW: If too many consecutive 401 errors, stop trying until next login
    if (_consecutiveAuthErrors >= 3) {
      debugPrint('⚠️ Too many auth errors (${_consecutiveAuthErrors}), stopping order checks. User needs to re-login.');
      return;
    }
    
    // Check if user is still logged in BEFORE making request
    final authManager = Provider.of<AuthManager>(context, listen: false);
    if (!authManager.isAuthenticated) {
      _clearOrderData();
      return;
    }
    
    // If there's already a current order being tracked, don't fetch new ones
    if (_currentOrderId != null) return;
    
    _isCheckingLatestOrder = true;
    try {
      // Fetch all orders and get the latest non-delivered one
      final orders = await ApiService.getUserOrders();
      
      // 🔥 Success = reset error counter
      _consecutiveAuthErrors = 0;
      
      if (orders != null && orders.isNotEmpty && mounted) {
        // Find latest order that's not delivered
        Map<String, dynamic>? latestPendingOrder;
        for (final order in orders) {
          final status = _normalizeStatus(order['status']?.toString() ?? 'pending');
          // Only track orders that are pending, processing, or out for delivery
          if (status != 'Delivered' && status != 'Cancelled') {
            if (latestPendingOrder == null) {
              latestPendingOrder = order;
            } else {
              // Compare timestamps to find the most recent one
              final currentDate = _parseDate(order['created_at'] ?? order['createdAt']);
              final latestDate = _parseDate(latestPendingOrder['created_at'] ?? latestPendingOrder['createdAt']);
              if (currentDate.isAfter(latestDate)) {
                latestPendingOrder = order;
              }
            }
          }
        }

        if (latestPendingOrder != null) {
          final orderId = latestPendingOrder['id']?.toString() ?? latestPendingOrder['order_id']?.toString();
          if (orderId != null && orderId.isNotEmpty && mounted) {
            debugPrint('Found latest pending order: $orderId');
            // 🔥 Cache the order data directly from getUserOrders
            setState(() {
              _cachedOrder = Map<String, dynamic>.from(latestPendingOrder!);
              _currentOrderId = orderId;
            });
            // Set it in cart manager for persistence
            Provider.of<CartManager>(context, listen: false).setLastOrderId(orderId);
            // Start light polling for status updates only (not full order)
            _startLightPolling(orderId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for latest order: $e');
      
      // Check if it's a 401 (unauthorized - token invalid or expired)
      if (e is ApiException && e.isUnauthorized) {
        _consecutiveAuthErrors++;
        debugPrint('❌ Got 401 (error #$_consecutiveAuthErrors) - Token invalid or expired');
        
        // After 3 consecutive 401s, stop trying - user needs to re-login
        if (_consecutiveAuthErrors >= 3) {
          debugPrint('🛑 Too many auth errors, clearing data. User should re-login.');
          _clearOrderData();
        }
      } 
      // If 429 (rate limited), reset error counter and stop
      else if (e is ApiException && e.isRateLimited) {
        _consecutiveAuthErrors = 0; // Reset on 429
        debugPrint('Got 429 - Rate limited, stopping order checks temporarily');
        _clearOrderData();
      }
      // For other errors, just log
      else {
        _consecutiveAuthErrors = 0; // Reset on other errors
      }
      // For other errors, just log but don't retry automatically
    } finally {
      _isCheckingLatestOrder = false;
    }
  }

  // Light polling - only fetch status, not full order
  void _startLightPolling(String orderId) {
    _pollingTimer?.cancel();
    
    // 🔥 Poll every 90 seconds (NOT 60) to prevent overwhelming API with rate limiting
    // Multiple widgets + profile fetches were causing combined 429 errors
    _pollingTimer = Timer.periodic(const Duration(seconds: 90), (_) async {
      // Check if user is still logged in
      final authManager = Provider.of<AuthManager>(context, listen: false);
      if (!authManager.isAuthenticated) {
        _clearOrderData();
        return;
      }

      if (!mounted) return;
      try {
        final orders = await ApiService.getUserOrders();
        if (orders != null) {
          for (final order in orders) {
            if ((order['id']?.toString() ?? order['order_id']?.toString()) == orderId) {
              if (mounted) {
                setState(() {
                  _cachedOrder!['status'] = order['status'];
                });
              }
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Light polling error: $e');
        
        // If 401, stop polling - token is invalid
        if (e is ApiException && e.isUnauthorized) {
          debugPrint('🛑 Got 401 during polling - stopping. User needs to re-login.');
          _pollingTimer?.cancel();
          _clearOrderData();
          return;
        }
        
        // If 429 (rate limit), stop polling and wait
        if (e is ApiException && e.isRateLimited) {
          debugPrint('Got rate limited (429) - pausing polling for 10 minutes');
          _pollingTimer?.cancel();
          // Retry after 10 minutes
          Future.delayed(const Duration(minutes: 10), () {
            if (mounted && _currentOrderId == orderId) {
              debugPrint('Retrying polling after rate limit cooldown');
              _startLightPolling(orderId);
            }
          });
        }
      }
    });
  }

  TextStyle _getTenorSansStyle(BuildContext context, double size,
      {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return TextStyle(
      fontFamily: 'TenorSans',
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor,
    );
  }

  // Initial fast fetch + slow polling for updates
  void _startSmartPolling(String orderId) {
    if (_currentOrderId == orderId && _pollingTimer != null) return;

    _currentOrderId = orderId;
    _pollingTimer?.cancel();

    // First fetch immediately
    _fetchOrder(orderId, isInitial: true);

    // Then poll every 30 seconds (not 10) - status doesn't change that fast
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchOrder(orderId, isInitial: false);
    });
  }

  Future<void> _fetchOrder(String orderId, {bool isInitial = false}) async {
    if (_isLoading && !isInitial) return;

    try {
      if (isInitial) setState(() => _isLoading = true);

      final order = await ApiService.getOrderById(orderId);
      if (order != null && mounted) {
        setState(() {
          _cachedOrder = Map<String, dynamic>.from(order);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is ApiException) {
        if (e.isUnauthorized) {
          debugPrint('Order fetch unauthorized (401) — retrying in 30 seconds...');
          // Don't stop polling, just wait longer before retry
        } else {
          debugPrint('API Error fetching order: $e');
        }
      } else {
        debugPrint('Error fetching order: $e');
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartManager = Provider.of<CartManager>(context);
    final orderId = cartManager.lastOrderId;

    //  Listen to admin role changes and hide for store owners
    return ValueListenableBuilder<String?>(
      valueListenable: ApiService.adminRoleNotifier,
      builder: (context, adminRole, child) {
        if (adminRole != null) {
          return const SizedBox.shrink();
        }

        // If no active order, check for latest one in background (schedule as microtask)
        if (orderId == null && !_isCheckingLatestOrder && _currentOrderId == null) {
          Future.microtask(() {
            if (mounted) _checkForLatestOrder();
          });
          return const SizedBox.shrink();
        }

        if (orderId == null) {
          _pollingTimer?.cancel();
          return const SizedBox.shrink();
        }

        // Start polling if new order (schedule as microtask)
        if (_currentOrderId != orderId) {
          Future.microtask(() {
            if (mounted) _startSmartPolling(orderId);
          });
        }

        // Show cached data immediately, or loading indicator only on first load
        if (_cachedOrder == null && _isLoading) {
          return _buildLoadingIndicator(context);
        }

        if (_cachedOrder == null) {
          return const SizedBox.shrink();
        }

        final status = _normalizeStatus(_cachedOrder!['status']?.toString() ?? 'pending');
        return _buildTrackerIndicator(context, orderId, status);
      },
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackerIndicator(BuildContext context, String orderId, String status) {
    Color statusColor = _getStatusColor(status);

    if (status == 'Delivered') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 1), () {
          Provider.of<CartManager>(context, listen: false).setLastOrderId(null);
        });
      });
      return const SizedBox.shrink();
    }

    IconData statusIcon;
    switch (status) {
      case 'Pending':
        statusIcon = Icons.hourglass_top;
        break;
      case 'Processing':
        statusIcon = Icons.kitchen_rounded;
        break;
      case 'Out for Delivery':
        statusIcon = Icons.delivery_dining;
        break;
      default:
        statusIcon = Icons.error_outline;
    }

    return Positioned(
      bottom: 20,
      right: 20,
      child: GestureDetector(
        onTap: () => _showOrderDetailsSheet(context, orderId, status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Center(
            child: Icon(statusIcon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  // OPTIMIZED: Show sheet immediately with cached data
  void _showOrderDetailsSheet(BuildContext context, String orderId, String currentStatus) {
    final Color cardColor = Theme.of(context).cardColor;

    final navContext = NavigationService.navigatorKey.currentContext ?? context;
    showModalBottomSheet(
      context: navContext,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.8,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30.0),
              topRight: Radius.circular(30.0),
            ),
          ),
          // Use StatefulBuilder to manage sheet state independently
          child: _OrderDetailsSheet(
            orderId: orderId,
            initialData: _cachedOrder,
            getTenorSansStyle: _getTenorSansStyle,
            toDouble: _toDouble,
          ),
        );
      },
    );
  }

  String _normalizeStatus(String raw) {
    final s = raw.trim().toLowerCase();
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
      case 'processing':
        return 'Processing';
      case 'shipped':
      case 'out for delivery':
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return raw;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.lightBlue.shade600;
      case 'Processing':
        return Colors.blue.shade600;
      case 'Out for Delivery':
        return Colors.green.shade600;
      case 'Delivered':
        return Colors.green.shade700;
      default:
        return Colors.red.shade600;
    }
  }
}

/// Separate StatefulWidget for the sheet - manages its own state
class _OrderDetailsSheet extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? initialData;
  final TextStyle Function(BuildContext, double, {FontWeight weight, Color? color}) getTenorSansStyle;
  final double Function(dynamic) toDouble;

  const _OrderDetailsSheet({
    required this.orderId,
    required this.initialData,
    required this.getTenorSansStyle,
    required this.toDouble,
  });

  @override
  State<_OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends State<_OrderDetailsSheet> {
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  bool _isAugmented = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // ALWAYS fetch the full order to ensure we have complete data with items
    _fetchFullOrder();

    // Poll for status updates only (lightweight) every 30 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFullOrder() async {
    try {
      // First, try to get the full order from user's orders list (which is authenticated)
      final orders = await ApiService.getUserOrders();
      
      if (orders != null && orders.isNotEmpty) {
        // Find the order with matching ID
        Map<String, dynamic>? foundOrder;
        for (final order in orders) {
          final orderId = order['id']?.toString() ?? order['order_id']?.toString();
          if (orderId == widget.orderId) {
            foundOrder = order;
            break;
          }
        }
        
        if (foundOrder != null && mounted) {
          setState(() {
            _orderData = Map<String, dynamic>.from(foundOrder!);
            _isLoading = false;
          });
          debugPrint('✅ Fetched order ${widget.orderId} from user orders - items: ${foundOrder["items"]?.length ?? 0}');
          _augmentOrderData();
          return;
        }
      }
      
      // Fallback: Try direct API call (may not have auth token)
      final order = await ApiService.getOrderById(widget.orderId);
      if (order != null && mounted) {
        setState(() {
          _orderData = Map<String, dynamic>.from(order);
          _isLoading = false;
        });
        debugPrint('✅ Fetched order ${widget.orderId} directly - items: ${order["items"]?.length ?? 0}');
        _augmentOrderData();
      }
    } catch (e) {
      debugPrint('Error fetching order: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Lightweight status refresh - only fetches status, not full order
  Future<void> _refreshStatus() async {
    if (_orderData == null) return;
    try {
      final orders = await ApiService.getUserOrders();
      if (orders != null) {
        for (final order in orders) {
          if ((order['id']?.toString() ?? order['order_id']?.toString()) == widget.orderId) {
            final newStatus = order['status'];
            if (newStatus != _orderData!['status'] && mounted) {
              setState(() {
                _orderData!['status'] = newStatus;
              });
              debugPrint('✅ Status updated to: $newStatus');
            }
            return;
          }
        }
      }
    } catch (_) {}
  }

  // Augment order data in background - doesn't block UI
  Future<void> _augmentOrderData() async {
    if (_orderData == null || _isAugmented) return;

    try {
      final order = _orderData!;

      // Normalize field names
      order['documentId'] = order['id']?.toString() ?? order['order_id']?.toString() ?? 'N/A';
      if (order['total_price'] != null && order['total'] == null) {
        order['total'] = order['total_price'];
      }
      if (order['shipping_address'] != null && order['address_Full'] == null) {
        order['address_Full'] = order['shipping_address'];
      }
      if (order['payment_method'] != null && order['paymentMethod'] == null) {
        order['paymentMethod'] = order['payment_method'];
      }
      if (order['delivery_option'] != null && order['deliveryOption'] == null) {
        order['deliveryOption'] = order['delivery_option'];
      }
      if (order['created_at'] != null && order['createdAt'] == null) {
        order['createdAt'] = order['created_at'];
      }

      // Fetch product details for items (in parallel for speed)
      var items = (order['items'] as List<dynamic>?) ?? [];
      debugPrint('📦 AUGMENT: Initial items count: ${items.length}');
      
      if (items.isNotEmpty) {
        final futures = <Future>[];
        final productCache = <String, dynamic>{};

        for (final item in items) {
          final pid = (item['product_id'] ?? item['productId'])?.toString();
          if (pid != null && pid.isNotEmpty && !productCache.containsKey(pid)) {
            futures.add(ApiService.getProductById(pid).then((prod) {
              if (prod != null) productCache[pid] = prod;
            }).catchError((_) {}));
          }
        }

        // Wait for all product fetches in parallel
        await Future.wait(futures);

        // Attach product info to items
        final updatedItems = <dynamic>[];
        for (var i = 0; i < items.length; i++) {
          final item = Map<String, dynamic>.from(items[i] as Map);
          final pid = (item['product_id'] ?? item['productId'])?.toString();
          if (pid != null && productCache.containsKey(pid)) {
            final prod = productCache[pid] as Map<String, dynamic>;
            item['name'] = item['name'] ?? prod['name'] ?? prod['product_name'];
            final rawImage = prod['image_url'] ?? prod['imageUrl'] ?? prod['image'];
            final String existingImage = (item['imageUrl'] as String?) ?? (item['image_url'] as String?) ?? '';
            String resolvedImage = '';
            if (existingImage.isNotEmpty) {
              resolvedImage = Product.getFullImageUrl(existingImage);
            } else if (rawImage != null && rawImage.toString().isNotEmpty) {
              resolvedImage = Product.getFullImageUrl(rawImage.toString());
            }
            item['imageUrl'] = resolvedImage;
            item['storeName'] = item['storeName'] ?? prod['store_name'] ?? prod['storeName'];
          }
          updatedItems.add(item);
        }
        order['items'] = updatedItems;
        debugPrint('📦 AUGMENT: After augmentation, items count: ${order["items"].length}');
      }

      // Fetch user profile for delivery instructions (only if missing)
      if (order['delivery_instructions'] == null) {
        try {
          final profile = await ApiService.getUserProfile();
          if (profile != null) {
            order['delivery_instructions'] = profile['deliveryInstructions'] ?? profile['delivery_instructions'];
            order['address_Full'] = order['address_Full'] ?? profile['address'];
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _orderData = order;
          _isAugmented = true;
        });
      }
    } catch (e) {
      debugPrint('Error augmenting order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary),
      );
    }

    if (_orderData == null) {
      return Center(
        child: Text("Order not found", style: widget.getTenorSansStyle(context, 18)),
      );
    }

    return _buildOrderDetailsContent(context, _orderData!);
  }

  Widget _buildOrderDetailsContent(BuildContext context, Map<String, dynamic> orderData) {
    String rawStatus = (orderData['status'] as String?) ?? 'pending';
    final status = _normalizeStatus(rawStatus);
    final total = widget.toDouble(orderData['total_price'] ?? orderData['total']);

    //  DEBUG: Print what we receive from API
    final rawCreatedAt = orderData['createdAt'] ?? orderData['created_at'];
    debugPrint('🕐 RAW createdAt from API: $rawCreatedAt (type: ${rawCreatedAt.runtimeType})');
    
    // FIXED: Proper date parsing
    final date = _parseDate(rawCreatedAt);
    debugPrint('🕐 PARSED date: $date');

    final documentId = orderData['documentId']?.toString() ?? orderData['id']?.toString() ?? 'N/A';
    final deliveryOption = orderData['deliveryOption'] ?? orderData['delivery_option'] ?? 'Standard';
    final items = (orderData['items'] as List<dynamic>?) ?? [];
    debugPrint('📦 ITEMS COUNT: ${items.length} | Items data: $items');
    final storeName = items.isNotEmpty ? (items.first['storeName'] ?? 'Store') : 'Store';

    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final formattedTime = '${timeFormat.format(date)} - ${dateFormat.format(date)}';
    debugPrint('🕐 FORMATTED time: $formattedTime');
    
    final paymentMethod = orderData['paymentMethod'] ?? orderData['payment_method'] ?? 'Not Specified';

    final trackingSteps = [
      {'title': 'Order Placed', 'status': 'Pending', 'icon': Icons.verified_user_outlined},
      {'title': 'Preparation', 'status': 'Processing', 'icon': Icons.restaurant_menu_outlined},
      {'title': 'On Delivery', 'status': 'Out for Delivery', 'icon': _getDeliveryIcon(deliveryOption)},
      {'title': 'Delivered', 'status': 'Delivered', 'icon': Icons.home_outlined},
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID - Premium Glass Badge
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    "Order #$documentId",
                    style: TextStyle(
                      fontFamily: 'TenorSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Tracking Timeline - Premium Enhanced
          _buildTrackingTimeline(context, trackingSteps, status),

          // Live Map (only when out for delivery)
          if (status == 'Out for Delivery') ...[
            Divider(height: 32, thickness: 0.8, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
            Center(
              child: Text(
                "Driver Location (Live)",
                style: TextStyle(
                  fontFamily: 'Didot',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
              ),
            ),
            const SizedBox(height: 15),
            DeliveryMapWidget(
              orderData: orderData,
              getTenorSansStyle: widget.getTenorSansStyle,
            ),
          ],

          Divider(height: 32, thickness: 0.8, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),

          // Order Summary - Premium Liquid Glass
          _buildSectionHeader(context, "$storeName Order Summary"),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDetailRow(context, "Order Time:", formattedTime, icon: Icons.access_time),
                    const SizedBox(height: 14),
                    _buildDetailRow(context, "Payment Method:", paymentMethod, icon: Icons.credit_card_outlined),
                    const SizedBox(height: 14),
                    _buildDetailRow(context, "Total Amount:", "\$${total.toStringAsFixed(2)}", color: Colors.deepOrange),
                  ],
                ),
              ),
            ),
          ),

          Divider(height: 32, thickness: 0.8, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),

          // Items Section - مع Badge أنيق
          Row(
            children: [
              Text(
                "Items Ordered",
                style: TextStyle(
                  fontFamily: 'Didot',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                ),
              ),
              const SizedBox(width: 12),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontFamily: 'TenorSans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No items in this order',
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 14,
                    color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.6) : LuxuryTheme.kDeepNavy.withOpacity(0.6),
                  ),
                ),
              ),
            )
          else
            ...items.map((item) => _buildProductItem(context, Map<String, dynamic>.from(item))).toList(),

          Divider(height: 32, thickness: 0.8, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),

          // Delivery Info
          _buildSectionHeader(context, "Delivery Info"),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),

                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDetailRow(context, "Delivery Method:", deliveryOption, icon: _getDeliveryIcon(deliveryOption)),
                    const SizedBox(height: 14),
                    _buildDetailRow(
                      context,
                      "Address:",
                      _formatFullAddress(orderData),
                      isAddress: true,
                      icon: Icons.location_on_outlined,
                    ),

                    const SizedBox(height: 14),
                    _buildDetailRow(
                      context,
                      "Instructions:",
                      orderData['delivery_instructions'] ?? 'None',
                      icon: Icons.notes_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // FIXED: Proper date parsing for MySQL timestamps
  // MySQL driver may return DateTime object or String
  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();

    // If already DateTime, check if it needs timezone adjustment
    if (raw is DateTime) {
      // MySQL returns local time, but Dart might interpret it as UTC
      // We want to display the exact hours/minutes from DB
      // If the DateTime is UTC, it means the driver converted it
      // We need to "undo" that by treating the UTC time as local
      if (raw.isUtc) {
        // The DB stored 02:38, driver made it 02:38 UTC
        // But we want to show 02:38 local, so create local DateTime with same values
        return DateTime(
          raw.year,
          raw.month,
          raw.day,
          raw.hour,
          raw.minute,
          raw.second,
        );
      }
      return raw;
    }

    if (raw is String) {
      // Handle MySQL format: "2025-12-23 02:38:01" or with T: "2025-12-23T02:38:01"
      final sqlTs = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})');
      final match = sqlTs.firstMatch(raw);
      if (match != null) {
        return DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
          int.parse(match.group(6)!),
        );
      }

      // Try standard parsing
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        // Same logic - treat as local time
        return DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
        );
      }
      return DateTime.now();
    }

    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    if (raw is Map && raw.containsKey('seconds')) {
      final secs = raw['seconds'];
      if (secs is int) return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
    }

    return DateTime.now();
  }

  // Format full address - clean up N/A and duplicates
  String _formatFullAddress(Map<String, dynamic> orderData) {
    String baseAddress = orderData['shipping_address'] ?? 
                        orderData['address_Full'] ?? 
                        orderData['customer']?['address'] ?? 
                        '';
    
    // Clean up the base address - remove N/A parts
    baseAddress = baseAddress
        .replaceAll(RegExp(r',?\s*N/A'), '')
        .replaceAll(RegExp(r',?\s*Apt:\s*N/A'), '')
        .replaceAll(RegExp(r',?\s*Building:\s*N/A'), '')
        .replaceAll(RegExp(r',\s*,'), ',')  // Remove double commas
        .replaceAll(RegExp(r',\s*$'), '')   // Remove trailing comma
        .trim();
    
    final buildingInfo = orderData['building_info'] ?? 
                         orderData['buildingInfo'] ?? 
                         orderData['customer']?['building_info'];
    
    final apartmentNumber = orderData['apartment_number'] ?? 
                            orderData['apartmentNumber'] ?? 
                            orderData['customer']?['apartment_number'];
    
    // Build complete address
    List<String> parts = [];
    
    if (baseAddress.isNotEmpty) {
      parts.add(baseAddress);
    }
    
    if (buildingInfo != null && 
        buildingInfo.toString().isNotEmpty && 
        buildingInfo.toString() != 'N/A' &&
        !baseAddress.contains('Building: $buildingInfo')) {
      parts.add('Building: $buildingInfo');
    }
    
    if (apartmentNumber != null && 
        apartmentNumber.toString().isNotEmpty && 
        apartmentNumber.toString() != 'N/A' &&
        !baseAddress.contains('Apt: $apartmentNumber')) {
      parts.add('Apt: $apartmentNumber');
    }
    
    return parts.join(', ');
  }

  Widget _buildProductItem(BuildContext context, Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = widget.toDouble(item['price']);
    final quantity = item['quantity'] as int? ?? 1;

    final String imageUrlStr = (item['imageUrl'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    image: imageUrlStr.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(imageUrlStr),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrlStr.isEmpty
                      ? Icon(
                          Icons.image_not_supported,
                          color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.2),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] as String? ?? 'Product',
                        style: TextStyle(
                          fontFamily: 'TenorSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Qty: $quantity × \$${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'TenorSans',
                          fontSize: 13,
                          color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.7) : LuxuryTheme.kDeepNavy.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Total Price
                Text(
                  '\$${(price * quantity).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, dynamic value,
      {Color? color, IconData? icon, bool isAddress = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: isAddress ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.6) : LuxuryTheme.kDeepNavy.withOpacity(0.6)),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'TenorSans',
                fontSize: 13,
                color: isDark ? LuxuryTheme.kPlatinum.withOpacity(0.7) : LuxuryTheme.kDeepNavy.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontFamily: 'TenorSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? (isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy),
              ),
              textAlign: TextAlign.right,
              maxLines: isAddress ? 4 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(BuildContext context, List<Map<String, dynamic>> steps, String currentStatus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final isCompleted = _isStepCompleted(step['status'] as String, currentStatus);
                final isCurrent = step['status'] == currentStatus;
                final statusColor = _getStatusColor(step['status']);
                final icon = step['icon'] as IconData;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status Circle
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isCompleted
                              ? LinearGradient(
                                  colors: [statusColor, statusColor.withOpacity(0.7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isCompleted ? null : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                          border: Border.all(
                            color: isCompleted ? statusColor : (isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                            width: isCurrent ? 2.5 : 1.5,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            color: isCompleted ? Colors.white : (isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Status Label
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontFamily: 'TenorSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? statusColor : (isCompleted ? statusColor : (isDark ? LuxuryTheme.kPlatinum.withOpacity(0.7) : LuxuryTheme.kDeepNavy.withOpacity(0.7))),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  bool _isStepCompleted(String stepStatus, String currentStatus) {
    final statusOrder = ['Pending', 'Processing', 'Out for Delivery', 'Delivered'];
    final currentIdx = statusOrder.indexOf(currentStatus);
    final stepIdx = statusOrder.indexOf(stepStatus);
    return currentIdx >= stepIdx;
  }

  IconData _getDeliveryIcon(String deliveryOption) {
    if (deliveryOption.toLowerCase().contains('drone')) return Icons.flight;
    if (deliveryOption.toLowerCase().contains('express')) return Icons.flash_on;
    return Icons.two_wheeler;
  }

  String _normalizeStatus(String raw) {
    final s = raw.trim().toLowerCase();
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
      case 'processing':
        return 'Processing';
      case 'shipped':
      case 'out for delivery':
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return raw;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.lightBlue.shade600;
      case 'Processing':
        return Colors.blue.shade600;
      case 'Out for Delivery':
        return Colors.green.shade600;
      case 'Delivered':
        return Colors.green.shade700;
      default:
        return Colors.red.shade600;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Didot',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy,
      ),
    );
  }
}

/// Optimized Delivery Map Widget
class DeliveryMapWidget extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final TextStyle Function(BuildContext, double, {FontWeight weight, Color? color}) getTenorSansStyle;

  const DeliveryMapWidget({
    Key? key,
    required this.orderData,
    required this.getTenorSansStyle,
  }) : super(key: key);

  @override
  State<DeliveryMapWidget> createState() => _DeliveryMapWidgetState();
}

class _DeliveryMapWidgetState extends State<DeliveryMapWidget> {
  static const String MAPBOX_ACCESS_TOKEN =
      'pk.eyJ1IjoibW9oYW1tZWRhbGFuc2kiLCJhIjoiY21ncGF5OTI0MGU2azJpczloZjI0YXRtZCJ9.W9tMyxkXcai-sHajAwp8NQ';

  List<LatLng> _routePoints = [];
  String _eta = 'Calculating...';
  Timer? _updateTimer;
  final MapController _mapController = MapController();

  late LatLng customerLocation;
  LatLng? driverLocation;

  @override
  void initState() {
    super.initState();
    _initializeLocations();
    _startPeriodicUpdate();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _initializeLocations() {
    final double customerLat = (widget.orderData['location_Latitude'] as num?)?.toDouble() ?? 0.0;
    final double customerLon = (widget.orderData['location_Longitude'] as num?)?.toDouble() ?? 0.0;
    customerLocation = LatLng(customerLat, customerLon);
    driverLocation = _parseDriverLocation(widget.orderData['driverLocation']);
  }

  void _startPeriodicUpdate() {
    _fetchRouteAndEta();
    // Update every 20 seconds (not 15)
    _updateTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final id = (widget.orderData['id'] ?? widget.orderData['documentId'])?.toString();
        if (id == null) return;
        final latest = await ApiService.getOrderById(id);
        if (latest != null) {
          final parsed = _parseDriverLocation(latest['driverLocation']);
          if (parsed != null && mounted) {
            setState(() => driverLocation = parsed);
            _fetchRouteAndEta();
          }
        }
      } catch (_) {}
    });
  }

  LatLng? _parseDriverLocation(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      final lat = (raw['latitude'] ?? raw['lat']) as num?;
      final lon = (raw['longitude'] ?? raw['lng'] ?? raw['lon']) as num?;
      if (lat != null && lon != null) return LatLng(lat.toDouble(), lon.toDouble());
    }
    if (raw is List && raw.length >= 2) {
      final a = raw[0];
      final b = raw[1];
      if (a is num && b is num) return LatLng(a.toDouble(), b.toDouble());
    }
    return null;
  }

  Future<void> _fetchRouteAndEta() async {
    if (driverLocation == null) {
      if (mounted) {
        setState(() {
          _eta = 'Waiting for driver...';
          _routePoints = [];
        });
      }
      return;
    }

    final coordinates =
        '${driverLocation!.longitude},${driverLocation!.latitude};${customerLocation.longitude},${customerLocation.latitude}';
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/$coordinates?geometries=geojson&overview=full');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final durationInSeconds = route['duration'] as double;
          final minutes = (durationInSeconds / 60).ceil();

          final List<dynamic> coords = route['geometry']['coordinates'];
          final newRoutePoints = coords.map<LatLng>((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          if (mounted) {
            setState(() {
              _routePoints = newRoutePoints;
              _eta = '$minutes min';
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _eta = 'Route unavailable';
          _routePoints = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eta = 'Error';
          _routePoints = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng mapCenter = driverLocation != null
        ? LatLng(
            (driverLocation!.latitude + customerLocation.latitude) / 2,
            (driverLocation!.longitude + customerLocation.longitude) / 2,
          )
        : customerLocation;

    double initialZoom = driverLocation != null ? 14.0 : 12.0;

    return Column(
      children: [
        // ETA Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade600.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade600),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Estimated Arrival: $_eta',
                style: widget.getTenorSansStyle(context, 15, weight: FontWeight.bold)
                    .copyWith(color: Colors.green.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Map
        Container(
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: initialZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$MAPBOX_ACCESS_TOKEN',
                userAgentPackageName: 'com.yshop.customer.app',
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.shade600,
                      strokeWidth: 6.0,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Customer marker
                  Marker(
                    point: customerLocation,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 5, spreadRadius: 1),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'YOU',
                          style: widget.getTenorSansStyle(context, 14, weight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  // Driver marker
                  if (driverLocation != null)
                    Marker(
                      point: driverLocation!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.green.withOpacity(0.7), blurRadius: 10, spreadRadius: 2),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'YS',
                            style:
                                widget.getTenorSansStyle(context, 16, weight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
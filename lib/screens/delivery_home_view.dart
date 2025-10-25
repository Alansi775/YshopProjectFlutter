import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart'; // 💡 تم إضافة هذا الاستيراد لاستخدام firstWhereOrNull

import 'admin_login_view.dart'; 
import '../screens/sign_in_view.dart'; 

// 🚀 الاستيراد للملفات الأخرى
import 'delivery_qr_scanner_view.dart'; 
import 'map_of_delivery_man.dart'; // 💡 استيراد شاشة الخريطة

// --------------------------------------------------
// MARK: - Constants & Models
// --------------------------------------------------

const Color kDarkBackground = Color(0xFF1C1C1E); 
const Color kCardBackground = Color(0xFF2C2C2E); 
const Color kAppBarBackground = Color(0xFF1C1C1E); 
const Color kPrimaryTextColor = Colors.white; 
const Color kSecondaryTextColor = Colors.white70; 
const Color kSeparatorColor = Color(0xFF48484A); 
const Color kAccentBlue = Color(0xFF007AFF); 

// نموذج Item داخل الطلب
class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final String storeName;
  final String storeOwnerEmail;
  final String storePhone;
  final String imageUrl;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.storeName,
    required this.storeOwnerEmail,
    required this.storePhone,
    required this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      storeName: json['storeName'] ?? '',
      storeOwnerEmail: json['storeOwnerEmail'] ?? '',
      storePhone: json['storePhone'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

// نموذج بيانات طلب الموصل
class DeliveryRequest {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String nationalID;
  final String address;
  final String status;
  final bool isWorking;

  DeliveryRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.nationalID,
    required this.address,
    required this.status,
    this.isWorking = false,
  });
  
  factory DeliveryRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return DeliveryRequest(
      id: doc.id,
      name: data?["name"] as String? ?? "",
      email: data?["email"] as String? ?? "",
      phoneNumber: data?["phoneNumber"] as String? ?? "N/A",
      nationalID: data?["nationalID"] as String? ?? "N/A",
      address: data?["address"] as String? ?? "N/A",
      status: data?["status"] as String? ?? "Pending",
      isWorking: data?["isWorking"] as bool? ?? false,
    );
  }
}


// نموذج الطلبات (Orders)
class Order {
  final String id;
  final String userName;
  final String userPhone;
  final String userEmail;
  final String addressFull;
  final String addressDeliveryInstructions;
  final String addressBuilding;
  final String addressApartment;
  final String deliveryOption;
  final String status;
  final double total;
  final List<OrderItem> items;
  final double locationLatitude;
  final double locationLongitude;
  final bool driverAccepted;
  final String? driverId;

  Order({
    required this.id,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
    required this.addressFull,
    required this.addressDeliveryInstructions,
    required this.addressBuilding,
    required this.addressApartment,
    required this.deliveryOption,
    required this.status,
    required this.total,
    required this.items,
    required this.locationLatitude,
    required this.locationLongitude,
    this.driverAccepted = false,
    this.driverId,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    List<OrderItem> loadedItems = (data?['items'] as List?)
            ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
            .toList() ?? [];

    return Order(
      id: doc.id,
      userName: data?['userName'] ?? 'N/A',
      userPhone: data?['userPhone'] ?? 'N/A',
      userEmail: data?['userEmail'] ?? 'N/A',
      addressFull: data?['address_Full'] ?? 'N/A',
      addressDeliveryInstructions: data?['address_DeliveryInstructions'] ?? '',
      addressBuilding: data?['address_Building'] ?? '',
      addressApartment: data?['address_Apartment'] ?? '',
      deliveryOption: data?['deliveryOption'] ?? 'Standard',
      status: data?['status'] ?? 'Processing',
      total: (data?['total'] as num?)?.toDouble() ?? 0.0,
      locationLatitude: (data?['location_Latitude'] as num?)?.toDouble() ?? 0.0,
      locationLongitude: (data?['location_Longitude'] as num?)?.toDouble() ?? 0.0,
      items: loadedItems,
      driverAccepted: data?['driverAccepted'] ?? false,
      driverId: data?['driverId'] as String?,
    );
  }
}

// --------------------------------------------------
// MARK: - Delivery Home View (Dashboard)
// --------------------------------------------------

class DeliveryHomeView extends StatefulWidget {
  final String driverName;
  
  const DeliveryHomeView({super.key, required this.driverName});

  @override
  State<DeliveryHomeView> createState() => _DeliveryHomeViewState();
}

class _DeliveryHomeViewState extends State<DeliveryHomeView> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  bool _isWorking = false;
  DeliveryRequest? _driverProfile;

  @override
  void initState() {
    super.initState();
    _loadDriverStatus();
  }
  
  void _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SignInView()), 
        (Route<dynamic> route) => false,
      );
    }
  }

  void _loadDriverStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('deliveryRequests').doc(uid).get();
    if (doc.exists) {
      final data = doc.data();
      setState(() {
        _driverProfile = DeliveryRequest.fromFirestore(doc);
        _isWorking = data?['isWorking'] ?? false; 
      });
    } else {
      setState(() => _isWorking = false);
    }
  }

  void _toggleWorkingStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _driverProfile?.status != "Approved") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account is not approved yet.')),
      );
      return;
    }

    final newStatus = !_isWorking;
    
    try {
      await _firestore.collection('deliveryRequests').doc(uid).update({
        'isWorking': newStatus,
      });
      setState(() {
        _isWorking = newStatus;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update work status: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isApproved = _driverProfile?.status == "Approved";

    return Scaffold(
      backgroundColor: kDarkBackground,
      appBar: AppBar(
        title: const Text('Driver Dashboard', style: TextStyle(color: kPrimaryTextColor)),
        backgroundColor: kAppBarBackground,
        foregroundColor: kPrimaryTextColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          _buildProfileButton(context),
        ],
      ),
      body: Column(
        children: [
          _buildWorkingToggle(context, isApproved),
          
          if (_isWorking && isApproved)
            Expanded(child: _buildCurrentOrAvailableOrdersStream()), // 💡 التغيير في اسم الدالة
          
          if (!_isWorking && isApproved)
            const Expanded(
              child: Center(
                child: EmptyStateView(
                  icon: Icons.motorcycle,
                  title: "Let's Start Working!",
                  message: "Toggle the switch to start receiving order requests from restaurants.",
                ),
              ),
            ),
          
          if (!isApproved)
            const Expanded(
              child: Center(
                child: EmptyStateView(
                  icon: Icons.lock,
                  title: "Pending Approval",
                  message: "Your application is under review. You must be approved to work.",
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // MARK: - UI Components
  // --------------------------------------------------

  Widget _buildProfileButton(BuildContext context) {
    final initial = _driverProfile?.name.isNotEmpty == true 
        ? _driverProfile!.name[0].toUpperCase() 
        : widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : '?';

    return IconButton(
      icon: CircleAvatar(
        backgroundColor: kAccentBlue.withOpacity(0.2),
        child: Text(
          initial,
          style: const TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold),
        ),
      ),
      onPressed: () {
        if (_driverProfile != null) {
          _showProfileBottomSheet(context);
        }
      },
    );
  }

  Widget _buildWorkingToggle(BuildContext context, bool isApproved) {
    return Padding(
      padding: const EdgeInsets.all(16.0), 
      child: Material(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: isApproved ? _toggleWorkingStatus : null,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(20.0), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isWorking ? "You're Live! Taking Orders..." : "Let's Get Started!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isWorking ? Colors.green.shade400 : kPrimaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis, 
                  ),
                ),
                const SizedBox(width: 12), 
                CupertinoSwitch(
                  value: _isWorking,
                  onChanged: isApproved ? (val) => _toggleWorkingStatus() : null,
                  activeColor: Colors.green.shade400, 
                  trackColor: kSecondaryTextColor.withOpacity(0.3), 
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // --------------------------------------------------
  // MARK: - Order Stream (Orders in Progress OR New Available Orders) 💡
  // --------------------------------------------------
  
  Widget _buildCurrentOrAvailableOrdersStream() {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      return const EmptyStateView(
        icon: Icons.error_outline,
        title: "Auth Error",
        message: "Driver ID is missing.",
      );
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection("orders")
          .where("deliveryOption", isEqualTo: "Standard")
          .where("status", whereIn: ["Processing", "Out for Delivery"]) // البحث عن الحالتين
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CupertinoActivityIndicator(radius: 15, color: kAccentBlue)
          );
        }
        if (snapshot.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline,
            title: "Error",
            message: "Failed to load orders: ${snapshot.error}",
          );
        }

        final allOrders = snapshot.data?.docs.map(Order.fromFirestore).toList() ?? [];
        
        // 1. البحث أولاً عن الطلب المقبول حاليًا (في مرحلة التوصيل)
        final currentOrder = allOrders.firstWhereOrNull(
          (order) => order.driverId == driverId && order.status == "Out for Delivery"
        );
        
        if (currentOrder != null) {
          // 💡 وجد طلب في مرحلة التوصيل: إظهاره فقط مع زر "الذهاب للخريطة"
          return _buildCurrentDeliveryOrder(currentOrder, driverId);
        }
        
        // 2. إذا لم يكن هناك طلب مقبول، عرض الطلبات الجديدة المتاحة
        final availableOrders = allOrders.where(
          (order) => order.status == "Processing" && order.driverAccepted == false
        ).toList();

        if (availableOrders.isEmpty) {
          return const Center(
            child: EmptyStateView(
              icon: Icons.waving_hand,
              title: "Waiting for Orders",
              message: "No standard orders are currently awaiting a driver.",
            ),
          );
        }

        // عرض قائمة الطلبات الجديدة
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: availableOrders.length,
          itemBuilder: (context, index) {
            final order = availableOrders[index];
            return _OrderListItem(
              order: order,
              onTap: () => _navigateToOrderDetails(context, order, driverId),
            );
          },
        );
      },
    );
  }
  
  // --------------------------------------------------
  // MARK: - Helper Methods
  // --------------------------------------------------

  // دالة مخصصة للانتقال لصفحة تفاصيل الطلب
  void _navigateToOrderDetails(BuildContext context, Order order, String driverId) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => OrderDetailsView(
          order: order, 
          driverId: driverId,
          // تمرير الثوابت
          kDarkBackground: kDarkBackground,
          kCardBackground: kCardBackground,
          kAppBarBackground: kAppBarBackground,
          kPrimaryTextColor: kPrimaryTextColor,
          kSecondaryTextColor: kSecondaryTextColor,
          kSeparatorColor: kSeparatorColor,
          kAccentBlue: kAccentBlue,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  // 💡 إضافة دالة لعرض الطلب الحالي في مرحلة التوصيل
  Widget _buildCurrentDeliveryOrder(Order order, String driverId) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Current Delivery",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          _OrderListItem(
            order: order,
            // 💡 عند الضغط، انتقل مباشرة إلى الخريطة
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DeliveryMapView(
                    order: order,
                    kDarkBackground: kDarkBackground,
                    kCardBackground: kCardBackground,
                    kAppBarBackground: kAppBarBackground,
                    kPrimaryTextColor: kPrimaryTextColor,
                    kSecondaryTextColor: kSecondaryTextColor,
                    kSeparatorColor: kSeparatorColor,
                    kAccentBlue: kAccentBlue,
                  ),
                ),
              );
            },
            // 💡 إضافة زر مخصص للذهاب للخريطة
            trailingWidget: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DeliveryMapView(
                      order: order,
                      kDarkBackground: kDarkBackground,
                      kCardBackground: kCardBackground,
                      kAppBarBackground: kAppBarBackground,
                      kPrimaryTextColor: kPrimaryTextColor,
                      kSecondaryTextColor: kSecondaryTextColor,
                      kSeparatorColor: kSeparatorColor,
                      kAccentBlue: kAccentBlue,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.map, color: kAccentBlue),
              label: Text("Go to Map", style: TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold)),
              
            ),
          ),
          const SizedBox(height: 16),
          const EmptyStateView(
            icon: Icons.info_outline,
            title: "Focus on Delivery",
            message: "You must complete the current delivery before accepting a new order.",
          )
        ],
      ),
    );
  }
  
  void _showProfileBottomSheet(BuildContext context) {
    if (_driverProfile == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kDarkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _DriverProfileSheet(profile: _driverProfile!, onLogout: _logout);
      },
    );
  }
}

// --------------------------------------------------
// MARK: - Utility Widgets (Shared)
// --------------------------------------------------

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: kSecondaryTextColor,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: kPrimaryTextColor),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: kSecondaryTextColor),
          ),
        ],
      ),
    );
  }
}

class StatusBadgeView extends StatelessWidget {
  final String status;

  const StatusBadgeView({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;

    switch (status) {
      case "Pending":
        color = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.2);
        break;
      case "Approved":
        color = Colors.green;
        bgColor = Colors.green.withOpacity(0.2);
        break;
      case "Rejected":
        color = Colors.red;
        bgColor = Colors.red.withOpacity(0.2);
        break;
      case "Processing":
        color = kAccentBlue;
        bgColor = kAccentBlue.withOpacity(0.2);
        break;
      case "Out for Delivery":
        color = kAccentBlue;
        bgColor = kAccentBlue.withOpacity(0.2);
        break;
      case "Delivered":
        color = Colors.green;
        bgColor = Colors.green.withOpacity(0.2);
        break;
      default:
        color = kSecondaryTextColor;
        bgColor = kSecondaryTextColor.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget { 
  final String label;
  final String value;
  final bool isMultiline;
  final TextAlign valueAlignment;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.isMultiline = false,
    this.valueAlignment = TextAlign.end, 
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryTextColor),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: valueAlignment,
              style: const TextStyle(color: kSecondaryTextColor),
              maxLines: isMultiline ? null : 1, 
              overflow: isMultiline ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// MARK: - Nested Components (Private)
// --------------------------------------------------

class _DriverProfileSheet extends StatelessWidget {
  final DeliveryRequest profile;
  final VoidCallback onLogout; 
  
  const _DriverProfileSheet({required this.profile, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final initial = profile.name[0].toUpperCase();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0, bottom: 40.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("Driver Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
          const Divider(color: kSeparatorColor, height: 20),
          
          CircleAvatar(
            radius: 40,
            backgroundColor: kAccentBlue.withOpacity(0.4),
            child: Text(initial, style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          
          Text(profile.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
          StatusBadgeView(status: profile.status),
          
          const SizedBox(height: 24),
          
          _DetailSection(
            title: "Personal Information",
            children: [
              DetailRow(label: "Email", value: profile.email),
              DetailRow(label: "Phone", value: profile.phoneNumber),
              DetailRow(label: "National ID", value: profile.nationalID),
              DetailRow(label: "Address", value: profile.address, isMultiline: true, valueAlignment: TextAlign.start),
            ],
          ),
          
          const SizedBox(height: 32),
          
          TextButton(
            onPressed: onLogout,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Logout",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.logout, size: 20, color: Colors.red),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kAccentBlue,
          ),
        ),
        const Divider(color: kSeparatorColor, height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kCardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _OrderListItem extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final Widget? trailingWidget; // 💡 تم إضافة هذا الحقل

  const _OrderListItem({required this.order, required this.onTap, this.trailingWidget});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kCardBackground,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.id.substring(0, 8)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadgeView(status: order.status),
                  Text(
                    "Total: \$${order.total.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(color: kSeparatorColor),
              DetailRow(label: "Pick up from", value: order.items.first.storeName, valueAlignment: TextAlign.start),
              DetailRow(label: "Deliver to", value: order.userName, valueAlignment: TextAlign.start),
              
              if (trailingWidget != null) // 💡 عرض الزر إذا تم تمريره
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: trailingWidget!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
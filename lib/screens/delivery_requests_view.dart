// lib/screens/delivery_requests_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home_view.dart'; // لاستيراد الألوان والنماذج (DeliveryRequest)

// --------------------------------------------------
// MARK: - Delivery Requests View
// --------------------------------------------------

class DeliveryRequestsView extends StatefulWidget {
  const DeliveryRequestsView({super.key});

  @override
  State<DeliveryRequestsView> createState() => _DeliveryRequestsViewState();
}

class _DeliveryRequestsViewState extends State<DeliveryRequestsView> {
  // مفتاح لتحديث محتوى StreamBuilder
  Key _deliveryRequestKey = UniqueKey();

  void _refreshData() {
    setState(() {
      _deliveryRequestKey = UniqueKey();
    });
  }

  // --------------------------------------------------
  // MARK: - Actions (قبول، رفض، تعليق)
  // --------------------------------------------------

  // 💡 تحديث حالة طلب الموصل
  void _updateDriverStatus(DeliveryRequest request, String status) async {
    final docRef = FirebaseFirestore.instance.collection("deliveryRequests").doc(request.id);
    
    try {
      if (status == "Rejected") {
        // 🚀 إذا كانت الحالة رفض، يتم حذف المستند بالكامل (كما طلبت)
        await docRef.delete();
      } else {
        // إذا كانت الحالة قبول أو تعليق (Pending/Approved)
        await docRef.update({
          "status": status,
        });
      }
      _refreshData();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Failed to update status: $e')),
       );
    }
  }

  // --------------------------------------------------
  // MARK: - Build Method
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBackground,
      appBar: AppBar(
        title: const Text('Manage Driver Requests', style: TextStyle(color: kPrimaryTextColor)),
        backgroundColor: kAppBarBackground,
        foregroundColor: kPrimaryTextColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _buildRequestStream(context),
    );
  }
  
  // --------------------------------------------------
  // MARK: - Firebase Stream
  // --------------------------------------------------

  Widget _buildRequestStream(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      key: _deliveryRequestKey,
      // سحب جميع الطلبات (Pending و Approved و Rejected)
      stream: FirebaseFirestore.instance
          .collection("deliveryRequests")
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAccentBlue));
        }
        if (snapshot.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline,
            title: "Error",
            message: "Failed to load requests: ${snapshot.error}",
          );
        }

        final requests = snapshot.data?.docs.map(DeliveryRequest.fromFirestore).toList() ?? [];
        
        if (requests.isEmpty) {
          return const Center(
            child: EmptyStateView(
              icon: Icons.motorcycle,
              title: "No Driver Requests",
              message: "There are no pending or active driver requests.",
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _DriverRequestCard(
              request: request,
              onApprove: () => _updateDriverStatus(request, "Approved"),
              onReject: () => _updateDriverStatus(request, "Rejected"),
              onRevert: () => _updateDriverStatus(request, "Pending"),
            );
          },
        );
      },
    );
  }
}

// --------------------------------------------------
// MARK: - Nested Component: Driver Card
// --------------------------------------------------

class _DriverRequestCard extends StatelessWidget {
  final DeliveryRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRevert;

  const _DriverRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onRevert,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = request.status == "Approved";
    
    return Card(
      color: kCardBackground,
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. العنوان والحالة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryTextColor),
                ),
                StatusBadgeView(status: request.status),
              ],
            ),
            const Divider(color: kSeparatorColor, height: 20),

            // 2. التفاصيل الأساسية
            _DetailRow(label: "Email", value: request.email),
            _DetailRow(label: "Phone", value: request.phoneNumber),
            _DetailRow(label: "National ID", value: request.nationalID),
            _DetailRow(label: "Address", value: request.address, isMultiline: true),

            const Divider(color: kSeparatorColor, height: 20),

            // 3. أزرار الإجراءات
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // زر الرفض (Reject)
                _ActionButton(
                  label: "Reject",
                  color: Colors.red,
                  onPressed: onReject,
                ),
                const SizedBox(width: 8),
                
                // زر إعادة التعليق/القبول
                if (isApproved)
                  _ActionButton(
                    label: "Pending",
                    color: Colors.orange,
                    onPressed: onRevert,
                  )
                else
                  _ActionButton(
                    label: "Approve",
                    color: Colors.green,
                    onPressed: onApprove,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// MARK: - Shared Utility Widgets (Add these if missing)
// --------------------------------------------------

// يجب إضافة هذه الودجتس في admin_home_view.dart إذا لم تكن موجودة بعد
// وإلا، يجب استيرادها من ملف آخر مشترك. سنضيفها هنا للتوثيق.

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;
  final TextAlign valueAlignment;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
    this.valueAlignment = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: kSecondaryTextColor, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: valueAlignment,
              style: const TextStyle(color: kPrimaryTextColor, fontSize: 14),
              maxLines: isMultiline ? 10 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

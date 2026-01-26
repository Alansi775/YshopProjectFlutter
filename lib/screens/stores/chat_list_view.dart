import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state_management/auth_manager.dart';
// يجب استيراد نموذج ProductS من هنا الآن
import '../../widgets/store_admin_widgets.dart'; 
import './chat_view.dart';  
// Chat functionality will be migrated to Backend API


//----------------------------------------------------------------------
// MARK: - 1. نماذج البيانات (تبقى كما هي)
//----------------------------------------------------------------------

//  نموذج بيانات المحادثة (Chat)
class ChatModel {
  final String id;
  final String productID;
  final String productName;
  final String productImageUrl;
  final String storeOwnerID;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String customerID; 

  ChatModel({
    required this.id,
    required this.productID,
    required this.productName,
    required this.productImageUrl,
    required this.storeOwnerID,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.customerID,
  });

  // تحويل من JSON (Backend API)
  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id']?.toString() ?? '',
      productID: json['productID'] ?? json['product_id'] ?? '',
      productName: json['productName'] ?? json['product_name'] ?? 'Deleted Product',
      productImageUrl: json['productImageUrl'] ?? json['product_image_url'] ?? '',
      storeOwnerID: json['storeOwnerID'] ?? json['store_owner_id'] ?? '',
      lastMessage: json['lastMessage'] ?? json['last_message'] ?? 'Start a conversation.',
      customerID: json['customerID'] ?? json['customer_id'] ?? '',
      lastMessageTime: _parseDateTime(json['timestamp'] ?? json['last_message_time']) ?? DateTime.now(),
    );
  }
}

// Helper function to parse DateTime
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}


//----------------------------------------------------------------------
// MARK: - 2. واجهة المستخدم (ChatListView)
//----------------------------------------------------------------------

class ChatListView extends StatelessWidget {
  final String storeOwnerID;
  
  const ChatListView({super.key, required this.storeOwnerID});
  
  //  دالة مساعدة لخط "TenorSans" (معدلة لاستقبال context)
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return TextStyle(
      fontFamily: 'TenorSans', 
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor,
    );
  }


  @override
  Widget build(BuildContext context) {
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    const double maxWidth = 600.0;

    return Scaffold(
      appBar: AppBar(
        title: Text("Customer Messages", style: _getTenorSansStyle(context, 20)),
        centerTitle: true,
        //  استخدام الألوان الديناميكية من الثيم
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, 
        foregroundColor: primaryColor, 
        elevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message, size: 50, color: secondaryColor.withOpacity(0.2)), 
                const SizedBox(height: 10),
                Text(
                  "Chat feature is being set up.",
                  style: _getTenorSansStyle(context, 16).copyWith(color: secondaryColor.withOpacity(0.7)),
                ),
                const SizedBox(height: 8),
                Text(
                  "Backend API integration in progress",
                  style: _getTenorSansStyle(context, 12).copyWith(color: secondaryColor.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//----------------------------------------------------------------------
// MARK: - 3. ودجت عرض المحادثة (ChatCard)
//----------------------------------------------------------------------

class ChatCard extends StatelessWidget {
  final ChatModel chat;
  final String currentUserID;
  final VoidCallback onTap;

  const ChatCard({
    super.key,
    required this.chat,
    required this.currentUserID,
    required this.onTap,
  });
  
  //  دالة مساعدة لخط "TenorSans"
  TextStyle _getTenorSansStyle(BuildContext context, double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return TextStyle(
      fontFamily: 'TenorSans', 
      fontSize: size,
      fontWeight: weight,
      color: color ?? primaryColor,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final date = DateTime(time.year, time.month, time.day);

    if (date == today) {
      return DateFormat('h:mm a').format(time);
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    //  جلب الألوان الديناميكية
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    final formattedTime = _formatTime(chat.lastMessageTime);
    
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: chat.productImageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 50, height: 50, 
            //  لون ديناميكي خفيف
            color: secondaryColor.withOpacity(0.1), 
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: secondaryColor.withOpacity(0.5)))),
          ),
          errorWidget: (context, url, error) => Container(
            width: 50, height: 50, 
            //  لون ديناميكي خفيف
            color: secondaryColor.withOpacity(0.1), 
            //  استخدام secondaryColor للأيقونة
            child: Icon(Icons.shopping_bag, size: 24, color: secondaryColor.withOpacity(0.5)),
          ),
        ),
      ),
      
      title: Text(
        chat.productName,
        //  استخدام primaryColor للعنوان
        style: _getTenorSansStyle(context, 16, weight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        chat.lastMessage,
        //  استخدام secondaryColor للرسالة
        style: _getTenorSansStyle(context, 14).copyWith(color: secondaryColor.withOpacity(0.7)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formattedTime,
            //  استخدام secondaryColor للوقت
            style: _getTenorSansStyle(context, 12, weight: FontWeight.w500).copyWith(color: secondaryColor.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}
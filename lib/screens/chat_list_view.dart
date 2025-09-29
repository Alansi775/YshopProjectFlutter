import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
// يجب استيراد نموذج ProductS من هنا الآن
import '../widgets/store_admin_widgets.dart'; 
import 'chat_view.dart';  


//----------------------------------------------------------------------
// MARK: - 1. نماذج البيانات (تم تصحيح اسم حقل الوقت)
//----------------------------------------------------------------------

//  نموذج بيانات المحادثة (Chat)
class ChatModel {
  final String id;
  final String productID;
  final String productName;
  final String productImageUrl;
  final String storeOwnerID;
  final String lastMessage;
  final Timestamp lastMessageTime;
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

  // 💡 تحويل من Firestore
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      productID: data['productID'] as String? ?? '',
      productName: data['productName'] as String? ?? 'Deleted Product',
      productImageUrl: data['productImageUrl'] as String? ?? '',
      storeOwnerID: data['storeOwnerID'] as String? ?? '',
      lastMessage: data['lastMessage'] as String? ?? 'Start a conversation.',
      customerID: data['customerID'] as String? ?? '',
      //  التصحيح: استخدام 'timestamp' من Firestore
      lastMessageTime: data['timestamp'] as Timestamp? ?? Timestamp.now(), 
      
    );
  }
}

//  يتم استيراد ProductS الآن من 'store_admin_widgets.dart' لذا لن نضعه هنا مجددًا.


//----------------------------------------------------------------------
// MARK: - 2. واجهة المستخدم (ChatListView)
//----------------------------------------------------------------------

class ChatListView extends StatelessWidget {
  final String storeOwnerID;
  
  const ChatListView({super.key, required this.storeOwnerID});

  @override
  Widget build(BuildContext context) {
    const double maxWidth = 600.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Messages"),
        centerTitle: true,
        //  التصحيح: لون خلفية App Bar أبيض
        backgroundColor: Colors.white,
        // لون النص والأيقونات يكون اللون الأساسي أو الأسود
        foregroundColor: Theme.of(context).colorScheme.primary, 
        elevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: StreamBuilder<QuerySnapshot>(
            //  التصحيح: استخدام حقل 'timestamp' للترتيب
            stream: FirebaseFirestore.instance
                .collection("chats")
                .where("storeOwnerID", isEqualTo: storeOwnerID)
               // .orderBy("timestamp", descending: true)
                .snapshots(),
            
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message, size: 50, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      const Text(
                        "No customer messages yet.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final chats = snapshot.data!.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();

              return ListView.separated(
                itemCount: chats.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 80, endIndent: 16),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return ChatCard(
                    chat: chat,
                    currentUserID: storeOwnerID,
                    onTap: () {
                      final product = ProductS(
                        id: chat.productID,
                        name: chat.productName,
                        price: "", description: "", imageUrl: chat.productImageUrl,
                        storeOwnerEmail: chat.storeOwnerID, storeName: "",
                        approved: true, status: "", storePhone: "",
                        customerID: chat.customerID,
                      );
                      
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChatView(
                            // 💡 يجب إعادة تكوين الـ chatID بنفس منطق العميل للتأكد من الثبات
                            // يجب أن نستخرج customerID من وثيقة المحادثة
                            chatID: chat.id, // سنبقيها chat.id بما أننا وثقنا توحيدها الآن
                            product: product,
                            currentUserID: storeOwnerID, // معرّف صاحب المتجر
                            isStoreOwner: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
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
    final formattedTime = _formatTime(chat.lastMessageTime.toDate());
    
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
            width: 50, height: 50, color: Colors.grey.shade200,
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          errorWidget: (context, url, error) => Container(
            width: 50, height: 50, color: Colors.grey.shade200,
            child: const Icon(Icons.shopping_bag, size: 24, color: Colors.grey),
          ),
        ),
      ),
      
      title: Text(
        chat.productName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        chat.lastMessage,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formattedTime,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
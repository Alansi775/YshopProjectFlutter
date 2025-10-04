import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // للتمرير التلقائي للأسفل
import 'package:firebase_auth/firebase_auth.dart'; // لإضافة Firebase Auth
import '../widgets/store_admin_widgets.dart'; // لاستخدام ProductS

//----------------------------------------------------------------------
// MARK: - نماذج البيانات (تبقى كما هي)
//----------------------------------------------------------------------

//  نموذج بيانات الرسالة (Message)
class MessageModel {
  final String id;
  final String text;
  final String senderID;
  final Timestamp timestamp;

  MessageModel({
    required this.id,
    required this.text,
    required this.senderID,
    required this.timestamp,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      text: data['text'] as String? ?? '',
      senderID: data['senderID'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(), 
    );
  }
}

//----------------------------------------------------------------------
// MARK: - الشاشة الرئيسية (ChatView)
//----------------------------------------------------------------------

class ChatView extends StatefulWidget {
  final String chatID;
  final ProductS product;
  final String currentUserID; 
  final bool isStoreOwner;

  const ChatView({
    super.key,
    required this.chatID,
    required this.product,
    required this.currentUserID,
    required this.isStoreOwner,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _scrollController = ItemScrollController(); 
  
  bool _isCurrentUser(MessageModel message) {
    return message.senderID == widget.currentUserID; 
  }

  // --------------------------------------------------
  // MARK: - وظيفة الإرسال (تبقى كما هي)
  // --------------------------------------------------
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final messageToSend = text; 
    _messageController.clear(); 

    final chatRef = FirebaseFirestore.instance.collection("chats").doc(widget.chatID);

    final String finalCustomerID = widget.isStoreOwner 
        ? widget.product.customerID 
        : widget.currentUserID;     

    final String finalStoreOwnerID = widget.isStoreOwner 
        ? widget.currentUserID 
        : widget.product.storeOwnerEmail;

    if (finalCustomerID.isEmpty || finalStoreOwnerID.isEmpty) {
        print("Error: CustomerID (${finalCustomerID}) or StoreOwnerID (${finalStoreOwnerID}) is missing.");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Cannot send message: Missing user information.')),
           );
        }
       return;
    }

    try {
        final Timestamp currentTimestamp = Timestamp.now();
        
        await chatRef.set({
          'lastMessage': messageToSend,
          'timestamp': FieldValue.serverTimestamp(), 
          'customerID': finalCustomerID, 
          'storeOwnerID': finalStoreOwnerID,
          'productName': widget.product.name,
          'productID': widget.product.id,
          'productImageUrl': widget.product.imageUrl, 
        }, SetOptions(merge: true));

        await chatRef.collection("messages").add({
          'text': messageToSend,
          'senderID': widget.currentUserID, 
          'timestamp': currentTimestamp, 
        });

    } catch (e) {
        print("Error sending message: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed to send message: ${e.toString()}')),
           );
        }
    }
  }

  // --------------------------------------------------
  // MARK: - Build Widget
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        centerTitle: false,
        elevation: 1,
        // 💡 استخدام الألوان الديناميكية من الثيم
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, 
        foregroundColor: primaryColor,
      ),
      body: Center(
        child: Column(
          children: [
            // 1. قائمة الرسائل (StreamBuilder)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("chats")
                    .doc(widget.chatID)
                    .collection("messages")
                    .orderBy('timestamp', descending: false) 
                    .snapshots(),
                
                builder: (context, snapshot) {
                  
                  if (snapshot.hasError) {
                    // 💡 استخدام primaryColor للنص
                    return Center(child: Text('Error: ${snapshot.error.toString()}\nCheck Firestore Rules and Chat IDs.', style: TextStyle(color: primaryColor)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // 💡 استخدام primaryColor للمؤشر
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  
                  final messages = snapshot.data!.docs
                      .map((doc) => MessageModel.fromFirestore(doc))
                      .toList();
                  
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (messages.isNotEmpty && _scrollController.isAttached) { // 💡 إضافة تحقق من isAttached
                      _scrollController.scrollTo(
                        index: messages.length - 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        alignment: 0,
                      );
                    }
                  });

                  return ScrollablePositionedList.builder(
                    itemCount: messages.length,
                    itemScrollController: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    reverse: false, 
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      
                      return MessageBubble(
                        message: message,
                        isCurrentUser: _isCurrentUser(message),
                      );
                    },
                  );
                },
              ),
            ),
            
            // 2. حقل إرسال الرسالة
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // MARK: - ودجت حقل الإدخال
  // --------------------------------------------------
  Widget _buildMessageComposer() {
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color inputFillColor = Theme.of(context).brightness == Brightness.light 
        ? Colors.grey.shade100 
        : Colors.grey.shade800; // لون خلفية الحقل الداكن

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        // 💡 استخدام لون خلفية النظام أو الـ CardColor
        color: Theme.of(context).cardColor, 
        // 💡 استخدام DividerColor
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (value) => _sendMessage(), 
              style: TextStyle(color: primaryColor), // 💡 لون النص
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)), // 💡 لون التلميح
                fillColor: inputFillColor, // 💡 لون خلفية الحقل الديناميكي
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          
          // زر الإرسال
          // 💡 استخدام primaryColor لزر الإرسال
          FloatingActionButton.small(
            heroTag: "send_button",
            onPressed: _sendMessage,
            backgroundColor: primaryColor, 
            foregroundColor: Theme.of(context).colorScheme.onPrimary, // لون الأيقونة
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

//----------------------------------------------------------------------
// MARK: - فقاعة الرسالة (MessageBubble)
//----------------------------------------------------------------------

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    // 💡 جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    final alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    
    // 💡 تعديل ألوان الخلفية والنص
    final Color bubbleColor = isCurrentUser 
        ? primaryColor // لون الفقاعة للمرسل هو اللون الأساسي
        : Theme.of(context).brightness == Brightness.light 
            ? Colors.grey.shade300 // رمادي فاتح للثيم الفاتح
            : Colors.grey.shade700; // رمادي غامق للثيم الداكن

    final Color textColor = isCurrentUser 
        ? Theme.of(context).colorScheme.onPrimary // لون النص للمرسل هو لون التباين الأساسي (عادة الأبيض)
        : secondaryColor; // لون النص للمستقبل هو لون النص الطبيعي للنظام (أسود/أبيض)
    
    // 💡 لون وقت الرسالة
    final Color timeColor = secondaryColor.withOpacity(0.5);

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: isCurrentUser ? const Radius.circular(15) : const Radius.circular(3),
                bottomRight: isCurrentUser ? const Radius.circular(3) : const Radius.circular(15),
              ),
              boxShadow: [
                // 💡 استخدام primaryColor للظل (بشفافية عالية لتجنب الظل القوي في الثيم الداكن)
                BoxShadow(
                  color: primaryColor.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 15),
            ),
          ),
          //  وقت الرسالة أسفل الفقاعة
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
            child: Text(
              '${message.timestamp.toDate().hour}:${message.timestamp.toDate().minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10, color: timeColor),
            ),
          ),
        ],
      ),
    );
  }
}
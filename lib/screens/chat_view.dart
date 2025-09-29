import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // للتمرير التلقائي للأسفل
import 'package:firebase_auth/firebase_auth.dart'; // لإضافة Firebase Auth
import '../widgets/store_admin_widgets.dart'; // لاستخدام ProductS

//----------------------------------------------------------------------
// MARK: - نماذج البيانات
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
  final String currentUserID; // معرّف صاحب المتجر أو العميل (UID أو Email)
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
  // MARK: - وظيفة الإرسال (التصحيح النهائي والحاسم)
  // --------------------------------------------------
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final messageToSend = text; 
    _messageController.clear(); 

    final chatRef = FirebaseFirestore.instance.collection("chats").doc(widget.chatID);

    // 1. تحديد المعرّفات بناءً على الدور والقيم المُمررة
    
    // إذا كنت عميلاً (isStoreOwner=false): finalCustomerID = UID الحالي.
    // إذا كنت متجراً (isStoreOwner=true): finalCustomerID = customerID المُمرر من ChatListView (وهو UID العميل).
    final String finalCustomerID = widget.isStoreOwner 
        ? widget.product.customerID 
        : widget.currentUserID;     

    // إذا كنت عميلاً (isStoreOwner=false): finalStoreOwnerID = Email المتجر (من بيانات المنتج).
    // إذا كنت متجراً (isStoreOwner=true): finalStoreOwnerID = Email الحالي للمتجر (currentUserID).
    final String finalStoreOwnerID = widget.isStoreOwner 
        ? widget.currentUserID 
        : widget.product.storeOwnerEmail;

    // 🚨 التحقق النهائي: إذا كان أي من المعرّفين فارغاً، لن نرسل الرسالة (هذا لمنع خطأ الصلاحيات الدائم)
    if (finalCustomerID.isEmpty || finalStoreOwnerID.isEmpty) {
        print("Error: CustomerID (${finalCustomerID}) or StoreOwnerID (${finalStoreOwnerID}) is missing.");
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Cannot send message: Missing user information.')),
         );
       return;
    }

    try {
        final Timestamp currentTimestamp = Timestamp.now();
        
        // 2. تحديث وثيقة المحادثة الرئيسية (لتحافظ على المعرّفات الصحيحة)
        await chatRef.set({
          'lastMessage': messageToSend,
          'timestamp': FieldValue.serverTimestamp(), 
          'customerID': finalCustomerID, 
          'storeOwnerID': finalStoreOwnerID,
          'productName': widget.product.name,
          'productID': widget.product.id,
          // 💡 إضافة حقل imageUrl (لتحسين عرض ChatListView)
          'productImageUrl': widget.product.imageUrl, 
        }, SetOptions(merge: true));

        // 3. إضافة الرسالة الجديدة
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        centerTitle: false,
        elevation: 1,
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
                  // 🛑 إذا كان هناك خطأ، اعرضه. هذا هو التحقق من الصلاحيات.
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error.toString()}\nCheck Firestore Rules and Chat IDs.'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final messages = snapshot.data!.docs
                      .map((doc) => MessageModel.fromFirestore(doc))
                      .toList();
                  
                  // التمرير التلقائي للأسفل
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (messages.isNotEmpty) {
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
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            onSubmitted: (value) => _sendMessage(), 
            decoration: InputDecoration(
              hintText: "Type a message...",
              fillColor: Colors.grey.shade100,
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
        FloatingActionButton.small(
          heroTag: "send_button",
          onPressed: _sendMessage,
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
    final alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isCurrentUser ? Theme.of(context).colorScheme.primary : Colors.grey.shade300;
    final textColor = isCurrentUser ? Colors.white : Colors.black87;

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: isCurrentUser ? const Radius.circular(15) : const Radius.circular(3),
                bottomRight: isCurrentUser ? const Radius.circular(3) : const Radius.circular(15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
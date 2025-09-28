// هذي
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // 🚀 للتمرير التلقائي للأسفل
import 'package:firebase_auth/firebase_auth.dart'; // 💡 لإضافة Firebase Auth
import '../widgets/store_admin_widgets.dart'; // لاستخدام ProductS

//----------------------------------------------------------------------
// MARK: - نماذج البيانات
//----------------------------------------------------------------------

// 💡 نموذج بيانات الرسالة (Message)
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
      // يجب أن يكون 'timestamp' قابلاً للـ null ويتم التعامل معه
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
  final String currentUserID; // معرّف صاحب المتجر أو العميل
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
  // 🚀 أداة تحكم للتمرير التلقائي
  final ItemScrollController _scrollController = ItemScrollController(); 
  
  // 💡 مفتاح لتحديد المراسِل (يُفضل استخدام UID إذا كان العميل/المالك يستخدمه)
  bool _isCurrentUser(MessageModel message) {
    // نعتمد على أن widget.currentUserID هو معرّف فريد (سواء UID أو Email)
    return message.senderID == widget.currentUserID; 
  }

  // --------------------------------------------------
  // MARK: - وظيفة الإرسال (مُعاد تنظيمها)
  // --------------------------------------------------
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final messageToSend = text; 
    _messageController.clear(); // مسح حقل الإدخال فوراً

    final chatRef = FirebaseFirestore.instance.collection("chats").doc(widget.chatID);
    
    try {
        // 1. إضافة الرسالة الجديدة
        await chatRef.collection("messages").add({
          'text': messageToSend,
          'senderID': widget.currentUserID, 
          'timestamp': FieldValue.serverTimestamp(), 
        });

        // 2. تحديث وثيقة المحادثة الرئيسية بآخر رسالة ووقتها
        await chatRef.update({
          'lastMessage': messageToSend,
          'timestamp': FieldValue.serverTimestamp(), 
        });

    } catch (e) {
        print("Error sending message: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed to send message: $e')),
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
                // 💡 جلب الرسائل بترتيب زمني تصاعدي (الأقدم أولاً)
                stream: FirebaseFirestore.instance
                    .collection("chats")
                    .doc(widget.chatID)
                    .collection("messages")
                    .orderBy('timestamp', descending: false) 
                    .snapshots(),
                
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final messages = snapshot.data!.docs
                      .map((doc) => MessageModel.fromFirestore(doc))
                      .toList();
                  
                  // 💡 التمرير التلقائي للأسفل إلى الرسالة الأخيرة
                  // يتم تنفيذه بعد كل تحديث للـ Stream
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (messages.isNotEmpty) {
                      _scrollController.scrollTo(
                        index: messages.length - 1, // التمرير إلى آخر عنصر
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        alignment: 0,
                      );
                    }
                  });

                  // 🚀 استخدام ScrollablePositionedList للعرض السلس
                  return ScrollablePositionedList.builder(
                    itemCount: messages.length,
                    itemScrollController: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    // نترك reverse: false لأننا نجلب الأقدم أولاً ونستخدم ScrollTo
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
            // 🚀 الإضافة هنا: تشغيل دالة الإرسال عند الضغط على Enter
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
    // محاذاة الرسالة: اليمين إذا كان المستخدم الحالي، اليسار إذا كان الطرف الآخر
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
                // زاوية صغيرة حادة لفقاعة المرسل (اليمين)
                bottomLeft: isCurrentUser ? const Radius.circular(15) : const Radius.circular(3),
                // زاوية صغيرة حادة لفقاعة المستقبل (اليسار)
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
          // 💡 وقت الرسالة أسفل الفقاعة
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
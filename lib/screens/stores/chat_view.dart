import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // للتمرير التلقائي للأسفل
import 'package:provider/provider.dart';
import '../../state_management/auth_manager.dart';
import '../../widgets/store_admin_widgets.dart'; // لاستخدام ProductS
// Chat functionality will be migrated to Backend API

//----------------------------------------------------------------------
// MARK: - نماذج البيانات (تبقى كما هي)
//----------------------------------------------------------------------

//  نموذج بيانات الرسالة (Message)
class MessageModel {
  final String id;
  final String text;
  final String senderID;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.text,
    required this.senderID,
    required this.timestamp,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      text: json['text'] as String? ?? '',
      senderID: json['senderID'] as String? ?? json['sender_id'] as String? ?? '',
      timestamp: _parseDateTime(json['timestamp']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'senderID': senderID,
    'timestamp': timestamp.toIso8601String(),
  };
}

// Helper function to parse DateTime
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
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
  // MARK: - وظيفة الإرسال (متوافقة مع Backend API)
  // --------------------------------------------------
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final messageToSend = text; 
    _messageController.clear(); 

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
        // TODO: Implement Backend chat API endpoint
        // For now, store message locally in memory or SharedPreferences
        // Expected Backend endpoint: POST /api/v1/chats/{chatID}/messages
        // Request body:
        // {
        //   "text": messageToSend,
        //   "senderID": widget.currentUserID,
        // }
        
        print("📨 Message to be sent: '$messageToSend' from '$finalCustomerID' to '$finalStoreOwnerID'");
        
        // Placeholder: Show success message
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Message sent (Backend integration pending)')),
           );
        }

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
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        centerTitle: false,
        elevation: 1,
        //  استخدام الألوان الديناميكية من الثيم
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, 
        foregroundColor: primaryColor,
      ),
      body: Center(
        child: Column(
          children: [
            // 1. قائمة الرسائل (Placeholder - Backend integration pending)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mail_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chat will be available soon',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Backend chat API is being set up',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
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
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color inputFillColor = Theme.of(context).brightness == Brightness.light 
        ? Colors.grey.shade100 
        : Colors.grey.shade800; // لون خلفية الحقل الداكن

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        //  استخدام لون خلفية النظام أو الـ CardColor
        color: Theme.of(context).cardColor, 
        //  استخدام DividerColor
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (value) => _sendMessage(), 
              style: TextStyle(color: primaryColor), //  لون النص
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)), //  لون التلميح
                fillColor: inputFillColor, //  لون خلفية الحقل الديناميكي
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
          //  استخدام primaryColor لزر الإرسال
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
    //  جلب الألوان الديناميكية
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface;
    
    final alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    
    //  تعديل ألوان الخلفية والنص
    final Color bubbleColor = isCurrentUser 
        ? primaryColor // لون الفقاعة للمرسل هو اللون الأساسي
        : Theme.of(context).brightness == Brightness.light 
            ? Colors.grey.shade300 // رمادي فاتح للثيم الفاتح
            : Colors.grey.shade700; // رمادي غامق للثيم الداكن

    final Color textColor = isCurrentUser 
        ? Theme.of(context).colorScheme.onPrimary // لون النص للمرسل هو لون التباين الأساسي (عادة الأبيض)
        : secondaryColor; // لون النص للمستقبل هو لون النص الطبيعي للنظام (أسود/أبيض)
    
    //  لون وقت الرسالة
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
                //  استخدام primaryColor للظل (بشفافية عالية لتجنب الظل القوي في الثيم الداكن)
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
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10, color: timeColor),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const ChatPage({super.key, required this.doctor});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  String get _chatId => '${_auth.currentUser!.uid}_${widget.doctor['id']}';
  String get _currentUserId => _auth.currentUser!.uid;
  String get _currentUserName => _auth.currentUser!.displayName ?? 'Patient';

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  void _markMessagesAsRead() {
    _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        doc.reference.update({'isRead': true});
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String messageText = _messageController.text.trim();
    final Timestamp timestamp = Timestamp.now();

    // Create message data - CONSISTENT STRUCTURE
    Map<String, dynamic> messageData = {
      'senderId': _currentUserId,
      'receiverId': widget.doctor['id'],
      'message': messageText,
      'timestamp': timestamp,
      'isRead': false,
      'senderName': _currentUserName,
      'receiverName': widget.doctor['name'],
      'senderType': 'patient', // Add sender type for identification
    };

    try {
      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add(messageData);

      // Update chat summary - CONSISTENT STRUCTURE
      await _firestore.collection('chats').doc(_chatId).set({
        'lastMessage': messageText,
        'lastMessageTime': timestamp,
        'participants': [_currentUserId, widget.doctor['id']],
        'participantNames': {
          _currentUserId: _currentUserName,
          widget.doctor['id']: widget.doctor['name'],
        },
        'doctorId': widget.doctor['id'],
        'patientId': _currentUserId,
        'doctorName': widget.doctor['name'],
        'patientName': _currentUserName,
        'updatedAt': timestamp,
        'lastMessageBy': 'patient', // Track who sent last message
      }, SetOptions(merge: true));

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(DocumentSnapshot messageDoc) {
    final message = messageDoc.data() as Map<String, dynamic>;
    final isMe = message['senderId'] == _currentUserId;
    final messageText = message['message'] ?? '';
    final timestamp = message['timestamp'] as Timestamp;
    final time = _formatTime(timestamp.toDate());
    final isRead = message['isRead'] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.3),
              backgroundImage: widget.doctor["image_url"] != null &&
                  widget.doctor["image_url"].toString().isNotEmpty
                  ? NetworkImage(widget.doctor["image_url"])
                  : null,
              radius: 16,
              child: widget.doctor["image_url"] == null ||
                  widget.doctor["image_url"].toString().isEmpty
                  ? const Icon(Icons.person, size: 16, color: Colors.white70)
                  : null,
            ),
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: isMe ? 50 : 8,
                right: isMe ? 8 : 50,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.blueAccent : Colors.grey[800],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messageText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: isRead ? Colors.blueAccent : Colors.white54,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe)
            CircleAvatar(
              backgroundColor: Colors.amberAccent.withOpacity(0.3),
              radius: 16,
              child: const Icon(Icons.person, size: 16, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B6F),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.3),
              backgroundImage: widget.doctor["image_url"] != null &&
                  widget.doctor["image_url"].toString().isNotEmpty
                  ? NetworkImage(widget.doctor["image_url"])
                  : null,
              radius: 20,
              child: widget.doctor["image_url"] == null ||
                  widget.doctor["image_url"].toString().isEmpty
                  ? const Icon(Icons.person, color: Colors.white70)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.doctor["name"] ?? "Doctor",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.doctor["specialty"] ?? "Medical Professional",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white70),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call feature coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat, size: 64, color: Colors.white54),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation with Dr. ${widget.doctor["name"]}',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask about your health concerns or treatment plans',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1B3B6F),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Type your message...",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
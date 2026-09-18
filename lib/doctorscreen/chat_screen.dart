import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorChatPage extends StatefulWidget {
  final Map<String, dynamic> patient;
  final Map<String, dynamic> doctor;

  const DoctorChatPage({
    super.key,
    required this.patient,
    required this.doctor,
  });

  @override
  State<DoctorChatPage> createState() => _DoctorChatPageState();
}

class _DoctorChatPageState extends State<DoctorChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  String get _chatId => '${widget.patient['id']}_${widget.doctor['id']}';

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String messageText = _messageController.text.trim();
    final Timestamp timestamp = Timestamp.now();

    // SAME STRUCTURE as patient chat
    Map<String, dynamic> messageData = {
      'senderId': widget.doctor['id'],
      'receiverId': widget.patient['id'],
      'message': messageText,
      'timestamp': timestamp,
      'isRead': false,
      'senderName': widget.doctor['name'],
      'receiverName': widget.patient['name'],
      'senderType': 'doctor', // Add sender type
    };

    try {
      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add(messageData);

      // Update chat summary - SAME STRUCTURE
      await _firestore.collection('chats').doc(_chatId).set({
        'lastMessage': messageText,
        'lastMessageTime': timestamp,
        'participants': [widget.patient['id'], widget.doctor['id']],
        'participantNames': {
          widget.patient['id']: widget.patient['name'],
          widget.doctor['id']: widget.doctor['name'],
        },
        'doctorId': widget.doctor['id'],
        'patientId': widget.patient['id'],
        'doctorName': widget.doctor['name'],
        'patientName': widget.patient['name'],
        'updatedAt': timestamp,
        'lastMessageBy': 'doctor', // Track who sent last message
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
    final isDoctor = message['senderId'] == widget.doctor['id'];
    final messageText = message['message'] ?? '';
    final timestamp = message['timestamp'] as Timestamp;
    final time = _formatTime(timestamp.toDate());
    final isRead = message['isRead'] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isDoctor ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isDoctor)
            CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.3),
              radius: 16,
              child: const Icon(Icons.person, size: 16, color: Colors.white70),
            ),
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: isDoctor ? 50 : 8,
                right: isDoctor ? 8 : 50,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDoctor ? Colors.greenAccent : Colors.grey[800],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isDoctor ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isDoctor ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messageText,
                    style: TextStyle(
                      color: isDoctor ? Colors.black : Colors.white,
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
                          color: isDoctor ? Colors.black54 : Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      if (isDoctor) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: isRead ? Colors.blueAccent : Colors.black54,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isDoctor)
            CircleAvatar(
              backgroundColor: Colors.greenAccent.withOpacity(0.3),
              radius: 16,
              child: const Icon(Icons.medical_services, size: 16, color: Colors.white70),
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
              radius: 20,
              child: const Icon(Icons.person, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient['name'] ?? "Patient",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Patient',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
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
                          'No messages with ${widget.patient['name']}',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
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
                    color: Colors.greenAccent,
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
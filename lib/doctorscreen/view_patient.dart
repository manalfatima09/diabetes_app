import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_chat_page.dart';

class DoctorPatientListScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorPatientListScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorPatientListScreen> createState() => _DoctorPatientListScreenState();
}

class _DoctorPatientListScreenState extends State<DoctorPatientListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to safely get fields from chat document
  String _getField(Map<String, dynamic> chat, String fieldName, String defaultValue) {
    try {
      if (chat.containsKey(fieldName) && chat[fieldName] != null) {
        return chat[fieldName].toString();
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B6F),
        title: Text('My Patients - ${widget.doctorName}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('doctorId', isEqualTo: widget.doctorId)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Firestore Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading patients',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 16),
                  Text(
                    'Loading patients...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    'No patients yet',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Patients will appear here when they message you',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Refresh the stream
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          // Filter out invalid chats (missing required fields)
          final validChats = chats.where((chatDoc) {
            try {
              final chat = chatDoc.data() as Map<String, dynamic>;
              final patientId = _getField(chat, 'patientId', '');
              final patientName = _getField(chat, 'patientName', '');
              return patientId.isNotEmpty && patientName.isNotEmpty;
            } catch (e) {
              return false;
            }
          }).toList();

          if (validChats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    'No valid patient chats',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All chat records are missing required patient information',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: validChats.length,
            itemBuilder: (context, index) {
              final chatDoc = validChats[index];
              final chat = chatDoc.data() as Map<String, dynamic>;

              // Safely get all fields with fallbacks
              final patientName = _getField(chat, 'patientName', 'Unknown Patient');
              final patientId = _getField(chat, 'patientId', 'unknown_id');
              final lastMessage = _getField(chat, 'lastMessage', 'No messages yet');
              final lastMessageBy = _getField(chat, 'lastMessageBy', 'patient');

              Timestamp? lastMessageTime;
              try {
                if (chat.containsKey('lastMessageTime') && chat['lastMessageTime'] != null) {
                  lastMessageTime = chat['lastMessageTime'] as Timestamp;
                }
              } catch (e) {
                print('Error parsing timestamp: $e');
              }

              return Card(
                color: const Color(0xFF1B3B6F),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.3),
                    child: const Icon(Icons.person, color: Colors.white70),
                  ),
                  title: Text(
                    patientName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (lastMessageBy == 'doctor')
                            const Icon(Icons.outgoing_mail, size: 12, color: Colors.green),
                          if (lastMessageBy == 'patient')
                            const Icon(Icons.call_received, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: const TextStyle(color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (lastMessageTime != null)
                        Text(
                          _formatDate(lastMessageTime.toDate()),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.amberAccent, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorChatPage(
                          doctor: {
                            'id': widget.doctorId,
                            'name': widget.doctorName,
                          },
                          patient: {
                            'id': patientId,
                            'name': patientName,
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
import 'package:flutter/material.dart';
import '../signin.dart';
import 'patientDetailPage.dart';
import 'view_lifestyleplan.dart';
import 'view_patient.dart';
import 'monitor_medication_page.dart';
import 'profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_chat_page.dart';
import 'glucose_emergency_alert.dart';

class DoctorDashboard extends StatefulWidget {
  final String? doctorName;
  final String? doctorId;

  const DoctorDashboard({
    super.key,
    this.doctorName,
    this.doctorId,
  });

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildHomePage(),
      _buildProfilePage(),
      _buildChatPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B6F),
        elevation: 3,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome,",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              "${widget.doctorName ?? 'Doctor'}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF1B3B6F),
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white70,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
        ],
      ),
    );
  }

  // ==================== Pages ====================

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildCard("View Patient", Icons.people_alt, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DoctorPatientListScreen(
                      doctorId: widget.doctorId ?? 'default_doctor_id',
                      doctorName: widget.doctorName ?? 'Doctor',
                    ),
                  ),
                );
              }),
              _buildCard("Receive Emergency Alerts", Icons.warning, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GlucoseEmergencyAlertPage(
                      doctorId: widget.doctorId ?? 'default_doctor_id',
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return DoctorProfilePage();
  }

  Widget _buildChatPage() {
    final doctorId = widget.doctorId ?? 'default_doctor_id';
    final doctorName = widget.doctorName ?? 'Doctor';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('lastMessageTime', descending: true) // Fixed field name
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading chats",
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final chatDocs = snapshot.data?.docs ?? [];

        if (chatDocs.isEmpty) {
          return const Center(
            child: Text(
              "No patients to chat with yet",
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chat = chatDocs[index].data() as Map<String, dynamic>;
            final patientName = chat['patientName'] ?? 'Patient';
            final patientId = chat['patientId'] ?? '';
            final lastMessage = chat['lastMessage'] ?? 'No messages yet';
            final lastMessageTime = chat['lastMessageTime'] as Timestamp?;

            return Card(
              color: const Color(0xFF1B3B6F),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent.withOpacity(0.3),
                  child: const Icon(Icons.person, color: Colors.white70),
                ),
                title: Text(patientName, style: const TextStyle(color: Colors.white)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastMessage,
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lastMessageTime != null)
                      Text(
                        _formatTime(lastMessageTime.toDate()),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward, color: Colors.greenAccent),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorChatPage(
                        doctor: {
                          'id': doctorId,
                          'name': doctorName,
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
    );
  }

  // ==================== Helper ====================
  Widget _buildCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF1B3B6F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: Colors.greenAccent),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // ==================== Logout ====================
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Logout",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.teal)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
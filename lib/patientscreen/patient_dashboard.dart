import 'package:flutter/material.dart';
import 'home_dashboard.dart';
import 'progresspage.dart';
import 'profile.dart';
import 'feedback.dart';
import '../signin.dart';
import '../services/firebase_helper.dart';

class PatientDashboard extends StatefulWidget {
  final String name;
  final int age;
  final bool hasDiabetes;
  final int patientId;
  final String patientName;

  const PatientDashboard({
    super.key,
    required this.name,
    required this.age,
    required this.hasDiabetes,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _selectedIndex = 0;
  String _riskLevel = "Unknown";

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      HomeDashboard(
        name: widget.name,
        age: widget.age,
        hasDiabetes: widget.hasDiabetes,
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
      // Progress page ke liye placeholder
      Center(child: Text("Progress Page - Risk Level: $_riskLevel")),
      const ProfilePage(),
      FeedbackPage(patientUid: widget.name),
      Container(), // Placeholder for Logout
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: Text(
          "Welcome, ${widget.name}",
          style: const TextStyle(color: Color(0xFFE1E2E1), fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFFE1E2E1)),
            onPressed: () {
              // TODO: Notification action
            },
          ),
        ],
      ),

      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFE1E2E1),
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color(0xFF0D1B2A),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 3) {
            _showLogoutDialog(context);
          } else if (index == 1) {
            // Progress page par click karte hi navigate karo
            _navigateToProgressPage(context);
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: "Progress"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.logout_rounded), label: "Logout"),
        ],
      ),
    );
  }

  Future<void> _navigateToProgressPage(BuildContext context) async {
    final firebaseUid = await FirebaseHelper.getCurrentUserUid();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressPage(
          patientName: widget.name,
          riskLevel: _riskLevel,
          patientId: widget.patientId,
          age: widget.age,
          patientFirebaseUid: firebaseUid,
          hasDiabetes: widget.hasDiabetes,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}
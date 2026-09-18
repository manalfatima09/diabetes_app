import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'doctor_detail_page.dart';
import 'chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorListPage extends StatefulWidget {
  final bool canMessage;

  const DoctorListPage({Key? key, required this.canMessage}) : super(key: key);

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
  List<Map<String, dynamic>> doctors = [];
  bool isLoading = true;
  bool get canMessage => widget.canMessage;

  @override
  void initState() {
    super.initState();
    fetchDoctorsFromFirebase();
  }

  Future<void> fetchDoctorsFromFirebase() async {
    try {
      final QuerySnapshot querySnapshot =
      await FirebaseFirestore.instance.collection('doctors').get();

      setState(() {
        doctors = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Doctor',
            'email': data['email'] ?? '',
            'experience': data['experience'] ?? '',
            'location': data['location'] ?? '',
            'phone_number': data['phone_number'] ?? '',
            'specialty': data['specialty'] ?? 'No specialty listed',
            'image_url': data['image_url'] ?? '',
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching doctors from Firebase: $e");
      setState(() => isLoading = false);
    }
  }

  void _showDoctorProfile(Map<String, dynamic> doctor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B3B6F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DoctorProfileBottomSheet(
        doctor: doctor,
        canMessage: canMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B6F),
        title: const Text("Available Doctors"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : doctors.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              "No doctors available at the moment.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: doctors.length,
        itemBuilder: (context, index) {
          final doctor = doctors[index];
          return DoctorCard(
            doctor: doctor,
            canMessage: canMessage,
            onTap: () => _showDoctorProfile(doctor),
          );
        },
      ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final bool canMessage;
  final VoidCallback onTap;

  const DoctorCard({
    Key? key,
    required this.doctor,
    required this.canMessage,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF1B3B6F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blueAccent.withOpacity(0.2),
            backgroundImage: doctor["image_url"] != null &&
                doctor["image_url"].toString().isNotEmpty
                ? NetworkImage(doctor["image_url"])
                : null,
            radius: 26,
            child: doctor["image_url"] == null || doctor["image_url"].toString().isEmpty
                ? const Icon(Icons.person, color: Colors.white70)
                : null,
          ),
          title: Text(
            doctor["name"],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            doctor["specialty"],
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              if (canMessage)
                IconButton(
                  icon: const Icon(Icons.message, color: Colors.greenAccent),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(doctor: doctor),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorProfileBottomSheet extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final bool canMessage;

  const DoctorProfileBottomSheet({
    Key? key,
    required this.doctor,
    required this.canMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              backgroundImage: doctor["image_url"] != null &&
                  doctor["image_url"].toString().isNotEmpty
                  ? NetworkImage(doctor["image_url"])
                  : null,
              radius: 40,
              child: doctor["image_url"] == null || doctor["image_url"].toString().isEmpty
                  ? const Icon(Icons.person, size: 40, color: Colors.white70)
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: Text(
              doctor["name"],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Text(
              doctor["specialty"],
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Doctor Details
          _buildDetailItem(Icons.work, "Experience", doctor["experience"]),
          _buildDetailItem(Icons.location_on, "Location", doctor["location"]),
          _buildDetailItem(Icons.phone, "Phone", doctor["phone_number"]),
          _buildDetailItem(Icons.email, "Email", doctor["email"]),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              if (canMessage)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(doctor: doctor),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.message),
                    label: const Text("Start Chat"),
                  ),
                ),
              if (canMessage) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amberAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : "Not provided",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_page.dart'; // make sure to create this page
import 'doctor_detail_page.dart';

class DoctorAppointmentPage extends StatefulWidget {
  final bool canMessage;
  const DoctorAppointmentPage({Key? key, required this.canMessage}) : super(key: key);

  @override
  State<DoctorAppointmentPage> createState() => _DoctorAppointmentPageState();
}

class _DoctorAppointmentPageState extends State<DoctorAppointmentPage> {
  List doctors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDoctors();
  }

  Future<void> fetchDoctors() async {
    final url = Uri.parse('http://127.0.0.1:5000/doctors'); // your API
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        setState(() {
          doctors = json.decode(res.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching doctors: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B6F),
        title: const Text("Doctor Appointments"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : doctors.isEmpty
          ? const Center(
        child: Text(
          "No doctors available",
          style: TextStyle(color: Colors.white70),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: doctors.length,
        itemBuilder: (context, index) {
          final doctor = doctors[index];
          return GestureDetector(
            onTap: () {
              if (widget.canMessage) {
                // Navigate to chat page only if allowed
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      doctor: doctor,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        "Messaging is only allowed for high-risk diabetic patients."),
                  ),
                );
              }
            },
            child: Card(
              color: const Color(0xFF1B3B6F),
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: doctor['image_url'] != null
                      ? NetworkImage(doctor['image_url'])
                      : const AssetImage('assets/default_doctor.png')
                  as ImageProvider,
                  radius: 26,
                ),
                title: Text(
                  doctor['name'] ?? "Unknown",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  doctor['specialty'] ?? "No specialty listed",
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    Text(
                      "${doctor['rating'] ?? '0'}",
                      style:
                      const TextStyle(color: Colors.amberAccent),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

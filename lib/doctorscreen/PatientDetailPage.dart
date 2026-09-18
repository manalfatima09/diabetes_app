import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PatientDetailPage extends StatefulWidget {
  final String patientId; // Use patientId to fetch data

  const PatientDetailPage({super.key, required this.patientId});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  late Future<Map<String, dynamic>> patientData;

  @override
  void initState() {
    super.initState();
    patientData = fetchPatientData();
  }

  Future<Map<String, dynamic>> fetchPatientData() async {
    final url = Uri.parse(
        'http://YOUR_FLASK_API_URL/patient/${widget.patientId}'); // Replace with your API endpoint
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body); // Should return a JSON map
    } else {
      throw Exception('Failed to load patient data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Details"),
        backgroundColor: const Color(0xFF1B3B6F),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: patientData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(
              child: Text("No data found", style: TextStyle(color: Colors.white70)),
            );
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Patient Info =====
                Card(
                  color: const Color(0xFF1B3B6F),
                  child: ListTile(
                    title: Text(data['name'] ?? 'Name',
                        style: const TextStyle(color: Colors.white, fontSize: 18)),
                    subtitle: Text(
                        "Age: ${data['age'] ?? '-'} | Gender: ${data['gender'] ?? '-'}",
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(height: 16),

                // ===== Analytics / Progress =====
                Card(
                  color: const Color(0xFF1B3B6F),
                  child: ListTile(
                    title: const Text("Progress Report",
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                        data['progress'] ?? "No progress data available",
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(height: 16),

                // ===== Glucose Readings =====
                Card(
                  color: const Color(0xFF1B3B6F),
                  child: ListTile(
                    title: const Text("Glucose Readings",
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                        data['glucose_readings']?.join(", ") ??
                            "No glucose readings available",
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(height: 16),

                // ===== Medication Tracker =====
                Card(
                  color: const Color(0xFF1B3B6F),
                  child: ListTile(
                    title: const Text("Medication Tracker",
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                        data['medications']?.map((e) => "${e['name']} (${e['dose']})").join(", ") ??
                            "No medications found",
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

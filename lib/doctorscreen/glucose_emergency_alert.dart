import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';



class GlucoseEmergencyAlertPage extends StatefulWidget {
  final String doctorId;

  const GlucoseEmergencyAlertPage({super.key, required this.doctorId});

  @override
  State<GlucoseEmergencyAlertPage> createState() =>
      _GlucoseEmergencyAlertPageState();
}

class _GlucoseEmergencyAlertPageState
    extends State<GlucoseEmergencyAlertPage> {

  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    final url = Uri.parse('http://YOUR_BACKEND_URL/get_emergency_alerts');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"doctor_id": widget.doctorId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["success"]) {
        return List<Map<String, dynamic>>.from(data["alerts"]);
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B6F),
        title: const Text(
          "Glucose Emergency Alerts",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading alerts",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final alerts = snapshot.data ?? [];

          if (alerts.isEmpty) {
            return const Center(
              child: Text(
                "No emergency alerts",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final patientName = alert['patientName'] ?? 'Patient';
              final glucoseValue = alert['glucoseValue'] ?? 0;
              final alertType = alert['type'] ?? 'High';

              return Card(
                color: alertType == 'Critical' || alertType == 'Dangerous'
                    ? Colors.redAccent.withOpacity(0.8)
                    : Colors.orangeAccent.withOpacity(0.8),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.white),
                  title: Text(
                    "$patientName - $alertType Glucose",
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "Glucose: $glucoseValue mg/dL\n${alert['message'] ?? ''}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.arrow_forward, color: Colors.white),
                  onTap: () {
                    // Optionally navigate to patient details
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

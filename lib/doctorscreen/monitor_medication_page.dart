import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MonitorMedicationPage extends StatefulWidget {
  final int patientId;
  final String patientName;

  const MonitorMedicationPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<MonitorMedicationPage> createState() => _MonitorMedicationPageState();
}

class _MonitorMedicationPageState extends State<MonitorMedicationPage> {
  List<Map<String, dynamic>> medications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMedications();
  }

  Future<void> fetchMedications() async {
    setState(() => isLoading = true);
    try {
      var response = await http.post(
        Uri.parse('http://YOUR_FLASK_API_URL/get_medicines'),
        body: {'patient_id': widget.patientId.toString()},
      );
      if (response.statusCode == 200) {
        var data = json.decode(response.body) as List;
        medications = data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        medications = [];
      }
    } catch (e) {
      medications = [];
      print("Error fetching meds: $e");
    }
    setState(() => isLoading = false);
  }

  Future<void> markTaken(int medId) async {
    await http.post(
      Uri.parse('http://YOUR_FLASK_API_URL/mark_taken'),
      body: {'med_id': medId.toString()},
    );
    fetchMedications();
  }

  Future<void> deleteMedicine(int medId) async {
    await http.post(
      Uri.parse('http://YOUR_FLASK_API_URL/delete_medicine'),
      body: {'med_id': medId.toString()},
    );
    fetchMedications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medication Tracker - ${widget.patientName}'),
        backgroundColor: const Color(0xFF1B3B6F),
      ),
      backgroundColor: const Color(0xFF0D1B2A),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : medications.isEmpty
          ? const Center(
        child: Text(
          'No medication found',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: medications.length,
        itemBuilder: (context, index) {
          final med = medications[index];
          return Card(
            color: const Color(0xFF1B3B6F),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                med['med_name'] ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Time: ${med['med_time']} | Status: ${med['status']}',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check,
                        color: Colors.greenAccent),
                    onPressed: med['status'] == 'Taken'
                        ? null
                        : () => markTaken(med['med_id']),
                  ),
                  IconButton(
                    icon:
                    const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => deleteMedicine(med['med_id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

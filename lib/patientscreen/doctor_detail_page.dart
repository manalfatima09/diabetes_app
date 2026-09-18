import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DoctorDetailPage extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const DoctorDetailPage({super.key, required this.doctor});

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  List<String> slots = [];
  String? selectedSlot;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAvailableSlots();
  }

  // ✅ Fetch available slots from backend
  Future<void> fetchAvailableSlots() async {
    final doctorId = widget.doctor['doctor_id'];
    final url = Uri.parse('http://10.115.149.50:5000/doctor/$doctorId');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          // Convert all slots to String to avoid int type issues
          slots = List<String>.from(data["availability_slots"]?.map((e) => e.toString()) ?? []);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching slots: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B6F),
        title: Text(doctor["name"]?.toString() ?? "Doctor Detail",
            style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage(doctor["image_url"]?.toString() ?? 'assets/doctor_placeholder.png'),
            ),
            const SizedBox(height: 15),

            Text(
              doctor["name"]?.toString() ?? "N/A",
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              "Specialty: ${doctor["specialty"]?.toString() ?? "N/A"}",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              "Experience: ${doctor["experience"]?.toString() ?? "0"} years",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              "Phone: ${doctor["contact"]?.toString() ?? "N/A"}",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const SizedBox(height: 30),

            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                "Select Available Slot",
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1B3B6F),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1B3B6F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              value: selectedSlot,
              hint: const Text(
                "Choose available date & time",
                style: TextStyle(color: Colors.white70),
              ),
              items: slots.map((slot) {
                return DropdownMenuItem<String>(
                  value: slot.toString(),
                  child: Text(slot.toString(), style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedSlot = value),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: () {
                if (selectedSlot == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please select a slot"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "Appointment booked with ${doctor["name"]} on $selectedSlot ✅"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Confirm Appointment"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Opening chat with doctor..."),
                    backgroundColor: Colors.blueAccent,
                  ),
                );
              },
              icon: const Icon(Icons.message, color: Colors.amberAccent),
              label: const Text("Message Doctor", style: TextStyle(color: Colors.amberAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.amberAccent),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

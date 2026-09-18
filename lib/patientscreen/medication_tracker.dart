import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MedicationTracker extends StatefulWidget {
  final String patientId;
  final String patientName;

  const MedicationTracker({
    super.key,
    required this.patientId,
    this.patientName = '',
  });

  @override
  State<MedicationTracker> createState() => _MedicationTrackerState();
}

class _MedicationTrackerState extends State<MedicationTracker> {
  final TextEditingController medNameCtrl = TextEditingController();
  final TextEditingController medDosageCtrl = TextEditingController();
  final TextEditingController medTimeCtrl = TextEditingController();
  final TextEditingController medFrequencyCtrl = TextEditingController();

  TimeOfDay selectedTime = TimeOfDay.now();
  List<Map<String, dynamic>> meds = [];
  List<Map<String, dynamic>> takenHistory = [];
  bool _isLoading = true;

  static const String baseUrl = "http://10.115.148.228:5000";

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadData();
  }

  void _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadData() async {
    await Future.wait([
      fetchMedicines(),
      fetchTakenHistory(),
    ]);
  }

  Future<void> fetchMedicines() async {
    try {
      setState(() => _isLoading = true);

      final url = Uri.parse("$baseUrl/get_medicines");
      final res = await http.post(
        url,
        body: {"patient_id": widget.patientId},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        setState(() {
          meds = data.map((item) => Map<String, dynamic>.from(item)).toList();
          _isLoading = false;
        });
        print("Fetched ${meds.length} medications");
      } else {
        _showErrorSnackbar("Failed to fetch medications: ${res.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showErrorSnackbar("Error fetching medicines: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchTakenHistory() async {
    try {
      final url = Uri.parse("$baseUrl/get_taken_history");
      final res = await http.post(
        url,
        body: {"patient_id": widget.patientId},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        setState(() {
          takenHistory = data.map((item) => Map<String, dynamic>.from(item)).toList();
        });
        print("Fetched ${takenHistory.length} history items");
      } else {
        print("History API Error: ${res.statusCode}");
      }
    } catch (e) {
      print("Error fetching history: $e");
    }
  }

  Future<void> addMedicine() async {
    if (medNameCtrl.text.trim().isEmpty || medTimeCtrl.text.trim().isEmpty) {
      _showErrorSnackbar('Please fill medicine name and time');
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/add_medicine");
      final response = await http.post(
        url,
        body: {
          "patient_id": widget.patientId,
          "med_name": medNameCtrl.text.trim(),
          "med_dosage": medDosageCtrl.text.trim(),
          "med_time": medTimeCtrl.text.trim(),
          "frequency": medFrequencyCtrl.text.trim().isNotEmpty
              ? medFrequencyCtrl.text.trim()
              : "Daily",
        },
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSuccessSnackbar('✅ Medicine added successfully');

        // Schedule notification
        _scheduleNotification(
          medNameCtrl.text.trim(),
          medTimeCtrl.text.trim(),
        );

        medNameCtrl.clear();
        medDosageCtrl.clear();
        medTimeCtrl.clear();
        medFrequencyCtrl.clear();

        await fetchMedicines();
      } else {
        _showErrorSnackbar('Failed to add medicine');
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> markTaken(String medId) async {
    try {
      final url = Uri.parse("$baseUrl/mark_taken");
      final response = await http.post(
        url,
        body: {"med_id": medId},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSuccessSnackbar('✅ Marked as taken');

        await Future.wait([
          fetchMedicines(),
          fetchTakenHistory(),
        ]);
      } else {
        _showErrorSnackbar('Failed to mark as taken');
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> deleteMed(String medId) async {
    try {
      final url = Uri.parse("$baseUrl/delete_medicine");
      final response = await http.post(
        url,
        body: {"med_id": medId},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSuccessSnackbar('✅ Medicine deleted');

        await Future.wait([
          fetchMedicines(),
          fetchTakenHistory(),
        ]);
      } else {
        _showErrorSnackbar('Failed to delete medicine');
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showDeleteDialog(String medId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Medication"),
        content: const Text("Are you sure you want to delete this medication?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteMed(medId);
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
        medTimeCtrl.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _scheduleNotification(String medName, String time) async {
    // Initialize timezone (only once)
    tz.initializeTimeZones();

    final parts = time.split(':');
    if (parts.length != 2) return;

    final now = DateTime.now();
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'Medication Reminders',
      channelDescription: 'Reminders for taking your medications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // Fixed API for latest version
    await flutterLocalNotificationsPlugin.zonedSchedule(
      medName.hashCode,
      'Medication Reminder',
      'Time to take $medName',
      scheduledTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMedicationCard(Map<String, dynamic> med) {
    final isTaken = med['status'] == 'Taken';
    final takenAt = med['taken_at'] != null
        ? DateTime.tryParse(med['taken_at'].toString())
        : null;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isTaken ? Colors.green.shade50 : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isTaken ? Colors.green.shade100 : Colors.teal.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isTaken ? Icons.check_circle : Icons.medication_liquid,
            color: isTaken ? Colors.green : Colors.teal,
            size: 28,
          ),
        ),
        title: Text(
          med['med_name'].toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isTaken ? Colors.green.shade800 : Colors.grey.shade800,
            decoration: isTaken ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (med['med_dosage'] != null && med['med_dosage'].toString().isNotEmpty)
              Text(
                "Dosage: ${med['med_dosage']}",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            Text(
              "Time: ${med['med_time']}",
              style: TextStyle(
                color: isTaken ? Colors.green.shade600 : Colors.teal.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (med['frequency'] != null)
              Text(
                "Frequency: ${med['frequency']}",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            if (isTaken && takenAt != null)
              Text(
                "Taken at: ${DateFormat('hh:mm a').format(takenAt)}",
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTaken)
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 20, color: Colors.teal),
                ),
                onPressed: () => markTaken(med['med_id'].toString()),
                tooltip: "Mark as taken",
              ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete, size: 20, color: Colors.red),
              ),
              onPressed: () => _showDeleteDialog(med['med_id'].toString()),
              tooltip: "Delete medication",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> history) {
    final takenAt = DateTime.tryParse(history['taken_at'].toString()) ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: ListTile(
        leading: const Icon(Icons.history, color: Colors.blue),
        title: Text(
          history['med_name'].toString(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          "Taken at ${DateFormat('hh:mm a').format(takenAt)} on ${DateFormat('MMM dd, yyyy').format(takenAt)}",
        ),
        trailing: Text(
          history['med_time'].toString(),
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _addMedicinePopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Add Medication",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medNameCtrl,
                decoration: InputDecoration(
                  labelText: "Medicine Name *",
                  prefixIcon: const Icon(Icons.medication, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: medDosageCtrl,
                decoration: InputDecoration(
                  labelText: "Dosage (e.g., 500mg)",
                  prefixIcon: const Icon(Icons.scale, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: medTimeCtrl,
                readOnly: true,
                onTap: () => _selectTime(context),
                decoration: InputDecoration(
                  labelText: "Time *",
                  prefixIcon: const Icon(Icons.access_time, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.schedule, color: Colors.teal),
                    onPressed: () => _selectTime(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: medFrequencyCtrl,
                decoration: InputDecoration(
                  labelText: "Frequency (e.g., Daily, Twice daily)",
                  prefixIcon: const Icon(Icons.repeat, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
            ),
            onPressed: () {
              addMedicine();
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          iconTheme: const IconThemeData(
            color: Colors.teal, // <-- your desired back button color
          ),
          title: Text(
            widget.patientName.isNotEmpty
                ? "💊 ${widget.patientName}'s Medications"
                : "💊 Medication Tracker",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF0D1B2A),
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.teal,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Current", icon: Icon(Icons.medication)),
              Tab(text: "History", icon: Icon(Icons.history)),
            ],
          ),
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addMedicinePopup,
          backgroundColor: Colors.teal,
          icon: const Icon(Icons.add),
          label: const Text("Add Medicine"),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : TabBarView(
          children: [
            meds.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medication_liquid,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No medications added yet",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap + button to add your first medication",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchMedicines,
              color: Colors.teal,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: meds.length,
                itemBuilder: (context, index) {
                  return _buildMedicationCard(meds[index]);
                },
              ),
            ),
            takenHistory.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No history yet",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Mark medications as taken to see history",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchTakenHistory,
              color: Colors.teal,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: takenHistory.length,
                itemBuilder: (context, index) {
                  return _buildHistoryItem(takenHistory[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'lifestyle_tracking_page.dart';
import 'medication_tracker.dart';
import 'glucose_monitoring.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth add karo

class ProgressPage extends StatefulWidget {
  final String patientName;
  final String riskLevel;
  final int patientId;
  final bool hasDiabetes;
  final int age;
  final String patientFirebaseUid; // Add this parameter

  const ProgressPage({
    super.key,
    required this.patientName,
    required this.riskLevel,
    required this.patientId,
    required this.age,
    required this.patientFirebaseUid, // Add this
    this.hasDiabetes = false,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  static const String BASE_URL = "http://192.168.18.245:5000";

  Map<String, dynamic>? _lastPrediction;
  List<dynamic> _glucoseReadings = [];
  List<dynamic> _medications = [];
  Map<String, dynamic>? _lifestyleProgress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    try {
      await _loadLastPrediction();
      await _loadGlucoseReadings();
      await _loadMedications();
      await _loadLifestyleProgress();
    } catch (e) {
      print('Error loading patient data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLastPrediction() async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/get_last_prediction'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': widget.patientId.toString()}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('risk_percentage')) {
          setState(() {
            _lastPrediction = data;
          });
        }
      }
    } catch (e) {
      print('Error loading prediction: $e');
    }
  }

  Future<void> _loadGlucoseReadings() async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/get_glucose'),
        body: {
          'patient_id': widget.patientId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _glucoseReadings = data;
          });
        }
      }
    } catch (e) {
      print('Error loading glucose readings: $e');
    }
  }

  Future<void> _loadMedications() async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/get_medicines'),
        body: {
          'patient_id': widget.patientId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _medications = data;
          });
        }
      }
    } catch (e) {
      print('Error loading medications: $e');
    }
  }

  Future<void> _loadLifestyleProgress() async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/lifestyle_analytics'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'patient_name': widget.patientName}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _lifestyleProgress = data;
        });
      }
    } catch (e) {
      print('Error loading lifestyle progress: $e');
    }
  }

  Widget _buildRiskSummary() {
    Color riskColor;
    String riskMessage;
    IconData riskIcon;
    String displayRiskLevel = widget.riskLevel;

    if (_lastPrediction != null && _lastPrediction!['risk_level'] != null) {
      displayRiskLevel = _lastPrediction!['risk_level'];
    }

    switch (displayRiskLevel.toLowerCase()) {
      case "high":
        riskColor = Colors.redAccent;
        riskMessage = widget.hasDiabetes
            ? "You have diabetes. Regular monitoring is essential."
            : "High diabetes risk detected. Preventive care recommended.";
        riskIcon = Icons.warning;
        break;
      case "moderate":
        riskColor = Colors.orangeAccent;
        riskMessage = "Moderate diabetes risk. Maintain healthy lifestyle.";
        riskIcon = Icons.info;
        break;
      case "low":
        riskColor = Colors.greenAccent;
        riskMessage = "Low diabetes risk. Keep up the good work!";
        riskIcon = Icons.check_circle;
        break;
      default:
        riskColor = Colors.grey;
        riskMessage = "Complete risk assessment to see your status.";
        riskIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor),
      ),
      child: Row(
        children: [
          Icon(riskIcon, color: riskColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${displayRiskLevel.toUpperCase()} Risk Level",
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  riskMessage,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (_lastPrediction != null && _lastPrediction!['risk_percentage'] != null)
                  Text(
                    "Probability: ${_lastPrediction!['risk_percentage'].toStringAsFixed(1)}%",
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (_lastPrediction == null)
                  Text(
                    "Take assessment to see your risk percentage",
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart(String title, double percentage, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            "${percentage.toStringAsFixed(1)}%",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseChart() {
    if (_glucoseReadings.isEmpty) {
      return _buildEmptyState("No glucose readings yet", Icons.bloodtype);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Glucose Readings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _glucoseReadings.length,
              itemBuilder: (context, index) {
                final reading = _glucoseReadings[index];
                final value = double.tryParse(reading['glucose'].toString()) ?? 0;
                final date = reading['g_date'] != null
                    ? DateTime.parse(reading['g_date'].toString())
                    : DateTime.now();

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(
                          color: value > 180 ? Colors.redAccent :
                          value > 140 ? Colors.orangeAccent : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 20,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 20,
                            height: (value / 300) * 80,
                            decoration: BoxDecoration(
                              color: value > 180 ? Colors.redAccent :
                              value > 140 ? Colors.orangeAccent : Colors.greenAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${date.day}/${date.month}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationSummary() {
    if (_medications.isEmpty) {
      return _buildEmptyState("No medications tracked", Icons.medication);
    }

    final taken = _medications.where((med) => med['status'] == 'Taken').length;
    final total = _medications.length;

    return _buildProgressChart(
      "Medication Adherence",
      total > 0 ? (taken / total * 100) : 0,
      Colors.greenAccent,
    );
  }

  Widget _buildPredictionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Diabetes Risk Assessment",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.purpleAccent,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Monitor your diabetes risk factors and predictions",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          if (_lastPrediction != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: Colors.purpleAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Latest Prediction: ${_lastPrediction!['risk_percentage']?.toStringAsFixed(1) ?? '0'}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Risk Level: ${_lastPrediction!['risk_level'] ?? 'Unknown'}",
                          style: TextStyle(
                            color: Colors.purpleAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.assessment,
                    color: Colors.purpleAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Complete risk assessment to see your prediction",
                      style: TextStyle(
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.assessment, color: Colors.white),
            label: const Text(
              "View Predictions",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              // Navigate to prediction history page
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.white54),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleCard(BuildContext context) {
    double completionPercentage = 0;
    if (_lifestyleProgress != null) {
      final weeklyDone = _lifestyleProgress!['weekly_done'] ?? 0;
      final weeklyTotal = _lifestyleProgress!['weekly_total'] ?? 1;
      completionPercentage = weeklyTotal > 0 ? (weeklyDone / weeklyTotal * 100) : 0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Lifestyle Tracking",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.amberAccent,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "View your weekly and monthly lifestyle progress",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          if (_lifestyleProgress != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    color: Colors.amberAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Weekly Completion: ${completionPercentage.toStringAsFixed(1)}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_lifestyleProgress!['weekly_done'] ?? 0}/${_lifestyleProgress!['weekly_total'] ?? 0} tasks completed",
                          style: TextStyle(
                            color: Colors.amberAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.track_changes, color: Colors.black),
            label: const Text(
              "Open Tracking",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LifestylePlanPage(
                    age: widget.age,
                    riskLevel: widget.riskLevel,
                    patientName: widget.patientName,
                    hasDiabetes: widget.hasDiabetes,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper function to get Firebase UID
  Future<String> _getFirebaseUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.uid;
    }
    return widget.patientFirebaseUid; // Use the passed parameter as fallback
  }

  Widget _buildGlucoseCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Glucose Monitoring",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Track your blood glucose readings over time",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          if (_glucoseReadings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bloodtype,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Latest: ${_glucoseReadings.first['glucose']} mg/dL",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_glucoseReadings.length} readings available",
                          style: TextStyle(
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.bloodtype, color: Colors.white),
            label: const Text(
              "View Glucose",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final firebaseUid = await _getFirebaseUid();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GlucoseMonitoringPage(
                    patientName: widget.patientName,
                    patientFirebaseUid: firebaseUid,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context) {
    final takenMeds = _medications.where((med) => med['status'] == 'Taken').length;
    final totalMeds = _medications.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Medication Tracking",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Track your medications and reminders",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          if (_medications.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medication,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$takenMeds/$totalMeds medications taken",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Medication adherence",
                          style: TextStyle(
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.add_alarm, color: Colors.white),
            label: const Text(
              "Manage Medications",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicationTracker(
                    patientId: widget.patientId.toString(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Health Progress - ${widget.patientName}",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            _buildRiskSummary(),
            const SizedBox(height: 20),

            if (widget.riskLevel.toLowerCase() == "low") ...[
              _buildPredictionCard(),
              const SizedBox(height: 20),
              _buildLifestyleCard(context),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.celebration, size: 40, color: Colors.greenAccent),
                    SizedBox(height: 8),
                    Text(
                      "Excellent Health Status!",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Continue with your healthy lifestyle habits to maintain low diabetes risk.",
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (widget.riskLevel.toLowerCase() == "moderate") ...[
              _buildPredictionCard(),
              const SizedBox(height: 20),
              _buildLifestyleCard(context),
              const SizedBox(height: 20),

              const Text(
                "Focus Areas:",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildProgressChart("Physical Activity", 65, Colors.orangeAccent),
              const SizedBox(height: 10),
              _buildProgressChart("Healthy Eating", 75, Colors.greenAccent),
              const SizedBox(height: 10),
              _buildProgressChart("Weight Management", 60, Colors.blueAccent),
            ] else if (widget.riskLevel.toLowerCase() == "high") ...[
              if (!widget.hasDiabetes) ...[
                _buildPredictionCard(),
                const SizedBox(height: 20),
                _buildLifestyleCard(context),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.health_and_safety, size: 40, color: Colors.orangeAccent),
                      SizedBox(height: 8),
                      Text(
                        "Preventive Care Needed",
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Focus on lifestyle changes and regular monitoring to prevent diabetes development.",
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Diabetes patient ke liye layout
                _buildPredictionCard(),
                const SizedBox(height: 20),
                _buildLifestyleCard(context),
                const SizedBox(height: 20),
                _buildGlucoseChart(),
                const SizedBox(height: 20),
                _buildMedicationSummary(),
                const SizedBox(height: 20),
                _buildGlucoseCard(context),
                const SizedBox(height: 20),
                _buildMedicationCard(context),
              ],
            ],
            const SizedBox(height: 40), // Extra padding for bottom
          ],
        ),
      ),
    );
  }
}
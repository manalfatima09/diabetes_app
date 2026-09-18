import 'package:flutter/material.dart';
import 'prediction_form.dart';
import 'medication_tracker.dart';
import 'glucose_monitoring.dart';
import 'doctor_list_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'lifestyle_tracking_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/patient_data_service.dart';

class HomeDashboard extends StatefulWidget {
  final String name;
  final int age;
  final bool hasDiabetes;
  final int patientId;
  final String patientName;

  const HomeDashboard({
    super.key,
    required this.name,
    required this.age,
    required this.hasDiabetes,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  String _currentRiskLevel = "Unknown";
  Map<String, dynamic>? _lastPredictionResult;
  bool? _userDiabetesStatus;
  bool _showOptionsAfterHighRisk = false;
  bool _isLoading = true;
  bool _dialogAlreadyShown = false;

  String get _riskLevelKey => 'user_risk_level_${widget.patientId}';
  String get _diabetesStatusKey => 'user_diabetes_status_${widget.patientId}';
  String get _showOptionsKey => 'show_high_risk_options_${widget.patientId}';
  String get _userSelectedKey => 'user_selected_diabetes_${widget.patientId}';
  String get _dialogShownKey => 'dialog_shown_for_${widget.patientId}';

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentRiskLevel = prefs.getString(_riskLevelKey) ?? "Unknown";
      final selected = prefs.getBool(_userSelectedKey) ?? false;
      _userDiabetesStatus = selected ? prefs.getBool(_diabetesStatusKey) : null;
      _showOptionsAfterHighRisk = prefs.getBool(_showOptionsKey) ?? false;
      _dialogAlreadyShown = prefs.getBool(_dialogShownKey) ?? false;
    });
    await _fetchLastPrediction();
  }

  Future<void> _saveUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_riskLevelKey, _currentRiskLevel);
    if (_userDiabetesStatus != null) {
      await prefs.setBool(_diabetesStatusKey, _userDiabetesStatus!);
      await prefs.setBool(_userSelectedKey, true);
    }
    await prefs.setBool(_showOptionsKey, _showOptionsAfterHighRisk);
    await prefs.setBool(_dialogShownKey, _dialogAlreadyShown);
  }

  Future<void> _fetchLastPrediction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final url = Uri.parse(
        "http://10.115.148.228:5000/get_last_prediction?user_id=${user.uid}");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["risk_level"] != null) {
        setState(() {
          _lastPredictionResult = data;
          _currentRiskLevel = data["risk_level"];
          _isLoading = false;
        });
        await _saveUserPreferences();
        _checkAndShowHighRiskDialog(_currentRiskLevel);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _checkAndShowHighRiskDialog(String level) {
    if (level == "High" &&
        _userDiabetesStatus == null &&
        !_dialogAlreadyShown) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _showHighRiskDialog();
      });
    }
  }

  void _showHighRiskDialog() {
    setState(() => _dialogAlreadyShown = true);
    _saveUserPreferences();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B3B6F),
        title: const Text("⚠ High Diabetes Risk",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "Do you already have diabetes?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _updateDiabetesStatus(true);
              Navigator.pop(context);
            },
            child: const Text("YES", style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () {
              _updateDiabetesStatus(false);
              Navigator.pop(context);
            },
            child: const Text("NO", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDiabetesStatus(bool value) async {
    setState(() {
      _userDiabetesStatus = value;
      _showOptionsAfterHighRisk = true;
    });
    await _saveUserPreferences();
  }

  // ------------------- TOP IMAGE -------------------
  Widget _buildTopImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/images/diabetesPatient.jpg',
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  // ------------------- MOTIVATIONAL CARD -------------------
  Widget _buildMotivationalCard() {
    String risk = _lastPredictionResult?["risk_level"] ?? _currentRiskLevel;
    double riskPercent = double.tryParse(
        _lastPredictionResult?["risk_percentage"]?.toString() ?? "0") ??
        0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "💡 Motivation & Insights",
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "“Take small steps every day towards a healthier life. Your health is your wealth!”",
            style: TextStyle(
                color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Text(
            "Risk Level: $risk",
            style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          Text(
            "Last Prediction: ${riskPercent.toStringAsFixed(2)}%",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ------------------- HEALTH CARD -------------------
  Widget _buildHealthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3B6F), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Health Insights",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Text("Name: ${widget.name}",
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text("Age: ${widget.age} years",
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text("Risk Level: $_currentRiskLevel",
              style: TextStyle(
                  color: _getRiskColor(),
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          if (_userDiabetesStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Diabetes Status: ${_userDiabetesStatus! ? 'Yes' : 'No'}",
                style: TextStyle(
                  color: _userDiabetesStatus!
                      ? Colors.orangeAccent
                      : Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthDataFormPage()),
              );
              if (result != null) _updateRiskFromPrediction(result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.shade700,
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              "Check Diabetes Risk",
              style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionBox() {
    if (_lastPredictionResult == null) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        "Last Prediction: $_currentRiskLevel",
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildHighRiskOptions() {
    if (_currentRiskLevel == "High" && _userDiabetesStatus != null) {
      return Container(
        margin: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _openGlucoseMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withOpacity(0.2),
                foregroundColor: Colors.orange,
              ),
              child: const ListTile(
                title: Text("📊 Glucose Monitoring"),
                subtitle: Text("Track sugar levels"),
                trailing: Icon(Icons.arrow_forward),
              ),
            ),
            ElevatedButton(
              onPressed: _openMedication,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.withOpacity(0.2),
                foregroundColor: Colors.purple,
              ),
              child: const ListTile(
                title: Text("💊 Medication"),
                subtitle: Text("Manage medicines"),
                trailing: Icon(Icons.arrow_forward),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Color _getRiskColor() {
    switch (_currentRiskLevel.toLowerCase()) {
      case "high":
        return Colors.redAccent;
      case "moderate":
        return Colors.orangeAccent;
      case "low":
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }

  void _openLifestylePlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LifestylePlanPage(
          age: widget.age,
          riskLevel: _currentRiskLevel,
          patientName: widget.name,
          hasDiabetes: _userDiabetesStatus ?? false,
        ),
      ),
    );
  }

  void _openGlucoseMonitoring() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GlucoseMonitoringPage(
            patientName: widget.name,
            patientFirebaseUid: user.uid,
          ),
        ),
      );
    }
  }

  void _openMedication() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationTracker(
          patientId: widget.patientId.toString(),
          patientName: widget.patientName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTopImage(),
            _buildMotivationalCard(),
            _buildHealthCard(),
            _buildPredictionBox(),
            if (_currentRiskLevel == "High" && _userDiabetesStatus != null)
              _buildHighRiskOptions(),
          ],
        ),
      ),
    );
  }

  void _updateRiskFromPrediction(Map<dynamic, dynamic> result) {
    final newRiskLevel =
        result['risk_level']?.toString() ?? result['level']?.toString() ?? "Unknown";
    setState(() {
      _lastPredictionResult = Map<String, dynamic>.from(result);
      _currentRiskLevel = newRiskLevel;
      _dialogAlreadyShown = false;
    });
    _checkAndShowHighRiskDialog(newRiskLevel);
    _saveUserPreferences();
  }
}

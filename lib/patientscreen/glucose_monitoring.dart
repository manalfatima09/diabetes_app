import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GlucoseMonitoringPage extends StatefulWidget {
  final String patientName;
  final String patientFirebaseUid;

  const GlucoseMonitoringPage({
    super.key,
    required this.patientName,
    required this.patientFirebaseUid,
  });

  @override
  State<GlucoseMonitoringPage> createState() => _GlucoseMonitoringPageState();
}

class _GlucoseMonitoringPageState extends State<GlucoseMonitoringPage> {
  static const String BASE_URL = "http://10.115.148.228:5000";

  final TextEditingController glucoseController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController fastingHoursController = TextEditingController();

  List<dynamic> glucoseHistory = [];
  Map<String, dynamic> glucoseStats = {};
  bool _isLoading = true;
  bool _showStats = false;
  String? _selectedMeasurementType = 'Random';
  String? _selectedMealType;
  int? _fastingHours;

  // Glucose categories
  final Map<String, Map<String, dynamic>> glucoseLevels = {
    "Hypoglycemia": {
      "min": 0, "max": 70,
      "color": Colors.red,
      "icon": Icons.warning_amber_rounded,
      "suggestions": ["⚠️ Immediate Action Required!", "Consume 15-20 grams of fast-acting carbohydrates"]
    },
    "Low": {
      "min": 71, "max": 100,
      "color": Colors.orange,
      "icon": Icons.info_outline_rounded,
      "suggestions": ["Monitor closely", "Consider small snack"]
    },
    "Normal": {
      "min": 101, "max": 140,
      "color": Colors.green,
      "icon": Icons.check_circle_outline_rounded,
      "suggestions": ["✅ Excellent control!", "Maintain current routine"]
    },
    "High": {
      "min": 141, "max": 180,
      "color": Colors.yellow[700],
      "icon": Icons.warning_outlined,
      "suggestions": ["Review recent food intake", "Consider light physical activity"]
    },
    "Dangerous": {
      "min": 181, "max": 250,
      "color": Colors.red[800],
      "icon": Icons.dangerous_rounded,
      "suggestions": ["⚠️ Take immediate action!", "Contact healthcare provider"]
    },
    "Critical": {
      "min": 251, "max": 1000,
      "color": Colors.purple[900],
      "icon": Icons.emergency_rounded,
      "suggestions": ["🚨 EMERGENCY - SEEK MEDICAL HELP!", "Call emergency services"]
    },
  };

  // Measurement types
  final List<String> measurementTypes = [
    'Fasting', 'Postprandial', 'Random', 'BeforeMeal', 'AfterMeal'
  ];

  // Meal types
  final List<String> mealTypes = [
    'Breakfast', 'Lunch', 'Dinner', 'Snack'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadGlucoseHistory();
    await _loadGlucoseStats();
    setState(() {
      _isLoading = false;
    });
  }

  // ✅ FIXED: GET FIREBASE TOKEN FUNCTION
// ✅ FIXED: GET FIREBASE TOKEN FUNCTION
  Future<String?> _getFirebaseToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ No user logged in");
        return null;
      }

      final token = await user.getIdToken(true);
      if (token != null && token.length >= 30) {
        print("✅ Firebase token obtained (first 30 chars): ${token.substring(0, 30)}...");
      } else {
        print("✅ Firebase token obtained: $token");
      }
      return token;
    } catch (e) {
      print("❌ Error getting Firebase token: $e");
      return null;
    }
  }

  // ✅ FIXED: LOAD GLUCOSE HISTORY WITH FIREBASE AUTH
  Future<void> _loadGlucoseHistory() async {
    try {
      print("🔄 Loading glucose history with Firebase auth");

      // Get Firebase token
      final token = await _getFirebaseToken();
      if (token == null) {
        _showSnackBar("Please login first", Colors.red);
        return;
      }

      final response = await http.post(
        Uri.parse('$BASE_URL/get_glucose_history'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'days': 30}), // ✅ No patient_id needed
      );

      print("📡 History response status: ${response.statusCode}");
      print("📡 History response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ Loaded glucose history data");

        setState(() {
          glucoseHistory = data['history'] ?? [];
        });

        if (glucoseHistory.isEmpty) {
          print("ℹ️ No glucose history found");
        }
      } else {
        print("❌ Failed to load glucose history: ${response.statusCode}");
        _showSnackBar("Failed to load history", Colors.orange);
      }
    } catch (e) {
      print('❌ Error loading glucose history: $e');
      _showSnackBar("Connection error: $e", Colors.red);
    }
  }

  // ✅ FIXED: LOAD GLUCOSE STATS WITH FIREBASE AUTH
  Future<void> _loadGlucoseStats() async {
    try {
      print("🔄 Loading glucose stats with Firebase auth");

      // Get Firebase token
      final token = await _getFirebaseToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('$BASE_URL/get_glucose_stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'days': 30}),
      );

      print("📡 Stats response status: ${response.statusCode}");
      print("📡 Stats response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          glucoseStats = data;
        });
        print("✅ Loaded glucose stats");
      } else {
        print("❌ Failed to load glucose stats: ${response.statusCode}");
      }
    } catch (e) {
      print('❌ Error loading glucose stats: $e');
    }
  }

  // ✅ FIXED: ADD GLUCOSE READING WITH FIREBASE AUTH
  Future<void> _addGlucoseReading() async {
    if (glucoseController.text.isEmpty) {
      _showSnackBar('Please enter glucose value', Colors.red);
      return;
    }

    double value = double.tryParse(glucoseController.text) ?? 0;
    if (value < 20 || value > 1000) {
      _showSnackBar('Please enter valid glucose (20-1000 mg/dL)', Colors.red);
      return;
    }

    try {
      // Get Firebase token
      final token = await _getFirebaseToken();
      if (token == null) {
        _showSnackBar('Please login first', Colors.red);
        return;
      }

      // ✅ FIXED: Prepare request data WITHOUT patient_id
      Map<String, dynamic> requestData = {
        'glucose_value': value,
        'measurement_type': _selectedMeasurementType ?? 'Random',
        'device_type': 'Mobile App',
      };

      // Add optional fields
      if (_selectedMealType != null && _selectedMealType!.isNotEmpty) {
        requestData['meal_type'] = _selectedMealType;
      }

      if (_fastingHours != null && _fastingHours! > 0) {
        requestData['fasting_hours'] = _fastingHours;
      }

      if (notesController.text.isNotEmpty) {
        requestData['notes'] = notesController.text;
      }

      print("🔄 Adding glucose reading");
      print("📊 Request data: $requestData");

      final response = await http.post(
        Uri.parse('$BASE_URL/add_glucose_reading'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestData),
      );

      print("📡 Add reading response status: ${response.statusCode}");
      print("📡 Add reading response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ Glucose reading added: $data");

        // Clear inputs
        glucoseController.clear();
        notesController.clear();
        fastingHoursController.clear();
        _selectedMealType = null;
        _fastingHours = null;

        // Reload data
        await _loadGlucoseHistory();
        await _loadGlucoseStats();

        _showSnackBar('Glucose reading added successfully', Colors.green);
      } else {
        print("❌ Failed to add glucose reading: ${response.statusCode}");

        // Try legacy endpoint as fallback
        await _tryLegacyAddReading(value, token);
      }
    } catch (e) {
      print('❌ Error adding glucose reading: $e');
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  // ✅ FALLBACK: TRY LEGACY ENDPOINT
  Future<void> _tryLegacyAddReading(double value, String token) async {
    try {
      print("🔄 Trying legacy endpoint...");

      // Get patient info first
      final patientResponse = await http.post(
        Uri.parse('$BASE_URL/get_patient_info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (patientResponse.statusCode == 200) {
        final patientData = json.decode(patientResponse.body);
        final patientId = patientData['patient_id'];

        if (patientId != null) {
          // Use legacy endpoint with patient_id
          final legacyResponse = await http.post(
            Uri.parse('$BASE_URL/add_glucose'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patient_id': patientId,
              'glucose_value': value,
              'measurement_type': _selectedMeasurementType ?? 'Random',
            }),
          );

          if (legacyResponse.statusCode == 200) {
            print("✅ Glucose added via legacy endpoint");

            // Clear inputs
            glucoseController.clear();
            notesController.clear();
            fastingHoursController.clear();
            _selectedMealType = null;
            _fastingHours = null;

            // Reload data
            await _loadGlucoseHistory();
            await _loadGlucoseStats();

            _showSnackBar('Glucose reading added successfully', Colors.green);
          }
        }
      }
    } catch (e) {
      print('❌ Legacy add also failed: $e');
    }
  }

  // ✅ FIXED: DELETE GLUCOSE READING
  Future<void> _deleteGlucoseReading(int glucoseId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete", style: TextStyle(color: Colors.red)),
        content: const Text("Are you sure you want to delete this glucose reading?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final token = await _getFirebaseToken();
                if (token == null) return;

                final response = await http.post(
                  Uri.parse('$BASE_URL/delete_glucose_reading'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({'glucose_id': glucoseId}),
                );

                if (response.statusCode == 200) {
                  await _loadGlucoseHistory();
                  await _loadGlucoseStats();

                  _showSnackBar('Glucose reading deleted', Colors.green);
                }
              } catch (e) {
                print('❌ Error deleting glucose reading: $e');
                _showSnackBar('Delete failed', Colors.red);
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ✅ HELPER: SHOW SNACKBAR
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (glucoseStats.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "30-Day Statistics",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showStats = !_showStats),
                icon: Icon(
                  _showStats ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          if (_showStats)
            Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                        "Avg",
                        "${glucoseStats['average_glucose']?.toStringAsFixed(1) ?? '0'} mg/dL",
                        Colors.blue
                    ),
                    _buildStatItem(
                        "Min",
                        "${glucoseStats['min_glucose']?.toStringAsFixed(1) ?? '0'} mg/dL",
                        Colors.green
                    ),
                    _buildStatItem(
                        "Max",
                        "${glucoseStats['max_glucose']?.toStringAsFixed(1) ?? '0'} mg/dL",
                        Colors.red
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                        "Normal",
                        "${glucoseStats['normal_count'] ?? '0'}",
                        Colors.green
                    ),
                    _buildStatItem(
                        "High",
                        "${glucoseStats['hyperglycemia_count'] ?? '0'}",
                        Colors.orange
                    ),
                    _buildStatItem(
                        "Low",
                        "${glucoseStats['hypoglycemia_count'] ?? '0'}",
                        Colors.red
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGlucoseIndicator(double value) {
    for (var entry in glucoseLevels.entries) {
      if (value >= entry.value["min"] && value <= entry.value["max"]) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: entry.value["color"].withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: entry.value["color"]),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(entry.value["icon"], color: entry.value["color"], size: 16),
              const SizedBox(width: 6),
              Text(
                entry.key,
                style: TextStyle(
                  color: entry.value["color"],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1B3B6F),
              Color(0xFF34495E),
              Color(0xFFE1E2E1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Glucose Monitoring",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.patientName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "Firebase UID: ${widget.patientFirebaseUid.substring(0, 10)}...",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _initializeData,
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      tooltip: "Refresh",
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Statistics Card
                _buildStatisticsCard(),
                const SizedBox(height: 20),

                // Input Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "New Glucose Reading",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Glucose Value Input
                      TextField(
                        controller: glucoseController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white12,
                          hintText: "Enter glucose value...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.monitor_heart, color: Colors.white70),
                          suffixText: "mg/dL",
                          suffixStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Measurement Type Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedMeasurementType,
                        dropdownColor: const Color(0xFF1B3B6F),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white12,
                          labelText: "Measurement Type",
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        items: measurementTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            _selectedMeasurementType = value;
                            if (value != 'Fasting') {
                              fastingHoursController.clear();
                              _fastingHours = null;
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // Conditional Fields
                      if (_selectedMeasurementType == 'Postprandial' ||
                          _selectedMeasurementType == 'AfterMeal')
                        DropdownButtonFormField<String>(
                          value: _selectedMealType,
                          dropdownColor: const Color(0xFF1B3B6F),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white12,
                            labelText: "Meal Type",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white30),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: mealTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type, style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _selectedMealType = value;
                            });
                          },
                        ),

                      if (_selectedMeasurementType == 'Fasting')
                        TextField(
                          controller: fastingHoursController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white12,
                            labelText: "Fasting Hours",
                            labelStyle: const TextStyle(color: Colors.white70),
                            suffixText: "hours",
                            suffixStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white30),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _fastingHours = int.tryParse(value);
                            });
                          },
                        ),

                      const SizedBox(height: 16),

                      // Notes Field
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white12,
                          labelText: "Notes (optional)",
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addGlucoseReading,
                          icon: const Icon(Icons.add_chart_rounded),
                          label: const Text("Record Reading", style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B3B6F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // History Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Glucose History",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Total: ${glucoseHistory.length}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Loading/Empty/History States
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                else if (glucoseHistory.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.history_edu_rounded, color: Colors.white54, size: 50),
                        const SizedBox(height: 10),
                        const Text(
                          "No glucose records yet",
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Add your first glucose reading above",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ...glucoseHistory.map((item) {
                    final value = double.tryParse(item['glucose_value'].toString()) ?? 0;
                    final date = item['reading_date'] != null
                        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(item['reading_date'].toString()))
                        : 'Unknown date';
                    final time = item['reading_time']?.toString() ?? 'Unknown time';
                    final measurementType = item['measurement_type']?.toString() ?? 'Random';
                    final notes = item['notes']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                date,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                time,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "${value.toStringAsFixed(1)} mg/dL",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      _buildGlucoseIndicator(value),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Type: $measurementType",
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () => _deleteGlucoseReading(item['glucose_id'] ?? 0),
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                tooltip: "Delete",
                              ),
                            ],
                          ),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Notes: $notes",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class HealthDataFormPage extends StatefulWidget {
  const HealthDataFormPage({super.key});

  @override
  State<HealthDataFormPage> createState() => _HealthDataFormPageState();
}

class _HealthDataFormPageState extends State<HealthDataFormPage> {
  final _formKey = GlobalKey<FormState>();

  // =================== ALL FIELDS ===================
  int? highBP, overweight, highChol, diffWalk, heartDisease, stroke, smoker, cholCheck;
  double? bmi, genHlth, physHlth, mentHlth, age, education, income, physActivity, fruits, veggies, hvyAlcohol;

  // =================== ✅ NEW FEATURES ===================
  int? familyHistoryDiabetes;
  int? bpMedication;
  double? waistCircumference;
  double? fastingGlucose;
  double? hba1c;

  // =================== BMI CONTROLLERS ===================
  final TextEditingController _heightFeetController = TextEditingController();
  final TextEditingController _heightInchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // =================== API URL - WEB COMPATIBLE ===================
  // For Flutter Web, we can ONLY use localhost or 127.0.0.1
  final List<String> possibleUrls = [
    "http://10.115.148.228:5000/predict",    // First try localhost (Flutter Web)
    "http://127.0.0.1:5000/predict",    // Alternative localhost
    "http://localhost:5001/predict",
    // Try different port if 5000 is blocked
  ];

  // Current URL to use
  String get apiUrl => possibleUrls.first;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    resetAllFields();

    // Test server connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      testServerConnection();
    });
  }

  void resetAllFields() {
    setState(() {
      highBP = null;
      overweight = null;
      highChol = null;
      diffWalk = null;
      heartDisease = null;
      stroke = null;
      smoker = null;
      cholCheck = null;
      bmi = null;
      genHlth = null;
      physHlth = null;
      mentHlth = null;
      age = null;
      education = null;
      income = null;
      physActivity = null;
      fruits = null;
      veggies = null;
      hvyAlcohol = null;
      familyHistoryDiabetes = null;
      bpMedication = null;
      waistCircumference = null;
      fastingGlucose = null;
      hba1c = null;
    });
  }

  // =================== SERVER CONNECTION TEST ===================
  Future<void> testServerConnection() async {
    print("🔍 Testing server connections for Flutter Web...");

    for (final url in possibleUrls) {
      try {
        final healthUrl = url.replaceAll("/predict", "/");
        print("🔄 Testing: $healthUrl");

        final response = await http.get(
          Uri.parse(healthUrl),
          headers: {
            'Accept': 'application/json',
            'Origin': 'http://localhost', // Add Origin header for web
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          print("✅ Flask server found at: $url");
          print("📊 Server response: ${response.body}");
          return;
        } else {
          print("⚠️ Server responded with status: ${response.statusCode}");
        }
      } catch (e) {
        print("❌ Connection failed: $url - ${e.toString()}");
      }
    }

    print("⚠️ No Flask server found. Make sure to run: python app.py");
    print("💡 Troubleshooting tips:");
    print("   1. Open terminal in your project folder");
    print("   2. Run: python app.py");
    print("   3. Check that you see: '🚀 Flask server running on http://0.0.0.0:5000'");
    print("   4. Open browser and go to: http://localhost:5000");
  }

  // =================== API REQUEST - WEB COMPATIBLE ===================
  Future<void> sendPredictionRequest(Map<String, dynamic> healthData) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    String? lastError;

    // Try each URL until one works
    for (final url in possibleUrls) {
      try {
        print("🌐 [Flutter Web] Trying URL: $url");

        // Parse URL
        final uri = Uri.parse(url);

        // Get Firebase token
        final user = FirebaseAuth.instance.currentUser;
        String? token;
        if (user != null) {
          try {
            token = await user.getIdToken();
            print("✅ Firebase token obtained");
          } catch (e) {
            print("⚠️ Firebase token error: $e");
          }
        }

        // Prepare headers for web
        final headers = {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Origin": "http://localhost", // Important for web
        };

        if (token != null && token.isNotEmpty) {
          headers["Authorization"] = "Bearer $token";
        }

        // Log data
        print("📤 Sending ${healthData.length} features");
        print("📊 Data sample: ${healthData.entries.take(3).toList()}");

        // Make request
        final response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(healthData),
        ).timeout(const Duration(seconds: 30));

        // Close loading
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        setState(() {
          _isLoading = false;
        });

        print("📥 Response status: ${response.statusCode}");
        print("📥 Response body: ${response.body}");

        if (response.statusCode == 200) {
          // Success! Process response
          final result = jsonDecode(response.body);
          print("✅ Prediction successful!");
          _handleSuccessResponse(result);
          return; // Exit loop on success

        } else if (response.statusCode == 401) {
          lastError = "Authentication failed. Please login again.";
        } else if (response.statusCode == 404) {
          lastError = "Endpoint not found at $url\nMake sure /predict route exists in Flask.";
        } else if (response.statusCode == 500) {
          lastError = "Server error. Please try again later.";
          print("❌ Server error details: ${response.body}");
        } else {
          lastError = "Request failed with status: ${response.statusCode}";
        }

      } on http.ClientException catch (e) {
        lastError = "Network error: ${e.message}\nMake sure Flask server is running.";
        print("❌ Client error: $e");
        continue;

      } on TimeoutException catch (e) {
        lastError = "Timeout connecting to $url\nServer might be busy or not responding.";
        print("❌ Timeout: $e");
        continue;

      } on FormatException catch (e) {
        lastError = "Invalid response from server\nServer might not be returning valid JSON.";
        print("❌ Format error: $e");
        continue;

      } catch (e) {
        lastError = "Unexpected error: $e";
        print("❌ Unexpected: $e");
        continue;
      }
    }

    // If we get here, all URLs failed
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }

    setState(() {
      _isLoading = false;
    });

    _showError(lastError ?? "All server connections failed.\n\nMake sure:\n1. Flask server is running (python app.py)\n2. You can access http://localhost:5000 in browser\n3. CORS is enabled in Flask");
  }

  void _handleSuccessResponse(Map<String, dynamic> result) {
    double riskPercentage;
    String riskLevel;

    // Extract risk percentage
    if (result.containsKey("risk_percentage")) {
      riskPercentage = double.tryParse(result["risk_percentage"].toString()) ?? 0.0;
    } else if (result.containsKey("probability")) {
      riskPercentage = (double.tryParse(result["probability"].toString()) ?? 0.0) * 100;
    } else if (result.containsKey("confidence")) {
      riskPercentage = double.tryParse(result["confidence"].toString()) ?? 0.0;
    } else {
      riskPercentage = 50.0; // Default
    }

    // Extract risk level
    if (result.containsKey("risk_level")) {
      riskLevel = result["risk_level"].toString();
    } else if (result.containsKey("prediction")) {
      final prediction = result["prediction"];
      if (prediction == 1 || prediction == "Diabetes" || prediction == "Positive") {
        riskLevel = "High";
      } else {
        riskLevel = "Low";
      }
    } else {
      // Determine based on percentage
      if (riskPercentage >= 70) {
        riskLevel = "High";
      } else if (riskPercentage >= 30) {
        riskLevel = "Moderate";
      } else {
        riskLevel = "Low";
      }
    }

    // Determine color
    Color color;
    if (riskLevel.toLowerCase().contains("high")) {
      color = Colors.redAccent;
    } else if (riskLevel.toLowerCase().contains("moderate") ||
        riskLevel.toLowerCase().contains("medium")) {
      color = Colors.orangeAccent;
    } else {
      color = Colors.greenAccent;
    }

    _showPredictionDialog(riskPercentage, riskLevel, color);
  }

  void _showPredictionDialog(double probability, String level, Color color) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B3B6F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Diabetes Risk Result",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(level,
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Probability: ${probability.toStringAsFixed(2)}%",
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              if (level == "High")
                const Text("⚠️ Please consult a doctor",
                    style: TextStyle(color: Colors.redAccent, fontSize: 14)),
              if (level == "Moderate")
                const Text("💡 Consider lifestyle changes",
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 14)),
              if (level == "Low")
                const Text("✅ Keep maintaining healthy habits",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, {
                    'level': level,
                    'risk': '${probability.toStringAsFixed(1)}%',
                    'color': color.value,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: const Size(150, 40),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: "Retry",
          textColor: Colors.white,
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Map<String, dynamic> data = _prepareData();
              sendPredictionRequest(data);
            }
          },
        ),
      ),
    );
  }

  // =================== BMI CALCULATOR ===================
  void _openBMIDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B3B6F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Calculate BMI",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _heightFeetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Height (feet)",
                labelStyle: TextStyle(color: Colors.white70),
                hintText: "e.g., 5",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _heightInchesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Height (inches)",
                labelStyle: TextStyle(color: Colors.white70),
                hintText: "e.g., 10",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Weight (kg)",
                labelStyle: TextStyle(color: Colors.white70),
                hintText: "e.g., 70",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: _calculateBMI,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text("Calculate", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _calculateBMI() {
    final feet = double.tryParse(_heightFeetController.text) ?? 0;
    final inches = double.tryParse(_heightInchesController.text) ?? 0;
    final weight = double.tryParse(_weightController.text) ?? 0;

    // Validate inputs
    if (feet <= 0 || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid height and weight"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (inches < 0 || inches >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Inches must be between 0 and 11"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Calculate BMI
    double totalInches = (feet * 12) + inches;
    double heightM = totalInches * 0.0254;
    double bmiValue = weight / (heightM * heightM);

    setState(() {
      bmi = double.parse(bmiValue.toStringAsFixed(1));
      overweight = (bmi ?? 0) >= 25 ? 1 : 0;

      // Auto-estimate waist circumference
      if (waistCircumference == null) {
        waistCircumference = _calculateWaistFromBMI(bmiValue);
      }
    });

    // Clear controllers
    _heightFeetController.clear();
    _heightInchesController.clear();
    _weightController.clear();

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("BMI calculated: ${bmi!.toStringAsFixed(1)}"),
        backgroundColor: Colors.green,
      ),
    );
  }

  double _calculateWaistFromBMI(double bmi) {
    // Simple estimation formula
    return (sqrt(bmi) * 20 + 60).clamp(60.0, 150.0);
  }

  // =================== WIDGET BUILDERS ===================
  Widget _buildYesNoSelector(String label, int? value, Function(int?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            children: [
              // Yes
              GestureDetector(
                onTap: () => setState(() => onChanged(1)),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: value == 1 ? Colors.greenAccent : Colors.transparent,
                        border: Border.all(color: value == 1 ? Colors.greenAccent : Colors.white54, width: 2),
                      ),
                      child: value == 1 ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                    ),
                    const SizedBox(width: 6),
                    const Text("Yes", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // No
              GestureDetector(
                onTap: () => setState(() => onChanged(0)),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: value == 0 ? Colors.redAccent : Colors.transparent,
                        border: Border.all(color: value == 0 ? Colors.redAccent : Colors.white54, width: 2),
                      ),
                      child: value == 0 ? const Icon(Icons.close, size: 16, color: Colors.black) : null,
                    ),
                    const SizedBox(width: 6),
                    const Text("No", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // Skip
              GestureDetector(
                onTap: () => setState(() => onChanged(null)),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: value == null ? Colors.grey : Colors.transparent,
                        border: Border.all(color: value == null ? Colors.grey : Colors.white54, width: 2),
                      ),
                      child: value == null ? const Icon(Icons.remove, size: 16, color: Colors.black) : null,
                    ),
                    const SizedBox(width: 6),
                    const Text("Skip", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool showClearOption = true,
  }) {
    List<DropdownMenuItem<T>> allItems = [];

    if (showClearOption) {
      allItems.add(DropdownMenuItem<T>(
        value: null,
        child: Text("Select option", style: TextStyle(color: Colors.grey)),
      ));
    }

    allItems.addAll(items);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        value: value,
        items: allItems,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          labelStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dropdownColor: const Color(0xFF1B3B6F),
        style: const TextStyle(color: Colors.white),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildNumberField(
      String label,
      String hint,
      Function(String?) onSaved, {
        bool isRequired = false,
        String? errorText,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          errorText: errorText,
        ),
        style: const TextStyle(color: Colors.white),
        onSaved: onSaved,
        validator: (v) {
          if (isRequired && (v == null || v.isEmpty)) {
            return "This field is required";
          }
          return null;
        },
      ),
    );
  }

  // =================== PREPARE DATA ===================
  Map<String, dynamic> _prepareData() {
    return {
      // Original features
      "HighBP": highBP ?? 0,
      "overweight": overweight ?? 0,
      "HighChol": highChol ?? 0,
      "DiffWalk": diffWalk ?? 0,
      "HeartDiseaseorAttack": heartDisease ?? 0,
      "Stroke": stroke ?? 0,
      "Smoker": smoker ?? 0,
      "CholCheck": cholCheck ?? 0,
      "BMI": bmi ?? 0.0,
      "GenHlth": genHlth ?? 0.0,
      "PhysHlth": physHlth ?? 0.0,
      "MentHlth": mentHlth ?? 0.0,
      "Age": age ?? 0.0,
      "Education": education ?? 0.0,
      "Income": income ?? 0.0,
      "PhysActivity": physActivity ?? 0.0,
      "Fruits": fruits ?? 0.0,
      "Veggies": veggies ?? 0.0,
      "HvyAlcoholConsump": hvyAlcohol ?? 0.0,

      // New features
      "family_history_diabetes": familyHistoryDiabetes ?? 0,
      "bp_medication": bpMedication ?? 0,
      "waist_circumference_cm": waistCircumference ?? 0.0,
      "fasting_glucose_mg_dl": fastingGlucose ?? 0.0,
      "hba1c_percent": hba1c ?? 0.0,
    };
  }

  // =================== BUILD METHOD ===================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text("Health Data Form"),
        backgroundColor: const Color(0xFF1B3B6F),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetAllFields,
            tooltip: "Reset Form",
          ),
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: _showHelpDialog,
            tooltip: "Help",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status Card
              Card(
                color: _isLoading ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _isLoading ? Icons.sync : Icons.info,
                        color: _isLoading ? Colors.orange : Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoading ? "Connecting to server..." : "Server Status",
                              style: TextStyle(
                                color: _isLoading ? Colors.orange : Colors.blue[200],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Using: ${apiUrl.replaceAll('/predict', '')}",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // SECTION 1: BASIC INFO
              const Text(
                "👤 Basic Information",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              _buildNumberField(
                "Age (years)*",
                "Enter your age",
                    (v) => age = double.tryParse(v ?? '0'),
                isRequired: true,
              ),

              _buildDropdownField<double>(
                label: "Education Level",
                value: education,
                items: const [
                  DropdownMenuItem<double>(value: 1.0, child: Text("No Schooling")),
                  DropdownMenuItem<double>(value: 2.0, child: Text("Primary School")),
                  DropdownMenuItem<double>(value: 3.0, child: Text("High School")),
                  DropdownMenuItem<double>(value: 4.0, child: Text("Some College")),
                  DropdownMenuItem<double>(value: 5.0, child: Text("Bachelor's Degree")),
                  DropdownMenuItem<double>(value: 6.0, child: Text("Postgraduate")),
                ],
                onChanged: (val) => setState(() => education = val),
              ),

              _buildDropdownField<double>(
                label: "Income Level",
                value: income,
                items: const [
                  DropdownMenuItem<double>(value: 1.0, child: Text("Low Income")),
                  DropdownMenuItem<double>(value: 2.0, child: Text("Medium Low Income")),
                  DropdownMenuItem<double>(value: 3.0, child: Text("Medium Income")),
                  DropdownMenuItem<double>(value: 4.0, child: Text("Medium High Income")),
                  DropdownMenuItem<double>(value: 5.0, child: Text("High Income")),
                ],
                onChanged: (val) => setState(() => income = val),
              ),

              const SizedBox(height: 30),

              // SECTION 2: CLINICAL MEASUREMENTS
              const Text(
                "🩺 Clinical Measurements",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              _buildYesNoSelector(
                "Family History of Diabetes?",
                familyHistoryDiabetes,
                    (val) => setState(() => familyHistoryDiabetes = val),
              ),

              _buildYesNoSelector(
                "On Blood Pressure Medication?",
                bpMedication,
                    (val) => setState(() => bpMedication = val),
              ),

              _buildNumberField(
                "Waist Circumference (cm)",
                "e.g., 85.0",
                    (v) => waistCircumference = double.tryParse(v ?? ''),
              ),

              _buildNumberField(
                "Fasting Glucose (mg/dL)",
                "Normal: 70-100",
                    (v) => fastingGlucose = double.tryParse(v ?? ''),
              ),

              _buildNumberField(
                "HbA1c (%)",
                "Normal: 4.0-5.6",
                    (v) => hba1c = double.tryParse(v ?? ''),
              ),

              const SizedBox(height: 30),

              // SECTION 3: HEALTH & LIFESTYLE
              const Text(
                "❤️ Health & Lifestyle",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              _buildYesNoSelector(
                "High Blood Pressure?",
                highBP,
                    (val) => setState(() => highBP = val),
              ),

              _buildYesNoSelector(
                "Have you ever had your cholesterol checked?",
                cholCheck,
                    (val) => setState(() => cholCheck = val),
              ),

              _buildYesNoSelector(
                "Do you have high cholesterol?",
                highChol,
                    (val) => setState(() => highChol = val),
              ),

              _buildYesNoSelector(
                "Heart Disease or Attack?",
                heartDisease,
                    (val) => setState(() => heartDisease = val),
              ),

              _buildYesNoSelector(
                "Stroke?",
                stroke,
                    (val) => setState(() => stroke = val),
              ),

              _buildYesNoSelector(
                "Difficulty Walking?",
                diffWalk,
                    (val) => setState(() => diffWalk = val),
              ),

              _buildYesNoSelector(
                "Smoker?",
                smoker,
                    (val) => setState(() => smoker = val),
              ),

              _buildDropdownField<int>(
                label: "Physically Active?",
                value: physActivity?.toInt(),
                items: const [
                  DropdownMenuItem<int>(value: 1, child: Text("Yes")),
                  DropdownMenuItem<int>(value: 0, child: Text("No")),
                ],
                onChanged: (val) => setState(() => physActivity = val?.toDouble()),
              ),

              _buildDropdownField<double>(
                label: "Eat Fruits Daily?",
                value: fruits,
                items: const [
                  DropdownMenuItem<double>(value: 1.0, child: Text("Yes")),
                  DropdownMenuItem<double>(value: 0.0, child: Text("No")),
                ],
                onChanged: (val) => setState(() => fruits = val),
              ),

              _buildDropdownField<double>(
                label: "Eat Vegetables Daily?",
                value: veggies,
                items: const [
                  DropdownMenuItem<double>(value: 1.0, child: Text("Yes")),
                  DropdownMenuItem<double>(value: 0.0, child: Text("No")),
                ],
                onChanged: (val) => setState(() => veggies = val),
              ),

              _buildDropdownField<double>(
                label: "Heavy Alcohol Consumption?",
                value: hvyAlcohol,
                items: const [
                  DropdownMenuItem<double>(value: 1.0, child: Text("Yes")),
                  DropdownMenuItem<double>(value: 0.0, child: Text("No")),
                ],
                onChanged: (val) => setState(() => hvyAlcohol = val),
              ),

              _buildDropdownField<double>(
                label: "General Health",
                value: genHlth,
                items: const [
                  DropdownMenuItem<double>(value: 1.0, child: Text("Excellent")),
                  DropdownMenuItem<double>(value: 2.0, child: Text("Very Good")),
                  DropdownMenuItem<double>(value: 3.0, child: Text("Good")),
                  DropdownMenuItem<double>(value: 4.0, child: Text("Fair")),
                  DropdownMenuItem<double>(value: 5.0, child: Text("Poor")),
                ],
                onChanged: (val) => setState(() => genHlth = val),
              ),

              _buildDropdownField<double>(
                label: "Physical Health Problems",
                value: physHlth,
                items: const [
                  DropdownMenuItem<double>(value: 0.0, child: Text("No problem")),
                  DropdownMenuItem<double>(value: 1.0, child: Text("< 6 months")),
                  DropdownMenuItem<double>(value: 2.0, child: Text("6-12 months")),
                  DropdownMenuItem<double>(value: 3.0, child: Text("1-2 years")),
                  DropdownMenuItem<double>(value: 4.0, child: Text("> 2 years")),
                ],
                onChanged: (val) => setState(() => physHlth = val),
              ),

              _buildDropdownField<double>(
                label: "Mental Health Issues",
                value: mentHlth,
                items: const [
                  DropdownMenuItem<double>(value: 0.0, child: Text("No issue")),
                  DropdownMenuItem<double>(value: 1.0, child: Text("< 6 months")),
                  DropdownMenuItem<double>(value: 2.0, child: Text("6-12 months")),
                  DropdownMenuItem<double>(value: 3.0, child: Text("1-2 years")),
                  DropdownMenuItem<double>(value: 4.0, child: Text("> 2 years")),
                ],
                onChanged: (val) => setState(() => mentHlth = val),
              ),

              const SizedBox(height: 20),

              // BMI CARD
              Card(
                color: Colors.white.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: const Text("Body Mass Index (BMI)", style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    bmi != null ? "Your BMI: $bmi (${_getBMICategory(bmi!)})" : "Tap to calculate BMI",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calculate, color: Colors.white),
                    onPressed: _openBMIDialog,
                  ),
                  onTap: _openBMIDialog,
                ),
              ),

              const SizedBox(height: 30),

              // ACTION BUTTONS
              Column(
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          onPressed: _isLoading ? null : resetAllFields,
                          child: const Text(
                            "Reset Form",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isLoading ? null : () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();

                              // Validate required fields
                              if (age == null) {
                                _showError("Age is required");
                                return;
                              }

                              if (bmi == null) {
                                _showError("Please calculate your BMI first");
                                return;
                              }

                              Map<String, dynamic> data = _prepareData();
                              print("📤 Sending data with ${data.length} features");
                              sendPredictionRequest(data);
                            }
                          },
                          child: _isLoading
                              ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text("Processing...", style: TextStyle(fontSize: 16, color: Colors.black)),
                            ],
                          )
                              : const Text(
                            "Predict Diabetes Risk",
                            style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Server Info Card
              Card(
                color: Colors.grey.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.computer, size: 16, color: Colors.greenAccent),
                          SizedBox(width: 8),

                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Server URL: ${apiUrl.replaceAll('/predict', '')}",
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "For Flutter Web, Flask must run on localhost:5000",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                      ElevatedButton(
                        onPressed: _showHelpDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.3),
                          minimumSize: const Size(double.infinity, 30),
                        ),
                        child: const Text("Troubleshooting Guide", style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25) return "Normal";
    if (bmi < 30) return "Overweight";
    return "Obese";
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B3B6F),
        title: const Text("Flutter Web + Flask Setup Guide", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("1️⃣ Start Flask Server:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black.withOpacity(0.3),
                child: const Text(
                  "python app.py",
                  style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 10),
              const Text("2️⃣ Check if Flask is running:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black.withOpacity(0.3),
                child: const Text(
                  "Open browser and go to: http://localhost:5000",
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 10),
              const Text("3️⃣ If you see:", style: TextStyle(color: Colors.white)),
              const Text("✅ DiabetesCare+ Flask API is running", style: TextStyle(color: Colors.green)),
              const SizedBox(height: 10),
              const Text("4️⃣ Common Issues:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Text("• Port 5000 might be blocked", style: TextStyle(color: Colors.white70)),
              const Text("• Try: python app.py --port=5001", style: TextStyle(color: Colors.yellow)),
              const Text("• Update URL in code to port 5001", style: TextStyle(color: Colors.yellow)),
              const SizedBox(height: 10),
              const Text("5️⃣ Testing Connection:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Text("Check browser console for connection logs", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              testServerConnection();
            },
            child: const Text("Test Connection"),
          ),
        ],
      ),
    );
  }
}
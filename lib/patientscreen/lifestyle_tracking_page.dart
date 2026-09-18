import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class LifestylePlanPage extends StatefulWidget {
  final int age;
  final String riskLevel;
  final String patientName;
  final bool hasDiabetes;

  LifestylePlanPage({
    super.key,
    required this.age,
    required this.riskLevel,
    required this.patientName,
    this.hasDiabetes = false,
  });

  @override
  State<LifestylePlanPage> createState() => _LifestylePlanPageState();
}

class _LifestylePlanPageState extends State<LifestylePlanPage> {
  Map<String, dynamic>? plan;
  bool _isLoading = false;
  String patientScenario = "";
  List<String> selectedPreferences = [];
  List<String> selectedRestrictions = [];
  String selectedCondition = "";

  final List<String> foodPreferences = [
    " NO Fruits ",
    "Vegetarian",
    "Non-vegetarian",
    "Low carb",
    "No sugar",
    "Gluten-free",
    "Lactose intolerant"
  ];

  final List<String> activityRestrictions = [
    "Leg injury",
    "Back pain",
    "Arthritis",
    "Heart condition",
    "High BP",
    "No restrictions"
  ];

  final List<String> healthConditions = [
    "Newly diagnosed",
    "Long-term diabetes",
    "Gestational diabetes",
    "Pre-diabetes",
    "With complications"
  ];

  Future<void> fetchLifestylePlan() async {
    if (_isLoading) return; // ✅ 429 FIX: multiple taps block

    setState(() {
      _isLoading = true;
      plan = null;
    });


    final backendUrl = Uri.parse("http://10.115.148.228:5000/lifestyle_plan_ai");

    try {
      final response = await http.post(
        backendUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "age": widget.age,
          "risk_level": widget.riskLevel,
          "has_diabetes": widget.hasDiabetes,
          "patient_name": widget.patientName,
          "scenario": patientScenario,
          "preferences": selectedPreferences,
          "restrictions": selectedRestrictions,
          "condition": selectedCondition,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          plan = data;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ plan generated!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper method for text styling
  TextStyle _textStyle({double size = 14, Color color = Colors.white, FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.roboto(
      fontSize: size,
      color: color,
      fontWeight: weight,
    );
  }

  Widget _buildScenarioInput() {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Describe your daily routine or concerns:",
              style: _textStyle(size: 14, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              style: _textStyle(color: Colors.white), // Explicit white color
              decoration: InputDecoration(
                hintText: "e.g., 'Office job, no time for exercise...'",
                hintStyle: _textStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              onChanged: (value) => patientScenario = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceSelector() {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Food Preferences:",
              style: _textStyle(size: 14, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: foodPreferences.map((pref) {
                bool isSelected = selectedPreferences.contains(pref);
                return ChoiceChip(
                  label: Text(
                    pref,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedPreferences.add(pref);
                      } else {
                        selectedPreferences.remove(pref);
                      }
                    });
                  },
                  selectedColor: Colors.teal,
                  backgroundColor: Colors.grey, // Even lighter background
                  side: BorderSide(
                    color: isSelected ? Colors.teal : Colors.white70, // Different border for selected
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictionSelector() {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Activity Restrictions:",
              style: _textStyle(size: 14, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activityRestrictions.map((restriction) {
                bool isSelected = selectedRestrictions.contains(restriction);
                return ChoiceChip(
                  label: Text(
                    restriction,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedRestrictions.add(restriction);
                      } else {
                        selectedRestrictions.remove(restriction);
                      }
                    });
                  },
                  selectedColor: Colors.teal,
                  backgroundColor: Colors.grey,
                  side: BorderSide(
                    color: isSelected ? Colors.teal : Colors.white70,
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildConditionSelector() {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Health Condition:",
              style: _textStyle(size: 14, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                value: selectedCondition.isNotEmpty ? selectedCondition : null,
                hint: Text("Select condition", style: _textStyle(color: Colors.white70)),
                dropdownColor: Color(0xFF1B3B6F),
                style: _textStyle(color: Colors.white),
                icon: Icon(Icons.arrow_drop_down, color: Colors.white70),
                iconSize: 24,
                underline: SizedBox(), // Remove default underline
                isExpanded: true,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedCondition = newValue ?? "";
                  });
                },
                items: healthConditions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: _textStyle(color: Colors.white)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDisplay() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text(
              "🤖 Gemini AI is creating your plan...",
              style: _textStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (plan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.blueAccent),
            SizedBox(height: 16),
            Text(
              "Generate Your  Lifestyle Plan",
              style: _textStyle(size: 18, color: Colors.white, weight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Click 'Generate ' button",

              style: _textStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Check if plan has error
    if (plan!.containsKey('error')) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              "AI Error",
              style: _textStyle(size: 20, color: Colors.red, weight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                plan!['error'].toString(),
                textAlign: TextAlign.center,
                style: _textStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    // Check actual Gemini response keys
    print("🔍 Plan Keys: ${plan!.keys.toList()}");

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SUCCESS HEADER
          Card(
            color: Colors.green.withOpacity(0.1),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "✅  Plan Generated Successfully",
                          style: _textStyle(size: 16, color: Colors.white, weight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        if (plan!['source'] != null)
                          Text(
                            "Source: ${plan!['source']}",
                            style: _textStyle(size: 12, color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // PATIENT SUMMARY
          if (plan!['patient_summary'] != null)
            Card(
              color: Colors.blueAccent.withOpacity(0.15),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.amber,
                          child: Text(
                            widget.patientName.substring(0, 1).toUpperCase(),
                            style: _textStyle(color: Colors.black, weight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.patientName,
                                style: _textStyle(size: 18, color: Colors.white, weight: FontWeight.bold),
                              ),
                              Text(
                                "${widget.age} years • ${widget.hasDiabetes ? 'Diabetes' : 'Pre-diabetic'} • ${widget.riskLevel} Risk",
                                style: _textStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      plan!['patient_summary'].toString(),
                      style: _textStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          SizedBox(height: 20),

          // PLAN OVERVIEW
          if (plan!['plan_overview'] != null)
            Card(
              color: Colors.teal.withOpacity(0.1),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "📋 Plan Overview",
                      style: _textStyle(size: 18, color: Colors.tealAccent, weight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Text(
                      plan!['plan_overview'].toString(),
                      style: _textStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          SizedBox(height: 20),

          // DAILY SCHEDULE
          if (plan!['daily_schedule'] != null && plan!['daily_schedule'] is List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "📅 Daily Schedule",
                    style: _textStyle(size: 18, color: Colors.greenAccent, weight: FontWeight.bold),
                  ),
                ),
                Column(
                  children: (plan!['daily_schedule'] as List).map<Widget>((item) {
                    String time = item['time']?.toString() ?? 'Time';
                    String activity = item['activity']?.toString() ?? 'Activity';

                    return Card(
                      color: Colors.white10,
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            time.split(':')[0],
                            style: _textStyle(color: Colors.greenAccent, weight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          time,
                          style: _textStyle(size: 12, color: Colors.white70),
                        ),
                        subtitle: Text(
                          activity,
                          style: _textStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
              ],
            ),

          // NUTRITION PLAN
          if (plan!['nutrition_plan'] != null && plan!['nutrition_plan'] is Map)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "🍽️ Nutrition Plan",
                    style: _textStyle(size: 18, color: Colors.orangeAccent, weight: FontWeight.bold),
                  ),
                ),
                Card(
                  color: Colors.white10,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildNutritionItem("🌅 Breakfast", plan!['nutrition_plan']['breakfast']),
                        Divider(color: Colors.white24),
                        _buildNutritionItem("🕛 Lunch", plan!['nutrition_plan']['lunch']),
                        Divider(color: Colors.white24),
                        _buildNutritionItem("🌙 Dinner", plan!['nutrition_plan']['dinner']),
                        Divider(color: Colors.white24),
                        _buildNutritionItem("🍎 Snacks", plan!['nutrition_plan']['snacks']),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),

          // EXERCISE PLAN
          if (plan!['exercise_plan'] != null && plan!['exercise_plan'] is List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "💪 Exercise Plan",
                    style: _textStyle(size: 18, color: Colors.blueAccent, weight: FontWeight.bold),
                  ),
                ),
                Column(
                  children: (plan!['exercise_plan'] as List).map<Widget>((exercise) {
                    return Card(
                      color: Colors.white10,
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.fitness_center, color: Colors.blueAccent, size: 20),
                        ),
                        title: Text(
                          exercise['activity']?.toString() ?? "Exercise",
                          style: _textStyle(color: Colors.white, weight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.timer, size: 14, color: Colors.white70),
                                SizedBox(width: 4),
                                Text(
                                  "${exercise['duration_minutes'] ?? '30'} minutes",
                                  style: _textStyle(color: Colors.white70),
                                ),
                                SizedBox(width: 12),
                                Icon(Icons.repeat, size: 14, color: Colors.white70),
                                SizedBox(width: 4),
                                Text(
                                  exercise['frequency']?.toString() ?? "Daily",
                                  style: _textStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            if (exercise['instructions'] != null)
                              Text(
                                exercise['instructions'].toString(),
                                style: _textStyle(color: Colors.white70, size: 13),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
              ],
            ),

          // MEDICATION REMINDERS
          if (plan!['medication_reminders'] != null && plan!['medication_reminders'] is List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "💊 Medication Reminders",
                    style: _textStyle(size: 16, color: Colors.purpleAccent, weight: FontWeight.bold),
                  ),
                ),
                Card(
                  color: Colors.purple.withOpacity(0.1),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: (plan!['medication_reminders'] as List).map<Widget>((reminder) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.circle, size: 8, color: Colors.purpleAccent),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reminder.toString(),
                                  style: _textStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),

          // MONITORING TIPS
          if (plan!['monitoring_tips'] != null && plan!['monitoring_tips'] is List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "📊 Monitoring Tips",
                    style: _textStyle(size: 18, color: Colors.greenAccent, weight: FontWeight.bold),
                  ),
                ),
                Card(
                  color: Colors.greenAccent.withOpacity(0.05),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: (plan!['monitoring_tips'] as List).map<Widget>((tip) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tip.toString(),
                                  style: _textStyle(color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),

          // WEEKLY CHECKLIST
          if (plan!['weekly_checklist'] != null && plan!['weekly_checklist'] is List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "✅ Weekly Checklist",
                    style: _textStyle(size: 16, color: Colors.greenAccent, weight: FontWeight.bold),
                  ),
                ),
                Card(
                  color: Colors.green.withOpacity(0.1),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: (plan!['weekly_checklist'] as List).map<Widget>((task) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_box_outline_blank, size: 20, color: Colors.greenAccent),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  task.toString(),
                                  style: _textStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),

          // AI INFO FOOTER
          Card(
            color: Colors.grey.withOpacity(0.1),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.model_training, size: 16, color: Colors.white60),
                  SizedBox(width: 8),
                  Text(
                    "Powered by ${plan!['model'] ?? 'Gemini AI'}",
                    style: _textStyle(size: 12, color: Colors.white60),
                  ),
                  Spacer(),
                  if (plan!['generated_at'] != null)
                    Text(
                      plan!['generated_at'].toString().substring(0, 10),
                      style: _textStyle(size: 12, color: Colors.white60),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // REGENERATE BUTTON
          Center(
            child: ElevatedButton.icon( onPressed: _isLoading ? null : fetchLifestylePlan,
              icon: Icon(Icons.refresh, color: Colors.white),
              label: Text(
                "Regenerate with Gemini AI",
                style: _textStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),

          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String title, dynamic description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          child: Text(
            title,
            style: _textStyle(color: Colors.amber, weight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            description?.toString() ?? "Not specified",
            style: _textStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gemini AI Lifestyle Plan", style: _textStyle(weight: FontWeight.bold)),
        backgroundColor: Color(0xFF1B3B6F),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      backgroundColor: Color(0xFF0D1B2A),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Patient Info
            Card(
              color: Colors.blueAccent.withOpacity(0.1),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Text(
                        widget.patientName.substring(0, 1).toUpperCase(),
                        style: _textStyle(color: Colors.black, weight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.patientName,
                            style: _textStyle(size: 18, color: Colors.white, weight: FontWeight.bold),
                          ),
                          Text(
                            "${widget.age} years • ${widget.hasDiabetes ? 'Diabetes' : 'Pre-diabetes'} • ${widget.riskLevel} Risk",
                            style: _textStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Input Sections - WITH FIXED VISIBILITY
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white10,
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    "Customize Your Plan",
                    style: _textStyle(size: 16, color: Colors.amber, weight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildPreferenceSelector(),
                  SizedBox(height: 16),
                  _buildRestrictionSelector(),
                  SizedBox(height: 16),
                  _buildConditionSelector(),
                  SizedBox(height: 16),
                  _buildScenarioInput(),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Generate Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : fetchLifestylePlan,

              icon: Icon(Icons.auto_awesome, size: 24, color: Colors.white),
              label: Text(
                "Generate with Gemini AI",
                style: _textStyle(size: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            SizedBox(height: 30),

            // Plan Display
            _buildPlanDisplay(),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ViewLifestylePlanPage extends StatefulWidget {
  const ViewLifestylePlanPage({super.key});

  @override
  State<ViewLifestylePlanPage> createState() => _ViewLifestylePlanPageState();
}

class _ViewLifestylePlanPageState extends State<ViewLifestylePlanPage> {
  List<dynamic> lifestylePlans = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLifestylePlans();
  }

  Future<void> fetchLifestylePlans() async {
    try {
      final response =
      await http.get(Uri.parse('http://192.168.1.115:5000/lifestyle_plan'));
      if (response.statusCode == 200) {
        setState(() {
          lifestylePlans = json.decode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load plans');
      }
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> updatePlan(int planId, String description, String riskLevel, String ageGroup) async {
    try {
      final response = await http.put(
        Uri.parse('http://192.168.1.115:5000/lifestyle_plan/$planId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'description': description,
          'risk_level': riskLevel,
          'age_group': ageGroup, // ✅ include age_group
        }),
      );

      if (response.statusCode == 200) {
        fetchLifestylePlans();
      } else {
        throw Exception('Failed to update plan');
      }
    } catch (e) {
      print('Error updating plan: $e');
    }
  }

  Future<void> _showPlanDetailsDialog(Map<String, dynamic> plan) async {
    final TextEditingController descriptionController =
    TextEditingController(text: plan['description'] ?? '');
    String riskLevel = plan['risk_level'] ?? 'Low';

    // Fetch activities and meals
    List<dynamic> activities = [];
    List<dynamic> meals = [];
    try {
      final activitiesRes = await http
          .get(Uri.parse('http://192.168.1.115:5000/activities/${plan['plan_id']}'));
      final mealsRes = await http
          .get(Uri.parse('http://192.168.1.115:5000/meal_plans/${plan['plan_id']}'));

      activities = json.decode(activitiesRes.body);
      meals = json.decode(mealsRes.body);
    } catch (e) {
      print('Error fetching plan details: $e');
    }

    // Create controllers for activities and meals
    List<TextEditingController> activityNameControllers = [];
    List<TextEditingController> durationControllers = [];
    List<TextEditingController> activityDescControllers = [];

    List<TextEditingController> mealTypeControllers = [];
    List<TextEditingController> mealDescControllers = [];

    for (var a in activities) {
      activityNameControllers.add(TextEditingController(text: a['activity_name']));
      durationControllers.add(TextEditingController(text: a['duration'].toString()));
      activityDescControllers.add(TextEditingController(text: a['description']));
    }

    for (var m in meals) {
      mealTypeControllers.add(TextEditingController(text: m['meal_type']));
      mealDescControllers.add(TextEditingController(text: m['description']));
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Plan ${plan['plan_id']} Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(controller: descriptionController, maxLines: 2),
                  const SizedBox(height: 10),
                  const Text('Risk Level:', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: riskLevel,
                    items: ['Low', 'Medium', 'High']
                        .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => riskLevel = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text('Physical Activities:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.generate(activities.length, (index) {
                    return Column(
                      children: [
                        TextField(controller: activityNameControllers[index], decoration: const InputDecoration(labelText: 'Activity Name')),
                        TextField(controller: durationControllers[index], decoration: const InputDecoration(labelText: 'Duration (mins)')),
                        TextField(controller: activityDescControllers[index], decoration: const InputDecoration(labelText: 'Description')),
                        const SizedBox(height: 10),
                      ],
                    );
                  }),
                  const Text('Meal Plans:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.generate(meals.length, (index) {
                    return Column(
                      children: [
                        TextField(controller: mealTypeControllers[index], decoration: const InputDecoration(labelText: 'Meal Type')),
                        TextField(controller: mealDescControllers[index], decoration: const InputDecoration(labelText: 'Description')),
                        const SizedBox(height: 10),
                      ],
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              TextButton(
                onPressed: () async {
                  // Update lifestyle plan
                  await updatePlan(plan['plan_id'], descriptionController.text, riskLevel, plan['age_group']);

                  // Update physical activities with controllers
                  for (int i = 0; i < activities.length; i++) {
                    await http.put(
                      Uri.parse('http://192.168.1.115:5000/activities/${activities[i]['activity_id']}'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'activity_name': activityNameControllers[i].text,
                        'duration': int.parse(durationControllers[i].text),
                        'description': activityDescControllers[i].text,
                      }),
                    );
                  }

                  // Update meal plans with controllers
                  for (int i = 0; i < meals.length; i++) {
                    await http.put(
                      Uri.parse('http://192.168.1.115:5000/meal_plans/${meals[i]['meal_id']}'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'meal_type': mealTypeControllers[i].text,
                        'description': mealDescControllers[i].text,
                      }),
                    );
                  }

                  Navigator.pop(context);
                  fetchLifestylePlans();
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lifestyle Plans'),
        backgroundColor: const Color(0xFF1B3B6F),
      ),
      backgroundColor: const Color(0xFF0D1B2A),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lifestylePlans.length,
        itemBuilder: (context, index) {
          final plan = lifestylePlans[index];
          return Card(
            color: const Color(0xFF1B3B6F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                'Plan ${plan['plan_id']} - ${plan['age_group']}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(plan['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('Risk Level: ${plan['risk_level']}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward, color: Colors.greenAccent),
              onTap: () => _showPlanDetailsDialog(plan),
            ),
          );
        },
      ),
    );
  }
}

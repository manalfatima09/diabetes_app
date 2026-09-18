import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AnalyticsPage extends StatefulWidget {
  final String patientName;

  const AnalyticsPage({super.key, required this.patientName});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool showWeekly = true;
  List<Map<String, dynamic>> taskProgress = [];
  bool isLoading = true; // 🔹 loading state
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchTrackingData(); // 🔹 call without argument because we use widget.patientName
  }

  Future<void> fetchTrackingData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse(
          "http://192.168.1.115:5000/get_tracking?patient_name=${widget.patientName}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // 🔹 Ensure all numeric fields are int
        taskProgress = data.map((item) {
          return {
            'task': item['task'].toString(),
            'weekly_done': int.parse(item['weekly_done'].toString()),
            'weekly_target': int.parse(item['weekly_target'].toString()),
            'monthly_done': int.parse(item['monthly_done'].toString()),
            'monthly_target': int.parse(item['monthly_target'].toString()),
          };
        }).toList();
      } else {
        errorMessage = "Failed to load data: ${response.statusCode}";
      }
    } catch (e) {
      errorMessage = "Error: $e";
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lifestyle Progress"),
        backgroundColor: const Color(0xFF1B3B6F),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFF0D1B2A),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔹 Choice Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Weekly",
                      style: TextStyle(color: Colors.white)),
                  selected: showWeekly,
                  selectedColor: Colors.lightBlueAccent,
                  onSelected: (_) => setState(() => showWeekly = true),
                  backgroundColor: Colors.white24,
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text("Monthly",
                      style: TextStyle(color: Colors.white)),
                  selected: !showWeekly,
                  selectedColor: Colors.lightGreenAccent,
                  onSelected: (_) => setState(() => showWeekly = false),
                  backgroundColor: Colors.white24,
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 🔹 Body
            Expanded(
              child: isLoading
                  ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
                  : errorMessage != null
                  ? Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ))
                  : ListView(
                children: taskProgress.map((task) {
                  int done = showWeekly
                      ? task['weekly_done']
                      : task['monthly_done'];
                  int target = showWeekly
                      ? task['weekly_target']
                      : task['monthly_target'];
                  double progress =
                  target == 0 ? 0 : done / target;

                  return Card(
                    color: Colors.white12,
                    margin:
                    const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        task['task'],
                        style:
                        const TextStyle(color: Colors.white),
                      ),
                      subtitle: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        color: showWeekly
                            ? Colors.lightBlueAccent
                            : Colors.lightGreenAccent,
                      ),
                      trailing: Text(
                        "${(progress * 100).toStringAsFixed(0)}%",
                        style:
                        const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

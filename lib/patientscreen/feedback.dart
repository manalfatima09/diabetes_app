import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FeedbackPage extends StatefulWidget {
  final String patientUid; // Use Firebase UID instead of name

  const FeedbackPage({super.key, required this.patientUid});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;

  final String apiBaseUrl = "http://10.115.149.50:5000/"; // Flask server URL
  List<Map<String, dynamic>> feedbackList = [];

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  // Fetch all feedback for this patient
  Future<void> _fetchFeedback() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/get_feedback_by_user/${widget.patientUid}"),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          feedbackList =
              data.map((item) => Map<String, dynamic>.from(item)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to fetch feedback");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching feedback: $e")),
      );
    }
  }

  // Submit new feedback or update existing
  Future<void> submitFeedback({int? feedbackId}) async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your feedback."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      Uri url;
      Map<String, dynamic> body = {
        "patient_uid": widget.patientUid,
        "feedback_text": _feedbackController.text.trim(),
        "timestamp": DateTime.now().toIso8601String(),
      };

      if (feedbackId == null) {
        url = Uri.parse("$apiBaseUrl/submit_feedback");
      } else {
        url = Uri.parse("$apiBaseUrl/update_feedback/$feedbackId");
      }

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _feedbackController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                feedbackId == null ? "Feedback submitted!" : "Feedback updated!"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchFeedback();
      } else {
        throw Exception("Failed: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // Delete feedback
  Future<void> deleteFeedback(int feedbackId) async {
    try {
      final response = await http.delete(
        Uri.parse("$apiBaseUrl/delete_feedback/$feedbackId"),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Feedback deleted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchFeedback();
      } else {
        throw Exception("Failed to delete feedback");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Edit feedback dialog
  void _editFeedbackDialog(Map<String, dynamic> feedback) {
    _feedbackController.text = feedback['feedback_text'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Feedback"),
          content: TextField(
            controller: _feedbackController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: "Edit your feedback"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _feedbackController.clear();
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                submitFeedback(feedbackId: feedback['id']);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // Reply to admin
  void _replyToFeedback(int parentId) {
    TextEditingController replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reply to Admin"),
          content: TextField(
            controller: replyController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "Type your reply"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (replyController.text.trim().isEmpty) return;
                await http.post(
                  Uri.parse("$apiBaseUrl/submit_feedback"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "patient_uid": widget.patientUid,
                    "feedback_text": replyController.text.trim(),
                    "timestamp": DateTime.now().toIso8601String(),
                    "parent_id": parentId
                  }),
                );
                Navigator.pop(context);
                _fetchFeedback();
              },
              child: const Text("Send"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text("Patient Feedback"),
        backgroundColor: const Color(0xFF1B3B6F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : feedbackList.isEmpty
                  ? const Center(
                child: Text(
                  "No feedback yet",
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _fetchFeedback,
                child: ListView.builder(
                  itemCount: feedbackList.length,
                  itemBuilder: (context, index) {
                    final fb = feedbackList[index];
                    return Card(
                      color: const Color(0xFF1B3B6F),
                      margin:
                      const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Feedback: ${fb['feedback_text']}",
                              style: const TextStyle(
                                  color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Admin Reply: ${fb['reply_text'].isEmpty ? 'Not replied yet' : fb['reply_text']}",
                              style: TextStyle(
                                color: fb['reply_text'].isEmpty
                                    ? Colors.grey
                                    : Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Date: ${fb['timestamp']}",
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (fb['id'] != null) ...[
                                  TextButton(
                                    onPressed: () =>
                                        _editFeedbackDialog(fb),
                                    child: const Text("Edit",
                                        style: TextStyle(
                                            color: Colors.amber)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        deleteFeedback(fb['id']),
                                    child: const Text("Delete",
                                        style: TextStyle(
                                            color:
                                            Colors.redAccent)),
                                  ),
                                ],
                                if (fb['reply_text'].isNotEmpty)
                                  TextButton(
                                    onPressed: () =>
                                        _replyToFeedback(fb['id']),
                                    child: const Text(
                                        "Reply to Admin",
                                        style: TextStyle(
                                            color: Colors.lightBlue)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter your feedback here...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : submitFeedback,
                icon: _isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _isSubmitting ? "Submitting..." : "Submit Feedback",
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B3B6F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

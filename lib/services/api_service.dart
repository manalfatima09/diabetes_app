import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://192.168.1.115:5000";

  // 🧠 Prediction Data Send karne ka Function
  static Future<Map<String, dynamic>> sendPredictionData(
      Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final response = await http.post(
      Uri.parse("$baseUrl/predict"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to send prediction data: ${response.body}");
    }
  }
}

// lib/services/patient_data_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PatientDataService {
  static Future<Map<String, dynamic>> getPatientData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'name': 'Patient',
          'uid': '',
          'patientId': null,
        };
      }

      // Option 1: Agar aapke paas local database se patient data fetch karne ka API hai
      final response = await http.post(
        Uri.parse('http://192.168.1.115:5000/get_patient_by_uid'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': user.uid,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'name': data['name'] ?? user.displayName ?? 'Patient',
          'uid': user.uid,
          'patientId': data['patient_id'] ?? null,
          'email': user.email,
        };
      }

      // Option 2: Firebase se hi data lelo
      return {
        'name': user.displayName ?? 'Patient',
        'uid': user.uid,
        'patientId': null, // Isko baad mein set kar sakte hain
        'email': user.email,
      };
    } catch (e) {
      print('Error getting patient data: $e');
      return {
        'name': 'Patient',
        'uid': '',
        'patientId': null,
      };
    }
  }
}
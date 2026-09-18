// lib/services/firebase_helper.dart
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseHelper {
  static Future<String> getCurrentUserUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.uid;
    }
    return '';
  }

  static Future<String> getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.displayName ?? 'Patient';
    }
    return 'Patient';
  }
}
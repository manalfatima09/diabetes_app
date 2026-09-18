// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Base URL for your Flask backend
  static const String BASE_URL = "http://192.168.1.115:5000";

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current user email
  String? get currentUserEmail => _auth.currentUser?.email;

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Sign in with email and password
  Future<AuthResult> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return AuthResult.success(result.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error("An unexpected error occurred");
    }
  }

  // Sign up new user
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    int? age,
    String? phone,
  }) async {
    try {
      // Validate inputs
      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        return AuthResult.error("Please fill all required fields");
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = result.user!;
      final userData = {
        'uid': user.uid,
        'email': email.trim(),
        'name': name.trim(),
        'role': role, // 'patient' or 'doctor'
        'age': age,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save user data to Firestore
      await _firestore.collection('users').doc(user.uid).set(userData);

      // Save to local database for MySQL sync
      final syncResult = await _syncUserToLocalDB(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        age: age,
        phone: phone,
      );

      if (!syncResult.success) {
        print("Warning: User synced to Firebase but local sync failed: ${syncResult.message}");
      }

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error("An unexpected error occurred: $e");
    }
  }

  // Save user to local database (MySQL)
  Future<SyncResult> _syncUserToLocalDB({
    required String uid,
    required String name,
    required String email,
    required String role,
    int? age,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/sync_user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': uid,
          'name': name,
          'email': email,
          'role': role,
          'age': age,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SyncResult.success(data['message'] ?? 'User synced successfully');
      } else {
        return SyncResult.error('Failed to sync user to local database: ${response.statusCode}');
      }
    } catch (e) {
      return SyncResult.error('Network error: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Get user data error: $e");
      return null;
    }
  }

  // Get current user's complete data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    if (_auth.currentUser == null) return null;
    return await getUserData(_auth.currentUser!.uid);
  }

  // Get current user role
  Future<String?> getCurrentUserRole() async {
    final data = await getCurrentUserData();
    return data?['role'];
  }

  // Check if current user is a patient
  Future<bool> isCurrentUserPatient() async {
    final role = await getCurrentUserRole();
    return role == 'patient';
  }

  // Check if current user is a doctor
  Future<bool> isCurrentUserDoctor() async {
    final role = await getCurrentUserRole();
    return role == 'doctor';
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? name,
    int? age,
    String? phone,
    String? profileImage,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name.trim();
      if (age != null) updateData['age'] = age;
      if (phone != null) updateData['phone'] = phone;
      if (profileImage != null) updateData['profileImage'] = profileImage;

      await _firestore.collection('users').doc(user.uid).update(updateData);

      // Also update local database
      await _updateLocalUserProfile(
        uid: user.uid,
        name: name,
        age: age,
        phone: phone,
      );

      return true;
    } catch (e) {
      print("Update profile error: $e");
      return false;
    }
  }

  // Update local database profile
  Future<void> _updateLocalUserProfile({
    required String uid,
    String? name,
    int? age,
    String? phone,
  }) async {
    try {
      await http.post(
        Uri.parse('$BASE_URL/update_user_profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': uid,
          'name': name,
          'age': age,
          'phone': phone,
        }),
      );
    } catch (e) {
      print("Error updating local profile: $e");
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      print("Password reset error: $e");
      return false;
    }
  }

  // Change password
  Future<bool> changePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.updatePassword(newPassword);
      return true;
    } catch (e) {
      print("Change password error: $e");
      return false;
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Delete from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete from local database
      await _deleteUserFromLocalDB(user.uid);

      // Delete Firebase auth user
      await user.delete();

      return true;
    } catch (e) {
      print("Delete account error: $e");
      return false;
    }
  }

  // Delete user from local database
  Future<void> _deleteUserFromLocalDB(String uid) async {
    try {
      await http.post(
        Uri.parse('$BASE_URL/delete_user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': uid,
        }),
      );
    } catch (e) {
      print("Error deleting user from local DB: $e");
    }
  }

  // Helper method to get user-friendly error messages
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  // Stream for auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Stream for user data changes
  Stream<Map<String, dynamic>?> userDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return null;
    });
  }
}

// Result classes for better type safety
class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  AuthResult._({
    required this.success,
    this.user,
    this.errorMessage,
  });

  factory AuthResult.success(User? user) => AuthResult._(
    success: true,
    user: user,
  );

  factory AuthResult.error(String errorMessage) => AuthResult._(
    success: false,
    errorMessage: errorMessage,
  );
}

class SyncResult {
  final bool success;
  final String? message;
  final String? errorMessage;

  SyncResult._({
    required this.success,
    this.message,
    this.errorMessage,
  });

  factory SyncResult.success(String message) => SyncResult._(
    success: true,
    message: message,
  );

  factory SyncResult.error(String errorMessage) => SyncResult._(
    success: false,
    errorMessage: errorMessage,
  );
}
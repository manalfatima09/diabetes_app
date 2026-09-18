import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patientscreen/patient_dashboard.dart';
import 'doctorscreen/doctor_dashboard.dart';
import 'signup.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});


  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Helper method to safely get field from document
  dynamic _getField(DocumentSnapshot doc, String fieldName, dynamic defaultValue) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey(fieldName)) {
        return data[fieldName];
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User data not found")),
        );
        return;
      }

      // Safely get fields from document
      String role = _getField(userDoc, 'role', 'patient');
      String name = _getField(userDoc, 'name', 'User');

      // Navigate based on role (patient, doctor, or admin)
      Widget destination;
      switch (role.toLowerCase()) {
        case "patient":
          dynamic ageField = _getField(userDoc, 'age', 25);
          dynamic diabetesField = _getField(userDoc, 'hasDiabetes', false);
          dynamic patientIdField = _getField(userDoc, 'patientId', 0);

          int age = 25;
          bool hasDiabetes = false;
          int patientId = 0;

          // Convert age field
          if (ageField is int) {
            age = ageField;
          } else if (ageField is String) {
            age = int.tryParse(ageField) ?? 25;
          }

          // Convert diabetes field
          if (diabetesField is bool) {
            hasDiabetes = diabetesField;
          } else if (diabetesField is String) {
            hasDiabetes = diabetesField.toLowerCase() == 'true';
          }

          // Convert patientId field
          if (patientIdField is int) {
            patientId = patientIdField;
          } else if (patientIdField is String) {
            patientId = int.tryParse(patientIdField) ?? 0;
          }

          destination = PatientDashboard(
            name: name,
            age: age,
            hasDiabetes: hasDiabetes,
            patientId: patientId,
            patientName: name,
          );
          break;

        case "doctor":
        // Safely get doctorId, fallback to uid if not exists
          String doctorId = _getField(userDoc, 'doctorId', uid);
          destination = DoctorDashboard(
            doctorName: name,
            doctorId: doctorId,
          );
          break;



        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Unknown role: $role")),
          );
          return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'user-not-found') message = 'No user found with this email.';
      if (e.code == 'wrong-password') message = 'Incorrect password.';
      if (e.code == 'invalid-email') message = 'Invalid email format.';
      if (e.code == 'user-disabled') message = 'This account has been disabled.';
      if (e.code == 'too-many-requests') message = 'Too many attempts. Try again later.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isPassword = false, IconData? icon}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      validator: (value) {
        if (value == null || value.isEmpty) return "Please enter $label";
        if (label.toLowerCase().contains('email') && !value.contains('@')) {
          return "Please enter a valid email";
        }
        if (label.toLowerCase().contains('password') && value.length < 6) {
          return "Password must be at least 6 characters";
        }
        return null;
      },
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE1E2E1),
              Color(0xFF34495E),
              Color(0xFF1B3B6F),
              Color(0xFF0D1B2A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Logo
                    SizedBox(
                      height: 150,
                      child: Image.asset(
                        "assets/images/logo.png",
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.medical_services,
                            size: 80,
                            color: Colors.tealAccent,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Welcome text
                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Sign in to continue",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Email
                    _buildTextField("Email", _emailController, icon: Icons.email),
                    const SizedBox(height: 20),

                    // Password
                    _buildTextField("Password", _passwordController,
                        isPassword: true, icon: Icons.lock),
                    const SizedBox(height: 30),

                    // Sign In Button
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.tealAccent)
                        : ElevatedButton(
                      onPressed: _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 80, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "Sign In",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Navigate to Signup
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account?",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignUpScreen()),
                            );
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Forgot Password
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Forgot password feature coming soon"),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
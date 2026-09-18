import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patientscreen/patient_dashboard.dart';
import 'doctorscreen/doctor_dashboard.dart';
import 'signin.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedRole = '';
  bool _isLoading = false;

  // Generate a unique patientId
  int _generatePatientId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(1000000);
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your role')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firebase Authentication
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCred.user!.uid;

      // Generate patientId if role is patient
      int patientId = _generatePatientId();

      // Prepare user data for Firestore
      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': Timestamp.now(),
      };

      // Add role-specific fields
      switch (_selectedRole.toLowerCase()) {
        case 'patient':
          userData['age'] = 0;
          userData['hasDiabetes'] = false;
          userData['patientId'] = patientId;
          break;
        case 'doctor':
          userData['doctorId'] = uid;
          break;
        case 'admin':
          userData['adminId'] = uid;
          break;
      }

      // Store user data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData);

      // Navigate based on role
      Widget destination;
      switch (_selectedRole.toLowerCase()) {
        case 'patient':
          destination = PatientDashboard(
            name: _nameController.text.trim(),
            age: 0,
            hasDiabetes: false,
            patientId: patientId,
            patientName: _nameController.text.trim(),
          );
          break;
        case 'doctor':
          destination = DoctorDashboard(
            doctorName: _nameController.text.trim(),
            doctorId: uid,
          );
          break;

        default:
          throw Exception('Unknown role: $_selectedRole');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );

    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred during sign up';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Email/password accounts are not enabled.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildRoleButton(String role, IconData icon, Color color, String description) {
    bool isSelected = _selectedRole.toLowerCase() == role.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 28,
                color: isSelected ? Colors.white : Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              role,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[300],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey[500],
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, bool isPassword, IconData icon) {
    return TextFormField(
      controller: label == 'Full Name' ? _nameController :
      label == 'Email Address' ? _emailController :
      _passwordController,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        if (label == 'Email Address' && !value.contains('@')) {
          return 'Please enter a valid email address';
        }
        if (label == 'Password' && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
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
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Logo
                    SizedBox(
                      height: 100,
                      child: Image.asset(
                        "assets/images/logo.png",
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.medical_services,
                            size: 60,
                            color: Colors.tealAccent,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Create Your Account",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Join our healthcare community",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Name
                    _buildTextField('Full Name', false, Icons.person_outline),
                    const SizedBox(height: 12),

                    // Email
                    _buildTextField('Email Address', false, Icons.email_outlined),
                    const SizedBox(height: 12),

                    // Password
                    _buildTextField('Password', true, Icons.lock_outline),
                    const SizedBox(height: 20),

                    // Role Selection
                    const Text(
                      "Select Your Role",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Choose your role",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Role Buttons - Single Row
                    SizedBox(
                      height: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _buildRoleButton(
                                'Patient',
                                Icons.favorite,
                                Colors.teal,
                                'Health tracking'
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildRoleButton(
                                'Doctor',
                                Icons.medical_services,
                                Colors.blue,
                                'Medical care'
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildRoleButton(
                                'Admin',
                                Icons.admin_panel_settings,
                                Colors.orange,
                                'System management'
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Sign Up Button
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.tealAccent)
                        : ElevatedButton(
                      onPressed: _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "Create Account",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Already have account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                            "Already have an account?",
                            style: TextStyle(color: Colors.white70, fontSize: 14)
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignInScreen()
                              ),
                            );
                          },
                          child: const Text(
                            "Sign In",
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        )
                      ],
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
}
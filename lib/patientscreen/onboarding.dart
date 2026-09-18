import 'package:diabetes_care/signin.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DiabetesCareApp());
}

class DiabetesCareApp extends StatelessWidget {
  const DiabetesCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const OnboardingScreen(),
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1B3B6F),
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo Image
                SizedBox(
                  height: 250,
                  child: Image.asset(
                    "assets/images/logo.png",
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          "Image not found",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 50),

                // Title
                const Text(
                  "Welcome to Diabetes Hub",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE1E2E1),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Description
                const Text(
                  "Track Today, Stay Healthy Tomorrow.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                // Get Started Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(55),
                    backgroundColor: const Color(0xFF1B3B6F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Get Started",
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFFE1E2E1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

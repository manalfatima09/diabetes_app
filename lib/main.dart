import 'package:diabetes_care/consts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'patientscreen/firebase_options.dart';
import 'patientscreen/onboarding.dart';
import 'signin.dart';
import 'signup.dart';
import 'patientscreen/patient_dashboard.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  Gemini.init(apiKey: GEMINI_API_KEY,);
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DiabetesCareApp());
}


class DiabetesCareApp extends StatelessWidget {
  const DiabetesCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DiabetesCare+',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const OnboardingScreen(),
    );
  }
}




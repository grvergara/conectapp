import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling (offline-safe)
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization failed (offline?): $e');
    // App continues without Firebase - will work offline
  }

  // Initialize Notification Service
  try {
    await NotificationService().initialize();
    print('Notification service initialized');
  } catch (e) {
    print('Notification service failed: $e');
  }

  runApp(const GoodPostureApp());
}

class GoodPostureApp extends StatelessWidget {
  const GoodPostureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Good Posture Reminder',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
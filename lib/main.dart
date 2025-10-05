import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  log.initialize();

  try {
    await Firebase.initializeApp();
    log.info('Firebase initialized successfully');
  } catch (e) {
    log.error('Firebase initialization failed (offline?): $e');
  }

  // Initialize Notification Service
  try {
    await NotificationService().initialize();
    log.info('Notification service initialized');
  } catch (e) {
    log.error('Notification service failed: $e');
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
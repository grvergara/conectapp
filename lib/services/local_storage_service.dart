import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

class LocalStorageService {
  static const String _remindersKey = 'reminders';
  static LocalStorageService? _instance;

  SharedPreferences? _prefs;

  LocalStorageService._();

  static Future<LocalStorageService> getInstance() async {
    if (_instance == null) {
      _instance = LocalStorageService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save all reminders
  Future<bool> saveReminders(List<Reminder> reminders) async {
    try {
      final jsonList = reminders.map((r) => r.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      return await _prefs!.setString(_remindersKey, jsonString);
    } catch (e) {
      print('Error saving reminders: $e');
      return false;
    }
  }

  // Load all reminders
  Future<List<Reminder>> loadReminders() async {
    try {
      final jsonString = _prefs!.getString(_remindersKey);
      if (jsonString == null) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Reminder.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading reminders: $e');
      return [];
    }
  }

  // Add a new reminder
  Future<bool> addReminder(Reminder reminder) async {
    try {
      final reminders = await loadReminders();
      reminders.add(reminder);
      return await saveReminders(reminders);
    } catch (e) {
      print('Error adding reminder: $e');
      return false;
    }
  }

  // Update an existing reminder
  Future<bool> updateReminder(Reminder reminder) async {
    try {
      final reminders = await loadReminders();
      final index = reminders.indexWhere((r) => r.id == reminder.id);

      if (index != -1) {
        reminders[index] = reminder;
        return await saveReminders(reminders);
      }
      return false;
    } catch (e) {
      print('Error updating reminder: $e');
      return false;
    }
  }

  // Delete a reminder
  Future<bool> deleteReminder(String id) async {
    try {
      final reminders = await loadReminders();
      reminders.removeWhere((r) => r.id == id);
      return await saveReminders(reminders);
    } catch (e) {
      print('Error deleting reminder: $e');
      return false;
    }
  }

  // Get a specific reminder by ID
  Future<Reminder?> getReminder(String id) async {
    try {
      final reminders = await loadReminders();
      return reminders.firstWhere(
            (r) => r.id == id,
        orElse: () => throw Exception('Reminder not found'),
      );
    } catch (e) {
      print('Error getting reminder: $e');
      return null;
    }
  }

  // Clear all reminders (useful for debugging)
  Future<bool> clearAll() async {
    try {
      return await _prefs!.remove(_remindersKey);
    } catch (e) {
      print('Error clearing reminders: $e');
      return false;
    }
  }

  // Get reminders by state
  Future<List<Reminder>> getRemindersByState(ReminderState state) async {
    try {
      final reminders = await loadReminders();
      return reminders.where((r) => r.state == state).toList();
    } catch (e) {
      print('Error getting reminders by state: $e');
      return [];
    }
  }

  // Get pending reminders
  Future<List<Reminder>> getPendingReminders() async {
    return await getRemindersByState(ReminderState.pending);
  }

  // Get completed reminders
  Future<List<Reminder>> getCompletedReminders() async {
    return await getRemindersByState(ReminderState.completed);
  }

  // Get skipped reminders
  Future<List<Reminder>> getSkippedReminders() async {
    return await getRemindersByState(ReminderState.skipped);
  }
}
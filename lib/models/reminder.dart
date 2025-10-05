import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderFrequency {
  nonRepeat,
  daily,
  weekly,
}

enum ReminderState {
  pending,
  completed,
  skipped,
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final ReminderFrequency frequency;
  final ReminderState state;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.frequency,
    required this.state,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Create a copy with modified fields
  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    ReminderFrequency? frequency,
    ReminderState? state,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      frequency: frequency ?? this.frequency,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Convert to JSON for shared_preferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'frequency': frequency.name,
      'state': state.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      frequency: ReminderFrequency.values.firstWhere(
            (e) => e.name == json['frequency'],
        orElse: () => ReminderFrequency.nonRepeat,
      ),
      state: ReminderState.values.firstWhere(
            (e) => e.name == json['state'],
        orElse: () => ReminderState.pending,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'frequency': frequency.name,
      'state': state.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore
  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reminder(
      id: data['id'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      frequency: ReminderFrequency.values.firstWhere(
            (e) => e.name == data['frequency'],
        orElse: () => ReminderFrequency.nonRepeat,
      ),
      state: ReminderState.values.firstWhere(
            (e) => e.name == data['state'],
        orElse: () => ReminderState.pending,
      ),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Helper method to get next occurrence for recurring reminders
  DateTime? getNextOccurrence() {
    if (frequency == ReminderFrequency.nonRepeat) {
      return null;
    }

    final now = DateTime.now();
    DateTime next = dateTime;

    // If the reminder time has passed, calculate next occurrence
    while (next.isBefore(now)) {
      if (frequency == ReminderFrequency.daily) {
        next = next.add(const Duration(days: 1));
      } else if (frequency == ReminderFrequency.weekly) {
        next = next.add(const Duration(days: 7));
      }
    }

    return next;
  }

  // Check if reminder is in the past
  bool get isPast => dateTime.isBefore(DateTime.now());

  // Check if reminder is today
  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }
}

// Extension for frequency display
extension ReminderFrequencyExtension on ReminderFrequency {
  String get displayName {
    switch (this) {
      case ReminderFrequency.nonRepeat:
        return 'One Time';
      case ReminderFrequency.daily:
        return 'Daily';
      case ReminderFrequency.weekly:
        return 'Weekly';
    }
  }
}

// Extension for state display
extension ReminderStateExtension on ReminderState {
  String get displayName {
    switch (this) {
      case ReminderState.pending:
        return 'Pending';
      case ReminderState.completed:
        return 'Completed';
      case ReminderState.skipped:
        return 'Skipped';
    }
  }
}
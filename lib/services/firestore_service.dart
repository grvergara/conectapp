import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'reminders';
  bool _isInitialized = false;

  // Initialize Firestore with offline persistence
  Future<void> initialize() async {
    try {
      // Enable offline persistence
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _isInitialized = true;
      print('Firestore initialized with offline support');
    } catch (e) {
      print('Firestore initialization failed: $e');
      _isInitialized = false;
    }
  }

  // Get the reminders collection reference
  CollectionReference get _remindersCollection =>
      _firestore.collection(_collectionName);

  // Check if Firestore is available (helper method)
  bool get isAvailable => _isInitialized;

  // Add a reminder to Firestore (offline-safe)
  Future<void> addReminderToFirestore(Reminder reminder) async {
    if (!_isInitialized) {
      print('Firestore not initialized - skipping cloud sync');
      return;
    }

    try {
      await _remindersCollection.doc(reminder.id).set(reminder.toFirestore());
      print('Reminder added to Firestore: ${reminder.id}');
    } catch (e) {
      print('Error adding reminder to Firestore (will retry): $e');
      // Don't throw - let the app continue working offline
    }
  }

  // Update a reminder in Firestore (offline-safe)
  Future<void> updateReminderInFirestore(Reminder reminder) async {
    if (!_isInitialized) {
      print('Firestore not initialized - skipping cloud sync');
      return;
    }

    try {
      await _remindersCollection.doc(reminder.id).update(reminder.toFirestore());
      print('Reminder updated in Firestore: ${reminder.id}');
    } catch (e) {
      print('Error updating reminder to Firestore (will retry): $e');
      // Don't throw - let the app continue working offline
    }
  }

  // Delete a reminder from Firestore (offline-safe)
  Future<void> deleteReminderFromFirestore(String id) async {
    if (!_isInitialized) {
      print('Firestore not initialized - skipping cloud sync');
      return;
    }

    try {
      await _remindersCollection.doc(id).delete();
      print('Reminder deleted from Firestore: $id');
    } catch (e) {
      print('Error deleting reminder from Firestore (will retry): $e');
      // Don't throw - let the app continue working offline
    }
  }

  // Get all reminders from Firestore (offline-safe with cache)
  Future<List<Reminder>> getRemindersFromFirestore() async {
    if (!_isInitialized) {
      print('Firestore not initialized - returning empty list');
      return [];
    }

    try {
      final snapshot = await _remindersCollection.get(
        const GetOptions(source: Source.serverAndCache),
      );
      print('Loaded ${snapshot.docs.length} reminders from Firestore');
      return snapshot.docs
          .map((doc) => Reminder.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting reminders from Firestore: $e');
      return [];
    }
  }

  // Get a specific reminder from Firestore (offline-safe)
  Future<Reminder?> getReminderFromFirestore(String id) async {
    if (!_isInitialized) return null;

    try {
      final doc = await _remindersCollection.doc(id).get(
        const GetOptions(source: Source.serverAndCache),
      );
      if (doc.exists) {
        return Reminder.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting reminder from Firestore: $e');
      return null;
    }
  }

  // Listen to real-time updates (offline-safe with cache)
  Stream<List<Reminder>> getRemindersStream() {
    if (!_isInitialized) {
      print('Firestore not initialized - returning empty stream');
      return Stream.value([]);
    }

    return _remindersCollection.snapshots().map((snapshot) {
      print('Received ${snapshot.docs.length} reminders from stream');
      return snapshot.docs
          .map((doc) => Reminder.fromFirestore(doc))
          .toList();
    }).handleError((error) {
      print('Stream error (offline?): $error');
      return <Reminder>[];
    });
  }

  // Listen to real-time updates for a specific reminder
  Stream<Reminder?> getReminderStream(String id) {
    if (!_isInitialized) return Stream.value(null);

    return _remindersCollection.doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return Reminder.fromFirestore(doc);
      }
      return null;
    }).handleError((error) {
      print('Stream error for reminder $id: $error');
      return null;
    });
  }

  // Batch add multiple reminders (offline-safe)
  Future<void> batchAddReminders(List<Reminder> reminders) async {
    if (!_isInitialized) {
      print('Firestore not initialized - skipping batch add');
      return;
    }

    try {
      final batch = _firestore.batch();
      for (final reminder in reminders) {
        final docRef = _remindersCollection.doc(reminder.id);
        batch.set(docRef, reminder.toFirestore());
      }
      await batch.commit();
      print('Batch added ${reminders.length} reminders to Firestore');
    } catch (e) {
      print('Error batch adding reminders (will retry): $e');
    }
  }

  // Delete all reminders (use with caution)
  Future<void> deleteAllReminders() async {
    if (!_isInitialized) return;

    try {
      final snapshot = await _remindersCollection.get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('All reminders deleted from Firestore');
    } catch (e) {
      print('Error deleting all reminders: $e');
    }
  }

  // Sync local reminders with Firestore (offline-safe)
  Future<void> syncWithFirestore(List<Reminder> localReminders) async {
    if (!_isInitialized) {
      print('Firestore not initialized - skipping sync');
      return;
    }

    try {
      // Get reminders from Firestore (will use cache if offline)
      final firestoreReminders = await getRemindersFromFirestore();
      final firestoreIds = firestoreReminders.map((r) => r.id).toSet();
      final localIds = localReminders.map((r) => r.id).toSet();

      // Find reminders to upload (in local but not in Firestore)
      final remindersToUpload = localReminders
          .where((r) => !firestoreIds.contains(r.id))
          .toList();

      // Upload missing reminders
      if (remindersToUpload.isNotEmpty) {
        await batchAddReminders(remindersToUpload);
      }

      // Find reminders to delete (in Firestore but not in local)
      final remindersToDelete = firestoreReminders
          .where((r) => !localIds.contains(r.id))
          .toList();

      // Delete extra reminders
      for (final reminder in remindersToDelete) {
        await deleteReminderFromFirestore(reminder.id);
      }

      // Update existing reminders (prefer local if it's newer)
      for (final localReminder in localReminders) {
        final firestoreReminder = firestoreReminders.firstWhere(
              (r) => r.id == localReminder.id,
          orElse: () => localReminder,
        );

        if (firestoreReminder.id == localReminder.id &&
            localReminder.updatedAt.isAfter(firestoreReminder.updatedAt)) {
          await updateReminderInFirestore(localReminder);
        }
      }

      print('Sync completed successfully');
    } catch (e) {
      print('Error syncing with Firestore (offline?): $e');
      // Don't throw - app continues working offline
    }
  }

  // Check network connectivity and sync status
  Future<bool> checkConnection() async {
    if (!_isInitialized) return false;

    try {
      // Try to read a small amount of data
      await _remindersCollection.limit(1).get(
        const GetOptions(source: Source.server),
      );
      return true;
    } catch (e) {
      print('No Firestore connection: $e');
      return false;
    }
  }
}
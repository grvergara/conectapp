import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/local_storage_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reminder_card.dart';
import 'reminder_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Reminder> _allReminders = [];
  List<Reminder> _filteredReminders = [];
  ReminderState? _selectedFilter;
  bool _isLoading = true;

  late LocalStorageService _localStorage;
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  bool _isOnline = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  // Initialize all services
  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    try {
      // Initialize LocalStorageService first (critical)
      _localStorage = await LocalStorageService.getInstance();

      // Initialize Firestore
      await _firestoreService.initialize();

      // Mark as initialized
      setState(() => _isInitialized = true);

      // Start loading and listening
      await _loadReminders();
      _listenToFirestoreChanges();
      _checkConnectivity();
    } catch (e) {
      print('Error initializing services: $e');
      // Even if Firestore fails, we can continue with local storage
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    }
  }

  // Check connectivity periodically
  Future<void> _checkConnectivity() async {
    _isOnline = await _firestoreService.checkConnection();
    setState(() {});

    // Check every 30 seconds
    Future.delayed(const Duration(seconds: 30), _checkConnectivity);
  }

  // Load reminders from local storage and sync with Firestore
  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);

    try {
      // Load from local storage first (fast)
      final localReminders = await _localStorage.loadReminders();

      if (mounted) {
        setState(() {
          _allReminders = localReminders;
          _applyFilter();
          _isLoading = false;
        });
      }

      // Sync with Firestore in background
      final firestoreReminders = await _firestoreService.getRemindersFromFirestore();

      if (firestoreReminders.isNotEmpty) {
        // Merge Firestore data (prefer newer data)
        await _mergeReminders(localReminders, firestoreReminders);
      } else if (localReminders.isNotEmpty) {
        // Upload local data to Firestore if Firestore is empty
        await _firestoreService.batchAddReminders(localReminders);
      }
    } catch (e) {
      print('Error loading reminders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Merge local and Firestore reminders
  Future<void> _mergeReminders(
      List<Reminder> local, List<Reminder> firestore) async {
    final Map<String, Reminder> mergedMap = {};

    // Add all local reminders
    for (final reminder in local) {
      mergedMap[reminder.id] = reminder;
    }

    // Merge with Firestore (prefer newer)
    for (final reminder in firestore) {
      if (!mergedMap.containsKey(reminder.id) ||
          reminder.updatedAt.isAfter(mergedMap[reminder.id]!.updatedAt)) {
        mergedMap[reminder.id] = reminder;
      }
    }

    final merged = mergedMap.values.toList();
    await _localStorage.saveReminders(merged);

    if (mounted) {
      setState(() {
        _allReminders = merged;
        _applyFilter();
      });
    }
  }

  // Listen to real-time Firestore changes
  void _listenToFirestoreChanges() {
    _firestoreService.getRemindersStream().listen((reminders) async {
      await _localStorage.saveReminders(reminders);
      if (mounted) {
        setState(() {
          _allReminders = reminders;
          _applyFilter();
        });
      }
    });
  }

  // Apply filter to reminders
  void _applyFilter() {
    if (_selectedFilter == null) {
      _filteredReminders = List.from(_allReminders);
    } else {
      _filteredReminders = _allReminders
          .where((r) => r.state == _selectedFilter)
          .toList();
    }

    // Sort by date (sooner first), then by state
    _filteredReminders.sort((a, b) {
      final dateCompare = a.dateTime.compareTo(b.dateTime);
      if (dateCompare != 0) return dateCompare;
      return a.state.index.compareTo(b.state.index);
    });
  }

  // Navigate to form screen
  Future<void> _navigateToForm({Reminder? reminder}) async {
    // Ensure services are initialized before allowing navigation
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, app is initializing...'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ReminderFormScreen(reminder: reminder),
      ),
    );

    if (result == true) {
      await _loadReminders();
    }
  }

  // Delete reminder
  Future<void> _deleteReminder(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: Text('Are you sure you want to delete "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _localStorage.deleteReminder(reminder.id);
      await _firestoreService.deleteReminderFromFirestore(reminder.id);
      await _notificationService.cancelNotification(reminder.id);
      await _loadReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Posture Reminders'),
            if (!_isOnline) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.cloud_off, size: 16),
                    SizedBox(width: 4),
                    Text('Offline', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Filter menu
          PopupMenuButton<ReminderState?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (state) {
              setState(() {
                _selectedFilter = state;
                _applyFilter();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Reminders'),
              ),
              const PopupMenuItem(
                value: ReminderState.pending,
                child: Text('Pending'),
              ),
              const PopupMenuItem(
                value: ReminderState.completed,
                child: Text('Completed'),
              ),
              const PopupMenuItem(
                value: ReminderState.skipped,
                child: Text('Skipped'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Initializing app...',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      )
          : _buildBody(),
      floatingActionButton: _isInitialized
          ? FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
      )
          : null, // Hide FAB until initialized
    );
  }

  Widget _buildBody() {
    if (_filteredReminders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 16,
          left: 8,
          right: 8,
          bottom: 80,
        ),
        itemCount: _filteredReminders.length,
        itemBuilder: (context, index) {
          final reminder = _filteredReminders[index];
          return ReminderCard(
            reminder: reminder,
            onTap: () => _navigateToForm(reminder: reminder),
            onDelete: () => _deleteReminder(reminder),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _selectedFilter == null
        ? 'No reminders yet.\nTap + to create your first reminder!'
        : 'No ${_selectedFilter!.displayName.toLowerCase()} reminders.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == null ? Icons.event_available : Icons.filter_list_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
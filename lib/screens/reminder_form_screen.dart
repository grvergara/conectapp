import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/local_storage_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class ReminderFormScreen extends StatefulWidget {
  final Reminder? reminder;

  const ReminderFormScreen({super.key, this.reminder});

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  ReminderFrequency _selectedFrequency = ReminderFrequency.nonRepeat;
  bool _isLoading = false;
  bool _isInitialized = false;

  late LocalStorageService _localStorage;
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  bool get _isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    _initializeServices();

    if (_isEditing) {
      _titleController.text = widget.reminder!.title;
      _descriptionController.text = widget.reminder!.description;
      _selectedDate = widget.reminder!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.reminder!.dateTime);
      _selectedFrequency = widget.reminder!.frequency;
    } else {
      final now = DateTime.now();
      _selectedDate = now;
      _selectedTime = TimeOfDay(hour: now.hour + 1, minute: 0);
    }
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    try {
      _localStorage = await LocalStorageService.getInstance();
      await _firestoreService.initialize();

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing services: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de inicialización: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: AppTheme.primaryColor,
              headerForegroundColor: Colors.white,
              dayStyle: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.2,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  DateTime _getCombinedDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    // Ensure services are initialized
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un minuto, inicializando servicios...'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final combinedDateTime = _getCombinedDateTime();

    // Check if date is in the past
    if (combinedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recordatorio debe tener fecha futura'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final reminder = Reminder(
        id: _isEditing ? widget.reminder!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dateTime: combinedDateTime,
        frequency: _selectedFrequency,
        state: _isEditing ? widget.reminder!.state : ReminderState.pending,
      );

      // Save locally
      if (_isEditing) {
        await _localStorage.updateReminder(reminder);
      } else {
        await _localStorage.addReminder(reminder);
      }

      // Save to Firestore
      if (_isEditing) {
        await _firestoreService.updateReminderInFirestore(reminder);
      } else {
        await _firestoreService.addReminderToFirestore(reminder);
      }

      // Schedule notification
      if (_isEditing) {
        await _notificationService.rescheduleNotification(reminder);
      } else {
        await _notificationService.scheduleNotification(reminder);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Recordatorio actualizado!' : 'Recordatorio creado!',
            ),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Delete reminder
  Future<void> _deleteReminder() async {
    if (!_isEditing) return;

    // Ensure services are initialized
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un minuto, inicializando servicios...'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Recordatorio'),
        content: Text('Confirma para eliminar "${widget.reminder!.title}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Delete from local storage
      await _localStorage.deleteReminder(widget.reminder!.id);

      // Delete from Firestore
      await _firestoreService.deleteReminderFromFirestore(widget.reminder!.id);

      // Cancel notification
      await _notificationService.cancelNotification(widget.reminder!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recordatorio borrado!'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error borrando: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Recordatorio' : 'Nuevo Recordatorio'),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _isInitialized ? 'Guardando...' : 'Inicializando...',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'E.g., Chequea tu postura',
                  prefixIcon: Icon(Icons.title),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un título';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 24),
              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'E.g., Sit up straight, shoulders back',
                  prefixIcon: Icon(Icons.description),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 24),

              // Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 32),
                title: const Text('Fecha'),
                subtitle: Text(
                  DateFormat('EEEE, dd MMMM, yyyy').format(_selectedDate),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectDate,
                tileColor: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppTheme.textSecondary,
                    width: 2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Time picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time, size: 32),
                title: const Text('Hora'),
                subtitle: Text(
                  _selectedTime.format(context),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectTime,
                tileColor: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppTheme.textSecondary,
                    width: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Frequency selector
              Text(
                'Frecuencia',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...ReminderFrequency.values.map((frequency) {
                return RadioListTile<ReminderFrequency>(
                  value: frequency,
                  groupValue: _selectedFrequency,
                  onChanged: (value) {
                    setState(() => _selectedFrequency = value!);
                  },
                  title: Text(
                    frequency.displayName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  activeColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),

              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _saveReminder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_isEditing ? 'Actualizar Recordatorio' : 'Crear Recordatorio'),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Cancelar'),
                ),
              ),

              // Delete button (only show when editing)
              if (_isEditing) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _deleteReminder,
                  icon: const Icon(Icons.delete_outline),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Eliminar Recordatorio'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor, width: 2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
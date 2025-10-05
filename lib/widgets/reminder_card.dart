import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../theme/app_theme.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onDelete,
  });

  Color _getStateColor() {
    switch (reminder.state) {
      case ReminderState.pending:
        return AppTheme.pendingColor;
      case ReminderState.completed:
        return AppTheme.completedColor;
      case ReminderState.skipped:
        return AppTheme.skippedColor;
    }
  }

  IconData _getStateIcon() {
    switch (reminder.state) {
      case ReminderState.pending:
        return Icons.schedule;
      case ReminderState.completed:
        return Icons.check_circle;
      case ReminderState.skipped:
        return Icons.skip_next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final stateColor = _getStateColor();

    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 36,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar Recordatorio'),
            content: Text('Eliminar "${reminder.title}"?'),
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
      },
      onDismissed: (direction) => onDelete(),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and state
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: reminder.state == ReminderState.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: stateColor, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStateIcon(),
                            size: 20,
                            color: stateColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            reminder.state.displayName,
                            style: TextStyle(
                              color: stateColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (reminder.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    reminder.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Date, Time, and Frequency
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildInfoChip(
                      icon: Icons.calendar_today,
                      label: dateFormat.format(reminder.dateTime),
                      color: reminder.isToday
                          ? AppTheme.secondaryColor
                          : AppTheme.textSecondary,
                    ),
                    _buildInfoChip(
                      icon: Icons.access_time,
                      label: timeFormat.format(reminder.dateTime),
                      color: AppTheme.textSecondary,
                    ),
                    _buildInfoChip(
                      icon: Icons.repeat,
                      label: reminder.frequency.displayName,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
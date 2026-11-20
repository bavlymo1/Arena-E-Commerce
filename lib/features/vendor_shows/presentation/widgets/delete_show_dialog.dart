import 'package:flutter/material.dart';

import '../../domain/models/show.dart';

/// Prompts the vendor to confirm permanent deletion of [show] and its records.
Future<bool> showDeleteShowConfirmDialog(
  BuildContext context,
  Show show,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      final bookedNote = show.bookedCount > 0
          ? '${show.bookedCount} booked seat(s), '
          : '';
      return AlertDialog(
        key: const ValueKey<String>('delete-show-confirm-dialog'),
        scrollable: true,
        title: Text('Delete ${show.title}?'),
        content: Text(
          'All sessions, ${bookedNote}bookings, and seat records for '
          '"${show.title}" will be permanently removed. Customers will no '
          'longer be able to book this show.',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('delete-show-cancel-button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('delete-show-confirm-button'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Inline progress banner rendered while show cleanup is running.
class VendorDeletingProgressBanner extends StatelessWidget {
  const VendorDeletingProgressBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

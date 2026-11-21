import 'package:flutter/material.dart';

/// In-app fallback banner displayed when OS alert permission is denied.
class AlertPermissionBanner extends StatelessWidget {
  const AlertPermissionBanner({required this.onRetryPermission, super.key});

  final VoidCallback onRetryPermission;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.notifications_off_outlined,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Device alerts are off. New bookings still appear here.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                key: const ValueKey<String>(
                  'vendor-updates-permission-retry-button',
                ),
                onPressed: onRetryPermission,
                child: const Text('Enable alerts'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

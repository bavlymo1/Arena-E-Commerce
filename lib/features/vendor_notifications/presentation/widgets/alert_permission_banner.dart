import 'package:flutter/material.dart';

import '../../../../shared/widgets/arena_notice_banner.dart';

/// In-app fallback banner displayed when OS alert permission is denied.
class AlertPermissionBanner extends StatelessWidget {
  const AlertPermissionBanner({required this.onRetryPermission, super.key});

  final VoidCallback onRetryPermission;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: ArenaNoticeBanner(
        icon: Icons.notifications_off_outlined,
        message: 'Device alerts are off. New bookings still appear here.',
        emphasizeText: true,
        actionLabel: 'Enable alerts',
        actionKey: const ValueKey<String>(
          'vendor-updates-permission-retry-button',
        ),
        onAction: onRetryPermission,
      ),
    );
  }
}

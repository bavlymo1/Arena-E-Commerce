import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/arena_busy_button_label.dart';
import '../../../../shared/widgets/arena_icon_label.dart';
import '../vendor_access_strings.dart';
import '../widgets/vendor_access_widgets.dart';

/// Displays the anonymous device [uid] for admin enrollment with copy and retry actions.
class VendorNotEnrolledScreen extends StatelessWidget {
  const VendorNotEnrolledScreen({
    required this.uid,
    required this.onRetry,
    this.isChecking = false,
    super.key,
  });

  final String uid;
  final VoidCallback? onRetry;
  final bool isChecking;

  Future<void> _copyDeviceId(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: uid));
    if (!context.mounted || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(VendorAccessStrings.deviceIdCopied)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return VendorAccessScaffold(
      children: <Widget>[
        Text(
          VendorAccessStrings.notEnrolledTitle,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          VendorAccessStrings.notEnrolledExplanation,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          container: true,
          child: Card(
            key: const ValueKey<String>('vendor-access-device-id-card'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    VendorAccessStrings.deviceIdLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    uid,
                    key: const ValueKey<String>('vendor-access-device-id'),
                    style: textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey<String>('vendor-access-copy-button'),
          onPressed: () => unawaited(_copyDeviceId(context)),
          child: const ArenaIconLabel(
            icon: Icons.copy_outlined,
            label: VendorAccessStrings.copyDeviceId,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey<String>('vendor-access-retry-button'),
          onPressed: isChecking ? null : onRetry,
          child: isChecking
              ? const ArenaBusyButtonLabel(
                  label: VendorAccessStrings.retrying,
                  mainAxisAlignment: MainAxisAlignment.center,
                  textAlign: TextAlign.center,
                )
              : const ArenaIconLabel(
                  icon: Icons.refresh,
                  label: VendorAccessStrings.retry,
                ),
        ),
      ],
    );
  }
}

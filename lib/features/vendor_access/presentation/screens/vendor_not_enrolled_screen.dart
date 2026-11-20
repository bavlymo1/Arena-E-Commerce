import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          child: Container(
            key: const ValueKey<String>('vendor-access-device-id-card'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
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
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey<String>('vendor-access-copy-button'),
          onPressed: () => unawaited(_copyDeviceId(context)),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const VendorAccessButtonContent(
            icon: Icon(Icons.copy_outlined, size: 18),
            label: VendorAccessStrings.copyDeviceId,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey<String>('vendor-access-retry-button'),
          onPressed: isChecking ? null : onRetry,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: VendorAccessButtonContent(
            icon: isChecking
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: isChecking
                ? VendorAccessStrings.retrying
                : VendorAccessStrings.retry,
          ),
        ),
      ],
    );
  }
}

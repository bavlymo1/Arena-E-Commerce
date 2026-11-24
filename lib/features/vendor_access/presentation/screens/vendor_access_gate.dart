import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/arena_icon_label.dart';
import '../cubit/vendor_access_cubit.dart';
import '../cubit/vendor_access_state.dart';
import '../vendor_access_strings.dart';
import '../widgets/vendor_access_widgets.dart';
import 'vendor_not_enrolled_screen.dart';

/// Gates vendor management UI behind [VendorAccessCubit] enrollment verification.
class VendorAccessGate extends StatelessWidget {
  const VendorAccessGate({
    required this.builder,
    this.blockedShellBuilder,
    super.key,
  });

  final Widget Function(BuildContext context, AccessAllowed allowed) builder;
  final Widget Function(BuildContext context, Widget child)?
  blockedShellBuilder;

  @override
  Widget build(BuildContext context) {
    Widget wrapBlocked(Widget child) =>
        blockedShellBuilder?.call(context, child) ?? child;

    return BlocBuilder<VendorAccessCubit, VendorAccessState>(
      builder: (context, state) {
        switch (state) {
          case AccessChecking():
            return wrapBlocked(const _VendorAccessCheckingView());
          case AccessNotEnrolled(:final uid):
            return wrapBlocked(
              VendorNotEnrolledScreen(
                uid: uid,
                onRetry: () =>
                    unawaited(context.read<VendorAccessCubit>().retry()),
              ),
            );
          case AccessError(:final message):
            return wrapBlocked(
              _VendorAccessErrorView(
                message: message,
                onRetry: () =>
                    unawaited(context.read<VendorAccessCubit>().retry()),
              ),
            );
          case AccessAllowed():
            return builder(context, state);
        }
      },
    );
  }
}

class _VendorAccessCheckingView extends StatelessWidget {
  const _VendorAccessCheckingView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return VendorAccessScaffold(
      children: <Widget>[
        Text(
          VendorAccessStrings.checkingTitle,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Semantics(
          key: const ValueKey<String>('vendor-access-checking-panel'),
          liveRegion: true,
          container: true,
          child: Card(
            semanticContainer: false,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(
                    key: ValueKey<String>('vendor-access-checking-indicator'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    VendorAccessStrings.checkingMessage,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VendorAccessErrorView extends StatelessWidget {
  const _VendorAccessErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return VendorAccessScaffold(
      children: <Widget>[
        Text(
          VendorAccessStrings.errorTitle,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Semantics(
          key: const ValueKey<String>('vendor-access-error-panel'),
          liveRegion: true,
          container: true,
          child: Card(
            semanticContainer: false,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey<String>('vendor-access-error-retry-button'),
          onPressed: onRetry,
          child: const ArenaIconLabel(
            icon: Icons.refresh,
            label: VendorAccessStrings.retry,
          ),
        ),
      ],
    );
  }
}

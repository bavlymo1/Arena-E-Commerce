import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/arena_brand_mark.dart';
import '../../../../shared/widgets/arena_notice_banner.dart';
import '../cubit/customer_auth_cubit.dart';
import '../cubit/customer_auth_state.dart';

/// Customer account screen displaying signed-in identity and logout control.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  String _initialForEmail(String? email) {
    final trimmed = email?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: <Widget>[
            ArenaBrandMark(),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Account',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<CustomerAuthCubit, CustomerAuthState>(
          builder: (context, state) {
            final cubit = context.read<CustomerAuthCubit>();
            final user = state.user;
            final emailText = user?.email ?? 'Not signed in';

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: <Widget>[
                Text(
                  'ArenaPass',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Profile',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.isChecking && user == null) ...<Widget>[
                  const SizedBox(height: 20),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Checking session…'),
                        ],
                      ),
                    ),
                  ),
                ],
                if (state.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 16),
                  ArenaNoticeBanner(
                    key: const ValueKey<String>('account-error-banner'),
                    icon: Icons.error_outline,
                    message: state.errorMessage!,
                    isError: true,
                    liveRegion: true,
                    useTextAction: true,
                    emphasizeText: true,
                    actionLabel: state.hasError ? 'Try again' : null,
                    actionKey: state.hasError
                        ? const ValueKey<String>('account-retry-button')
                        : null,
                    onAction: state.hasError
                        ? () => unawaited(cubit.retry())
                        : null,
                  ),
                ],
                const SizedBox(height: 20),
                Semantics(
                  container: true,
                  child: Container(
                    key: const ValueKey<String>('account-user-card'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        ExcludeSemantics(
                          child: Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              _initialForEmail(user?.email),
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Customer account',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Semantics(
                                container: true,
                                child: Text(
                                  emailText,
                                  key: const ValueKey<String>(
                                    'account-email-text',
                                  ),
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  key: const ValueKey<String>('account-logout-button'),
                  onPressed: state.busy || user == null
                      ? null
                      : () => unawaited(cubit.logout()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.busy
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Flexible(child: Text('Signing out…')),
                          ],
                        )
                      : const Text('Log out'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

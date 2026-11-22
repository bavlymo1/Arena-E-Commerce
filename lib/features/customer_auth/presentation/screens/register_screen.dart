import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/arena_notice_banner.dart';
import '../cubit/customer_auth_cubit.dart';
import '../cubit/customer_auth_state.dart';
import '../widgets/customer_auth_widgets.dart';

/// Customer registration screen consuming [CustomerAuthCubit].
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.onLoginRequested, super.key});

  final VoidCallback onLoginRequested;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  late final FocusNode _confirmPasswordFocusNode;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submittedOnce = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return 'Confirm your password.';
    if (confirm != _passwordController.text) return 'Passwords must match.';
    return null;
  }

  void _submit(CustomerAuthCubit cubit, CustomerAuthState state) {
    if (state.busy) return;
    if (!_submittedOnce) {
      setState(() => _submittedOnce = true);
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      cubit.clearError();
      return;
    }
    FocusScope.of(context).unfocus();
    unawaited(cubit.register(_emailController.text, _passwordController.text));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<CustomerAuthCubit, CustomerAuthState>(
      builder: (context, state) {
        final cubit = context.read<CustomerAuthCubit>();
        final inputsEnabled = !state.busy;
        final handleBackToLogin = state.busy
            ? null
            : () {
                cubit.clearError();
                widget.onLoginRequested();
              };

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              key: const ValueKey<String>('register-appbar-back-button'),
              tooltip: 'Back to sign in',
              onPressed: handleBackToLogin,
              icon: const Icon(Icons.arrow_back),
            ),
            title: const Text(
              'Register',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  'Create account',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Register with your email and password to reserve arena seats.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (state.isChecking && !state.busy) ...<Widget>[
                  const SizedBox(height: 16),
                  const ArenaNoticeBanner(
                    icon: Icons.info_outline,
                    message: 'Checking session…',
                    liveRegion: true,
                    emphasizeText: true,
                  ),
                ],
                if (state.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 16),
                  ArenaNoticeBanner(
                    key: const ValueKey<String>('register-error-banner'),
                    icon: Icons.error_outline,
                    message: state.errorMessage!,
                    isError: true,
                    liveRegion: true,
                    useTextAction: true,
                    emphasizeText: true,
                    actionLabel: state.hasError ? 'Try again' : null,
                    actionKey: state.hasError
                        ? const ValueKey<String>('register-retry-button')
                        : null,
                    onAction: state.hasError
                        ? () => unawaited(cubit.retry())
                        : null,
                  ),
                ],
                const SizedBox(height: 20),
                AutofillGroup(
                  key: const ValueKey<String>('register-autofill-group'),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submittedOnce
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          key: const ValueKey<String>('register-email-field'),
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          enabled: inputsEnabled,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[AutofillHints.email],
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (value) =>
                              CustomerAuthCubit.validateEmail(value ?? ''),
                          onChanged: (_) => cubit.clearError(),
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomerPasswordFormField(
                          fieldKey: const ValueKey<String>(
                            'register-password-field',
                          ),
                          toggleKey: const ValueKey<String>(
                            'register-password-visibility-toggle',
                          ),
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          labelText: 'Password',
                          obscureText: _obscurePassword,
                          onToggleVisibility: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          enabled: inputsEnabled,
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                          validator: (value) =>
                              CustomerAuthCubit.validatePassword(value ?? ''),
                          onChanged: (_) => cubit.clearError(),
                          onFieldSubmitted: (_) =>
                              _confirmPasswordFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: 16),
                        CustomerPasswordFormField(
                          fieldKey: const ValueKey<String>(
                            'register-confirm-password-field',
                          ),
                          toggleKey: const ValueKey<String>(
                            'register-confirm-password-visibility-toggle',
                          ),
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          labelText: 'Confirm password',
                          obscureText: _obscureConfirmPassword,
                          onToggleVisibility: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                          enabled: inputsEnabled,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                          showLabel: 'Show confirm password',
                          hideLabel: 'Hide confirm password',
                          validator: _validateConfirmPassword,
                          onChanged: (_) => cubit.clearError(),
                          onFieldSubmitted: (_) => _submit(cubit, state),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const ValueKey<String>('register-submit-button'),
                          onPressed: state.busy
                              ? null
                              : () => _submit(cubit, state),
                          style: FilledButton.styleFrom(
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
                                    const Flexible(
                                      child: Text('Creating account…'),
                                    ),
                                  ],
                                )
                              : const Text('Register'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const ValueKey<String>(
                            'register-back-to-login-button',
                          ),
                          onPressed: handleBackToLogin,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Back to sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

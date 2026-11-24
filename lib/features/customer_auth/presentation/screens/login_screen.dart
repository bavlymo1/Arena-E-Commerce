import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/arena_brand_app_bar_title.dart';
import '../../../../shared/widgets/arena_busy_button_label.dart';
import '../../../../shared/widgets/arena_notice_banner.dart';
import '../../../../shared/widgets/arena_page_header.dart';
import '../cubit/customer_auth_cubit.dart';
import '../cubit/customer_auth_state.dart';
import '../widgets/customer_auth_widgets.dart';

/// Customer email/password sign-in screen consuming [CustomerAuthCubit].
class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onRegisterRequested, super.key});

  final VoidCallback onRegisterRequested;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  bool _obscurePassword = true;
  bool _submittedOnce = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
    unawaited(cubit.login(_emailController.text, _passwordController.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const ArenaBrandAppBarTitle(title: 'Sign in', spacing: 12),
      ),
      body: SafeArea(
        child: BlocBuilder<CustomerAuthCubit, CustomerAuthState>(
          builder: (context, state) {
            final cubit = context.read<CustomerAuthCubit>();
            final inputsEnabled = !state.busy;

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: <Widget>[
                const ArenaPageHeader(
                  eyebrow: 'ArenaPass',
                  title: 'Customer sign in',
                  subtitle: 'Sign in with your customer email and password to book seats.',
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
                    key: const ValueKey<String>('login-error-banner'),
                    icon: Icons.error_outline,
                    message: state.errorMessage!,
                    isError: true,
                    liveRegion: true,
                    useTextAction: true,
                    emphasizeText: true,
                    actionLabel: state.hasError ? 'Try again' : null,
                    actionKey: state.hasError
                        ? const ValueKey<String>('login-retry-button')
                        : null,
                    onAction: state.hasError
                        ? () => unawaited(cubit.retry())
                        : null,
                  ),
                ],
                const SizedBox(height: 20),
                AutofillGroup(
                  key: const ValueKey<String>('login-autofill-group'),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submittedOnce
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          key: const ValueKey<String>('login-email-field'),
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
                            'login-password-field',
                          ),
                          toggleKey: const ValueKey<String>(
                            'login-password-visibility-toggle',
                          ),
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          labelText: 'Password',
                          obscureText: _obscurePassword,
                          onToggleVisibility: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          enabled: inputsEnabled,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[AutofillHints.password],
                          validator: (value) =>
                              CustomerAuthCubit.validatePassword(value ?? ''),
                          onChanged: (_) => cubit.clearError(),
                          onFieldSubmitted: (_) => _submit(cubit, state),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const ValueKey<String>('login-submit-button'),
                          onPressed: state.busy
                              ? null
                              : () => _submit(cubit, state),
                          child: state.busy
                              ? const ArenaBusyButtonLabel(label: 'Signing in…')
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          key: const ValueKey<String>(
                            'login-create-account-button',
                          ),
                          onPressed: state.busy
                              ? null
                              : () {
                                  cubit.clearError();
                                  widget.onRegisterRequested();
                                },
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/account_screen.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/login_screen.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _TestCustomerAuthRepository implements CustomerAuthRepository {
  StreamController<AppUser?> controller = StreamController<AppUser?>();
  bool throwOnAuthChanges = false;
  Future<void> Function(String email, String password)? onLogin;
  Future<void> Function(String email, String password)? onRegister;
  Future<void> Function()? onLogout;
  int loginCount = 0;
  int registerCount = 0;
  int logoutCount = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Stream<AppUser?> authChanges() {
    if (throwOnAuthChanges) {
      throw StateError('Auth listener failed');
    }
    return controller.stream;
  }

  @override
  Future<void> login(String email, String password) {
    loginCount++;
    lastEmail = email;
    lastPassword = password;
    if (onLogin != null) return onLogin!(email, password);
    return Future<void>.value();
  }

  @override
  Future<void> register(String email, String password) {
    registerCount++;
    lastEmail = email;
    lastPassword = password;
    if (onRegister != null) return onRegister!(email, password);
    return Future<void>.value();
  }

  @override
  Future<void> logout() {
    logoutCount++;
    if (onLogout != null) return onLogout!();
    return Future<void>.value();
  }

  void dispose() {
    unawaited(controller.close());
  }
}

Widget _wrapScreen({
  required CustomerAuthCubit cubit,
  required Widget child,
  ThemeData? theme,
  Size size = const Size(390, 812),
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: BlocProvider<CustomerAuthCubit>.value(value: cubit, child: child),
    ),
  );
}

void main() {
  testWidgets(
    'LoginScreen validates inputs, toggles password obscurity, submits, handles busy/error/retry, and triggers callback',
    (tester) async {
      final gate = Completer<void>();
      var failLogin = true;
      final repo = _TestCustomerAuthRepository()
        ..onLogin = (_, _) async {
          await gate.future;
          if (failLogin) throw StateError('Invalid credentials');
        };
      addTearDown(repo.dispose);
      final cubit = CustomerAuthCubit(repo);
      var registerRequested = 0;

      try {
        await tester.pumpWidget(
          _wrapScreen(
            cubit: cubit,
            child: LoginScreen(onRegisterRequested: () => registerRequested++),
          ),
        );
        await tester.pump();
        expect(find.text('Checking session…'), findsOneWidget);

        repo.controller.add(null);
        await tester.pumpAndSettle();

        // Obscure password initially, toggle visibility and verify tooltip labels.
        TextField passwordField() => tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('login-password-field')),
            matching: find.byType(TextField),
          ),
        );
        expect(passwordField().obscureText, isTrue);
        expect(find.byTooltip('Show password'), findsOneWidget);

        await tester.tap(
          find.byKey(
            const ValueKey<String>('login-password-visibility-toggle'),
          ),
        );
        await tester.pump();
        expect(passwordField().obscureText, isFalse);
        expect(find.byTooltip('Hide password'), findsOneWidget);

        await tester.tap(
          find.byKey(
            const ValueKey<String>('login-password-visibility-toggle'),
          ),
        );
        await tester.pump();
        expect(passwordField().obscureText, isTrue);

        // Validation blocks repository submission on invalid input.
        await tester.tap(
          find.byKey(const ValueKey<String>('login-submit-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(CustomerAuthCubit.emailRequiredMessage),
          findsOneWidget,
        );
        expect(
          find.text(CustomerAuthCubit.passwordRequiredMessage),
          findsOneWidget,
        );
        expect(repo.loginCount, 0);

        await tester.enterText(
          find.byKey(const ValueKey<String>('login-email-field')),
          'bad-email',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('login-submit-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(CustomerAuthCubit.emailInvalidMessage),
          findsOneWidget,
        );
        expect(repo.loginCount, 0);

        // Valid input triggers busy state, disables buttons, then shows safe error.
        await tester.enterText(
          find.byKey(const ValueKey<String>('login-email-field')),
          ' alex@example.test ',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('login-password-field')),
          'secret-pass',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('login-submit-button')),
        );
        await tester.pump();

        expect(repo.loginCount, 1);
        expect(repo.lastEmail, 'alex@example.test');
        expect(repo.lastPassword, 'secret-pass');
        expect(find.text('Signing in…'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey<String>('login-submit-button')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(
                  const ValueKey<String>('login-create-account-button'),
                ),
              )
              .onPressed,
          isNull,
        );

        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text(CustomerAuthCubit.loginErrorMessage), findsOneWidget);

        // Callback to RegisterScreen works when idle.
        await tester.tap(
          find.byKey(const ValueKey<String>('login-create-account-button')),
        );
        await tester.pump();
        expect(registerRequested, 1);

        // Stream error displays retry button and recovers when stream restores.
        repo.throwOnAuthChanges = false;
        repo.controller.addError(StateError('Connection dropped'));
        await tester.pumpAndSettle();
        expect(find.text(CustomerAuthCubit.streamErrorMessage), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('login-retry-button')),
          findsOneWidget,
        );

        await repo.controller.close();
        repo.controller = StreamController<AppUser?>();
        await tester.tap(
          find.byKey(const ValueKey<String>('login-retry-button')),
        );
        await tester.pump();
        repo.controller.add(null);
        await tester.pumpAndSettle();
        expect(find.text(CustomerAuthCubit.streamErrorMessage), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'RegisterScreen checks confirm-password match, toggles fields, submits, handles errors and back callbacks',
    (tester) async {
      final gate = Completer<void>();
      var shouldFail = true;
      final repo = _TestCustomerAuthRepository()
        ..onRegister = (_, _) async {
          await gate.future;
          if (shouldFail) throw StateError('Email already in use');
        };
      addTearDown(repo.dispose);
      final cubit = CustomerAuthCubit(repo);
      var loginRequested = 0;

      try {
        await tester.pumpWidget(
          _wrapScreen(
            cubit: cubit,
            child: RegisterScreen(onLoginRequested: () => loginRequested++),
          ),
        );
        repo.controller.add(null);
        await tester.pumpAndSettle();

        TextField passwordField() => tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('register-password-field')),
            matching: find.byType(TextField),
          ),
        );
        TextField confirmField() => tester.widget<TextField>(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('register-confirm-password-field'),
            ),
            matching: find.byType(TextField),
          ),
        );

        expect(passwordField().obscureText, isTrue);
        expect(confirmField().obscureText, isTrue);
        expect(find.byTooltip('Show password'), findsOneWidget);
        expect(find.byTooltip('Show confirm password'), findsOneWidget);

        await tester.tap(
          find.byKey(
            const ValueKey<String>(
              'register-confirm-password-visibility-toggle',
            ),
          ),
        );
        await tester.pump();
        expect(passwordField().obscureText, isTrue);
        expect(confirmField().obscureText, isFalse);

        // Mismatch validation prevents submit.
        await tester.enterText(
          find.byKey(const ValueKey<String>('register-email-field')),
          'jordan@example.test',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('register-password-field')),
          'pass-one',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('register-confirm-password-field')),
          'pass-two',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('register-submit-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('register-submit-button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Passwords must match.'), findsOneWidget);
        expect(repo.registerCount, 0);

        // Matching password submits and enters busy state.
        await tester.enterText(
          find.byKey(const ValueKey<String>('register-confirm-password-field')),
          'pass-one',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('register-submit-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('register-submit-button')),
        );
        await tester.pump();

        expect(repo.registerCount, 1);
        expect(repo.lastEmail, 'jordan@example.test');
        expect(repo.lastPassword, 'pass-one');
        expect(find.text('Creating account…'), findsOneWidget);

        gate.complete();
        await tester.pumpAndSettle();
        expect(
          find.text(CustomerAuthCubit.registerErrorMessage),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('register-back-to-login-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('register-back-to-login-button')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('register-appbar-back-button')),
        );
        await tester.pump();
        expect(loginRequested, 2);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'AccountScreen displays signed-in email, invokes logout, handles busy/error/retry, and disables logout when signed out',
    (tester) async {
      final logoutGate = Completer<void>();
      var failLogout = true;
      final repo = _TestCustomerAuthRepository()
        ..onLogout = () async {
          await logoutGate.future;
          if (failLogout) throw StateError('Logout failed');
        };
      addTearDown(repo.dispose);
      final cubit = CustomerAuthCubit(repo);

      try {
        await tester.pumpWidget(
          _wrapScreen(cubit: cubit, child: const AccountScreen()),
        );
        await tester.pump();
        expect(find.text('Checking session…'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey<String>('account-logout-button')),
              )
              .onPressed,
          isNull,
        );

        repo.controller.add(AppUser(uid: 'cust-1', email: 'alex@example.test'));
        await tester.pumpAndSettle();

        expect(find.text('alex@example.test'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('account-user-card')),
            matching: find.text('A'),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('account-logout-button')),
        );
        await tester.pump();
        expect(repo.logoutCount, 1);
        expect(find.text('Signing out…'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey<String>('account-logout-button')),
              )
              .onPressed,
          isNull,
        );

        logoutGate.complete();
        await tester.pumpAndSettle();
        expect(find.text(CustomerAuthCubit.logoutErrorMessage), findsOneWidget);

        // Stream error retry works on AccountScreen too.
        repo.controller.addError(StateError('Session dropped'));
        await tester.pumpAndSettle();
        expect(find.text(CustomerAuthCubit.streamErrorMessage), findsOneWidget);
        await repo.controller.close();
        repo.controller = StreamController<AppUser?>();

        await tester.tap(
          find.byKey(const ValueKey<String>('account-retry-button')),
        );
        await tester.pump();
        repo.controller.add(null);
        await tester.pumpAndSettle();
        expect(find.text('Not signed in'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey<String>('account-logout-button')),
              )
              .onPressed,
          isNull,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
    testWidgets(
      'Login, Register, and Account screens fit 300px width at 2.0x text scale without overflow in ${brightness.name} mode',
      (tester) async {
        tester.view.physicalSize = const Size(300, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xffd52f65),
            brightness: brightness,
          ),
        );

        for (final entry in <String, Widget>{
          'login': LoginScreen(onRegisterRequested: () {}),
          'register': RegisterScreen(onLoginRequested: () {}),
          'account': const AccountScreen(),
        }.entries) {
          final repo = _TestCustomerAuthRepository();
          addTearDown(repo.dispose);
          final cubit = CustomerAuthCubit(repo);

          try {
            await tester.pumpWidget(
              _wrapScreen(
                cubit: cubit,
                theme: theme,
                size: const Size(300, 640),
                textScale: 2.0,
                child: entry.value,
              ),
            );
            repo.controller.add(
              entry.key == 'account'
                  ? AppUser(
                      uid: 'cust-long',
                      email: 'very.long.customer.email.address@arenapass.test',
                    )
                  : null,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: entry.key);

            await tester.drag(find.byType(ListView), const Offset(0, -300));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: entry.key);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(cubit.close);
          }
        }
      },
    );
  }

  testWidgets(
    'supports keyboard submit, cleans up controllers on unmount, and exposes screen-reader labels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        // 1. LoginScreen keyboard submit + semantics + clean unmount mid-entry.
        final loginRepo = _TestCustomerAuthRepository();
        addTearDown(loginRepo.dispose);
        final loginCubit = CustomerAuthCubit(loginRepo);
        try {
          await tester.pumpWidget(
            _wrapScreen(
              cubit: loginCubit,
              child: LoginScreen(onRegisterRequested: () {}),
            ),
          );
          loginRepo.controller.add(null);
          await tester.pumpAndSettle();

          final loginToggleSemantics = tester.getSemantics(
            find.byKey(
              const ValueKey<String>('login-password-visibility-toggle'),
            ),
          );
          expect(loginToggleSemantics.tooltip, 'Show password');
          expect(find.bySemanticsLabel('Sign in'), findsWidgets);
          expect(find.bySemanticsLabel('Create account'), findsOneWidget);

          await tester.enterText(
            find.byKey(const ValueKey<String>('login-email-field')),
            'alex@example.test',
          );
          await tester.testTextInput.receiveAction(TextInputAction.next);
          await tester.pump();
          await tester.enterText(
            find.byKey(const ValueKey<String>('login-password-field')),
            'keyboard-pass',
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          expect(loginRepo.loginCount, 1);
          expect(loginRepo.lastEmail, 'alex@example.test');
          expect(loginRepo.lastPassword, 'keyboard-pass');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(loginCubit.close);
        }
        expect(tester.takeException(), isNull);

        // 2. RegisterScreen keyboard submit + semantics + clean unmount.
        final registerRepo = _TestCustomerAuthRepository();
        addTearDown(registerRepo.dispose);
        final registerCubit = CustomerAuthCubit(registerRepo);
        try {
          await tester.pumpWidget(
            _wrapScreen(
              cubit: registerCubit,
              child: RegisterScreen(onLoginRequested: () {}),
            ),
          );
          registerRepo.controller.add(null);
          await tester.pumpAndSettle();

          expect(
            tester
                .getSemantics(
                  find.byKey(
                    const ValueKey<String>('register-appbar-back-button'),
                  ),
                )
                .tooltip,
            'Back to sign in',
          );
          expect(
            tester
                .getSemantics(
                  find.byKey(
                    const ValueKey<String>(
                      'register-password-visibility-toggle',
                    ),
                  ),
                )
                .tooltip,
            'Show password',
          );
          expect(
            tester
                .getSemantics(
                  find.byKey(
                    const ValueKey<String>(
                      'register-confirm-password-visibility-toggle',
                    ),
                  ),
                )
                .tooltip,
            'Show confirm password',
          );

          await tester.enterText(
            find.byKey(const ValueKey<String>('register-email-field')),
            'jordan@example.test',
          );
          await tester.testTextInput.receiveAction(TextInputAction.next);
          await tester.pump();
          await tester.enterText(
            find.byKey(const ValueKey<String>('register-password-field')),
            'reg-pass',
          );
          await tester.testTextInput.receiveAction(TextInputAction.next);
          await tester.pump();
          await tester.enterText(
            find.byKey(
              const ValueKey<String>('register-confirm-password-field'),
            ),
            'reg-pass',
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          expect(registerRepo.registerCount, 1);
          expect(registerRepo.lastEmail, 'jordan@example.test');
          expect(registerRepo.lastPassword, 'reg-pass');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(registerCubit.close);
        }
        expect(tester.takeException(), isNull);

        // 3. AccountScreen semantics exclude decorative avatar/brand mark and label logout + live error.
        final accountRepo = _TestCustomerAuthRepository()
          ..onLogout = () async => throw StateError('Logout failed');
        addTearDown(accountRepo.dispose);
        final accountCubit = CustomerAuthCubit(accountRepo);
        try {
          await tester.pumpWidget(
            _wrapScreen(cubit: accountCubit, child: const AccountScreen()),
          );
          accountRepo.controller.add(
            AppUser(uid: 'cust-1', email: 'alex@example.test'),
          );
          await tester.pumpAndSettle();

          expect(find.bySemanticsLabel('alex@example.test'), findsOneWidget);
          expect(find.bySemanticsLabel('Log out'), findsOneWidget);

          await tester.tap(
            find.byKey(const ValueKey<String>('account-logout-button')),
          );
          await tester.pumpAndSettle();
          final bannerSemantics = tester.getSemantics(
            find.byKey(const ValueKey<String>('account-error-banner')),
          );
          expect(bannerSemantics.flagsCollection.isLiveRegion, isTrue);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(accountCubit.close);
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}

import 'dart:async';

import 'package:e_commerce_project/app/customer/customer_app.dart';
import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/login_screen.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/customer_auth_journey.dart';
import '../support/fake_shows_repository.dart';

class _Auth implements CustomerAuthRepository {
  final events = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? current;
  bool emitInitial = true;
  bool failLogin = false;
  bool failRegister = false;
  @override
  Stream<AppUser?> authChanges() => Stream.multi((sink) {
    final sub = events.stream.listen(sink.add, onError: sink.addError);
    sink.onCancel = sub.cancel;
    if (emitInitial) sink.add(current);
  });
  @override
  Future<void> register(String email, String password) async {
    if (failRegister) throw StateError('Registration failed');
    return login(email, password);
  }

  @override
  Future<void> login(String email, String password) async {
    if (failLogin) throw StateError('Invalid credentials');
    current = AppUser(uid: email, email: email);
    events.add(current);
  }

  @override
  Future<void> logout() async {
    current = null;
    events.add(null);
  }
}

void main() {
  testWidgets(
    'root auth lifecycle, signout Back, protected deep links and second UID isolation',
    (tester) async {
      final auth = _Auth();
      addTearDown(auth.events.close);
      await verifyCustomerAuthJourney(tester, auth);
    },
  );
  testWidgets('checking keeps startup visible and denies protected routes', (
    tester,
  ) async {
    final auth = _Auth()..emitInitial = false;
    final graph = createAuthenticatedCustomerServices(
      authRepository: auth,
      showsRepository: FakeShowsRepository(),
    );
    await tester.pumpWidget(createCustomerApp(services: graph));
    await tester.pump();
    expect(find.text('Checking session'), findsOneWidget);
    GoRouter.of(tester.element(find.text('Checking session'))).go('/account');
    await tester.pump();
    expect(find.text('Checking session'), findsOneWidget);
    auth.events.add(null);
    await waitForScreen(tester, LoginScreen);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await auth.events.close();
  });

  testWidgets(
    'navigating between login and register clears stale auth error banners',
    (tester) async {
      final auth = _Auth()
        ..failLogin = true
        ..failRegister = true;
      final graph = createAuthenticatedCustomerServices(
        authRepository: auth,
        showsRepository: FakeShowsRepository(),
      );

      Future<void> tapKey(String key) async {
        final target = find.byKey(ValueKey<String>(key));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
      }

      await tester.pumpWidget(createCustomerApp(services: graph));
      await waitForScreen(tester, LoginScreen);

      // Fail login() then navigate /login -> /register.
      await tester.enterText(
        find.byKey(const ValueKey<String>('login-email-field')),
        'alex@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('login-password-field')),
        'wrong-pass',
      );
      await tapKey('login-submit-button');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('login-error-banner')),
        findsOneWidget,
      );
      expect(find.text(CustomerAuthCubit.loginErrorMessage), findsOneWidget);

      await tapKey('login-create-account-button');
      await waitForScreen(tester, RegisterScreen);
      expect(
        find.byKey(const ValueKey<String>('register-error-banner')),
        findsNothing,
      );
      expect(find.text(CustomerAuthCubit.loginErrorMessage), findsNothing);

      // Fail register() then navigate /register -> /login via Back to sign in.
      Future<void> failRegisterOnScreen() async {
        await tester.enterText(
          find.byKey(const ValueKey<String>('register-email-field')),
          'alex@example.test',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('register-password-field')),
          'secret-pass',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('register-confirm-password-field')),
          'secret-pass',
        );
        await tapKey('register-submit-button');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('register-error-banner')),
          findsOneWidget,
        );
        expect(
          find.text(CustomerAuthCubit.registerErrorMessage),
          findsOneWidget,
        );
      }

      await failRegisterOnScreen();
      await tapKey('register-back-to-login-button');
      await waitForScreen(tester, LoginScreen);
      expect(
        find.byKey(const ValueKey<String>('login-error-banner')),
        findsNothing,
      );
      expect(find.text(CustomerAuthCubit.registerErrorMessage), findsNothing);

      // Fail register() then navigate /register -> /login via AppBar back.
      await tapKey('login-create-account-button');
      await waitForScreen(tester, RegisterScreen);
      await failRegisterOnScreen();
      await tapKey('register-appbar-back-button');
      await waitForScreen(tester, LoginScreen);
      expect(
        find.byKey(const ValueKey<String>('login-error-banner')),
        findsNothing,
      );
      expect(find.text(CustomerAuthCubit.registerErrorMessage), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await auth.events.close();
    },
  );
}

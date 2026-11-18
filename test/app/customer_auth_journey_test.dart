import 'dart:async';

import 'package:e_commerce_project/app/customer/customer_app.dart';
import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/customer_auth_journey.dart';
import '../support/fake_shows_repository.dart';

class _Auth implements CustomerAuthRepository {
  final events = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? current;
  bool emitInitial = true;
  @override
  Stream<AppUser?> authChanges() => Stream.multi((sink) {
    final sub = events.stream.listen(sink.add, onError: sink.addError);
    sink.onCancel = sub.cancel;
    if (emitInitial) sink.add(current);
  });
  @override
  Future<void> register(String email, String password) =>
      login(email, password);
  @override
  Future<void> login(String email, String password) async {
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
}

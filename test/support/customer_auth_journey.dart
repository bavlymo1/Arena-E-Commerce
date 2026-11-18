import 'package:e_commerce_project/app/customer/customer_app.dart';
import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/login_screen.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/register_screen.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/account_screen.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_shows_repository.dart';

Future<void> waitForScreen(WidgetTester tester, Type screen) async {
  for (var i = 0; i < 150 && find.byType(screen).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(screen), findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

Future<void> verifyCustomerAuthJourney(
  WidgetTester tester,
  CustomerAuthRepository repository,
) async {
  final suffix = DateTime.now().microsecondsSinceEpoch;
  final firstEmail = 'customer-a-$suffix@example.test';
  final secondEmail = 'customer-b-$suffix@example.test';
  const password = 'Local-auth-flow-47';
  await repository.register(secondEmail, password);
  await repository.logout();
  final shows = FakeShowsRepository();
  final graph = createAuthenticatedCustomerServices(
    authRepository: repository,
    showsRepository: shows,
  );
  await tester.pumpWidget(createCustomerApp(services: graph));
  await waitForScreen(tester, LoginScreen);
  final rootAuth = tester
      .element(find.byType(LoginScreen))
      .read<CustomerAuthCubit>();
  await _tap(tester, 'login-create-account-button');
  await waitForScreen(tester, RegisterScreen);
  await tester.enterText(
    find.byKey(const ValueKey('register-email-field')),
    firstEmail,
  );
  await tester.enterText(
    find.byKey(const ValueKey('register-password-field')),
    password,
  );
  await tester.enterText(
    find.byKey(const ValueKey('register-confirm-password-field')),
    password,
  );
  await _tap(tester, 'register-submit-button');
  await waitForScreen(tester, DiscoveryScreen);
  final firstDiscovery = tester
      .element(find.byType(DiscoveryScreen))
      .read<DiscoveryCubit>();
  await tester.enterText(find.byType(TextField), 'first customer search');
  await tester.pumpAndSettle();
  final firstUid = rootAuth.state.user!.uid;
  await tester.tap(find.byTooltip('Account'));
  await waitForScreen(tester, AccountScreen);
  expect(find.text(firstEmail), findsOneWidget);
  expect(
    identical(
      rootAuth,
      tester.element(find.byType(AccountScreen)).read<CustomerAuthCubit>(),
    ),
    isTrue,
  );
  await _tap(tester, 'account-logout-button');
  await waitForScreen(tester, LoginScreen);
  await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  expect(firstDiscovery.isClosed, isTrue);
  expect(rootAuth.state.user, isNull);
  expect(shows.cacheClears, 1);
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byType(DiscoveryScreen), findsNothing);
  expect(find.byType(AccountScreen), findsNothing);
  var router = GoRouter.of(tester.element(find.byType(LoginScreen)));
  router.go('/account');
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
  router.go('/show/private-old-show');
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
  await tester.enterText(
    find.byKey(const ValueKey('login-email-field')),
    secondEmail,
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-password-field')),
    password,
  );
  await _tap(tester, 'login-submit-button');
  await waitForScreen(tester, DiscoveryScreen);
  final secondDiscovery = tester
      .element(find.byType(DiscoveryScreen))
      .read<DiscoveryCubit>();
  expect(identical(firstDiscovery, secondDiscovery), isFalse);
  expect(secondDiscovery.state.searchQuery, isEmpty);
  expect(rootAuth.state.user!.uid, isNot(firstUid));
  expect(shows.cacheClears, 1);
  await tester.tap(find.byTooltip('Account'));
  await waitForScreen(tester, AccountScreen);
  expect(find.text(secondEmail), findsOneWidget);
  expect(find.text(firstEmail), findsNothing);
  await _tap(tester, 'account-logout-button');
  await waitForScreen(tester, LoginScreen);
  expect(shows.cacheClears, 2);
  await tester.enterText(
    find.byKey(const ValueKey('login-email-field')),
    firstEmail,
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-password-field')),
    password,
  );
  await _tap(tester, 'login-submit-button');
  await waitForScreen(tester, DiscoveryScreen);
  expect(rootAuth.state.user!.uid, firstUid);
  await repository.logout();
  await waitForScreen(tester, LoginScreen);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  expect(rootAuth.isClosed, isTrue);
  expect(shows.disposed, isTrue);
}

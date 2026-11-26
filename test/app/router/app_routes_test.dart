import 'package:e_commerce_project/app/router/app_routes.dart';
import 'package:e_commerce_project/app/router/customer_router.dart';
import 'package:e_commerce_project/app/router/vendor_router.dart';
import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_state.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/account_screen.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/screens/login_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/vendor_shows_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_shows_repository.dart';

final class _StaticCustomerAuthRepository implements CustomerAuthRepository {
  _StaticCustomerAuthRepository(this.user);

  final AppUser user;

  @override
  Stream<AppUser?> authChanges() => Stream<AppUser?>.value(user);

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> register(String email, String password) async {}
}

void main() {
  test('AppRoutes builders encode path segments and separate app scopes', () {
    expect(AppRoutes.customerShowDetailsPath('a/b c'), '/show/a%2Fb%20c');
    expect(
      AppRoutes.customerSeatSelectionPath('a/b', '19:00'),
      '/show/a%2Fb/session/19%3A00',
    );
    expect(
      AppRoutes.customerBookingResultPath('s 1', '19:00', 'b/1'),
      '/show/s%201/session/19%3A00/result/b%2F1',
    );
    expect(AppRoutes.vendorShowDetailsPath('v/1 2'), '/show/v%2F1%202');

    expect(AppRoutes.customerDiscover, '/discover');
    expect(AppRoutes.vendorShows, '/shows');
    expect(AppRoutes.vendorAddShow, '/add-show');
    expect(AppRoutes.vendorUpdates, '/updates');
  });

  testWidgets(
    'createCustomerRouter redirects checking, signedOut, and hasShows=false',
    (tester) async {
      final user = AppUser(uid: 'cust-1', email: 'cust-1@example.test');
      var currentState = const CustomerAuthState(
        status: CustomerAuthStatus.checking,
      );
      final refresh = ValueNotifier<int>(0);
      final router = createCustomerRouter(
        refreshListenable: refresh,
        readAuthState: () => currentState,
        readSessionEpoch: () => 0,
        hasShows: false,
      );

      await tester.pumpWidget(
        BlocProvider<CustomerAuthCubit>(
          create: (_) => CustomerAuthCubit(_StaticCustomerAuthRepository(user)),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.text('Checking session'), findsOneWidget);

      router.go(AppRoutes.customerAccount);
      await tester.pump();
      expect(find.text('Checking session'), findsOneWidget);

      currentState = const CustomerAuthState(
        status: CustomerAuthStatus.signedOut,
      );
      refresh.value++;
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      router.go(AppRoutes.customerDiscover);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      currentState = CustomerAuthState(
        status: CustomerAuthStatus.signedIn,
        user: user,
      );
      refresh.value++;
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.text('cust-1@example.test'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      router.dispose();
      refresh.dispose();
    },
  );

  testWidgets(
    'createVendorRouter redirects add-show when form disabled and omits updates when disabled',
    (tester) async {
      final showsRepo = FakeShowsRepository();

      final router = createVendorRouter(
        createShowsCubit: () => VendorShowsCubit(showsRepo, vendorId: 'v1'),
        createDetailsCubit: (showId) =>
            VendorShowDetailsCubit(showsRepo, vendorId: 'v1', showId: showId),
        createShowFormCubit: null,
        hasUpdates: false,
      );

      final routePaths = router.configuration.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();
      expect(routePaths, <String>[
        AppRoutes.vendorShows,
        AppRoutes.vendorAddShow,
        AppRoutes.vendorShowDetails,
      ]);
      expect(routePaths, isNot(contains(AppRoutes.vendorUpdates)));

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(VendorShowsScreen), findsOneWidget);

      router.go(AppRoutes.vendorAddShow);
      await tester.pumpAndSettle();
      expect(find.byType(VendorShowsScreen), findsOneWidget);

      final withUpdatesRouter = createVendorRouter(
        createShowsCubit: () => VendorShowsCubit(showsRepo, vendorId: 'v1'),
        createDetailsCubit: (showId) =>
            VendorShowDetailsCubit(showsRepo, vendorId: 'v1', showId: showId),
        hasUpdates: true,
      );
      expect(
        withUpdatesRouter.configuration.routes
            .whereType<GoRoute>()
            .map((route) => route.path)
            .toList(),
        contains(AppRoutes.vendorUpdates),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      withUpdatesRouter.dispose();
      router.dispose();
      showsRepo.dispose();
    },
  );
}

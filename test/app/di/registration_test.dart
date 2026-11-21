import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/app/customer/customer_app.dart';
import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/app/di/vendor_registration.dart';
import 'package:e_commerce_project/app/startup/app_variant.dart';
import 'package:e_commerce_project/app/startup/arena_pass_app.dart';
import 'package:e_commerce_project/app/startup/startup_cubit.dart';
import 'package:e_commerce_project/app/vendor/vendor_app.dart';
import 'package:e_commerce_project/app/vendor/vendor_enrolled_app.dart';
import 'package:e_commerce_project/features/booking/domain/repositories/booking_repository.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/booking_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_cubit.dart';
import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/show_details_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/cubit/vendor_access_cubit.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/alert_permission.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_alert.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/booking_events_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/local_alert_presenter.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/watermark_store.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/vendor_shows_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_booking_repository.dart';
import '../../support/fake_shows_repository.dart';

// ignore_for_file: subtype_of_sealed_class

final class _FakeUser extends Fake implements User {
  @override
  String get uid => 'fake-uid';
}

final class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

final class _FakeFirebaseFirestore extends Fake implements FirebaseFirestore {}

final class _StubAccessRepository implements VendorAccessRepository {
  _StubAccessRepository([this.result]);

  final VendorAccess? result;

  @override
  Future<VendorAccess> check() async =>
      result ?? VendorNotEnrolled(uid: 'anon-1');
}

final class _StubCustomerAuthRepository implements CustomerAuthRepository {
  _StubCustomerAuthRepository(this.user);

  final AppUser? user;

  @override
  Stream<AppUser?> authChanges() => Stream<AppUser?>.value(user);

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> register(String email, String password) async {}
}

final class _StubBookingEventsRepository implements BookingEventsRepository {
  @override
  Stream<List<BookingEvent>> watchEvents(String vendorId) =>
      Stream<List<BookingEvent>>.value(const <BookingEvent>[]);
}

final class _StubAlertPresenter implements LocalAlertPresenter {
  @override
  Future<AlertPermission> requestPermission() async => AlertPermission.denied;

  @override
  Future<void> showBookingAlert(BookingAlert alert) async {}

  @override
  Future<void> showGroupedAlert(int count) async {}
}

void main() {
  test('containers are separate and startup cubits are factories', () async {
    final customer = createCustomerServices();
    final vendor = createVendorServices();
    expect(customer<AppVariant>(), AppVariant.customer);
    expect(vendor<AppVariant>(), AppVariant.vendor);
    final first = customer<StartupCubit>();
    final second = customer<StartupCubit>();
    expect(identical(first, second), isFalse);
    await first.close();
    await second.close();
    await customer.reset();
    await vendor.reset();
  });
  testWidgets('route provider closes its factory cubit when app leaves', (
    tester,
  ) async {
    final services = createCustomerServices();
    await services.unregister<StartupCubit>();
    late StartupCubit created;
    services.registerFactory<StartupCubit>(
      () => created = StartupCubit(() async => 'Pending'),
    );
    await tester.pumpWidget(ArenaPassApp(services: services));
    await tester.pumpAndSettle();
    expect(created.isClosed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(created.isClosed, isTrue);
    expect(services.isRegistered<AppVariant>(), isFalse);
  });

  test('createLocalVendorServices registers singletons and parameterized vendor factories', () async {
    final services = createLocalVendorServices(
      auth: _FakeFirebaseAuth(),
      firestore: _FakeFirebaseFirestore(),
      accessRepository: _StubAccessRepository(),
      watermarkStore: InMemoryWatermarkStore(),
      alertPresenter: _StubAlertPresenter(),
      posterPicker: (_) async => Uint8List(0),
      recoverPoster: () async => null,
    );

    expect(services<AppVariant>(), AppVariant.vendor);
    expect(services.isRegistered<VendorAccessRepository>(), isTrue);
    expect(services.isRegistered<ShowsRepository>(), isTrue);
    expect(services.isRegistered<BookingEventsRepository>(), isTrue);
    expect(services.isRegistered<WatermarkStore>(), isTrue);
    expect(services.isRegistered<LocalAlertPresenter>(), isTrue);

    final accessA = services<VendorAccessCubit>();
    final accessB = services<VendorAccessCubit>();
    expect(identical(accessA, accessB), isFalse);

    final formA = services<ShowFormCubit>(param1: 'vendor-a');
    final formB = services<ShowFormCubit>(param1: 'vendor-a');
    expect(identical(formA, formB), isFalse);

    final showsCubit = services<VendorShowsCubit>(param1: 'vendor-a');
    final detailsCubit = services<VendorShowDetailsCubit>(
      param1: 'vendor-a',
      param2: 'show-1',
    );
    final notificationsCubit = services<VendorNotificationsCubit>(
      param1: 'vendor-a',
    );
    expect(showsCubit.state.vendorId, 'vendor-a');
    expect(detailsCubit.state.vendorId, 'vendor-a');
    expect(detailsCubit.state.showId, 'show-1');
    expect(notificationsCubit.state.vendorId, 'vendor-a');

    await accessA.close();
    await accessB.close();
    await formA.close();
    await formB.close();
    await showsCubit.close();
    await detailsCubit.close();
    await notificationsCubit.close();
    await services.reset();
    expect(services.isRegistered<ShowsRepository>(), isFalse);
  });

  test('createLiveCustomerServices registers live auth, shows, booking, and factories', () async {
    final defaultServices = createLiveCustomerServices(
      auth: _FakeFirebaseAuth(),
      firestore: _FakeFirebaseFirestore(),
    );
    expect(defaultServices<AppVariant>(), AppVariant.customer);
    expect(defaultServices.isRegistered<CustomerAuthRepository>(), isTrue);
    expect(defaultServices.isRegistered<ShowsRepository>(), isTrue);
    expect(defaultServices.isRegistered<BookingRepository>(), isTrue);
    expect(defaultServices.isRegistered<CustomerAuthCubit>(), isTrue);
    expect(defaultServices.isRegistered<DiscoveryCubit>(), isTrue);
    expect(defaultServices.isRegistered<ShowDetailsCubit>(), isTrue);
    expect(defaultServices.isRegistered<SeatSelectionCubit>(), isTrue);
    expect(defaultServices.isRegistered<BookingCubit>(), isTrue);

    final bookingCubit = defaultServices<BookingCubit>(
      param1: 'show-1',
      param2: '1900',
    );
    expect(bookingCubit.showId, 'show-1');
    expect(bookingCubit.sessionId, '1900');
    await bookingCubit.close();
    await defaultServices.reset();
    expect(defaultServices.isRegistered<ShowsRepository>(), isFalse);

    final fakeShows = FakeShowsRepository();
    final fakeBooking = FakeBookingRepository();
    final stubServices = createLiveCustomerServices(
      auth: _FakeFirebaseAuth(),
      firestore: _FakeFirebaseFirestore(),
      authRepository: _StubCustomerAuthRepository(
        AppUser(uid: 'cust-1', email: 'c1@test.dev'),
      ),
      showsRepository: fakeShows,
      bookingRepository: fakeBooking,
      currentCustomerUid: () => 'cust-1',
    );

    final authCubit = stubServices<CustomerAuthCubit>();
    final discoveryCubit = stubServices<DiscoveryCubit>();
    final detailsCubit = stubServices<ShowDetailsCubit>(param1: 'show-1');
    final seatCubit = stubServices<SeatSelectionCubit>(
      param1: 'show-1',
      param2: '1900',
    );
    final liveBooking = stubServices<BookingCubit>(
      param1: 'show-1',
      param2: '1900',
    );
    expect(liveBooking.customerUid, 'cust-1');
    expect(seatCubit.state.customerUid, 'cust-1');

    await authCubit.close();
    await discoveryCubit.close();
    await detailsCubit.close();
    await seatCubit.close();
    await liveBooking.close();
    await stubServices.reset();
    expect(fakeShows.disposed, isTrue);
  });

  testWidgets(
    'live Customer and Vendor apps omit emulator banners while emulator defaults keep them',
    (tester) async {
      // 1. Live Customer app (banner: null) omits LOCAL EMULATORS banner.
      final liveCustomerServices = createLiveCustomerServices(
        auth: _FakeFirebaseAuth(),
        firestore: _FakeFirebaseFirestore(),
        authRepository: _StubCustomerAuthRepository(
          AppUser(uid: 'cust-1', email: 'c1@test.dev'),
        ),
        showsRepository: FakeShowsRepository(),
        bookingRepository: FakeBookingRepository(),
        currentCustomerUid: () => 'cust-1',
      );
      await tester.pumpWidget(
        createCustomerApp(services: liveCustomerServices, banner: null),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(find.textContaining('LOCAL EMULATORS'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));

      // 2. Default Customer emulator app preserves LOCAL EMULATORS banner.
      final emuCustomerServices = createLiveCustomerServices(
        auth: _FakeFirebaseAuth(),
        firestore: _FakeFirebaseFirestore(),
        authRepository: _StubCustomerAuthRepository(
          AppUser(uid: 'cust-1', email: 'c1@test.dev'),
        ),
        showsRepository: FakeShowsRepository(),
        bookingRepository: FakeBookingRepository(),
        currentCustomerUid: () => 'cust-1',
      );
      await tester.pumpWidget(createCustomerApp(services: emuCustomerServices));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(find.text('LOCAL EMULATORS'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));

      // 3. Live Vendor app via createEnrolledVendorApp(banner: null) omits banner.
      final liveVendorServices = createLocalVendorServices(
        auth: _FakeFirebaseAuth(),
        firestore: _FakeFirebaseFirestore(),
        accessRepository: _StubAccessRepository(
          VendorAllowed(uid: 'anon-1', vendorId: 'arena'),
        ),
        watermarkStore: InMemoryWatermarkStore(),
        alertPresenter: _StubAlertPresenter(),
        posterPicker: (_) async => Uint8List(0),
        recoverPoster: () async => null,
      );
      await liveVendorServices.unregister<BookingEventsRepository>();
      liveVendorServices.registerSingleton<BookingEventsRepository>(
        _StubBookingEventsRepository(),
      );
      await tester.pumpWidget(
        createEnrolledVendorApp(services: liveVendorServices, banner: null),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VendorShowsScreen), findsOneWidget);
      expect(find.textContaining('LOCAL EMULATORS'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));

      // 4. Default VendorEnrolledApp preserves LOCAL EMULATORS banner.
      final emuVendorServices = createLocalVendorServices(
        auth: _FakeFirebaseAuth(),
        firestore: _FakeFirebaseFirestore(),
        accessRepository: _StubAccessRepository(
          VendorAllowed(uid: 'anon-1', vendorId: 'arena'),
        ),
        watermarkStore: InMemoryWatermarkStore(),
        alertPresenter: _StubAlertPresenter(),
        posterPicker: (_) async => Uint8List(0),
        recoverPoster: () async => null,
      );
      await emuVendorServices.unregister<BookingEventsRepository>();
      emuVendorServices.registerSingleton<BookingEventsRepository>(
        _StubBookingEventsRepository(),
      );
      await tester.pumpWidget(VendorEnrolledApp(services: emuVendorServices));
      await tester.pumpAndSettle();
      expect(find.byType(VendorShowsScreen), findsOneWidget);
      expect(find.text('LOCAL EMULATORS · enrolled vendor'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    },
  );
}

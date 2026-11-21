import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/app/di/vendor_registration.dart';
import 'package:e_commerce_project/app/startup/app_variant.dart';
import 'package:e_commerce_project/app/startup/arena_pass_app.dart';
import 'package:e_commerce_project/app/startup/startup_cubit.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/cubit/vendor_access_cubit.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/alert_permission.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_alert.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/booking_events_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/local_alert_presenter.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/watermark_store.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: subtype_of_sealed_class

final class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

final class _FakeFirebaseFirestore extends Fake implements FirebaseFirestore {}

final class _StubAccessRepository implements VendorAccessRepository {
  @override
  Future<VendorAccess> check() async => VendorNotEnrolled(uid: 'anon-1');
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
}

import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/app/customer/demo_customer_repository.dart';
import 'package:e_commerce_project/app/di/vendor_registration.dart';
import 'package:e_commerce_project/app/vendor/vendor_demo_app.dart';
import 'package:e_commerce_project/app/vendor/vendor_enrolled_app.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/cubit/vendor_access_cubit.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/screens/vendor_not_enrolled_screen.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/alert_permission.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_alert.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/booking_events_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/local_alert_presenter.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/watermark_store.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/screens/vendor_updates_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/add_show_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/vendor_show_details_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/vendor_shows_screen.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/fake_shows_repository.dart';

final class _SequenceVendorAccessRepository implements VendorAccessRepository {
  _SequenceVendorAccessRepository(this.results);

  final List<VendorAccess> results;
  int _index = 0;

  @override
  Future<VendorAccess> check() async {
    final current =
        results[_index < results.length ? _index : results.length - 1];
    _index++;
    return current;
  }
}

final class _StreamingBookingEventsRepository
    implements BookingEventsRepository {
  final StreamController<List<BookingEvent>> controller =
      StreamController<List<BookingEvent>>.broadcast();
  int watchCalls = 0;

  @override
  Stream<List<BookingEvent>> watchEvents(String vendorId) {
    watchCalls++;
    return controller.stream;
  }

  Future<void> dispose() => controller.close();
}

final class _RecordingAlertPresenter implements LocalAlertPresenter {
  final List<BookingAlert> shownAlerts = <BookingAlert>[];
  final List<int> groupedCounts = <int>[];

  @override
  Future<AlertPermission> requestPermission() async => AlertPermission.granted;

  @override
  Future<void> showBookingAlert(BookingAlert alert) async {
    shownAlerts.add(alert);
  }

  @override
  Future<void> showGroupedAlert(int count) async {
    groupedCounts.add(count);
  }
}

void main() {
  testWidgets('local Add Show route owns its form and returns after saving', (
    tester,
  ) async {
    final repository = FakeShowsRepository();
    final services = GetIt.asNewInstance()
      ..registerSingleton<ShowsRepository>(repository);
    registerVendorJourney(
      services,
      vendorId: 'fixture-vendor',
      posterPicker: (_) async => Uint8List.fromList([1, 2, 3]),
      recoverPoster: () async => Uint8List.fromList([6, 5, 4]),
    );
    await tester.pumpWidget(
      VendorDemoApp(services: services, canAddShow: true),
    );
    await tester.pumpAndSettle();
    final shows = find.byType(VendorShowsScreen);
    final list = tester.element(shows).read<VendorShowsCubit>();
    await tester.tap(find.text('Add show').first);
    await tester.pumpAndSettle();
    final form = tester
        .element(find.byType(AddShowScreen))
        .read<ShowFormCubit>();
    expect(form.state.posterBytes, [6, 5, 4]);
    form.updateTitle('Local route test');
    form.updateDescription('Fixture description');
    form.updateShowDate('2026-12-20');
    form.updateSessionTime(0, '16:23');
    final poster = Uint8List.fromList([9, 8, 7]);
    form.setPosterBytes(poster);
    poster[0] = 0;
    expect(() => form.state.posterBytes![0] = 0, throwsUnsupportedError);
    await form.submit();
    await tester.pumpAndSettle();

    expect(tester.element(shows).read<VendorShowsCubit>(), same(list));
    expect(form.isClosed, isTrue);
    expect(repository.added.single.$1.vendorId, 'fixture-vendor');
    expect(repository.added.single.$1.sessions.single.value, '16:23');
    expect(repository.added.single.$2, [9, 8, 7]);
  });

  testWidgets('vendor list details session map and back own their Cubits', (
    tester,
  ) async {
    final services = createDemoVendorServices();
    await tester.pumpWidget(createVendorDemoApp(services: services));
    await tester.pumpAndSettle();
    expect(find.textContaining('LOCAL DEMO'), findsOneWidget);
    final list = tester
        .element(find.byType(VendorShowsScreen))
        .read<VendorShowsCubit>();
    await tester.tap(find.text('Skyline Jam'));
    await tester.pumpAndSettle();
    final details = tester
        .element(find.byType(VendorShowDetailsScreen))
        .read<VendorShowDetailsCubit>();
    expect(details.state.showId, 'demo-success');
    expect(details.state.vendorId, 'demo-vendor');
    expect(details.state.selectedSession!.bookedSeats, {7});
    final evening = find.byKey(const ValueKey('vendor-session-option-1900'));
    await tester.ensureVisible(evening);
    await tester.pumpAndSettle();
    await tester.tap(evening);
    await tester.pumpAndSettle();
    expect(details.state.selectedSession!.bookedSeats, {9, 18});
    final seat = find.byKey(const ValueKey('seat-grid-1'));
    await tester.ensureVisible(seat);
    await tester.pumpAndSettle();
    final tiles = tester.widgetList<SeatTile>(find.byType(SeatTile)).toList();
    expect(tiles, hasLength(47));
    expect(tiles.every((tile) => tile.readOnly), isTrue);
    await tester.tap(seat);
    await tester.pumpAndSettle();
    expect(details.state.selectedSession!.bookedSeats, {9, 18});
    expect(find.textContaining('Confirm'), findsNothing);
    final repository = services<ShowsRepository>() as DemoCustomerRepository;
    await repository.confirm(
      BookingRequest(
        bookingId: 'vendor-journey-customer-booking',
        customerUid: DemoCustomerRepository.customerUid,
        showId: 'demo-success',
        sessionId: '1900',
        seats: [1, 47],
      ),
    );
    await tester.pumpAndSettle();
    expect(details.state.selectedSession!.bookedSeats, {1, 9, 18, 47});
    expect(details.state.show!.bookedCount, 5);
    expect(list.state.shows.first.bookedCount, 5);
    await tester.tap(find.byTooltip('Back to My shows'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    expect(details.isClosed, isTrue);
    expect(list.isClosed, isFalse);
    expect(find.byType(VendorShowsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    expect(list.isClosed, isTrue);
  });

  testWidgets(
    'enrolled Vendor gate starts notifications on My shows before visiting Updates and resets GetIt only at root',
    (tester) async {
      final showsRepo = FakeShowsRepository();
      showsRepo.shows['show-1'] = Show(
        id: 'show-1',
        vendorId: 'vendor-a',
        title: 'Finals Night',
        description: 'Championship match',
        showDate: '2026-12-20',
        imageId: 'show-1',
        status: ShowStatus.active,
        bookedCount: 2,
        lastBookingId: 'b1',
        createdAt: DateTime.utc(2026, 11, 20),
        updatedAt: DateTime.utc(2026, 11, 20),
      );
      showsRepo.sessions['show-1'] = <Session>[
        Session(
          id: '1900',
          time: SessionTime('19:00'),
          bookedSeats: const <int>{1, 2},
          lastBookingId: 'b1',
        ),
      ];

      final eventsRepo = _StreamingBookingEventsRepository();
      addTearDown(eventsRepo.dispose);
      final alertPresenter = _RecordingAlertPresenter();
      final accessRepo = _SequenceVendorAccessRepository(<VendorAccess>[
        VendorNotEnrolled(uid: 'anon-device-1'),
        VendorAllowed(uid: 'anon-device-1', vendorId: 'vendor-a'),
      ]);

      final services = GetIt.asNewInstance();
      registerVendorAccess(services, repository: accessRepo);
      services.registerSingleton<ShowsRepository>(
        showsRepo,
        dispose: (repo) => repo.dispose(),
      );
      services.registerSingleton<BookingEventsRepository>(eventsRepo);
      services.registerSingleton<WatermarkStore>(InMemoryWatermarkStore());
      services.registerSingleton<LocalAlertPresenter>(alertPresenter);
      registerVendorEnrolledJourney(
        services,
        posterPicker: (_) async => Uint8List(0),
        recoverPoster: () async => null,
      );

      await tester.pumpWidget(VendorEnrolledApp(services: services));
      await tester.pumpAndSettle();

      // Before enrollment: not enrolled screen visible, notifications inactive.
      expect(find.byType(VendorNotEnrolledScreen), findsOneWidget);
      expect(find.text('anon-device-1'), findsOneWidget);
      expect(eventsRepo.watchCalls, 0);

      final accessCubit = tester
          .element(find.byType(VendorNotEnrolledScreen))
          .read<VendorAccessCubit>();

      // Retry enrolls and unlocks My shows with live notifications active immediately.
      await tester.tap(
        find.byKey(const ValueKey<String>('vendor-access-retry-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VendorShowsScreen), findsOneWidget);
      expect(eventsRepo.watchCalls, 1);

      final notificationsCubit = tester
          .element(find.byType(VendorShowsScreen))
          .read<VendorNotificationsCubit>();
      final showsCubit = tester
          .element(find.byType(VendorShowsScreen))
          .read<VendorShowsCubit>();

      // Initial server empty snapshot seeds watermark, then live event alerts on My shows.
      eventsRepo.controller.add(const <BookingEvent>[]);
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Booking updates'), findsOneWidget);

      eventsRepo.controller.add(<BookingEvent>[
        BookingEvent(
          bookingId: 'b1',
          vendorId: 'vendor-a',
          showId: 'show-1',
          sessionId: '1900',
          seats: const <int>[1, 2],
          showTitle: 'Finals Night',
          slotTime: SessionTime('19:00'),
          slotTotal: 2,
          showTotal: 2,
          createdAt: DateTime.utc(2026, 11, 21, 10, 0),
        ),
      ]);
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(alertPresenter.shownAlerts.map((a) => a.bookingId), <String>[
        'b1',
      ]);
      expect(find.text('Booking updates (1)'), findsOneWidget);
      expect(services.isRegistered<ShowsRepository>(), isTrue);

      // Visiting /updates reuses the same ancestor VendorNotificationsCubit.
      await tester.tap(
        find.byKey(const ValueKey<String>('vendor-shows-open-updates-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VendorUpdatesScreen), findsOneWidget);
      expect(eventsRepo.watchCalls, 1);
      expect(
        tester
            .element(find.byType(VendorUpdatesScreen))
            .read<VendorNotificationsCubit>(),
        same(notificationsCubit),
      );

      // Tapping event marks read and opens show details; GetIt remains open.
      await tester.tap(
        find.byKey(const ValueKey<String>('vendor-update-card-b1')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VendorShowDetailsScreen), findsOneWidget);
      expect(notificationsCubit.state.unreadCount, 0);
      expect(showsRepo.disposed, isFalse);

      // Returning to My shows keeps unread count cleared.
      await tester.tap(find.byTooltip('Back to My shows'));
      await tester.pumpAndSettle();
      expect(find.byType(VendorShowsScreen), findsOneWidget);
      expect(find.text('Booking updates'), findsOneWidget);

      // Disposing root VendorEnrolledApp closes Cubits and resets GetIt once.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      expect(accessCubit.isClosed, isTrue);
      expect(notificationsCubit.isClosed, isTrue);
      expect(showsCubit.isClosed, isTrue);
      expect(showsRepo.disposed, isTrue);
      expect(services.isRegistered<ShowsRepository>(), isFalse);
    },
  );
}

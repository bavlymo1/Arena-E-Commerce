import 'dart:async';

import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/booking_events_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/screens/vendor_updates_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

BookingEvent _event({
  required String id,
  String title = 'Apex Finals',
  String slot = '19:00',
  Iterable<int> seats = const <int>[1],
  int slotTotal = 1,
  int showTotal = 1,
  DateTime? createdAt,
}) {
  final parsedSlot = SessionTime(slot);
  return BookingEvent(
    bookingId: id,
    vendorId: 'vendor-a',
    showId: 'show-1',
    sessionId: parsedSlot.id,
    seats: seats,
    showTitle: title,
    slotTime: parsedSlot,
    slotTotal: slotTotal,
    showTotal: showTotal,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 20, 12, 0),
  );
}

final class _ControllableEventsRepository implements BookingEventsRepository {
  StreamController<List<BookingEvent>> controller =
      StreamController<List<BookingEvent>>();

  @override
  Stream<List<BookingEvent>> watchEvents(String vendorId) => controller.stream;

  Future<void> resetForRetry() async {
    await controller.close();
    controller = StreamController<List<BookingEvent>>();
  }

  void dispose() {
    unawaited(controller.close());
  }
}

Widget _buildApp(
  VendorNotificationsCubit cubit, {
  Brightness brightness = Brightness.light,
  VoidCallback? onBackToShows,
  ValueChanged<BookingEvent>? onEventSelected,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffd52f65),
        brightness: brightness,
      ),
    ),
    home: BlocProvider<VendorNotificationsCubit>.value(
      value: cubit,
      child: VendorUpdatesScreen(
        onBackToShows: onBackToShows,
        onEventSelected: onEventSelected,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'displays loading, error+retry, empty state, live unread booking totals, and callbacks',
    (tester) async {
      final repo = _ControllableEventsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorNotificationsCubit(repo, vendorId: 'vendor-a');
      final opened = <String>[];
      var backTapped = 0;

      try {
        await tester.pumpWidget(
          _buildApp(
            cubit,
            onBackToShows: () => backTapped++,
            onEventSelected: (event) => opened.add(event.id),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('vendor-updates-loading')),
          findsOneWidget,
        );

        repo.controller.addError(StateError('offline'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vendor-updates-error-state')),
          findsOneWidget,
        );

        await repo.resetForRetry();
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-updates-retry-button')),
        );
        await tester.pump();

        repo.controller.add(const <BookingEvent>[]);
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vendor-updates-empty-state')),
          findsOneWidget,
        );
        expect(find.text('No updates yet'), findsOneWidget);
        expect(
          find.text('Confirmed bookings will appear here.'),
          findsOneWidget,
        );

        // First live booking arrives after empty launch.
        repo.controller.add(<BookingEvent>[
          _event(
            id: 'b1',
            title: 'Skyline Jam',
            slot: '14:00',
            seats: const <int>[2, 5],
            slotTotal: 2,
            showTotal: 6,
            createdAt: DateTime.utc(2026, 11, 20, 14, 0),
          ),
        ]);
        await tester.pump();

        expect(find.text('Skyline Jam'), findsOneWidget);
        expect(find.text('2:00 PM'), findsOneWidget);
        expect(find.text('Seats 2, 5 booked'), findsOneWidget);
        expect(find.text('Session 2 / 47 booked'), findsOneWidget);
        expect(find.text('Show total: 6 booked'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('vendor-update-unread-b1')),
          findsOneWidget,
        );
        expect(find.text('1 unread'), findsOneWidget);

        expect(
          find.bySemanticsLabel(
            RegExp('Skyline Jam.*Session 2 / 47 booked.*Show total: 6 booked'),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-update-card-b1')),
        );
        await tester.pump();
        expect(opened, <String>['b1']);
        expect(cubit.state.unreadCount, 0);

        // Stream error while populated shows inline banner + retry without dropping cards.
        repo.controller.addError(StateError('transient'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vendor-updates-inline-error')),
          findsOneWidget,
        );
        expect(find.text('Skyline Jam'), findsOneWidget);

        await repo.resetForRetry();
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-updates-inline-retry-button'),
          ),
        );
        await tester.pump();
        repo.controller.add(<BookingEvent>[
          _event(
            id: 'b2',
            title: 'Neon Arena',
            slot: '19:00',
            seats: const <int>[9],
            slotTotal: 1,
            showTotal: 1,
            createdAt: DateTime.utc(2026, 11, 20, 15, 0),
          ),
          _event(
            id: 'b1',
            title: 'Skyline Jam',
            slot: '14:00',
            seats: const <int>[2, 5],
            slotTotal: 2,
            showTotal: 6,
            createdAt: DateTime.utc(2026, 11, 20, 14, 0),
          ),
        ]);
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('vendor-updates-inline-error')),
          findsNothing,
        );
        expect(find.text('Seat 9 booked'), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey<String>('vendor-updates-mark-all-read-button'),
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-updates-mark-all-read-button'),
          ),
        );
        await tester.pump();
        expect(cubit.state.unreadCount, 0);

        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-updates-back-button')),
        );
        await tester.pump();
        expect(backTapped, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'renders without overflow on dark narrow 300x640 viewport at 2.0x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _ControllableEventsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorNotificationsCubit(repo, vendorId: 'vendor-a');

      try {
        repo.controller.add(const <BookingEvent>[]);
        await tester.pumpWidget(_buildApp(cubit, brightness: Brightness.dark));
        await tester.pump();

        repo.controller.add(<BookingEvent>[
          _event(
            id: 'b-long',
            title: 'World Championship Grand Finals Championship',
            slot: '19:00',
            seats: const <int>[1, 2, 3, 4, 5],
            slotTotal: 25,
            showTotal: 112,
            createdAt: DateTime.utc(2026, 11, 20, 19, 30),
          ),
        ]);
        await tester.pump();

        await tester.scrollUntilVisible(
          find.text('Show total: 112 booked'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Show total: 112 booked'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );
}

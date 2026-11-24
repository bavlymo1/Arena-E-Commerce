import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/app/customer/customer_app.dart';
import 'package:e_commerce_project/features/booking/data/repositories/firestore_booking_repository.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/domain/repositories/booking_repository.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/booking_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/screens/booking_result_screen.dart';
import 'package:e_commerce_project/features/vendor_access/data/repositories/firebase_vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/data/repositories/firestore_shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/shared/seating/seat_layout.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_tile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/vendor_demo_app.dart';
import 'support/emulator_support.dart';
import 'support/poster_fixture.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> scrollAndWaitFor(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable);
  for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
    if (i % 5 == 0 && scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -250));
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Finder tile(int seat, SeatVisualStatus status) => find.byWidgetPredicate(
  (w) => w is SeatTile && w.seatNumber == seat && w.status == status,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'local Customer booking persists, Vendor sees it, and two Customers contend atomically',
    (tester) async {
      final graph = await createLocalCustomerServices();
      final a = graph<BookingRepository>();
      final tag = DateTime.now().microsecondsSinceEpoch.toString();
      final auth = FirebaseAuth.instance;
      final alice = (await auth.createUserWithEmailAndPassword(
        email: 'alice-$tag@example.test',
        password: 'Local-demo-47',
      )).user!.uid;
      final (bobAuth, bobDb) = await createNamedEmulatorClient('bob-$tag');
      final bob = (await bobAuth.createUserWithEmailAndPassword(
        email: 'bob-$tag@example.test',
        password: 'Local-demo-47',
      )).user!.uid;
      final b = FirestoreBookingRepository(
        bobDb,
        bobAuth,
        FirestoreShowsRepository(bobDb),
      );
      final (vendorAuth, vendorDb) = await createNamedEmulatorClient(
        'vendor-$tag',
      );
      final vendorUid = (await vendorAuth.signInAnonymously()).user!.uid;
      final vendorId = 'vendor-$tag';
      await enrollVendorDeviceOnEmulator(vendorUid, vendorId);
      final shows = FirestoreShowsRepository(
        vendorDb,
        vendorAccess: FirebaseVendorAccessRepository(vendorAuth, vendorDb),
      );
      final title = 'Booking arena $tag';
      final posterBytes = loadFixturePosterBytes();
      await shows.addShow(
        NewShow(
          vendorId: vendorId,
          title: title,
          description: 'Booking integration',
          showDate: '2026-12-20',
          sessions: [SessionTime('19:00')],
        ),
        posterBytes,
      );
      final show =
          (await shows
                  .watchVendorShows(vendorId)
                  .firstWhere((s) => s.isNotEmpty))
              .single;
      final chip = find.byKey(const ValueKey('session-chip-1900'));
      await tester.pumpWidget(createCustomerApp(services: graph));
      await tap(tester, find.text(title));
      await tap(tester, chip);
      await tap(tester, tile(1, SeatVisualStatus.available));
      await tap(tester, find.text('Confirm 1 seats'));
      await waitFor(tester, find.text('Booking confirmed'));
      await tap(tester, find.text('Back to details'));
      await tap(tester, chip);
      await waitFor(tester, tile(1, SeatVisualStatus.mineConfirmed));
      final mine = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerUid', isEqualTo: alice)
          .get(const GetOptions(source: Source.server));
      final reference = mine.docs.single.id;
      expect(
        await a.recover(bookingId: reference, customerUid: alice),
        isA<RecoveryConfirmed>(),
      );
      expect(
        await b.recover(bookingId: reference, customerUid: bob),
        isA<RecoveryUnresolved>(),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final vendorGraph = GetIt.asNewInstance()
        ..registerSingleton<ShowsRepository>(shows);
      registerVendorJourney(vendorGraph, vendorId: vendorId);
      await tester.pumpWidget(VendorDemoApp(services: vendorGraph));
      await tap(tester, find.text(title));
      await scrollAndWaitFor(tester, tile(1, SeatVisualStatus.bookedByOther));
      expect(
        tester
            .widget<SeatTile>(tile(1, SeatVisualStatus.bookedByOther))
            .readOnly,
        isTrue,
      );

      BookingRequest request(String uid, int seat, String label) =>
          BookingRequest(
            bookingId: '$tag-$label',
            customerUid: uid,
            showId: show.id,
            sessionId: '1900',
            seats: [seat],
          );
      final replay = BookingRequest(
        bookingId: reference,
        customerUid: alice,
        showId: show.id,
        sessionId: '1900',
        seats: [1],
      );
      expect(await a.confirm(replay), isA<BookingConfirmed>());
      final mismatchedReplay = BookingRequest(
        bookingId: reference,
        customerUid: alice,
        showId: show.id,
        sessionId: '1900',
        seats: [47],
      );
      expect(await a.confirm(mismatchedReplay), isA<BookingUnconfirmed>());
      expect(await b.confirm(replay), isA<BookingUnconfirmed>());
      final contestants = [
        for (final (repo, uid, label) in [(a, alice, 'a2'), (b, bob, 'b2')])
          BookingCubit(
            repository: repo,
            customerUid: uid,
            showId: show.id,
            sessionId: '1900',
            newBookingId: () => '$tag-$label',
          ),
      ];
      await Future.wait(contestants.map((cubit) => cubit.submit({2})));
      final winner = contestants.singleWhere(
        (c) => c.state.phase == BookingPhase.confirmed,
      );
      final loser = contestants.singleWhere(
        (c) => c.state.phase == BookingPhase.conflict,
      );
      final lost = loser.state.request!;
      expect(loser.state.conflicts, {2});
      expect(
        await (lost.customerUid == alice ? a : b).recover(
          bookingId: lost.bookingId,
          customerUid: lost.customerUid,
        ),
        isA<RecoveryAuthoritativelyAbsent>(),
      );
      final distinct = await Future.wait([
        a.confirm(request(alice, 3, 'a3')),
        b.confirm(request(bob, 4, 'b4')),
      ]);
      expect(
        distinct.whereType<BookingConfirmed>(),
        hasLength(2),
        reason: '$distinct',
      );
      final events = await vendorDb
          .collection('bookingEvents')
          .where('vendorId', isEqualTo: vendorId)
          .get(const GetOptions(source: Source.server));
      expect(
        events.docs.map((d) => d['slotTotal']),
        unorderedEquals([1, 2, 3, 4]),
      );
      expect(
        events.docs.every((d) => d['slotTotal'] == d['showTotal']),
        isTrue,
      );
      expect(
        events.docs.map((d) => d.id),
        unorderedEquals([
          reference,
          winner.state.request!.bookingId,
          '$tag-a3',
          '$tag-b4',
        ]),
      );
      expect(
        (await vendorDb
            .doc('shows/${show.id}')
            .get(const GetOptions(source: Source.server)))['bookedCount'],
        4,
      );
      for (final seat in [1, 2, 3, 4]) {
        await waitFor(tester, tile(seat, SeatVisualStatus.bookedByOther));
        expect(
          tester
              .widget<SeatTile>(tile(seat, SeatVisualStatus.bookedByOther))
              .readOnly,
          isTrue,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: loser,
            child: BookingResultScreen(
              bookingId: lost.bookingId,
              onDetails: () {},
              onReviewMap: () {},
            ),
          ),
        ),
      );
      await waitFor(tester, find.text('Not booked'));
      expect(find.text('Conflicting seats: 2'), findsOneWidget);
      expect(find.text('Review seat map'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final c in contestants) {
        await c.close();
      }
      await auth.signOut();
      await bobAuth.signOut();
      await vendorAuth.signOut();
    },
  );
}

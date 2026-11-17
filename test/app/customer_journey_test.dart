import 'package:e_commerce_project/app/customer/customer_journey_app.dart';
import 'package:e_commerce_project/app/customer/demo_customer_repository.dart';
import 'package:e_commerce_project/app/di/customer_journey_registration.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/booking_cubit.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/screens/seat_selection_screen.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // These two buttons are route test fixtures, not discovery/details screens.
  Future<void> mount(WidgetTester tester, String showId) async {
    await tester.pumpWidget(
      CustomerJourneyApp(
        services: createDemoCustomerServices(),
        discoverBuilder: (_, onShow) => Scaffold(
          body: TextButton(
            onPressed: () => onShow(showId),
            child: const Text('Open fixture'),
          ),
        ),
        detailsBuilder: (_, id, onSession) => Scaffold(
          body: TextButton(
            onPressed: () => onSession('1900'),
            child: Text('Fixture details $id'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture details $showId'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'seating/result routes retain their Cubits and show confirmed own seats',
    (tester) async {
      await mount(tester, 'demo-success');
      final context = tester.element(find.byType(SeatSelectionScreen));
      final selection = context.read<SeatSelectionCubit>();
      final booking = context.read<BookingCubit>();
      final tile = find.byWidgetPredicate(
        (w) => w is SeatTile && w.seatNumber == 1,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(selection.state.selectedSeats, {1});
      await tester.ensureVisible(find.text('Confirm 1 seats'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm 1 seats'));
      await tester.pumpAndSettle();
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Seats: 1'), findsOneWidget);
      expect(selection.isClosed, isFalse);
      expect(booking.isClosed, isFalse);
      expect(selection.state.myConfirmedSeats, {1});
      await tester.tap(find.text('Back to details'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      expect(selection.isClosed, isTrue);
      expect(booking.isClosed, isTrue);
      await unmount(tester);
    },
  );

  for (final scenario in ['demo-conflict', 'demo-uncertain']) {
    testWidgets(
      '$scenario preserves outcome and permits only the appropriate next action',
      (tester) async {
        await mount(tester, scenario);
        final context = tester.element(find.byType(SeatSelectionScreen));
        final selection = context.read<SeatSelectionCubit>();
        final booking = context.read<BookingCubit>();
        selection.toggleSeat(1);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Confirm 1 seats'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm 1 seats'));
        await tester.pumpAndSettle();
        if (scenario == 'demo-uncertain') {
          expect(find.text('Confirmation unknown'), findsOneWidget);
          expect(find.text('Back to details'), findsNothing);
          final id = booking.state.request!.bookingId;
          final resultContext = tester.element(
            find.text('Confirmation unknown'),
          );
          GoRouter.of(resultContext)
              .go('/show/demo-uncertain/session/1900/result/wrong-reference');
          await tester.pumpAndSettle();
          expect(find.text('Reference: $id'), findsOneWidget);
          expect(find.text('Back to details'), findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Confirmation unknown'), findsOneWidget);
          await tester.tap(find.text('Check status'));
          await tester.pumpAndSettle();
          expect(booking.state.phase, BookingPhase.confirmed);
          expect(
            find.text('Reference unavailable in this session'),
            findsOneWidget,
          );
          GoRouter.of(
            tester.element(find.text('Reference unavailable in this session')),
          ).go('/show/demo-uncertain/session/1900/result/$id');
          await tester.pumpAndSettle();
          expect(find.text('Booking confirmed'), findsOneWidget);
          expect(booking.state.request!.bookingId, id);
        } else {
          expect(find.text('Not booked'), findsOneWidget);
          expect(booking.state.conflicts, {1});
          await tester.tap(find.text('Review seat map'));
          await tester.pumpAndSettle();
          expect(selection.state.selectedSeats, isEmpty);
          expect(selection.state.bookedSeats, contains(1));
          expect(booking.state.phase, BookingPhase.ready);
        }
        await unmount(tester);
      },
    );
  }

  for (final scenario in ['demo-sold-out', 'demo-unavailable']) {
    testWidgets('$scenario cannot submit', (tester) async {
      await mount(tester, scenario);
      final context = tester.element(find.byType(SeatSelectionScreen));
      final selection = context.read<SeatSelectionCubit>();
      expect(selection.state.canSubmit, isFalse);
      expect(
        scenario == 'demo-sold-out'
            ? selection.state.isSoldOut
            : selection.state.session == null,
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm 0 seats'),
            )
            .onPressed,
        isNull,
      );
      await unmount(tester);
    });
  }

  test(
    'demo ignores another UID and own-seat streams are fully scoped',
    () async {
      final demo = DemoCustomerRepository();
      final request = BookingRequest(
        bookingId: 'demo-booking',
        customerUid: DemoCustomerRepository.customerUid,
        showId: 'demo-success',
        sessionId: '1900',
        seats: {1, 2},
      );
      expect(await demo.confirm(request), isA<BookingConfirmed>());
      expect(
        await demo
            .watchMySeats(
              DemoCustomerRepository.customerUid,
              'demo-success',
              '1900',
            )
            .first,
        {1, 2},
      );
      expect(
        await demo.confirm(
          BookingRequest(
            bookingId: 'conflict',
            customerUid: DemoCustomerRepository.customerUid,
            showId: 'demo-success',
            sessionId: '1900',
            seats: {2, 3},
          ),
        ),
        isA<BookingConflict>(),
      );
      expect(
        await demo
            .watchMySeats(
              DemoCustomerRepository.customerUid,
              'demo-success',
              '1900',
            )
            .first,
        {1, 2},
      );
      expect(
        await demo.recover(bookingId: 'demo-booking', customerUid: 'other'),
        isA<RecoveryUnresolved>(),
      );
      expect(
        await demo
            .watchMySeats(
              DemoCustomerRepository.customerUid,
              'demo-conflict',
              '1900',
            )
            .first,
        isEmpty,
      );
      expect(
        await demo.watchMySeats('other', 'demo-success', '1900').first,
        isEmpty,
      );
      expect(
        await demo
            .watchMySeats(
              DemoCustomerRepository.customerUid,
              'demo-success',
              '2000',
            )
            .first,
        isEmpty,
      );
      demo.dispose();
    },
  );
}

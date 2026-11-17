import 'package:e_commerce_project/app/customer/customer_demo_app.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/booking_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/screens/seat_selection_screen.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/show_details_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:e_commerce_project/features/discovery/presentation/screens/show_details_screen.dart';
import 'package:e_commerce_project/shared/seating/seat_layout.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openShow(WidgetTester tester, String search, String title) async {
  await tester.enterText(find.byType(TextField), search);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(title));
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  expect(find.byType(ShowDetailsScreen), findsOneWidget);
}

Future<void> _openSession(WidgetTester tester, String sessionId) async {
  final session = find.byKey(ValueKey('session-chip-$sessionId'));
  await tester.ensureVisible(session);
  await tester.tap(session);
  await tester.pumpAndSettle();
  expect(find.byType(SeatSelectionScreen), findsOneWidget);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'complete journey preserves show/session and own seats across back navigation',
    (tester) async {
      await tester.pumpWidget(createCustomerDemoApp());
      await tester.pumpAndSettle();
      expect(find.textContaining('LOCAL DEMO'), findsOneWidget);
      final discovery = tester
          .element(find.byType(DiscoveryScreen))
          .read<DiscoveryCubit>();
      await _openShow(tester, 'Skyline', 'Skyline Jam');
      final details = tester
          .element(find.byType(ShowDetailsScreen))
          .read<ShowDetailsCubit>();
      expect(details.state.showId, 'demo-success');
      await _openSession(tester, '1900');
      final seatContext = tester.element(find.byType(SeatSelectionScreen));
      final selection = seatContext.read<SeatSelectionCubit>();
      final booking = seatContext.read<BookingCubit>();
      expect(selection.state.sessionId, '1900');
      await tester.tap(find.byKey(const ValueKey('seat-grid-1')));
      await tester.tap(find.byKey(const ValueKey('seat-grid-47')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm 2 seats'));
      await tester.pumpAndSettle();
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Seats: 1, 47'), findsOneWidget);
      final request = booking.state.request!;
      expect(request.showId, 'demo-success');
      expect(request.sessionId, '1900');
      expect(selection.isClosed, isFalse);
      await tester.tap(find.text('Back to details'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      expect(selection.isClosed, isTrue);
      expect(booking.isClosed, isTrue);
      expect(discovery.isClosed, isTrue);
      expect(details.isClosed, isTrue);
      expect(find.text('Skyline Jam'), findsOneWidget);
      await _openSession(tester, '1900');
      final own = tester
          .element(find.byType(SeatSelectionScreen))
          .read<SeatSelectionCubit>();
      expect(own.state.myConfirmedSeats, {1, 47});
      final tile = tester.widget<SeatTile>(
        find.byWidgetPredicate((w) => w is SeatTile && w.seatNumber == 1),
      );
      expect(tile.status, SeatVisualStatus.mineConfirmed);
      await tester.tap(find.byKey(const ValueKey('seat-grid-1')));
      await tester.pumpAndSettle();
      expect(own.state.selectedSeats, isEmpty);
      await tester.tap(find.byTooltip('Back to details'));
      await tester.pumpAndSettle();
      await _openSession(tester, '1400');
      final afternoon = tester
          .element(find.byType(SeatSelectionScreen))
          .read<SeatSelectionCubit>();
      expect(afternoon.state.showId, 'demo-success');
      expect(afternoon.state.sessionId, '1400');
      expect(afternoon.state.myConfirmedSeats, isEmpty);
      expect(afternoon.state.bookedSeats, {7});
      await tester.tap(find.byTooltip('Back to details'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      await _openShow(tester, 'Kingdom', 'Kingdom Clash · conflict demo');
      await _openSession(tester, '1900');
      expect(
        tester
            .element(find.byType(SeatSelectionScreen))
            .read<SeatSelectionCubit>()
            .state
            .myConfirmedSeats,
        isEmpty,
      );
      await _unmount(tester);
    },
  );

  for (final scenario in [
    ('Kingdom', 'Kingdom Clash · conflict demo', false),
    ('Midnight', 'Midnight Drift · lost response demo', true),
  ]) {
    testWidgets(
      'full ${scenario.$1} journey preserves conflict or unknown recovery',
      (tester) async {
        await tester.pumpWidget(createCustomerDemoApp());
        await tester.pumpAndSettle();
        await _openShow(tester, scenario.$1, scenario.$2);
        await _openSession(tester, '1900');
        final context = tester.element(find.byType(SeatSelectionScreen));
        final selection = context.read<SeatSelectionCubit>();
        final booking = context.read<BookingCubit>();
        await tester.tap(find.byKey(const ValueKey('seat-grid-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm 1 seats'));
        await tester.pumpAndSettle();
        if (scenario.$3) {
          expect(find.text('Confirmation unknown'), findsOneWidget);
          final id = booking.state.request!.bookingId;
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Confirmation unknown'), findsOneWidget);
          await tester.tap(find.text('Check status'));
          await tester.pumpAndSettle();
          expect(find.text('Booking confirmed'), findsOneWidget);
          expect(booking.state.request!.bookingId, id);
          await tester.tap(find.text('Back to details'));
          await tester.pumpAndSettle();
          expect(find.text(scenario.$2), findsOneWidget);
        } else {
          expect(find.text('Not booked'), findsOneWidget);
          await tester.tap(find.text('Review seat map'));
          await tester.pumpAndSettle();
          expect(selection.state.bookedSeats, contains(1));
          expect(selection.state.myConfirmedSeats, isEmpty);
          expect(selection.state.selectedSeats, isEmpty);
        }
        await _unmount(tester);
      },
    );
  }

  testWidgets(
    'full sold-out and unavailable journeys never enable confirmation',
    (tester) async {
      await tester.pumpWidget(createCustomerDemoApp());
      await tester.pumpAndSettle();
      await _openShow(tester, 'Overclock', 'Overclock Cup · sold out demo');
      expect(find.text('Sold out'), findsWidgets);
      await tester.ensureVisible(
        find.byKey(const ValueKey('session-chip-1900')),
      );
      await tester.tap(find.byKey(const ValueKey('session-chip-1900')));
      await tester.pumpAndSettle();
      expect(find.byType(SeatSelectionScreen), findsNothing);
      await tester.tap(find.byTooltip('Back to Discover'));
      await tester.pumpAndSettle();
      await _openShow(tester, 'Hellfire', 'Hellfire Moto · unavailable demo');
      await _openSession(tester, '1900');
      expect(find.text('Show unavailable'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm 0 seats'),
            )
            .onPressed,
        isNull,
      );
      await _unmount(tester);
    },
  );
}

import 'dart:ui' show SemanticsAction;

import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_state.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/shared/seating/seat_layout.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_legend.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_map_view.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_tile.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_booking_repository.dart';

Widget _wrap(
  Widget child, {
  Size size = const Size(390, 812),
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders all 47 seats with aisles on rows 1-4 only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SeatMapView(
          bookedSeats: {14, 21},
          myConfirmedSeats: {14},
          selectedSeats: {5},
        ),
      ),
    );

    for (var seat = 1; seat <= 47; seat++) {
      expect(find.byKey(ValueKey<String>('seat-grid-$seat')), findsOneWidget);
    }
    for (var row = 1; row <= 4; row++) {
      expect(
        find.byKey(ValueKey<String>('seat-aisle-row-$row')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('seat-aisle-row-5')),
      findsNothing,
    );
    expect(find.text('14✓'), findsOneWidget);
    expect(find.text('2 / 47'), findsOneWidget);
    expect(find.text('5'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'single tap toggles available seat immediately without zoom gate',
    (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        _wrap(
          SeatMapView(
            bookedSeats: const {14, 21},
            myConfirmedSeats: const {14},
            selectedSeats: const {15},
            onSeatTap: tapped.add,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('seat-grid-1')));
      await tester.tap(find.byKey(const ValueKey<String>('seat-grid-15')));
      await tester.tap(find.byKey(const ValueKey<String>('seat-grid-14')));
      await tester.tap(find.byKey(const ValueKey<String>('seat-grid-21')));
      await tester.pump();

      expect(tapped, [1, 15]);
    },
  );

  testWidgets('vendor mode is read-only and hides customer legend/selection', (
    tester,
  ) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      _wrap(
        SeatMapView(
          bookedSeats: const {14, 21},
          myConfirmedSeats: const {14},
          selectedSeats: const {15},
          vendorMode: true,
          onSeatTap: tapped.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('seat-grid-1')));
    await tester.pump();

    expect(tapped, isEmpty);
    expect(
      find.descendant(
        of: find.byType(SeatLegend),
        matching: find.text('Available'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SeatLegend),
        matching: find.text('Booked'),
      ),
      findsOneWidget,
    );
    expect(find.text('Selected'), findsNothing);
    expect(find.text('Yours'), findsNothing);
    expect(find.text('Selected seats'), findsNothing);
    expect(find.text('14✓'), findsNothing);
  });

  testWidgets(
    'fitted map and row list stay within narrow width with large text',
    (tester) async {
      tester.view.physicalSize = const Size(280, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tapped = <int>[];
      await tester.pumpWidget(
        _wrap(
          SeatMapView(bookedSeats: const {38}, onSeatTap: tapped.add),
          size: const Size(280, 640),
          textScale: 1.8,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(SeatMapView)))
            .scale(10),
        18,
      );
      for (var seat = 1; seat <= 47; seat++) {
        final bounds = tester.getRect(
          find.byKey(ValueKey<String>('seat-grid-$seat')),
        );
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(280));
      }

      expect(
        find.byKey(const ValueKey<String>('seat-map-fit-box')),
        findsOneWidget,
      );
      expect(find.text('Enlarge map'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SeatMapView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal,
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      final modeToggle = find.byKey(const ValueKey<String>('seat-mode-toggle'));
      await tester.ensureVisible(modeToggle);
      await tester.tap(modeToggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('row-list-seats-1')),
        findsOneWidget,
      );

      final rowTab5 = find.byKey(const ValueKey<String>('row-tab-5'));
      await tester.ensureVisible(rowTab5);
      await tester.tap(rowTab5);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('row-list-seats-5')),
        findsOneWidget,
      );
      for (var seat = 37; seat <= 47; seat++) {
        expect(find.byKey(ValueKey<String>('seat-list-$seat')), findsOneWidget);
      }

      final seat47 = find.byKey(const ValueKey<String>('seat-list-47'));
      await tester.ensureVisible(seat47);
      await tester.tap(seat47);
      final seat38 = find.byKey(const ValueKey<String>('seat-list-38'));
      await tester.ensureVisible(seat38);
      await tester.tap(seat38);
      await tester.pump();

      expect(tapped, [47]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('semantic taps honor the same seat interaction guards', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final tapped = <int>[];
    await tester.pumpWidget(
      _wrap(
        Row(
          children: [
            SeatTile(
              seatNumber: 1,
              status: SeatVisualStatus.available,
              onTap: tapped.add,
            ),
            SeatTile(
              seatNumber: 2,
              status: SeatVisualStatus.selected,
              onTap: tapped.add,
            ),
            SeatTile(
              seatNumber: 3,
              status: SeatVisualStatus.bookedByOther,
              onTap: tapped.add,
            ),
            SeatTile(
              seatNumber: 4,
              status: SeatVisualStatus.mineConfirmed,
              onTap: tapped.add,
            ),
            SeatTile(
              seatNumber: 5,
              status: SeatVisualStatus.available,
              readOnly: true,
              onTap: tapped.add,
            ),
            SeatTile(
              seatNumber: 6,
              status: SeatVisualStatus.available,
              busy: true,
              onTap: tapped.add,
            ),
          ],
        ),
      ),
    );

    for (var seat = 1; seat <= 6; seat++) {
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Seat $seat, row 1,')),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), seat <= 2);
      node.owner!.performAction(node.id, SemanticsAction.tap);
    }
    await tester.pump();
    expect(tapped, [1, 2]);
    handle.dispose();
  });

  testWidgets('exposes semantics labels and state colors', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        const SeatMapView(
          bookedSeats: {14, 21},
          myConfirmedSeats: {14},
          selectedSeats: {5},
        ),
      ),
    );

    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Seat 1, row 1, Available'))
          .label,
      'Seat 1, row 1, Available',
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Seat 5, row 1, Selected'))
          .label,
      'Seat 5, row 1, Selected',
    );
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel('Seat 14, row 2, Your confirmed seat'),
          )
          .label,
      'Seat 14, row 2, Your confirmed seat',
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Seat 21, row 3, Booked'))
          .label,
      'Seat 21, row 3, Booked',
    );

    final availableMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey<String>('seat-grid-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    final bookedMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey<String>('seat-grid-21')),
            matching: find.byType(Material),
          )
          .first,
    );
    final selectedMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey<String>('seat-grid-5')),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(availableMaterial.color, SeatColors.availableFill);
    expect(bookedMaterial.color, SeatColors.bookedFill);
    expect(selectedMaterial.color, SeatColors.greenFill);
    semanticsHandle.dispose();
  });

  testWidgets(
    'renders loading, unavailable, error, busy, conflict and sold-out states',
    (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(const SeatMapView(loadState: SeatMapLoadState.loading)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        _wrap(const SeatMapView(loadState: SeatMapLoadState.unavailable)),
      );
      expect(find.text('Show unavailable'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          SeatMapView(
            loadState: SeatMapLoadState.error,
            onRetry: () => retried = true,
          ),
        ),
      );
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);

      final tappedWhileBusy = <int>[];
      await tester.pumpWidget(
        _wrap(
          SeatMapView(
            bookedSeats: SeatLayout.allSeats.toSet(),
            busy: true,
            conflictMessage: 'Seat 12 was just booked by another customer.',
            onSeatTap: tappedWhileBusy.add,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('seat-busy-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('seat-conflict-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('seat-sold-out-banner')),
        findsOneWidget,
      );
      expect(find.text('47 / 47'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('seat-grid-1')));
      expect(tappedWhileBusy, isEmpty);
    },
  );

  testWidgets('seatSelectorBuilder rebuilds only toggled seat tile', (
    tester,
  ) async {
    final fake = FakeBookingRepository();
    fake.sessions[('show-1', '1900')] = Session(
      id: '1900',
      time: SessionTime('19:00'),
    );
    final cubit = SeatSelectionCubit(
      bookingRepository: fake,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    try {
      final buildsPerSeat = <int, int>{};

      await tester.pumpWidget(
        _wrap(
          BlocProvider<SeatSelectionCubit>.value(
            value: cubit,
            child: BlocBuilder<SeatSelectionCubit, SeatSelectionState>(
              buildWhen: (prev, curr) =>
                  prev.status != curr.status ||
                  !setEquals(prev.bookedSeats, curr.bookedSeats) ||
                  !setEquals(prev.myConfirmedSeats, curr.myConfirmedSeats) ||
                  prev.conflictMessage != curr.conflictMessage ||
                  prev.submitting != curr.submitting,
              builder: (context, state) {
                if (state.status == SeatSelectionStatus.loading) {
                  return const SeatMapView(loadState: SeatMapLoadState.loading);
                }
                return SeatMapView(
                  bookedSeats: state.bookedSeats,
                  myConfirmedSeats: state.myConfirmedSeats,
                  busy: state.submitting,
                  onSeatTap: cubit.toggleSeat,
                  seatSelectorBuilder: (context, seatNumber, buildTile) {
                    return BlocSelector<
                      SeatSelectionCubit,
                      SeatSelectionState,
                      (SeatVisualStatus, bool)
                    >(
                      selector: (s) =>
                          (s.visualStatusFor(seatNumber), s.submitting),
                      builder: (context, tuple) {
                        buildsPerSeat[seatNumber] =
                            (buildsPerSeat[seatNumber] ?? 0) + 1;
                        return buildTile(context, tuple.$1, tuple.$2);
                      },
                    );
                  },
                  selectedSummaryBuilder: (context) {
                    return BlocSelector<
                      SeatSelectionCubit,
                      SeatSelectionState,
                      Set<int>
                    >(
                      selector: (s) => s.selectedSeats,
                      builder: (context, selected) {
                        final sorted = selected.toList()..sort();
                        return Text(
                          sorted.isEmpty ? 'None' : sorted.join(', '),
                          key: const ValueKey<String>('seat-selected-summary'),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final seat1BuildsBefore = buildsPerSeat[1] ?? 0;
      final seat2BuildsBefore = buildsPerSeat[2] ?? 0;
      expect(seat1BuildsBefore, 1);
      expect(seat2BuildsBefore, 1);

      await tester.tap(find.byKey(const ValueKey<String>('seat-grid-1')));
      await tester.pump();

      expect(buildsPerSeat[1], seat1BuildsBefore + 1);
      expect(buildsPerSeat[2], seat2BuildsBefore);
      expect(cubit.state.selectedSeats, {1});
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('seat-selected-summary')),
            )
            .data,
        '1',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      // Stream cancellation must finish outside the widget's fake async clock.
      await tester.runAsync(cubit.close);
    }
  });
}

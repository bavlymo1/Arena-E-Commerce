import 'dart:async';

import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/domain/repositories/booking_repository.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/booking_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/screens/booking_result_screen.dart';
import 'package:e_commerce_project/features/booking/presentation/screens/seat_selection_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ControllableBookingRepository implements BookingRepository {
  StreamController<Session?> sessionController =
      StreamController<Session?>.broadcast();
  StreamController<Set<int>> mySeatsController =
      StreamController<Set<int>>.broadcast();
  Future<BookingResult> Function(BookingRequest request)? onConfirm;
  Future<BookingRecovery> Function({
    required String bookingId,
    required String customerUid,
  })?
  onRecover;

  @override
  Stream<Session?> watchSession(String showId, String sessionId) =>
      sessionController.stream;

  @override
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId) =>
      mySeatsController.stream;

  @override
  Future<BookingResult> confirm(BookingRequest request) => onConfirm != null
      ? onConfirm!(request)
      : Future<BookingResult>.value(BookingConfirmed(request));

  @override
  Future<BookingRecovery> recover({
    required String bookingId,
    required String customerUid,
  }) => onRecover != null
      ? onRecover!(bookingId: bookingId, customerUid: customerUid)
      : Future<BookingRecovery>.value(
          RecoveryUnresolved(
            bookingId: bookingId,
            customerUid: customerUid,
            reason: 'Unresolved',
          ),
        );

  Future<void> dispose() async {
    await sessionController.close();
    await mySeatsController.close();
  }
}

Widget _wrapBooking({
  required SeatSelectionCubit selectionCubit,
  required BookingCubit bookingCubit,
  required Widget child,
  ThemeData? theme,
  Size size = const Size(390, 812),
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      theme: theme ?? buildAppTheme(),
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<SeatSelectionCubit>.value(value: selectionCubit),
          BlocProvider<BookingCubit>.value(value: bookingCubit),
        ],
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'SeatSelectionScreen renders session banner, handles single-tap selection, live conflict, and submit',
    (tester) async {
      final repo = _ControllableBookingRepository();
      addTearDown(repo.dispose);
      final confirmGate = Completer<BookingResult>();
      repo.onConfirm = (_) => confirmGate.future;

      final selection = SeatSelectionCubit(
        bookingRepository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
      );
      final booking = BookingCubit(
        repository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
        newBookingId: () => 'ref-100',
      );
      final results = <String>[];
      var detailsTaps = 0;

      try {
        await tester.pumpWidget(
          _wrapBooking(
            selectionCubit: selection,
            bookingCubit: booking,
            child: SeatSelectionScreen(
              onResult: results.add,
              onDetails: () => detailsTaps++,
            ),
          ),
        );
        await tester.pump();

        repo.sessionController.add(
          Session(
            id: '1900',
            time: SessionTime('19:00'),
            label: 'Evening',
            bookedSeats: const <int>{21},
          ),
        );
        repo.mySeatsController.add(const <int>{14});
        await tester.pumpAndSettle();

        expect(find.text('Choose your seats'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('seat-selection-session-header')),
          findsOneWidget,
        );
        expect(find.textContaining('19:00'), findsOneWidget);
        expect(find.textContaining('Evening'), findsOneWidget);
        expect(find.text('Confirm 0 seats'), findsOneWidget);

        // Single-tap toggles seats 5 and 12 immediately.
        await tester.tap(find.byKey(const ValueKey<String>('seat-grid-5')));
        await tester.tap(find.byKey(const ValueKey<String>('seat-grid-12')));
        await tester.pump();
        expect(find.text('5, 12'), findsOneWidget);
        expect(find.text('Confirm 2 seats'), findsOneWidget);

        // Live stream marks seat 12 booked by another customer -> drops 12 & shows conflict banner.
        repo.sessionController.add(
          Session(
            id: '1900',
            time: SessionTime('19:00'),
            label: 'Evening',
            bookedSeats: const <int>{12, 21},
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('seat-conflict-banner')),
          findsOneWidget,
        );
        expect(find.text('5'), findsAtLeastNWidgets(1));
        expect(find.text('Confirm 1 seats'), findsOneWidget);

        // Tap Confirm -> busy state -> completes -> triggers onResult('ref-100').
        await tester.tap(
          find.byKey(const ValueKey<String>('seat-confirm-button')),
        );
        await tester.pump();
        expect(find.text('Confirming…'), findsOneWidget);

        // Back button is disabled while submitting.
        await tester.tap(find.byTooltip('Back to details'));
        await tester.pump();
        expect(detailsTaps, 0);

        confirmGate.complete(
          BookingConfirmed(
            BookingRequest(
              bookingId: 'ref-100',
              customerUid: 'cust-1',
              showId: 'show-1',
              sessionId: '1900',
              seats: const <int>[5],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(results, <String>['ref-100']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(selection.close);
        await tester.runAsync(booking.close);
      }
    },
  );

  testWidgets(
    'BookingResultScreen displays confirmed, conflict, unconfirmed recovery, and missing reference states',
    (tester) async {
      final repo = _ControllableBookingRepository();
      addTearDown(repo.dispose);
      final selection = SeatSelectionCubit(
        bookingRepository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
        autoStart: false,
      );

      // 1. Confirmed booking
      repo.onConfirm = (req) async => BookingConfirmed(req);
      final confirmedCubit = BookingCubit(
        repository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
        newBookingId: () => 'ref-ok',
      );
      var detailsTaps = 0;

      try {
        await confirmedCubit.submit(const <int>{1, 47});
        await tester.pumpWidget(
          _wrapBooking(
            selectionCubit: selection,
            bookingCubit: confirmedCubit,
            child: BookingResultScreen(
              bookingId: 'ref-ok',
              onDetails: () => detailsTaps++,
              onReviewMap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Booking confirmed'), findsOneWidget);
        expect(find.text('Reference: ref-ok'), findsOneWidget);
        expect(find.text('Seats: 1, 47'), findsOneWidget);
        await tester.tap(find.text('Back to details'));
        expect(detailsTaps, 1);

        // Mismatched reference shows reference unavailable message.
        await tester.pumpWidget(
          _wrapBooking(
            selectionCubit: selection,
            bookingCubit: confirmedCubit,
            child: BookingResultScreen(
              bookingId: 'other-ref',
              onDetails: () {},
              onReviewMap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Reference unavailable in this session'),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(confirmedCubit.close);
      }

      // 2. Conflict booking
      repo.onConfirm = (req) async => BookingConflict(req, const <int>{2});
      final conflictCubit = BookingCubit(
        repository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
        newBookingId: () => 'ref-conflict',
      );
      var reviewTaps = 0;
      try {
        await conflictCubit.submit(const <int>{2, 3});
        await tester.pumpWidget(
          _wrapBooking(
            selectionCubit: selection,
            bookingCubit: conflictCubit,
            child: BookingResultScreen(
              bookingId: 'ref-conflict',
              onDetails: () {},
              onReviewMap: () => reviewTaps++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Not booked'), findsOneWidget);
        expect(find.text('Conflicting seats: 2'), findsOneWidget);
        await tester.tap(find.text('Review seat map'));
        expect(reviewTaps, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(conflictCubit.close);
      }

      // 3. Unconfirmed -> Check status recovers confirmed booking
      repo.onConfirm = (req) async =>
          BookingUnconfirmed(req, reason: 'Timeout');
      repo.onRecover = ({required bookingId, required customerUid}) async =>
          RecoveryConfirmed(
            bookingId: bookingId,
            customerUid: customerUid,
            booking: Booking(
              request: BookingRequest(
                bookingId: bookingId,
                customerUid: customerUid,
                showId: 'show-1',
                sessionId: '1900',
                seats: const <int>{9},
              ),
              showTitle: 'Finals',
              showDate: '2026-12-01',
              slotTime: SessionTime('19:00'),
              vendorId: 'arena',
              createdAt: DateTime.utc(2026, 11, 21),
            ),
          );
      final recoverCubit = BookingCubit(
        repository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
        newBookingId: () => 'ref-recover',
      );
      try {
        await recoverCubit.submit(const <int>{9});
        await tester.pumpWidget(
          _wrapBooking(
            selectionCubit: selection,
            bookingCubit: recoverCubit,
            child: BookingResultScreen(
              bookingId: 'ref-recover',
              onDetails: () {},
              onReviewMap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Confirmation unknown'), findsOneWidget);
        await tester.tap(find.text('Check status'));
        await tester.pumpAndSettle();
        expect(find.text('Booking confirmed'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(recoverCubit.close);
        await tester.runAsync(selection.close);
      }
    },
  );

  for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
    testWidgets(
      'SeatSelectionScreen and BookingResultScreen fit 300x640 at 2.0x text scale in ${brightness.name} mode',
      (tester) async {
        tester.view.physicalSize = const Size(300, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _ControllableBookingRepository();
        addTearDown(repo.dispose);
        final theme = buildAppTheme(brightness: brightness);

        final selection = SeatSelectionCubit(
          bookingRepository: repo,
          customerUid: 'cust-1',
          showId: 'show-1',
          sessionId: '1900',
        );
        repo.onConfirm = (req) async => BookingConflict(req, const <int>{1});
        final booking = BookingCubit(
          repository: repo,
          customerUid: 'cust-1',
          showId: 'show-1',
          sessionId: '1900',
          newBookingId: () => 'ref-narrow',
        );

        try {
          await tester.pumpWidget(
            _wrapBooking(
              selectionCubit: selection,
              bookingCubit: booking,
              theme: theme,
              size: const Size(300, 640),
              textScale: 2.0,
              child: SeatSelectionScreen(onResult: (_) {}, onDetails: () {}),
            ),
          );
          repo.sessionController.add(
            Session(
              id: '1900',
              time: SessionTime('19:00'),
              label: 'Championship Evening Session',
              bookedSeats: const <int>{21},
            ),
          );
          repo.mySeatsController.add(const <int>{14});
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await booking.submit(const <int>{1, 2});
          await tester.pumpWidget(
            _wrapBooking(
              selectionCubit: selection,
              bookingCubit: booking,
              theme: theme,
              size: const Size(300, 640),
              textScale: 2.0,
              child: BookingResultScreen(
                bookingId: 'ref-narrow',
                onDetails: () {},
                onReviewMap: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(selection.close);
          await tester.runAsync(booking.close);
        }
      },
    );
  }
}

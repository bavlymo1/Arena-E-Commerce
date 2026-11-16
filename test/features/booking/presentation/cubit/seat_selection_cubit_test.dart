import 'dart:async';

import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/domain/repositories/booking_repository.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_state.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/shared/seating/seat_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_booking_repository.dart';

final class _StreamingBookingRepository implements BookingRepository {
  final sessionController = StreamController<Session?>();
  final mySeatsController = StreamController<Set<int>>();
  (String, String)? watchedSessionArgs;
  (String, String, String)? watchedMySeatsArgs;
  int watchSessionCalls = 0;
  int watchMySeatsCalls = 0;

  @override
  Stream<Session?> watchSession(String showId, String sessionId) {
    watchSessionCalls++;
    watchedSessionArgs = (showId, sessionId);
    return sessionController.stream;
  }

  @override
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId) {
    watchMySeatsCalls++;
    watchedMySeatsArgs = (uid, showId, sessionId);
    return mySeatsController.stream;
  }

  @override
  Future<BookingResult> confirm(BookingRequest request) async =>
      BookingUnconfirmed(request, reason: 'Unused in SeatSelectionCubit');

  @override
  Future<BookingRecovery> recover({
    required String bookingId,
    required String customerUid,
  }) async => RecoveryUnresolved(
    bookingId: bookingId,
    customerUid: customerUid,
    reason: 'Unused in SeatSelectionCubit',
  );

  Future<void> dispose() async {
    await sessionController.close();
    await mySeatsController.close();
  }
}

Session _session({Iterable<int> bookedSeats = const []}) => Session(
  id: '1900',
  time: SessionTime('19:00'),
  label: 'Evening',
  bookedSeats: bookedSeats,
);

void main() {
  test('rejects blank constructor identifiers', () {
    final fake = FakeBookingRepository();
    expect(
      () => SeatSelectionCubit(
        bookingRepository: fake,
        customerUid: ' ',
        showId: 'show-1',
        sessionId: '1900',
      ),
      throwsArgumentError,
    );
    expect(
      () => SeatSelectionCubit(
        bookingRepository: fake,
        customerUid: 'cust-1',
        showId: '',
        sessionId: '1900',
      ),
      throwsArgumentError,
    );
    expect(
      () => SeatSelectionCubit(
        bookingRepository: fake,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: ' ',
      ),
      throwsArgumentError,
    );
  });

  test(
    'loads FakeBookingRepository streams scoped to uid, show and session',
    () async {
      final fake = FakeBookingRepository();
      fake.sessions[('show-1', '1900')] = _session(bookedSeats: {14, 21});
      fake.ownSeats[('cust-1', 'show-1', '1900')] = {14};
      fake.ownSeats[('cust-2', 'show-1', '1900')] = {21};

      final cubit = SeatSelectionCubit(
        bookingRepository: fake,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
      );
      addTearDown(cubit.close);

      await pumpEventQueue();

      expect(cubit.state.status, SeatSelectionStatus.ready);
      expect(cubit.state.bookedSeats, {14, 21});
      expect(cubit.state.myConfirmedSeats, {14});
      expect(cubit.state.otherBookedSeats, {21});
      expect(cubit.state.visualStatusFor(14), SeatVisualStatus.mineConfirmed);
      expect(cubit.state.visualStatusFor(21), SeatVisualStatus.bookedByOther);
      expect(cubit.state.visualStatusFor(1), SeatVisualStatus.available);
    },
  );

  test(
    'toggles available seats directly and blocks booked/own seats',
    () async {
      final repo = _StreamingBookingRepository();
      addTearDown(repo.dispose);
      final cubit = SeatSelectionCubit(
        bookingRepository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
      );
      addTearDown(cubit.close);

      expect(repo.watchedSessionArgs, ('show-1', '1900'));
      expect(repo.watchedMySeatsArgs, ('cust-1', 'show-1', '1900'));
      expect(cubit.state.status, SeatSelectionStatus.loading);

      repo.sessionController.add(_session(bookedSeats: {14, 21}));
      repo.mySeatsController.add({14});
      await pumpEventQueue();

      cubit.toggleSeat(12);
      cubit.toggleSeat(5);
      cubit.toggleSeat(14);
      cubit.toggleSeat(21);
      cubit.toggleSeat(0);
      cubit.toggleSeat(48);

      expect(cubit.state.selectedSeats, {5, 12});
      expect(cubit.state.canSubmit, isTrue);
      final request = cubit.state.toBookingRequest(bookingId: 'booking-ref-1');
      expect(request.bookingId, 'booking-ref-1');
      expect(request.customerUid, 'cust-1');
      expect(request.seats, {5, 12});

      cubit.toggleSeat(5);
      expect(cubit.state.selectedSeats, {12});
    },
  );

  test('drops conflicting seats from snapshot and transitions own confirmations cleanly', () async {
    final repo = _StreamingBookingRepository();
    addTearDown(repo.dispose);
    final cubit = SeatSelectionCubit(
      bookingRepository: repo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    addTearDown(cubit.close);

    repo.sessionController.add(_session(bookedSeats: {14}));
    repo.mySeatsController.add({14});
    await pumpEventQueue();

    cubit.toggleSeat(12);
    cubit.toggleSeat(13);
    expect(cubit.state.selectedSeats, {12, 13});

    // Another customer confirms seat 12 while 13 stays free.
    repo.sessionController.add(_session(bookedSeats: {14, 12}));
    await pumpEventQueue();

    expect(cubit.state.selectedSeats, {13});
    expect(cubit.state.droppedByConflict, {12});
    expect(cubit.state.conflictMessage, contains('Seat 12'));

    // Current customer's own booking for seat 13 confirms cleanly (no false conflict).
    cubit.clearConflictNotice();
    repo.sessionController.add(_session(bookedSeats: {14, 12, 13}));
    repo.mySeatsController.add({14, 13});
    await pumpEventQueue();

    expect(cubit.state.selectedSeats, isEmpty);
    expect(cubit.state.myConfirmedSeats, {13, 14});
    expect(cubit.state.droppedByConflict, isEmpty);
    expect(cubit.state.conflictMessage, isNull);
  });

  test('submitting state blocks interaction until cleared', () async {
    final repo = _StreamingBookingRepository();
    addTearDown(repo.dispose);
    final cubit = SeatSelectionCubit(
      bookingRepository: repo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    addTearDown(cubit.close);

    repo.sessionController.add(_session());
    repo.mySeatsController.add({});
    await pumpEventQueue();

    cubit.toggleSeat(7);
    cubit.setSubmitting(true);
    expect(cubit.state.submitting, isTrue);
    expect(cubit.state.canSubmit, isFalse);

    cubit.toggleSeat(8);
    cubit.clearSelection();
    expect(cubit.state.selectedSeats, {7});

    cubit.setSubmitting(false);
    cubit.toggleSeat(8);
    expect(cubit.state.selectedSeats, {7, 8});
  });

  test('transitions to unavailable when session stream emits null', () async {
    final repo = _StreamingBookingRepository();
    addTearDown(repo.dispose);
    final cubit = SeatSelectionCubit(
      bookingRepository: repo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    addTearDown(cubit.close);

    repo.sessionController.add(_session());
    repo.mySeatsController.add({});
    await pumpEventQueue();
    cubit.toggleSeat(3);

    repo.sessionController.add(null);
    await pumpEventQueue();

    expect(cubit.state.status, SeatSelectionStatus.unavailable);
    expect(cubit.state.selectedSeats, isEmpty);
    expect(cubit.state.canSubmit, isFalse);
  });

  test('stream error transitions to error preserving selection and recovers on retry', () async {
    var failFirst = true;
    final retryRepo = _RetryableBookingRepository(() => failFirst);
    final cubit = SeatSelectionCubit(
      bookingRepository: retryRepo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    addTearDown(cubit.close);

    await pumpEventQueue();
    expect(cubit.state.status, SeatSelectionStatus.error);

    failFirst = false;
    cubit.retry();
    await pumpEventQueue();

    expect(cubit.state.status, SeatSelectionStatus.ready);
    expect(cubit.state.bookedSeats, {21});
  });

  test(
    'close cancels subscriptions and ignores late stream emissions',
    () async {
      final repo = _StreamingBookingRepository();
      addTearDown(repo.dispose);
      final cubit = SeatSelectionCubit(
        bookingRepository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
      );

      expect(repo.sessionController.hasListener, isTrue);
      expect(repo.mySeatsController.hasListener, isTrue);

      await cubit.close();
      expect(repo.sessionController.hasListener, isFalse);
      expect(repo.mySeatsController.hasListener, isFalse);

      repo.sessionController.add(_session(bookedSeats: {1, 2}));
      repo.mySeatsController.add({1});
      repo.sessionController.addError(StateError('Late failure'));
      await pumpEventQueue();

      expect(cubit.isClosed, isTrue);
      expect(cubit.state.status, SeatSelectionStatus.loading);
    },
  );
}

final class _RetryableBookingRepository implements BookingRepository {
  _RetryableBookingRepository(this._shouldFail);

  final bool Function() _shouldFail;

  @override
  Stream<Session?> watchSession(String showId, String sessionId) =>
      _shouldFail()
      ? Stream<Session?>.error(StateError('Transient stream error'))
      : Stream<Session?>.value(_session(bookedSeats: {21}));

  @override
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId) =>
      Stream<Set<int>>.value(const <int>{});

  @override
  Future<BookingResult> confirm(BookingRequest request) async =>
      BookingUnconfirmed(request, reason: 'Unused');

  @override
  Future<BookingRecovery> recover({
    required String bookingId,
    required String customerUid,
  }) async => RecoveryUnresolved(
    bookingId: bookingId,
    customerUid: customerUid,
    reason: 'Unused',
  );
}

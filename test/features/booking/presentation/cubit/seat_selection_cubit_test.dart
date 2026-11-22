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
  _StreamingBookingRepository({
    Future<void> Function()? onSessionCancel,
    Future<void> Function()? onMySeatsCancel,
    this.throwOnOwnWatch = false,
    this.wrapSessionStream,
  }) : sessionController = StreamController<Session?>(
         onCancel: onSessionCancel,
       ),
       mySeatsController = StreamController<Set<int>>.broadcast(
         onCancel: onMySeatsCancel,
       );

  StreamController<Session?> sessionController;
  StreamController<Set<int>> mySeatsController;
  bool throwOnOwnWatch;
  Stream<Session?> Function(Stream<Session?>)? wrapSessionStream;
  (String, String)? watchedSessionArgs;
  (String, String, String)? watchedMySeatsArgs;
  int watchSessionCalls = 0;
  int watchMySeatsCalls = 0;

  @override
  Stream<Session?> watchSession(String showId, String sessionId) {
    watchSessionCalls++;
    watchedSessionArgs = (showId, sessionId);
    final stream = sessionController.stream;
    return wrapSessionStream != null ? wrapSessionStream!(stream) : stream;
  }

  @override
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId) {
    if (throwOnOwnWatch) throw StateError('Cannot construct ownership query');
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
    unawaited(sessionController.close());
    unawaited(mySeatsController.close());
  }
}

Session _session({Iterable<int> bookedSeats = const []}) => Session(
  id: '1900',
  time: SessionTime('19:00'),
  label: 'Evening',
  bookedSeats: bookedSeats,
);

void main() {
  for (final failedOwnership in [true, false]) {
    test(
      'failed ${failedOwnership ? 'ownership' : 'session'} channel needs fresh data',
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
        await pumpEventQueue();
        repo.sessionController.add(_session());
        repo.mySeatsController.add({});
        await pumpEventQueue();
        cubit.toggleSeat(7);
        if (failedOwnership) {
          repo.mySeatsController.addError(StateError('Ownership denied'));
        } else {
          repo.sessionController.addError(StateError('Session denied'));
        }
        await pumpEventQueue();
        expect(cubit.state.status, SeatSelectionStatus.error);
        if (failedOwnership) {
          repo.sessionController.add(_session(bookedSeats: {21}));
        } else {
          repo.mySeatsController.add({});
        }
        await pumpEventQueue();
        expect(cubit.state.status, SeatSelectionStatus.error);
        expect(cubit.state.canSubmit, isFalse);
        expect(cubit.state.selectedSeats, {7});
        if (failedOwnership) {
          repo.mySeatsController.add({});
        } else {
          repo.sessionController.add(_session());
        }
        await pumpEventQueue();
        expect(cubit.state.status, SeatSelectionStatus.ready);
      },
    );
  }

  test(
    'synchronous query failure cancels the already-open sibling stream',
    () async {
      final repo = _StreamingBookingRepository(throwOnOwnWatch: true);
      addTearDown(repo.dispose);
      final cubit = SeatSelectionCubit(
        bookingRepository: repo,
        customerUid: 'cust-1',
        showId: 'show-1',
        sessionId: '1900',
        autoStart: false,
      );
      addTearDown(cubit.close);
      await expectLater(Future<void>.sync(cubit.start), completes);
      expect(cubit.state.status, SeatSelectionStatus.error);
      expect(repo.sessionController.hasListener, isFalse);
    },
  );

  test('close waits for asynchronous stream resource cleanup', () async {
    final released = Completer<void>();
    final repo = _StreamingBookingRepository(
      onSessionCancel: () => released.future,
    );
    addTearDown(repo.dispose);
    final cubit = SeatSelectionCubit(
      bookingRepository: repo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    await pumpEventQueue();
    var closed = false;
    final closing = cubit.close().then((_) => closed = true);
    await pumpEventQueue();
    try {
      expect(closed, isFalse);
    } finally {
      released.complete();
      await closing;
    }
    expect(closed, isTrue);
  });

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

      await pumpEventQueue();
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

    await pumpEventQueue();
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

    await pumpEventQueue();
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

    await pumpEventQueue();
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

      await pumpEventQueue();
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

  test('close completes without throwing and cancels sibling when a stream cancel fails', () async {
    var mySeatsCancelled = false;
    final repo = _StreamingBookingRepository(
      onSessionCancel: () =>
          Future<void>.error(StateError('session cancel failed')),
      onMySeatsCancel: () async {
        mySeatsCancelled = true;
      },
    );
    addTearDown(repo.dispose);
    final cubit = SeatSelectionCubit(
      bookingRepository: repo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    await pumpEventQueue();

    await expectLater(cubit.close(), completes);
    expect(cubit.isClosed, isTrue);
    expect(mySeatsCancelled, isTrue);
    expect(repo.sessionController.hasListener, isFalse);
    expect(repo.mySeatsController.hasListener, isFalse);
  });

  test('retry and start recover cleanly without poisoning _cancellation when prior cancel or sibling attach fails', () async {
    var sessionCancels = 0;
    final repo = _StreamingBookingRepository(
      onSessionCancel: () {
        sessionCancels++;
        if (sessionCancels == 1) {
          return Future<void>.error(StateError('session cancel failed'));
        }
        return Future<void>.value();
      },
      throwOnOwnWatch: true,
    );
    addTearDown(repo.dispose);
    final cubit = SeatSelectionCubit(
      bookingRepository: repo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
      autoStart: false,
    );
    addTearDown(cubit.close);

    await expectLater(cubit.start(), completes);
    expect(cubit.state.status, SeatSelectionStatus.error);
    expect(repo.sessionController.hasListener, isFalse);

    repo.throwOnOwnWatch = false;
    final oldSession = repo.sessionController;
    repo.sessionController = StreamController<Session?>();

    await expectLater(cubit.retry(), completes);
    await oldSession.close();

    repo.sessionController.add(_session());
    repo.mySeatsController.add(const <int>{});
    await pumpEventQueue();
    expect(cubit.state.status, SeatSelectionStatus.ready);

    await expectLater(cubit.close(), completes);
  });

  test('handles synchronous StreamSubscription.cancel() throw on close and retry without Zone errors while cancelling sibling', () async {
    final uncaught = <Object>[];

    // 1. close() completes cleanly and cancels sibling on sync cancel throw.
    var mySeatsCancelled1 = false;
    final repo1 = _StreamingBookingRepository(
      onMySeatsCancel: () async {
        mySeatsCancelled1 = true;
      },
      wrapSessionStream: (inner) => _SyncCancelThrowStream<Session?>(inner),
    );
    addTearDown(repo1.dispose);
    Object? close1Error;
    late SeatSelectionCubit cubit1;
    final done1 = Completer<void>();
    runZonedGuarded(() async {
      try {
        cubit1 = SeatSelectionCubit(
          bookingRepository: repo1,
          customerUid: 'cust-1',
          showId: 'show-1',
          sessionId: '1900',
        );
        await pumpEventQueue();
        try {
          await cubit1.close();
        } catch (error) {
          close1Error = error;
        }
      } finally {
        if (!done1.isCompleted) done1.complete();
      }
    }, (error, _) => uncaught.add(error));
    await done1.future;

    expect(uncaught, isEmpty);
    expect(close1Error, isNull);
    expect(cubit1.isClosed, isTrue);
    expect(mySeatsCancelled1, isTrue);
    expect(repo1.sessionController.hasListener, isFalse);
    expect(repo1.mySeatsController.hasListener, isFalse);

    // 2. retry()/start() recovers cleanly after sync cancel throw without Zone errors.
    var mySeatsCancelled2 = false;
    var wrapFirst = true;
    final repo2 = _StreamingBookingRepository(
      onMySeatsCancel: () async {
        mySeatsCancelled2 = true;
      },
      wrapSessionStream: (inner) =>
          wrapFirst ? _SyncCancelThrowStream<Session?>(inner) : inner,
    );
    addTearDown(repo2.dispose);
    Object? retry2Error;
    Object? close2Error;
    late SeatSelectionCubit cubit2;
    final done2 = Completer<void>();
    runZonedGuarded(() async {
      try {
        cubit2 = SeatSelectionCubit(
          bookingRepository: repo2,
          customerUid: 'cust-1',
          showId: 'show-1',
          sessionId: '1900',
        );
        await pumpEventQueue();
        repo2.sessionController.addError(StateError('stream drop'));
        await pumpEventQueue();

        wrapFirst = false;
        final oldSession = repo2.sessionController;
        repo2.sessionController = StreamController<Session?>();
        unawaited(oldSession.close());

        try {
          await cubit2.retry();
        } catch (error) {
          retry2Error = error;
        }
        repo2.sessionController.add(_session());
        repo2.mySeatsController.add(const <int>{});
        await pumpEventQueue();

        try {
          await cubit2.close();
        } catch (error) {
          close2Error = error;
        }
      } finally {
        if (!done2.isCompleted) done2.complete();
      }
    }, (error, _) => uncaught.add(error));
    await done2.future;

    expect(uncaught, isEmpty);
    expect(retry2Error, isNull);
    expect(close2Error, isNull);
    expect(mySeatsCancelled2, isTrue);
    expect(cubit2.state.status, SeatSelectionStatus.ready);
    expect(cubit2.isClosed, isTrue);
  });

  test('SeatSelectionState compares session by value while keeping bookedSeats equality', () {
    final t1 = DateTime.utc(2026, 11, 20, 10, 0);
    SeatSelectionState buildState({
      Session? session,
      Iterable<int> bookedSeats = const [1, 2],
    }) => SeatSelectionState(
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
      status: SeatSelectionStatus.ready,
      session: session,
      bookedSeats: bookedSeats,
    );

    final s1 = Session(
      id: '1900',
      time: SessionTime('19:00'),
      label: 'Evening',
      bookedSeats: const [1, 2],
      lastBookingId: 'b-1',
      updatedAt: t1,
    );
    final s2 = Session(
      id: '1900',
      time: SessionTime('19:00'),
      label: 'Evening',
      bookedSeats: const [2, 1],
      lastBookingId: 'b-1',
      updatedAt: t1,
    );
    expect(buildState(session: s1), buildState(session: s2));
    expect(buildState(session: s1).hashCode, buildState(session: s2).hashCode);

    expect(
      buildState(session: s1),
      isNot(
        buildState(
          session: Session(
            id: '1900',
            time: SessionTime('19:00'),
            label: 'Matinee',
            bookedSeats: const [1, 2],
            lastBookingId: 'b-1',
            updatedAt: t1,
          ),
        ),
      ),
    );
    expect(
      buildState(session: s1),
      isNot(
        buildState(
          session: Session(
            id: '1900',
            time: SessionTime('19:00'),
            label: 'Evening',
            bookedSeats: const [1, 2],
            lastBookingId: 'b-2',
            updatedAt: t1,
          ),
        ),
      ),
    );
    expect(
      buildState(session: s1),
      isNot(
        buildState(
          session: Session(
            id: '1900',
            time: SessionTime('19:00'),
            label: 'Evening',
            bookedSeats: const [1, 2],
            lastBookingId: 'b-1',
            updatedAt: t1.add(const Duration(seconds: 1)),
          ),
        ),
      ),
    );
    expect(
      buildState(session: s1, bookedSeats: const [1, 2]),
      isNot(
        buildState(
          session: Session(
            id: '1900',
            time: SessionTime('19:00'),
            label: 'Evening',
            bookedSeats: const [1, 3],
            lastBookingId: 'b-1',
            updatedAt: t1,
          ),
          bookedSeats: const [1, 2],
        ),
      ),
    );
    expect(
      buildState(session: null, bookedSeats: const [1]),
      isNot(buildState(session: null, bookedSeats: const [2])),
    );
  });

  test('deduplicates identical Session snapshots, emits on session field updates, and transitions through loading on retry', () async {
    final repo = _StreamingBookingRepository();
    addTearDown(repo.dispose);
    final cubit = SeatSelectionCubit(
      bookingRepository: repo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    addTearDown(cubit.close);

    final emitted = <SeatSelectionState>[];
    final sub = cubit.stream.listen(emitted.add);
    addTearDown(sub.cancel);

    final t1 = DateTime.utc(2026, 11, 20, 10, 0);
    final t2 = DateTime.utc(2026, 11, 20, 10, 5);
    await pumpEventQueue();
    emitted.clear();

    repo.sessionController.add(
      Session(
        id: '1900',
        time: SessionTime('19:00'),
        label: 'Evening',
        bookedSeats: const [5],
        lastBookingId: 'b-1',
        updatedAt: t1,
      ),
    );
    repo.mySeatsController.add(const <int>{});
    await pumpEventQueue();
    expect(emitted, hasLength(1));

    // Identical Session snapshot (with reordered bookedSeats) deduplicates.
    repo.sessionController.add(
      Session(
        id: '1900',
        time: SessionTime('19:00'),
        label: 'Evening',
        bookedSeats: const [5],
        lastBookingId: 'b-1',
        updatedAt: t1,
      ),
    );
    await pumpEventQueue();
    expect(emitted, hasLength(1));

    // Changes to label, lastBookingId, updatedAt, and bookedSeats each emit.
    repo.sessionController.add(
      Session(
        id: '1900',
        time: SessionTime('19:00'),
        label: 'Late',
        bookedSeats: const [5],
        lastBookingId: 'b-1',
        updatedAt: t1,
      ),
    );
    await pumpEventQueue();
    expect(emitted, hasLength(2));
    expect(emitted.last.session?.label, 'Late');

    repo.sessionController.add(
      Session(
        id: '1900',
        time: SessionTime('19:00'),
        label: 'Late',
        bookedSeats: const [5],
        lastBookingId: 'b-2',
        updatedAt: t1,
      ),
    );
    await pumpEventQueue();
    expect(emitted, hasLength(3));
    expect(emitted.last.session?.lastBookingId, 'b-2');

    repo.sessionController.add(
      Session(
        id: '1900',
        time: SessionTime('19:00'),
        label: 'Late',
        bookedSeats: const [5],
        lastBookingId: 'b-2',
        updatedAt: t2,
      ),
    );
    await pumpEventQueue();
    expect(emitted, hasLength(4));
    expect(emitted.last.session?.updatedAt, t2);

    repo.sessionController.add(
      Session(
        id: '1900',
        time: SessionTime('19:00'),
        label: 'Late',
        bookedSeats: const [5, 6],
        lastBookingId: 'b-2',
        updatedAt: t2,
      ),
    );
    await pumpEventQueue();
    expect(emitted, hasLength(5));
    expect(emitted.last.bookedSeats, const <int>{5, 6});

    // Stream error -> retry() transitions through loading -> ready even for same data.
    repo.sessionController.addError(StateError('drop'));
    await pumpEventQueue();
    expect(emitted.last.status, SeatSelectionStatus.error);

    final oldSession = repo.sessionController;
    repo.sessionController = StreamController<Session?>();
    unawaited(oldSession.close());

    final retryCountStart = emitted.length;
    await cubit.retry();
    expect(emitted[retryCountStart].status, SeatSelectionStatus.loading);

    repo.sessionController.add(
      Session(
        id: '1900',
        time: SessionTime('19:00'),
        label: 'Late',
        bookedSeats: const [5, 6],
        lastBookingId: 'b-2',
        updatedAt: t2,
      ),
    );
    repo.mySeatsController.add(const <int>{});
    await pumpEventQueue();
    expect(emitted.last.status, SeatSelectionStatus.ready);
  });
}

final class _SyncCancelThrowStream<T> extends Stream<T> {
  _SyncCancelThrowStream(this._inner);

  final Stream<T> _inner;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final innerSub = _inner.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    return _SyncCancelThrowSubscription<T>(innerSub);
  }
}

final class _SyncCancelThrowSubscription<T> implements StreamSubscription<T> {
  _SyncCancelThrowSubscription(this._inner);

  final StreamSubscription<T> _inner;

  @override
  Future<void> cancel() {
    unawaited(_inner.cancel());
    throw StateError('sync cancel boom');
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
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

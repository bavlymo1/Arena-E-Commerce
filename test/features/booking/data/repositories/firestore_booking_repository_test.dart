import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/features/booking/data/repositories/firestore_booking_repository.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/domain/repositories/booking_repository.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_state.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _StreamingShowsRepository implements ShowsRepository {
  _StreamingShowsRepository({
    Future<void> Function()? onShowCancel,
    Future<void> Function()? onSessionsCancel,
  }) : showController = StreamController<Show?>(onCancel: onShowCancel),
       sessionsController = StreamController<List<Session>>(
         onCancel: onSessionsCancel,
       );

  final StreamController<Show?> showController;
  final StreamController<List<Session>> sessionsController;

  @override
  Stream<Show?> watchShow(String showId) => showController.stream;

  @override
  Stream<List<Session>> watchSessions(String showId) =>
      sessionsController.stream;

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) =>
      const Stream<List<Show>>.empty();

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) =>
      const Stream<List<Show>>.empty();

  @override
  Future<void> addShow(NewShow show, Uint8List poster) async {}

  @override
  Future<void> deleteShow(String showId) async {}

  @override
  Future<void> resumeDeletes(String vendorId) async {}

  @override
  Future<Uint8List?> loadPoster(String showId) async => null;

  @override
  void clearPosterCache() {}

  @override
  void dispose() {
    unawaited(showController.close());
    unawaited(sessionsController.close());
  }
}

Show _show({ShowStatus status = ShowStatus.active}) => Show(
  id: 'show-1',
  vendorId: 'vendor-1',
  title: 'Arena Show',
  description: 'Live event',
  showDate: '2026-12-20',
  imageId: 'show-1',
  status: status,
  bookedCount: 0,
  lastBookingId: '',
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: DateTime.utc(2026, 11, 20),
);

Session _session({Iterable<int> bookedSeats = const <int>[]}) => Session(
  id: '1900',
  time: SessionTime('19:00'),
  label: 'Evening',
  bookedSeats: bookedSeats,
);

void main() {
  test('watchSession emits null immediately when show transitions to deleting even before sessions are deleted', () async {
    final shows = _StreamingShowsRepository();
    addTearDown(shows.dispose);
    final repo = FirestoreBookingRepository(
      _FakeFirestore(),
      _FakeFirebaseAuth(),
      shows,
    );

    final emitted = <Session?>[];
    final sub = repo.watchSession('show-1', '1900').listen(emitted.add);
    addTearDown(sub.cancel);

    shows.showController.add(_show(status: ShowStatus.active));
    await pumpEventQueue();
    expect(emitted, isEmpty);

    shows.sessionsController.add([
      _session(bookedSeats: [1]),
    ]);
    await pumpEventQueue();
    expect(emitted, hasLength(1));
    expect(emitted.single?.id, '1900');

    // Show becomes deleting while sessions still exist.
    shows.showController.add(_show(status: ShowStatus.deleting));
    await pumpEventQueue();
    expect(emitted.last, isNull);
  });

  test('watchSession emits null when show disappears and cancels both subscriptions on close', () async {
    var showCancelled = false;
    var sessionsCancelled = false;
    final shows = _StreamingShowsRepository(
      onShowCancel: () async => showCancelled = true,
      onSessionsCancel: () async => sessionsCancelled = true,
    );
    addTearDown(shows.dispose);
    final repo = FirestoreBookingRepository(
      _FakeFirestore(),
      _FakeFirebaseAuth(),
      shows,
    );

    final emitted = <Session?>[];
    final sub = repo.watchSession('show-1', '1900').listen(emitted.add);

    shows.showController.add(_show(status: ShowStatus.active));
    shows.sessionsController.add([_session()]);
    await pumpEventQueue();
    expect(emitted.single?.id, '1900');

    shows.showController.add(null);
    await pumpEventQueue();
    expect(emitted.last, isNull);

    await sub.cancel();
    expect(showCancelled, isTrue);
    expect(sessionsCancelled, isTrue);
  });

  test('watchSession forwards errors from show or sessions stream', () async {
    final shows = _StreamingShowsRepository();
    addTearDown(shows.dispose);
    final repo = FirestoreBookingRepository(
      _FakeFirestore(),
      _FakeFirebaseAuth(),
      shows,
    );

    final errors = <Object>[];
    final sub = repo
        .watchSession('show-1', '1900')
        .listen((_) {}, onError: errors.add);
    addTearDown(sub.cancel);

    shows.showController.addError(StateError('show stream failed'));
    await pumpEventQueue();
    expect(errors, hasLength(1));

    shows.sessionsController.addError(StateError('sessions stream failed'));
    await pumpEventQueue();
    expect(errors, hasLength(2));
  });

  test('SeatSelectionCubit transitions to unavailable when FirestoreBookingRepository observes deleting show', () async {
    final shows = _StreamingShowsRepository();
    addTearDown(shows.dispose);
    final bookingRepo = FirestoreBookingRepository(
      _FakeFirestore(),
      _FakeFirebaseAuth(),
      shows,
    );
    final mySeats = StreamController<Set<int>>.broadcast();
    addTearDown(mySeats.close);

    final repo = _CombinedBookingRepo(bookingRepo, mySeats.stream);
    final cubit = SeatSelectionCubit(
      bookingRepository: repo,
      customerUid: 'cust-1',
      showId: 'show-1',
      sessionId: '1900',
    );
    addTearDown(cubit.close);

    await pumpEventQueue();
    shows.showController.add(_show(status: ShowStatus.active));
    shows.sessionsController.add([_session()]);
    mySeats.add(<int>{});
    await pumpEventQueue();

    expect(cubit.state.status, SeatSelectionStatus.ready);
    cubit.toggleSeat(5);
    expect(cubit.state.selectedSeats, <int>{5});

    shows.showController.add(_show(status: ShowStatus.deleting));
    await pumpEventQueue();

    expect(cubit.state.status, SeatSelectionStatus.unavailable);
    expect(cubit.state.selectedSeats, isEmpty);
    expect(cubit.state.canSubmit, isFalse);
  });
}

final class _CombinedBookingRepo implements BookingRepository {
  _CombinedBookingRepo(this._delegate, this._mySeatsStream);

  final FirestoreBookingRepository _delegate;
  final Stream<Set<int>> _mySeatsStream;

  @override
  Stream<Session?> watchSession(String showId, String sessionId) =>
      _delegate.watchSession(showId, sessionId);

  @override
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId) =>
      _mySeatsStream;

  @override
  Future<BookingResult> confirm(BookingRequest request) =>
      _delegate.confirm(request);

  @override
  Future<BookingRecovery> recover({
    required String bookingId,
    required String customerUid,
  }) => _delegate.recover(bookingId: bookingId, customerUid: customerUid);
}

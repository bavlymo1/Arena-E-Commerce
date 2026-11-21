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

// ignore_for_file: subtype_of_sealed_class

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

final class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);

  @override
  final String uid;
}

final class _StubAuth extends Fake implements FirebaseAuth {
  _StubAuth([String? initialUid])
    : user = initialUid == null ? null : _FakeUser(initialUid);

  User? user;

  @override
  User? get currentUser => user;
}

final class _DocRecord {
  _DocRecord(
    this.data, {
    this.isFromCache = false,
    this.hasPendingWrites = false,
  });

  Map<String, dynamic>? data;
  bool isFromCache;
  bool hasPendingWrites;
}

final class _BookingStore {
  final Map<String, _DocRecord> docs = <String, _DocRecord>{};
  final StreamController<QuerySnapshot<Map<String, dynamic>>>
  mySeatsController =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  final List<(Object field, Object? value)> whereCalls = <(Object, Object?)>[];
  final List<String> queriedCollections = <String>[];
  final List<(String path, bool includeMetadataChanges)> snapshotListeners =
      <(String, bool)>[];
  final List<String> transactionWrites = <String>[];
  final List<(String path, GetOptions? options)> getCalls =
      <(String, GetOptions?)>[];
  Object? Function(String path, GetOptions? options)? onGet;
  void Function(String path, GetOptions? options)? onBeforeGet;
  Future<void> Function(int attempt)? onBeforeTransactionCommit;
  int transactionAttempts = 0;

  void setDoc(
    String path,
    Map<String, dynamic>? data, {
    bool isFromCache = false,
    bool hasPendingWrites = false,
  }) {
    docs[path] = _DocRecord(
      data,
      isFromCache: isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  Future<void> dispose() => mySeatsController.close();
}

final class _FakeBookingFirestore extends Fake implements FirebaseFirestore {
  _FakeBookingFirestore(this.store);

  final _BookingStore store;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollectionReference(collectionPath, store, this);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    store.transactionAttempts++;
    final tx = _FakeTransaction(store);
    final result = await transactionHandler(tx);
    await store.onBeforeTransactionCommit?.call(store.transactionAttempts);
    tx.apply();
    return result;
  }
}

final class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this.path, this.store, this.firestore);

  @override
  final String path;
  final _BookingStore store;

  @override
  final FirebaseFirestore firestore;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocumentReference(
        '${this.path}/${path ?? 'auto'}',
        store,
        firestore,
      );

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    store.queriedCollections.add(path);
    return _FakeQuery(path, store).where(
      field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      arrayContains: arrayContains,
      arrayContainsAny: arrayContainsAny,
      whereIn: whereIn,
      whereNotIn: whereNotIn,
      isNull: isNull,
    );
  }
}

final class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery(this.path, this.store);

  final String path;
  final _BookingStore store;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    store.whereCalls.add((field, isEqualTo));
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    store.snapshotListeners.add((path, includeMetadataChanges));
    return store.mySeatsController.stream;
  }
}

final class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference(this.path, this.store, this.firestore);

  @override
  final String path;
  final _BookingStore store;

  @override
  final FirebaseFirestore firestore;

  @override
  String get id => path.split('/').last;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollectionReference('$path/$collectionPath', store, firestore);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.getCalls.add((path, options));
    store.onBeforeGet?.call(path, options);
    final custom = store.onGet?.call(path, options);
    if (custom != null) {
      if (custom is Future<DocumentSnapshot<Map<String, dynamic>>>) {
        return custom;
      }
      throw custom;
    }
    final record = store.docs[path];
    return _FakeDocumentSnapshot(
      this,
      record?.data,
      isFromCache: record?.isFromCache ?? false,
      hasPendingWrites: record?.hasPendingWrites ?? false,
    );
  }
}

final class _FakeSnapshotMetadata extends Fake implements SnapshotMetadata {
  _FakeSnapshotMetadata({
    this.isFromCache = false,
    this.hasPendingWrites = false,
  });

  @override
  final bool isFromCache;

  @override
  final bool hasPendingWrites;
}

final class _FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot(
    this.reference,
    this._data, {
    bool isFromCache = false,
    bool hasPendingWrites = false,
  }) : metadata = _FakeSnapshotMetadata(
         isFromCache: isFromCache,
         hasPendingWrites: hasPendingWrites,
       );

  @override
  final DocumentReference<Map<String, dynamic>> reference;

  @override
  String get id => reference.id;

  final Map<String, dynamic>? _data;

  @override
  final SnapshotMetadata metadata;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic operator [](Object field) {
    final map = _data;
    if (map == null || !map.containsKey(field)) {
      throw StateError('Missing field $field on ${reference.path}');
    }
    return map[field];
  }
}

final class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(
    this.docs, {
    bool isFromCache = false,
    bool hasPendingWrites = false,
  }) : metadata = _FakeSnapshotMetadata(
         isFromCache: isFromCache,
         hasPendingWrites: hasPendingWrites,
       );

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  final SnapshotMetadata metadata;
}

final class _FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic operator [](Object field) => _data[field];
}

final class _FakeTransaction extends Fake implements Transaction {
  _FakeTransaction(this.store);

  final _BookingStore store;
  final List<void Function()> _staged = <void Function()>[];

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final record = store.docs[documentReference.path];
    return _FakeDocumentSnapshot(
      documentReference as DocumentReference<Map<String, dynamic>>,
      record?.data,
      isFromCache: record?.isFromCache ?? false,
      hasPendingWrites: record?.hasPendingWrites ?? false,
    ) as DocumentSnapshot<T>;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    _staged.add(() {
      final path = documentReference.path;
      store.transactionWrites.add('update:$path');
      final existing = Map<String, dynamic>.from(
        store.docs[path]?.data ?? const <String, dynamic>{},
      );
      for (final entry in data.entries) {
        existing[entry.key.toString()] = entry.value;
      }
      store.setDoc(path, existing);
    });
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _staged.add(() {
      final path = documentReference.path;
      store.transactionWrites.add('set:$path');
      store.setDoc(path, Map<String, dynamic>.from(data as Map));
    });
    return this;
  }

  void apply() {
    for (final write in _staged) {
      write();
    }
  }
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

  group('FirestoreBookingRepository watchMySeats, recover, and confirm', () {
    Map<String, dynamic> showData({
      String status = 'active',
      int bookedCount = 2,
      String lastBookingId = 'prior',
      Timestamp? updatedAt,
    }) => <String, dynamic>{
      'vendorId': 'vendor-1',
      'title': 'Arena Show',
      'description': 'Live event',
      'showDate': '2026-12-20',
      'imageId': 'show-1',
      'status': status,
      'bookedCount': bookedCount,
      'lastBookingId': lastBookingId,
      'updatedAt':
          updatedAt ?? Timestamp.fromDate(DateTime.utc(2026, 11, 20, 10, 0)),
    };

    Map<String, dynamic> sessionData({
      List<int> bookedSeats = const <int>[1, 2],
      String lastBookingId = 'prior',
      Timestamp? updatedAt,
    }) => <String, dynamic>{
      'time': '19:00',
      'label': 'Evening',
      'capacity': 47,
      'bookedSeats': bookedSeats,
      'lastBookingId': lastBookingId,
      'updatedAt':
          updatedAt ?? Timestamp.fromDate(DateTime.utc(2026, 11, 20, 10, 0)),
    };

    Map<String, dynamic> bookingData({
      String customerUid = 'cust-1',
      String showId = 'show-1',
      String sessionId = '1900',
      List<int> seats = const <int>[3, 4],
      String status = 'confirmed',
    }) => <String, dynamic>{
      'showId': showId,
      'sessionId': sessionId,
      'customerUid': customerUid,
      'seats': seats,
      'showTitle': 'Arena Show',
      'showDate': '2026-12-20',
      'slotTime': '19:00',
      'vendorId': 'vendor-1',
      'status': status,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 20, 12, 0)),
    };

    BookingRequest makeRequest({
      String bookingId = 'book-1',
      String customerUid = 'cust-1',
      Set<int> seats = const <int>{4, 3},
    }) => BookingRequest(
      bookingId: bookingId,
      customerUid: customerUid,
      showId: 'show-1',
      sessionId: '1900',
      seats: seats,
    );

    test('watchMySeats scopes query, ignores pending/cached snapshots, merges seats, and rejects account change', () async {
      final store = _BookingStore();
      addTearDown(store.dispose);
      final auth = _StubAuth('cust-1');
      final repo = FirestoreBookingRepository(
        _FakeBookingFirestore(store),
        auth,
        _StreamingShowsRepository(),
      );

      final emitted = <Set<int>>[];
      final errors = <Object>[];
      final sub = repo
          .watchMySeats('cust-1', 'show-1', '1900')
          .listen(emitted.add, onError: errors.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      expect(store.queriedCollections, <String>['bookings']);
      expect(store.snapshotListeners, <(String, bool)>[('bookings', true)]);
      expect(store.whereCalls, <(Object, Object?)>[
        ('customerUid', 'cust-1'),
        ('showId', 'show-1'),
        ('sessionId', '1900'),
        ('status', 'confirmed'),
      ]);

      store.mySeatsController.add(
        _FakeQuerySnapshot(<_FakeQueryDocumentSnapshot>[
          _FakeQueryDocumentSnapshot('b1', <String, dynamic>{
            'seats': <int>[9],
          }),
        ], isFromCache: true),
      );
      store.mySeatsController.add(
        _FakeQuerySnapshot(<_FakeQueryDocumentSnapshot>[
          _FakeQueryDocumentSnapshot('b2', <String, dynamic>{
            'seats': <int>[10],
          }),
        ], hasPendingWrites: true),
      );
      await pumpEventQueue();
      expect(emitted, isEmpty);

      store.mySeatsController.add(
        _FakeQuerySnapshot(<_FakeQueryDocumentSnapshot>[
          _FakeQueryDocumentSnapshot('b1', <String, dynamic>{
            'seats': <int>[1, 2],
          }),
          _FakeQueryDocumentSnapshot('b2', <String, dynamic>{
            'seats': <int>[5],
          }),
        ]),
      );
      await pumpEventQueue();
      expect(emitted, <Set<int>>[
        <int>{1, 2, 5},
      ]);

      auth.user = _FakeUser('cust-2');
      store.mySeatsController.add(
        _FakeQuerySnapshot(const <_FakeQueryDocumentSnapshot>[]),
      );
      await pumpEventQueue();
      expect(errors.single, isA<StateError>());
    });

    test('recover verifies ownership, server authority, absence, confirmed decode, and error resilience', () async {
      final store = _BookingStore();
      addTearDown(store.dispose);
      final auth = _StubAuth('cust-1');
      final repo = FirestoreBookingRepository(
        _FakeBookingFirestore(store),
        auth,
        _StreamingShowsRepository(),
      );

      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-2'),
        isA<RecoveryUnresolved>(),
      );
      expect(store.getCalls, isEmpty);

      auth.user = null;
      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-1'),
        isA<RecoveryUnresolved>(),
      );
      expect(store.getCalls, isEmpty);
      auth.user = _FakeUser('cust-1');

      store.setDoc('bookings/b1', bookingData(), isFromCache: true);
      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-1'),
        isA<RecoveryUnresolved>(),
      );

      store.setDoc('bookings/b1', bookingData(), hasPendingWrites: true);
      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-1'),
        isA<RecoveryUnresolved>(),
      );

      store.setDoc('bookings/b1', null);
      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-1'),
        isA<RecoveryAuthoritativelyAbsent>(),
      );

      store.setDoc('bookings/b1', bookingData(customerUid: 'cust-2'));
      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-1'),
        isA<RecoveryUnresolved>(),
      );

      store.setDoc('bookings/b1', bookingData(status: 'cancelled'));
      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-1'),
        isA<RecoveryUnresolved>(),
      );

      store.setDoc('bookings/b1', bookingData(seats: <int>[4, 3]));
      final confirmed = await repo.recover(
        bookingId: 'b1',
        customerUid: 'cust-1',
      );
      expect(confirmed, isA<RecoveryConfirmed>());
      final decoded = (confirmed as RecoveryConfirmed).booking;
      expect(decoded.request.seats, <int>{3, 4});
      expect(decoded.showTitle, 'Arena Show');
      expect(decoded.slotTime, SessionTime('19:00'));
      expect(
        store.getCalls.every(
          (call) =>
              call.$1 == 'bookings/b1' && call.$2?.source == Source.server,
        ),
        isTrue,
      );

      store.onBeforeGet = (_, _) {
        auth.user = null;
      };
      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-1'),
        isA<RecoveryUnresolved>(),
      );
      store.onBeforeGet = null;
      auth.user = _FakeUser('cust-1');

      store.onGet = (_, _) => StateError('network unavailable');
      expect(
        await repo.recover(bookingId: 'b1', customerUid: 'cust-1'),
        isA<RecoveryUnresolved>(),
      );
    });

    test('confirm writes 4-doc transaction atomically and handles idempotent replay, conflicts, and unavailable shows', () async {
      final store = _BookingStore()
        ..setDoc('shows/show-1', showData())
        ..setDoc('shows/show-1/sessions/1900', sessionData());
      addTearDown(store.dispose);
      final auth = _StubAuth('cust-1');
      final repo = FirestoreBookingRepository(
        _FakeBookingFirestore(store),
        auth,
        _StreamingShowsRepository(),
      );

      final req = makeRequest();
      final confirmed = await repo.confirm(req);
      expect(confirmed, isA<BookingConfirmed>());
      expect(store.transactionWrites, <String>[
        'update:shows/show-1',
        'update:shows/show-1/sessions/1900',
        'set:bookings/book-1',
        'set:bookingEvents/book-1',
      ]);
      expect(store.docs['shows/show-1']!.data!['bookedCount'], 4);
      expect(store.docs['shows/show-1']!.data!['lastBookingId'], 'book-1');
      expect(store.docs['shows/show-1/sessions/1900']!.data!['bookedSeats'], [
        1,
        2,
        3,
        4,
      ]);
      final bookingDoc = store.docs['bookings/book-1']!.data!;
      expect(bookingDoc['showId'], 'show-1');
      expect(bookingDoc['sessionId'], '1900');
      expect(bookingDoc['customerUid'], 'cust-1');
      expect(bookingDoc['seats'], <int>[3, 4]);
      expect(bookingDoc['showTitle'], 'Arena Show');
      expect(bookingDoc['showDate'], '2026-12-20');
      expect(bookingDoc['slotTime'], '19:00');
      expect(bookingDoc['vendorId'], 'vendor-1');
      expect(bookingDoc['status'], 'confirmed');
      expect(bookingDoc['createdAt'], isA<FieldValue>());

      final eventDoc = store.docs['bookingEvents/book-1']!.data!;
      expect(eventDoc['bookingId'], 'book-1');
      expect(eventDoc['kind'], 'booked');
      expect(eventDoc['showId'], 'show-1');
      expect(eventDoc['sessionId'], '1900');
      expect(eventDoc['seats'], <int>[3, 4]);
      expect(eventDoc['vendorId'], 'vendor-1');
      expect(eventDoc['showTitle'], 'Arena Show');
      expect(eventDoc['slotTime'], '19:00');
      expect(eventDoc['slotTotal'], 4);
      expect(eventDoc['showTotal'], 4);
      expect(eventDoc['createdAt'], isA<FieldValue>());

      // Idempotent replay with same request returns BookingConfirmed with no writes.
      store.transactionWrites.clear();
      expect(await repo.confirm(req), isA<BookingConfirmed>());
      expect(store.transactionWrites, isEmpty);

      // Mismatched existing booking returns BookingUnconfirmed.
      expect(
        await repo.confirm(makeRequest(seats: const <int>{5})),
        isA<BookingUnconfirmed>(),
      );

      // Non-authoritative prior booking returns BookingUnconfirmed.
      store.setDoc('bookings/book-1', bookingData(), isFromCache: true);
      expect(await repo.confirm(req), isA<BookingUnconfirmed>());

      // Overlapping seat returns BookingConflict with zero writes.
      store.transactionWrites.clear();
      final conflict = await repo.confirm(
        makeRequest(bookingId: 'book-2', seats: const <int>{2, 5}),
      );
      expect(conflict, isA<BookingConflict>());
      expect((conflict as BookingConflict).conflictSeats, <int>{2});
      expect(store.transactionWrites, isEmpty);

      // Missing or cache-only session rejects cleanly.
      store.setDoc('shows/show-1/sessions/1900', null);
      expect(
        await repo.confirm(makeRequest(bookingId: 'book-missing-slot')),
        isA<BookingUnavailable>(),
      );
      store.setDoc(
        'shows/show-1/sessions/1900',
        sessionData(),
        hasPendingWrites: true,
      );
      expect(
        await repo.confirm(makeRequest(bookingId: 'book-cached-slot')),
        isA<BookingUnconfirmed>(),
      );
      store.setDoc('shows/show-1/sessions/1900', sessionData());

      // Deleting or missing show returns BookingUnavailable.
      store.setDoc('shows/show-1', showData(status: 'deleting'));
      expect(
        await repo.confirm(makeRequest(bookingId: 'book-3')),
        isA<BookingUnavailable>(),
      );
      store.setDoc('shows/show-1', null);
      expect(
        await repo.confirm(makeRequest(bookingId: 'book-4')),
        isA<BookingUnavailable>(),
      );
    });

    test('confirm retries permission-denied only when server shows absent booking and changed revision, up to 3 attempts', () async {
      final store = _BookingStore()
        ..setDoc('shows/show-1', showData())
        ..setDoc('shows/show-1/sessions/1900', sessionData());
      addTearDown(store.dispose);
      final auth = _StubAuth('cust-1');
      final repo = FirestoreBookingRepository(
        _FakeBookingFirestore(store),
        auth,
        _StreamingShowsRepository(),
      );

      store.onBeforeTransactionCommit = (attempt) async {
        if (attempt < 3) {
          store.setDoc(
            'shows/show-1',
            showData(
              bookedCount: 3,
              lastBookingId: 'other-$attempt',
              updatedAt: Timestamp.fromDate(
                DateTime.utc(2026, 11, 20, 10, attempt),
              ),
            ),
          );
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        }
      };

      final okAfterRetry = await repo.confirm(
        makeRequest(bookingId: 'book-retry', seats: const <int>{6}),
      );
      expect(okAfterRetry, isA<BookingConfirmed>());
      expect(store.transactionAttempts, 3);
      expect(store.getCalls, hasLength(6));
      expect(
        store.getCalls.every((call) => call.$2?.source == Source.server),
        isTrue,
      );
      expect(store.getCalls.map((call) => call.$1), <String>[
        'bookings/book-retry',
        'shows/show-1',
        'shows/show-1/sessions/1900',
        'bookings/book-retry',
        'shows/show-1',
        'shows/show-1/sessions/1900',
      ]);

      // Slot-only revision change still triggers retry and succeeds on attempt 2.
      store.transactionAttempts = 0;
      store.getCalls.clear();
      store.setDoc('shows/show-1', showData());
      store.setDoc('shows/show-1/sessions/1900', sessionData());
      store.onBeforeTransactionCommit = (attempt) async {
        if (attempt == 1) {
          store.setDoc(
            'shows/show-1/sessions/1900',
            sessionData(
              bookedSeats: const <int>[1, 2, 10],
              lastBookingId: 'slot-only-change',
              updatedAt: Timestamp.fromDate(DateTime.utc(2026, 11, 20, 11, 0)),
            ),
          );
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        }
      };
      final slotRevisionRetry = await repo.confirm(
        makeRequest(bookingId: 'book-slot-retry', seats: const <int>{7}),
      );
      expect(slotRevisionRetry, isA<BookingConfirmed>());
      expect(store.transactionAttempts, 2);

      // Attempt 3 still failing permission-denied stops cleanly at 3 attempts.
      store.transactionAttempts = 0;
      store.getCalls.clear();
      store.onBeforeTransactionCommit = (attempt) async {
        store.setDoc(
          'shows/show-1',
          showData(
            lastBookingId: 'exhaust-$attempt',
            updatedAt: Timestamp.fromDate(
              DateTime.utc(2026, 11, 20, 12, attempt),
            ),
          ),
        );
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      };
      final exhausted = await repo.confirm(
        makeRequest(bookingId: 'book-exhaust', seats: const <int>{8}),
      );
      expect(exhausted, isA<BookingUnconfirmed>());
      expect(store.transactionAttempts, 3);
      expect(store.getCalls, hasLength(6));

      // Non-permission-denied FirebaseException aborts immediately without retry.
      store.transactionAttempts = 0;
      store.getCalls.clear();
      store.onBeforeTransactionCommit = (_) async {
        store.setDoc('shows/show-1', showData(lastBookingId: 'unavailable'));
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      };
      final unavailableError = await repo.confirm(
        makeRequest(bookingId: 'book-unavailable-err', seats: const <int>{8}),
      );
      expect(unavailableError, isA<BookingUnconfirmed>());
      expect(store.transactionAttempts, 1);
      expect(store.getCalls, isEmpty);

      // Revision unchanged -> aborts immediately without retrying.
      store.transactionAttempts = 0;
      store.onBeforeTransactionCommit = (_) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      };
      final unchanged = await repo.confirm(
        makeRequest(bookingId: 'book-no-retry', seats: const <int>{8}),
      );
      expect(unchanged, isA<BookingUnconfirmed>());
      expect(store.transactionAttempts, 1);

      // Existing booking on server -> aborts immediately without retrying.
      store.transactionAttempts = 0;
      store.onBeforeTransactionCommit = (_) async {
        store.setDoc('shows/show-1', showData(lastBookingId: 'changed'));
        store.setDoc('bookings/book-exists', bookingData());
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      };
      final alreadyCreated = await repo.confirm(
        makeRequest(bookingId: 'book-exists', seats: const <int>{8}),
      );
      expect(alreadyCreated, isA<BookingUnconfirmed>());
      expect(store.transactionAttempts, 1);

      // Non-authoritative show snapshot -> BookingUnconfirmed.
      store.transactionAttempts = 0;
      store.onBeforeTransactionCommit = null;
      store.setDoc('shows/show-1', showData(), isFromCache: true);
      expect(
        await repo.confirm(
          makeRequest(bookingId: 'book-cached', seats: const <int>{9}),
        ),
        isA<BookingUnconfirmed>(),
      );

      // Unauthenticated, wrong account, or mid-flight sign-out -> BookingUnconfirmed.
      store.setDoc('shows/show-1', showData());
      store.transactionAttempts = 0;
      auth.user = null;
      expect(
        await repo.confirm(
          makeRequest(bookingId: 'book-signed-out', seats: const <int>{9}),
        ),
        isA<BookingUnconfirmed>(),
      );
      expect(store.transactionAttempts, 0);

      auth.user = _FakeUser('cust-2');
      expect(
        await repo.confirm(
          makeRequest(bookingId: 'book-wrong-user', seats: const <int>{9}),
        ),
        isA<BookingUnconfirmed>(),
      );
      expect(store.transactionAttempts, 0);

      auth.user = _FakeUser('cust-1');
      store.onBeforeTransactionCommit = (_) async {
        auth.user = null;
      };
      expect(
        await repo.confirm(
          makeRequest(
            bookingId: 'book-midflight-logout',
            seats: const <int>{9},
          ),
        ),
        isA<BookingUnconfirmed>(),
      );
    });
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

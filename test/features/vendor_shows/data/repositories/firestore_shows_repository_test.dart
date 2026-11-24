import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/data/repositories/firestore_shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: subtype_of_sealed_class

final class _FakeVendorAccessRepository implements VendorAccessRepository {
  _FakeVendorAccessRepository(this.access, {this.onCheck});

  final VendorAccess access;
  final Future<VendorAccess> Function()? onCheck;

  @override
  Future<VendorAccess> check() =>
      onCheck != null ? onCheck!() : Future<VendorAccess>.value(access);
}

class _ShowStore {
  _ShowStore({
    required this.deletingShows,
    this.failShowId,
    StreamController<QuerySnapshot<Map<String, dynamic>>>?
    showsQueryStreamController,
  }) : showsQueryStreamController =
           showsQueryStreamController ??
           StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

  final Map<String, Map<String, dynamic>> deletingShows;
  final String? failShowId;
  final List<String> attemptedShowIds = <String>[];
  final List<String> deletedPaths = <String>[];
  final List<String> _stagedDeletes = <String>[];
  final Map<String, Map<String, dynamic>> showImages =
      <String, Map<String, dynamic>>{};
  final List<List<String>> bookingEventBatches = <List<String>>[];
  final Map<String, List<(String id, Map<String, dynamic> data)>>
  sessionDocsByShow = <String, List<(String, Map<String, dynamic>)>>{};
  final List<(String path, Map<String, dynamic> data)> updates =
      <(String, Map<String, dynamic>)>[];
  final List<(String path, Map<String, dynamic> data)> transactionSets =
      <(String, Map<String, dynamic>)>[];
  final List<(String showId, GetOptions? options)> posterGetCalls =
      <(String, GetOptions?)>[];
  final List<(String path, String field, Object? isEqualTo)> whereCalls =
      <(String, String, Object?)>[];
  final List<(String path, String field, bool descending)> orderByCalls =
      <(String, String, bool)>[];
  final List<(String path, int limit)> limitCalls = <(String, int)>[];
  final List<(String path, GetOptions? options)> queryGetCalls =
      <(String, GetOptions?)>[];
  final List<(String path, bool includeMetadataChanges)> snapshotCalls =
      <(String, bool)>[];
  int generatedIdCounter = 0;
  int runTransactionCalls = 0;
  Future<void> Function(String showId)? onBeforeShowGet;
  Future<void> Function(String showId)? onBeforePosterGet;
  final StreamController<DocumentSnapshot<Map<String, dynamic>>>
  showStreamController =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
  final StreamController<QuerySnapshot<Map<String, dynamic>>>
  showsQueryStreamController;
  final StreamController<QuerySnapshot<Map<String, dynamic>>>
  sessionsStreamController =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

  Future<void> dispose() async {
    await showStreamController.close();
    await showsQueryStreamController.close();
    await sessionsStreamController.close();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchDeletingShows() async {
    return _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
      for (final entry in deletingShows.entries)
        _FakeQueryDocumentSnapshot(entry.key, entry.value),
    ]);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchDoc(
    String collection,
    String id,
    GetOptions? options,
  ) async {
    if (collection == 'shows') {
      attemptedShowIds.add(id);
      await onBeforeShowGet?.call(id);
      if (id == failShowId) {
        return _failingShowRead();
      }
      final data = deletingShows[id];
      return _FakeDocumentSnapshot(id, data);
    }
    if (collection == 'showImages') {
      posterGetCalls.add((id, options));
      await onBeforePosterGet?.call(id);
      return _FakeDocumentSnapshot(id, showImages[id]);
    }
    return _FakeDocumentSnapshot(id, null);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _failingShowRead() async {
    throw StateError('forced failure on $failShowId');
  }
}

final class _FakeFirestore extends Fake implements FirebaseFirestore {
  _FakeFirestore(this.store);

  final _ShowStore store;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollectionReference(collectionPath, store);

  @override
  WriteBatch batch() => _FakeWriteBatch(store);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    store.runTransactionCalls++;
    final tx = _FakeTransaction(store);
    final result = await transactionHandler(tx);
    tx.apply();
    return result;
  }
}

final class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this.path, this.store);

  @override
  final String path;
  final _ShowStore store;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocumentReference(
        this.path,
        path ?? 'generated-${++store.generatedIdCounter}',
        store,
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
  }) => _FakeQuery(path, store).where(
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

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    store.snapshotCalls.add((path, includeMetadataChanges));
    if (path == 'shows') {
      return store.showsQueryStreamController.stream;
    }
    return store.sessionsStreamController.stream;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _FakeQuery(path, store).get(options);
}

final class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery(this.path, this.store);

  final String path;
  final _ShowStore store;

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
    store.whereCalls.add((path, field.toString(), isEqualTo));
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    store.orderByCalls.add((path, field.toString(), descending));
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    store.limitCalls.add((path, limit));
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    store.snapshotCalls.add((path, includeMetadataChanges));
    if (path == 'shows') {
      return store.showsQueryStreamController.stream;
    }
    return store.sessionsStreamController.stream;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.queryGetCalls.add((path, options));
    if (path == 'shows') {
      return store.fetchDeletingShows();
    }
    if (path == 'bookingEvents') {
      final batchIds = store.bookingEventBatches.isEmpty
          ? const <String>[]
          : store.bookingEventBatches.removeAt(0);
      return _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
        for (final id in batchIds)
          _FakeQueryDocumentSnapshot(
            id,
            <String, dynamic>{'bookingId': id},
            referenceOverride: _FakeDocumentReference(
              'bookingEvents',
              id,
              store,
            ),
          ),
      ]);
    }
    if (path.startsWith('shows/') && path.endsWith('/sessions')) {
      final showId = path.split('/')[1];
      final docs = store.sessionDocsByShow[showId] ?? const [];
      return _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
        for (final entry in docs)
          _FakeQueryDocumentSnapshot(entry.$1, entry.$2),
      ]);
    }
    return _FakeQuerySnapshot(
      const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    );
  }
}

final class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference(this.collectionPath, this.id, this.store);

  final String collectionPath;
  @override
  final String id;
  final _ShowStore store;

  @override
  String get path => '$collectionPath/$id';

  @override
  CollectionReference<Map<String, dynamic>> collection(String subPath) =>
      _FakeCollectionReference('$collectionPath/$id/$subPath', store);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      store.fetchDoc(collectionPath, id, options);

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    store.snapshotCalls.add((path, includeMetadataChanges));
    return store.showStreamController.stream;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final normalized = data.map((k, v) => MapEntry(k.toString(), v));
    store.updates.add((path, normalized));
    if (collectionPath == 'shows' && store.deletingShows[id] != null) {
      store.deletingShows[id] = <String, dynamic>{
        ...store.deletingShows[id]!,
        ...normalized,
      };
    }
  }

  @override
  Future<void> delete() async {
    store.deletedPaths.add(path);
    if (collectionPath == 'shows') {
      store.deletingShows.remove(id);
    }
  }
}

final class _FakeTransaction extends Fake implements Transaction {
  _FakeTransaction(this.store);

  final _ShowStore store;
  final List<(String path, Map<String, dynamic> data)> _stagedSets =
      <(String, Map<String, dynamic>)>[];

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _stagedSets.add((
      documentReference.path,
      Map<String, dynamic>.from(data as Map),
    ));
    return this;
  }

  void apply() {
    for (final entry in _stagedSets) {
      store.transactionSets.add(entry);
      final parts = entry.$1.split('/');
      if (parts.length == 2 && parts[0] == 'shows') {
        store.deletingShows[parts[1]] = entry.$2;
      } else if (parts.length == 2 && parts[0] == 'showImages') {
        store.showImages[parts[1]] = entry.$2;
      } else if (parts.length == 4 &&
          parts[0] == 'shows' &&
          parts[2] == 'sessions') {
        (store.sessionDocsByShow[parts[1]] ??=
                <(String, Map<String, dynamic>)>[])
            .add((parts[3], entry.$2));
      }
    }
  }
}

final class _FakeWriteBatch extends Fake implements WriteBatch {
  _FakeWriteBatch(this.store);

  final _ShowStore store;

  @override
  void delete(DocumentReference<Object?> document) {
    store._stagedDeletes.add(document.path);
  }

  @override
  Future<void> commit() async {
    store.deletedPaths.addAll(store._stagedDeletes);
    store._stagedDeletes.clear();
  }
}

final class _FakeSnapshotMetadata extends Fake implements SnapshotMetadata {
  _FakeSnapshotMetadata({this.isFromCache = false});

  @override
  final bool isFromCache;
}

final class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

final class _FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocumentSnapshot(this.id, this._data, {this.referenceOverride});

  @override
  final String id;
  final Map<String, dynamic> _data;
  final DocumentReference<Map<String, dynamic>>? referenceOverride;

  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      referenceOverride ??
      (throw UnimplementedError('No DocumentReference configured'));

  @override
  Map<String, dynamic> data() => _data;
}

final class _FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot(this.id, this._data, {bool isFromCache = false})
    : metadata = _FakeSnapshotMetadata(isFromCache: isFromCache);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  final SnapshotMetadata metadata;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resumeDeletes continues after first failed show and surfaces first error with stack trace', () async {
    final store = _ShowStore(
      failShowId: 'show-fail',
      deletingShows: <String, Map<String, dynamic>>{
        'show-fail': <String, dynamic>{
          'vendorId': 'vendor-a',
          'status': 'deleting',
          'sessionIds': const <String>['1900'],
        },
        'show-ok': <String, dynamic>{
          'vendorId': 'vendor-a',
          'status': 'deleting',
          'sessionIds': const <String>['1900'],
        },
      },
    );
    final repository = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
    );

    Object? caughtError;
    StackTrace? caughtStack;
    try {
      await repository.resumeDeletes('vendor-a');
    } catch (error, stackTrace) {
      caughtError = error;
      caughtStack = stackTrace;
    }

    expect(caughtError, isA<StateError>());
    expect(caughtError.toString(), contains('forced failure on show-fail'));
    expect(caughtStack.toString(), contains('_failingShowRead'));
    expect(store.attemptedShowIds, <String>['show-fail', 'show-ok']);
    expect(
      store.deletedPaths,
      containsAllInOrder(<String>[
        'shows/show-ok/sessions/1900',
        'shows/show-ok',
      ]),
    );
    expect(store.deletingShows.containsKey('show-ok'), isFalse);
    expect(store.deletingShows.containsKey('show-fail'), isTrue);
  });

  test('watchActiveShows rejects non-positive limit, queries active shows descending, and decodes docs', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    final repo = FirestoreShowsRepository(_FakeFirestore(store));

    expect(() => repo.watchActiveShows(limit: 0), throwsArgumentError);

    final emitted = <List<Show>>[];
    final sub = repo.watchActiveShows(limit: 25).listen(emitted.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    expect(store.whereCalls, contains(('shows', 'status', 'active')));
    expect(store.orderByCalls, contains(('shows', 'createdAt', true)));
    expect(store.limitCalls, contains(('shows', 25)));

    final createdAt = DateTime.utc(2026, 11, 20, 12);
    final updatedAt = DateTime.utc(2026, 11, 20, 13);
    store.showsQueryStreamController.add(
      _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
        _FakeQueryDocumentSnapshot('show-a', <String, dynamic>{
          'vendorId': 'vendor-a',
          'title': 'Skyline Jam',
          'description': 'Live concert',
          'showDate': '2026-12-20',
          'imageId': 'show-a',
          'status': 'active',
          'bookedCount': 4,
          'lastBookingId': 'b-4',
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(updatedAt),
        }),
      ]),
    );
    await pumpEventQueue();

    expect(emitted, hasLength(1));
    final show = emitted.single.single;
    expect(show.id, 'show-a');
    expect(show.vendorId, 'vendor-a');
    expect(show.title, 'Skyline Jam');
    expect(show.description, 'Live concert');
    expect(show.showDate, '2026-12-20');
    expect(show.imageId, 'show-a');
    expect(show.status, ShowStatus.active);
    expect(show.bookedCount, 4);
    expect(show.lastBookingId, 'b-4');
    expect(show.createdAt?.toUtc(), createdAt);
    expect(show.updatedAt?.toUtc(), updatedAt);
  });

  test('watchVendorShows gates vendor enrollment and queries vendor-scoped shows descending', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);

    final customerRepo = FirestoreShowsRepository(_FakeFirestore(store));
    await expectLater(
      customerRepo.watchVendorShows('vendor-a').first,
      throwsUnsupportedError,
    );

    final notEnrolledRepo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorNotEnrolled(uid: 'anon-1'),
      ),
    );
    await expectLater(
      notEnrolledRepo.watchVendorShows('vendor-a').first,
      throwsStateError,
    );

    final otherVendorRepo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-b'),
      ),
    );
    await expectLater(
      otherVendorRepo.watchVendorShows('vendor-a').first,
      throwsStateError,
    );

    final repo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
    );
    final emitted = <List<Show>>[];
    final sub = repo.watchVendorShows('vendor-a').listen(emitted.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    expect(store.whereCalls, contains(('shows', 'vendorId', 'vendor-a')));
    expect(store.orderByCalls, contains(('shows', 'createdAt', true)));

    store.showsQueryStreamController.add(
      _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
        _FakeQueryDocumentSnapshot('show-v1', <String, dynamic>{
          'vendorId': 'vendor-a',
          'title': 'Vendor Show',
          'description': 'Desc',
          'showDate': '2026-12-22',
          'imageId': 'show-v1',
          'status': 'active',
          'bookedCount': 0,
          'lastBookingId': '',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 21)),
          'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 21)),
        }),
      ]),
    );
    await pumpEventQueue();

    expect(emitted.single.single.id, 'show-v1');
    expect(emitted.single.single.vendorId, 'vendor-a');
  });

  test('watchShow suppresses cache-only missing snapshot and decodes server-confirmed docs', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    final repo = FirestoreShowsRepository(_FakeFirestore(store));

    final emitted = <Show?>[];
    final sub = repo.watchShow('show-1').listen(emitted.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(store.snapshotCalls, contains(('shows/show-1', true)));

    store.showStreamController.add(
      _FakeDocumentSnapshot('show-1', null, isFromCache: true),
    );
    await pumpEventQueue();
    expect(emitted, isEmpty);

    store.showStreamController.add(
      _FakeDocumentSnapshot('show-1', null, isFromCache: false),
    );
    await pumpEventQueue();
    expect(emitted, <Show?>[null]);

    store.showStreamController.add(
      _FakeDocumentSnapshot('show-1', <String, dynamic>{
        'vendorId': 'vendor-a',
        'title': 'Finals',
        'description': 'Match',
        'showDate': '2026-12-20',
        'imageId': 'show-1',
        'status': 'active',
        'bookedCount': 2,
        'lastBookingId': 'b1',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 20)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 20)),
      }),
    );
    await pumpEventQueue();
    expect(emitted, hasLength(2));
    expect(emitted.last?.title, 'Finals');
    expect(emitted.last?.bookedCount, 2);
  });

  test(
    'watchSessions decodes valid sessions and rejects invalid capacity',
    () async {
      final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
      addTearDown(store.dispose);
      final repo = FirestoreShowsRepository(_FakeFirestore(store));

      final emitted = <List<Session>>[];
      final errors = <Object>[];
      final sub = repo
          .watchSessions('show-1')
          .listen(emitted.add, onError: errors.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(store.snapshotCalls, contains(('shows/show-1/sessions', false)));

      store.sessionsStreamController.add(
        _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
          _FakeQueryDocumentSnapshot('1900', <String, dynamic>{
            'time': '19:00',
            'label': 'Evening',
            'capacity': 47,
            'bookedSeats': <int>[1, 2],
            'lastBookingId': 'b1',
          }),
        ]),
      );
      await pumpEventQueue();
      expect(emitted, hasLength(1));
      final session = emitted.single.single;
      expect(session.id, '1900');
      expect(session.time, SessionTime('19:00'));
      expect(session.label, 'Evening');
      expect(session.bookedSeats, <int>{1, 2});
      expect(session.lastBookingId, 'b1');

      store.sessionsStreamController.add(
        _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
          _FakeQueryDocumentSnapshot('1900', <String, dynamic>{
            'time': '19:00',
            'capacity': 50,
            'bookedSeats': <int>[],
            'lastBookingId': '',
          }),
        ]),
      );
      await pumpEventQueue();
      expect(errors.single, isA<FormatException>());
    },
  );

  test('loadPoster fetches from server, returns defensive copy, enforces 32-entry LRU, skips empty payloads, and guards clear/dispose', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    for (var i = 0; i < 33; i++) {
      store.showImages['s$i'] = <String, dynamic>{
        'poster': Blob(Uint8List.fromList(<int>[i, 2, 3])),
      };
    }
    store.showImages['empty-blob'] = <String, dynamic>{
      'poster': Blob(Uint8List(0)),
    };
    final repo = FirestoreShowsRepository(_FakeFirestore(store));

    // Missing or empty poster returns null without populating cache.
    expect(await repo.loadPoster('missing-img'), isNull);
    expect(await repo.loadPoster('missing-img'), isNull);
    expect(await repo.loadPoster('empty-blob'), isNull);
    expect(await repo.loadPoster('empty-blob'), isNull);
    expect(store.posterGetCalls.map((c) => c.$1), <String>[
      'missing-img',
      'missing-img',
      'empty-blob',
      'empty-blob',
    ]);
    store.posterGetCalls.clear();

    final first = await repo.loadPoster('s0');
    expect(first, <int>[0, 2, 3]);
    expect(store.posterGetCalls.single.$2?.source, Source.server);
    first![0] = 99;
    final cached = await repo.loadPoster('s0');
    expect(cached, <int>[0, 2, 3]);
    expect(store.posterGetCalls.map((c) => c.$1), <String>['s0']);

    // Load s1..s32 so total unique keys = 33; s0 should be evicted (LRU).
    for (var i = 1; i < 33; i++) {
      await repo.loadPoster('s$i');
    }
    expect(store.posterGetCalls, hasLength(33));

    // Re-reading s1 hits cache (no fetch), whereas s0 was evicted and re-fetches.
    await repo.loadPoster('s1');
    expect(store.posterGetCalls, hasLength(33));
    await repo.loadPoster('s0');
    expect(store.posterGetCalls, hasLength(34));

    // Mid-flight clearPosterCache discards in-flight loadPoster result.
    final gate = Completer<void>();
    store.onBeforePosterGet = (_) => gate.future;
    final inFlight = repo.loadPoster('s2');
    await pumpEventQueue();
    repo.clearPosterCache();
    store.onBeforePosterGet = null;
    gate.complete();
    expect(await inFlight, isNull);

    // clearPosterCache also evicted s1 so a new read fetches from server again.
    final countAfterClear = store.posterGetCalls.length;
    expect(await repo.loadPoster('s1'), <int>[1, 2, 3]);
    expect(store.posterGetCalls, hasLength(countAfterClear + 1));

    repo.dispose();
    expect(await repo.loadPoster('s1'), isNull);
    expect(store.posterGetCalls, hasLength(countAfterClear + 1));
  });

  test('invalidatePoster evicts only target show, discards matching in-flight load without dropping sibling loads, and cleans up per-show tracking', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[1, 2, 3])),
    };
    store.showImages['show-b'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[4, 5, 6])),
    };
    store.showImages['show-c'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[7, 8, 9])),
    };

    final repo = FirestoreShowsRepository(_FakeFirestore(store));

    // 1. Invalidating show-a evicts only show-a while preserving show-b cached.
    expect(await repo.loadPoster('show-a'), <int>[1, 2, 3]);
    expect(await repo.loadPoster('show-b'), <int>[4, 5, 6]);
    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[10, 20, 30])),
    };
    repo.invalidatePoster('show-a');

    final getsBeforeSiblingRead = store.posterGetCalls.length;
    expect(await repo.loadPoster('show-b'), <int>[4, 5, 6]);
    expect(store.posterGetCalls, hasLength(getsBeforeSiblingRead));

    expect(await repo.loadPoster('show-a'), <int>[10, 20, 30]);
    expect(store.posterGetCalls, hasLength(getsBeforeSiblingRead + 1));

    // 2. Mid-flight invalidatePoster(show-a) discards in-flight show-a while concurrent show-c still caches.
    repo.invalidatePoster('show-a');
    final gateA = Completer<void>();
    final gateC = Completer<void>();
    store.onBeforePosterGet = (id) => switch (id) {
      'show-a' => gateA.future,
      'show-c' => gateC.future,
      _ => Future<void>.value(),
    };

    final inFlightA = repo.loadPoster('show-a');
    final inFlightC = repo.loadPoster('show-c');
    await pumpEventQueue();

    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[99, 98, 97])),
    };
    repo.invalidatePoster('show-a');

    store.onBeforePosterGet = null;
    gateA.complete();
    gateC.complete();

    expect(await inFlightA, isNull);
    expect(await inFlightC, <int>[7, 8, 9]);

    // show-c is cached and show-b remains cached; show-a was not repopulated and fresh load caches new bytes.
    final getsAfterConcurrent = store.posterGetCalls.length;
    expect(await repo.loadPoster('show-c'), <int>[7, 8, 9]);
    expect(await repo.loadPoster('show-b'), <int>[4, 5, 6]);
    expect(store.posterGetCalls, hasLength(getsAfterConcurrent));

    expect(await repo.loadPoster('show-a'), <int>[99, 98, 97]);
    expect(store.posterGetCalls, hasLength(getsAfterConcurrent + 1));
    expect(await repo.loadPoster('show-a'), <int>[99, 98, 97]);
    expect(store.posterGetCalls, hasLength(getsAfterConcurrent + 1));

    // 3. Error during loadPoster decrements in-flight count cleanly so subsequent loads work.
    repo.invalidatePoster('show-a');
    store.onBeforePosterGet = (id) => id == 'show-a'
        ? Future<void>.error(StateError('transient read failure'))
        : Future<void>.value();
    await expectLater(repo.loadPoster('show-a'), throwsStateError);

    store.onBeforePosterGet = null;
    repo.invalidatePoster('show-a');
    expect(await repo.loadPoster('show-a'), <int>[99, 98, 97]);
  });

  test('concurrent same-show loadPoster calls keep per-show generation intact across refcount decrements until all stale loads finish', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[1, 2, 3])),
    };

    final repo = FirestoreShowsRepository(_FakeFirestore(store));
    final gates = <Completer<void>>[];
    store.onBeforePosterGet = (id) {
      if (id != 'show-a') return Future<void>.value();
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    };

    // Sub-case A: Call 1 + Call 2 -> invalidate -> Call 3 -> complete 1 -> 2 -> 3.
    final call1 = repo.loadPoster('show-a');
    final call2 = repo.loadPoster('show-a');
    await pumpEventQueue();
    expect(gates, hasLength(2));

    repo.invalidatePoster('show-a');
    final call3 = repo.loadPoster('show-a');
    await pumpEventQueue();
    expect(gates, hasLength(3));

    gates[0].complete();
    expect(await call1, isNull);
    gates[1].complete();
    expect(await call2, isNull);

    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[20, 21, 22])),
    };
    gates[2].complete();
    expect(await call3, <int>[20, 21, 22]);

    final getsAfterCall3 = store.posterGetCalls.length;
    expect(await repo.loadPoster('show-a'), <int>[20, 21, 22]);
    expect(store.posterGetCalls, hasLength(getsAfterCall3));

    // Sub-case B: Call 1 finishes after invalidate and BEFORE Call 3 starts while Call 2 stays active.
    gates.clear();
    repo.invalidatePoster('show-a');
    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[1, 2, 3])),
    };

    final subCall1 = repo.loadPoster('show-a');
    final subCall2 = repo.loadPoster('show-a');
    await pumpEventQueue();
    expect(gates, hasLength(2));

    repo.invalidatePoster('show-a');
    gates[0].complete();
    expect(await subCall1, isNull);

    final subCall3 = repo.loadPoster('show-a');
    await pumpEventQueue();
    expect(gates, hasLength(3));

    gates[1].complete();
    expect(await subCall2, isNull);

    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[30, 31, 32])),
    };
    gates[2].complete();
    expect(await subCall3, <int>[30, 31, 32]);

    final getsAfterSubCall3 = store.posterGetCalls.length;
    expect(await repo.loadPoster('show-a'), <int>[30, 31, 32]);
    expect(store.posterGetCalls, hasLength(getsAfterSubCall3));
  });

  test('overlapping clearPosterCache and invalidatePoster across concurrent same-show loads discards both and lets subsequent load fetch and cache fresh bytes', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[1, 2, 3])),
    };

    final repo = FirestoreShowsRepository(_FakeFirestore(store));
    final gates = <Completer<void>>[];
    store.onBeforePosterGet = (id) {
      if (id != 'show-a') return Future<void>.value();
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    };

    final call1 = repo.loadPoster('show-a');
    await pumpEventQueue();
    expect(gates, hasLength(1));

    repo.clearPosterCache();

    final call2 = repo.loadPoster('show-a');
    await pumpEventQueue();
    expect(gates, hasLength(2));

    repo.invalidatePoster('show-a');
    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[44, 55, 66])),
    };

    gates[0].complete();
    expect(await call1, isNull);
    gates[1].complete();
    expect(await call2, isNull);

    store.onBeforePosterGet = null;
    final getsBeforeFresh = store.posterGetCalls.length;
    expect(await repo.loadPoster('show-a'), <int>[44, 55, 66]);
    expect(store.posterGetCalls, hasLength(getsBeforeFresh + 1));

    expect(await repo.loadPoster('show-a'), <int>[44, 55, 66]);
    expect(store.posterGetCalls, hasLength(getsBeforeFresh + 1));
  });

  test('in-flight loadPoster started before or during deleteShow resolves null and never repopulates cache', () async {
    final store = _ShowStore(
      deletingShows: <String, Map<String, dynamic>>{
        'show-a': <String, dynamic>{
          'vendorId': 'vendor-a',
          'status': 'active',
          'sessionIds': const <String>[],
        },
      },
    );
    addTearDown(store.dispose);
    store.showImages['show-a'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[1, 2, 3])),
    };
    store.showImages['show-b'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[4, 5, 6])),
    };

    final repo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
    );

    // 1. Pre-cache show-b and pause a loadPoster('show-a') started BEFORE deleteShow.
    expect(await repo.loadPoster('show-b'), <int>[4, 5, 6]);
    final preDeletePosterGate = Completer<void>();
    store.onBeforePosterGet = (id) =>
        id == 'show-a' ? preDeletePosterGate.future : Future<void>.value();
    final preDeleteLoad = repo.loadPoster('show-a');
    await pumpEventQueue();

    // Start deleteShow('show-a') paused on show get to also test loadPoster DURING deleteShow.
    final deleteGate = Completer<void>();
    store.onBeforeShowGet = (id) =>
        id == 'show-a' ? deleteGate.future : Future<void>.value();
    final deleteFuture = repo.deleteShow('show-a');
    await pumpEventQueue();

    // A loadPoster('show-a') started DURING deleteShow must resolve null immediately
    // without touching showImages, while show-b remains cached.
    final getCountBeforeDuring = store.posterGetCalls.length;
    expect(await repo.loadPoster('show-a'), isNull);
    expect(store.posterGetCalls, hasLength(getCountBeforeDuring));
    expect(await repo.loadPoster('show-b'), <int>[4, 5, 6]);

    // Finish deleteShow, then release pre-delete loadPoster('show-a').
    store.onBeforeShowGet = null;
    store.onBeforePosterGet = null;
    deleteGate.complete();
    await deleteFuture;

    preDeletePosterGate.complete();
    expect(await preDeleteLoad, isNull);

    // Confirm _posters['show-a'] was NOT repopulated by preDeleteLoad:
    // if _posters['show-a'] had been populated, this call would hit cache instead of server.
    final getCountAfterDelete = store.posterGetCalls.length;
    await repo.loadPoster('show-a');
    expect(store.posterGetCalls, hasLength(getCountAfterDelete + 1));
  });

  test('addShow validates inputs, enforces vendor enrollment, and writes atomic 3-collection show transaction', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    final jpegBytes = File('test/fixtures/posters/skyline_jam.jpg')
        .readAsBytesSync();
    NewShow validShow({
      String vendorId = 'vendor-a',
      String? title,
      String? description,
      List<SessionTime>? sessions,
    }) => NewShow(
      vendorId: vendorId,
      title: title ?? 'Skyline Jam',
      description: description ?? 'Outdoor synth showcase',
      showDate: '2026-12-20',
      sessions:
          sessions ?? <SessionTime>[SessionTime('14:00'), SessionTime('19:00')],
    );

    final customerRepo = FirestoreShowsRepository(_FakeFirestore(store));
    await expectLater(
      customerRepo.addShow(validShow(), jpegBytes),
      throwsUnsupportedError,
    );

    final wrongVendorRepo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-b'),
      ),
    );
    await expectLater(
      wrongVendorRepo.addShow(validShow(), jpegBytes),
      throwsStateError,
    );

    final repo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
    );
    final validHeader = Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xe0]);

    await expectLater(
      repo.addShow(validShow(title: 'a' * 81), validHeader),
      throwsArgumentError,
    );
    await expectLater(
      repo.addShow(validShow(description: 'd' * 1001), validHeader),
      throwsArgumentError,
    );
    await expectLater(
      repo.addShow(validShow(), Uint8List(0)),
      throwsArgumentError,
    );
    await expectLater(
      repo.addShow(validShow(), Uint8List.fromList(<int>[0xff, 0xd8])),
      throwsArgumentError,
    );
    await expectLater(
      repo.addShow(validShow(), Uint8List.fromList(<int>[0x89, 0x50, 0x4e])),
      throwsArgumentError,
    );
    await expectLater(
      repo.addShow(
        validShow(),
        Uint8List(204801)
          ..[0] = 0xff
          ..[1] = 0xd8
          ..[2] = 0xff,
      ),
      throwsArgumentError,
    );

    await repo.addShow(validShow(), jpegBytes);

    expect(store.transactionSets.map((entry) => entry.$1), <String>[
      'shows/generated-1',
      'showImages/generated-1',
      'shows/generated-1/sessions/1400',
      'shows/generated-1/sessions/1900',
    ]);
    final showDoc = store.deletingShows['generated-1']!;
    expect(showDoc['vendorId'], 'vendor-a');
    expect(showDoc['title'], 'Skyline Jam');
    expect(showDoc['titleSearch'], 'skyline jam');
    expect(showDoc['description'], 'Outdoor synth showcase');
    expect(showDoc['showDate'], '2026-12-20');
    expect(showDoc['imageId'], 'generated-1');
    expect(showDoc['sessionIds'], <String>['1400', '1900']);
    expect(showDoc['status'], 'active');
    expect(showDoc['bookedCount'], 0);
    expect(showDoc['lastBookingId'], '');
    expect(showDoc['createdAt'], isA<FieldValue>());
    expect(showDoc['updatedAt'], isA<FieldValue>());

    final imageDoc = store.showImages['generated-1']!;
    expect(imageDoc['vendorId'], 'vendor-a');
    expect(imageDoc['mimeType'], 'image/jpeg');
    expect(imageDoc['width'], greaterThan(0));
    expect(imageDoc['height'], greaterThan(0));
    expect((imageDoc['poster'] as Blob).bytes, jpegBytes);

    final sessions = store.sessionDocsByShow['generated-1']!;
    expect(sessions.map((s) => s.$1), <String>['1400', '1900']);
    expect(sessions[0].$2['time'], '14:00');
    expect(sessions[0].$2['capacity'], 47);
    expect(sessions[0].$2['bookedSeats'], isEmpty);
    expect(sessions[0].$2['lastBookingId'], '');
    expect(sessions[0].$2['updatedAt'], isA<FieldValue>());
    expect(sessions[1].$2['time'], '19:00');
  });

  test('addShow uses injected readImageDimensions to persist width and height without dart:ui decoding', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    // Header-only JPEG bytes would fail dart:ui.instantiateImageCodec decoding.
    final headerOnlyPoster = Uint8List.fromList(<int>[
      0xff,
      0xd8,
      0xff,
      0xe0,
      0x01,
      0x02,
    ]);
    Uint8List? receivedBytes;

    final repo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
      readImageDimensions: (bytes) async {
        receivedBytes = bytes;
        return (1280, 720);
      },
    );

    await repo.addShow(
      NewShow(
        vendorId: 'vendor-a',
        title: 'Synthetic Dimensions',
        description: 'Uses injected dimension reader',
        showDate: '2026-12-21',
        sessions: <SessionTime>[SessionTime('14:00')],
      ),
      headerOnlyPoster,
    );

    expect(receivedBytes, headerOnlyPoster);
    expect(store.runTransactionCalls, 1);
    expect(store.transactionSets.map((entry) => entry.$1), <String>[
      'shows/generated-1',
      'showImages/generated-1',
      'shows/generated-1/sessions/1400',
    ]);
    final imageDoc = store.showImages['generated-1']!;
    expect(imageDoc['vendorId'], 'vendor-a');
    expect(imageDoc['mimeType'], 'image/jpeg');
    expect(imageDoc['width'], 1280);
    expect(imageDoc['height'], 720);
    expect((imageDoc['poster'] as Blob).bytes, headerOnlyPoster);
  });

  test('addShow rethrows readImageDimensions errors before vendor check or Firestore transaction', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    var vendorCheckCalls = 0;
    final headerOnlyPoster = Uint8List.fromList(<int>[
      0xff,
      0xd8,
      0xff,
      0xe0,
      0x01,
      0x02,
    ]);
    final show = NewShow(
      vendorId: 'vendor-a',
      title: 'Corrupt Poster Show',
      description: 'Should fail before vendor check or writes',
      showDate: '2026-12-21',
      sessions: <SessionTime>[SessionTime('14:00')],
    );

    Future<void> expectThrowsAndNoSideEffects(Object error) async {
      final repo = FirestoreShowsRepository(
        _FakeFirestore(store),
        vendorAccess: _FakeVendorAccessRepository(
          VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
          onCheck: () async {
            vendorCheckCalls++;
            return VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a');
          },
        ),
        readImageDimensions: (_) async => throw error,
      );

      await expectLater(
        repo.addShow(show, headerOnlyPoster),
        throwsA(same(error)),
      );
      expect(vendorCheckCalls, 0);
      expect(store.runTransactionCalls, 0);
      expect(store.generatedIdCounter, 0);
      expect(store.transactionSets, isEmpty);
      expect(store.deletingShows, isEmpty);
      expect(store.showImages, isEmpty);
      expect(store.sessionDocsByShow, isEmpty);
    }

    await expectThrowsAndNoSideEffects(
      const FormatException('Corrupt JPEG body'),
    );
    await expectThrowsAndNoSideEffects(StateError('Image codec failed'));
  });

  test('deleteShow validates inputs, guards ownership, coalesces calls, chunks <=3 pairs per batch, and deletes parent last', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);

    final customerRepo = FirestoreShowsRepository(_FakeFirestore(store));
    expect(() => customerRepo.deleteShow(' '), throwsArgumentError);
    await expectLater(
      customerRepo.deleteShow('show-1'),
      throwsUnsupportedError,
    );

    final batchHooks = <(int, int)>[];
    final repo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
      onDeletePairBatchCommitted: (index, pairCount) async {
        batchHooks.add((index, pairCount));
      },
    );

    // Missing show completes idempotently.
    await repo.deleteShow('missing-show');
    expect(store.deletedPaths, isEmpty);

    // Show owned by another vendor fails cleanly.
    store.deletingShows['other-show'] = <String, dynamic>{
      'vendorId': 'vendor-b',
      'status': 'active',
    };
    await expectLater(repo.deleteShow('other-show'), throwsStateError);

    // Active show with 4 booking/event pairs, D11 sessionIds manifest + subcollection, and poster.
    store.deletingShows['show-del'] = <String, dynamic>{
      'vendorId': 'vendor-a',
      'status': 'active',
      'sessionIds': <String>['1400'],
    };
    store.sessionDocsByShow['show-del'] = <(String, Map<String, dynamic>)>[
      ('1900', <String, dynamic>{'time': '19:00'}),
    ];
    store.showImages['show-del'] = <String, dynamic>{
      'poster': Blob(Uint8List.fromList(<int>[0xff, 0xd8, 0xff])),
    };
    store.bookingEventBatches.addAll(<List<String>>[
      <String>['b1', 'b2', 'b3', 'b4'],
    ]);

    final readGate = Completer<void>();
    var readCount = 0;
    store.onBeforeShowGet = (showId) async {
      if (showId == 'show-del') {
        readCount++;
        await readGate.future;
      }
    };

    final firstDelete = repo.deleteShow('show-del');
    final secondDelete = repo.deleteShow('show-del');
    expect(identical(firstDelete, secondDelete), isTrue);
    readGate.complete();
    await firstDelete;

    expect(readCount, 1);
    expect(store.updates.single.$1, 'shows/show-del');
    expect(store.updates.single.$2['status'], 'deleting');
    expect(store.updates.single.$2['updatedAt'], isA<FieldValue>());
    expect(
      store.whereCalls,
      containsAllInOrder(<(String, String, Object?)>[
        ('bookingEvents', 'vendorId', 'vendor-a'),
        ('bookingEvents', 'showId', 'show-del'),
      ]),
    );
    expect(
      store.queryGetCalls.any(
        (call) =>
            call.$1 == 'bookingEvents' && call.$2?.source == Source.server,
      ),
      isTrue,
    );
    expect(batchHooks, <(int, int)>[(0, 3), (1, 1)]);
    expect(store.deletedPaths, <String>[
      'bookings/b1',
      'bookingEvents/b1',
      'bookings/b2',
      'bookingEvents/b2',
      'bookings/b3',
      'bookingEvents/b3',
      'bookings/b4',
      'bookingEvents/b4',
      'shows/show-del/sessions/1400',
      'shows/show-del/sessions/1900',
      'showImages/show-del',
      'shows/show-del',
    ]);
    expect(store.deletingShows.containsKey('show-del'), isFalse);

    // Already-deleting show skips redundant status update and cleans up remaining parent.
    store.updates.clear();
    store.deletedPaths.clear();
    store.deletingShows['show-resumed'] = <String, dynamic>{
      'vendorId': 'vendor-a',
      'status': 'deleting',
      'sessionIds': const <String>[],
    };
    await repo.deleteShow('show-resumed');
    expect(store.updates, isEmpty);
    expect(store.deletedPaths, <String>['shows/show-resumed']);
  });

  test('watchVendorShows cancels cleanly while vendor check is pending without Zone errors or Firestore listener leakage', () async {
    final uncaught = <Object>[];
    final errors1 = <Object>[];
    Object? cancel1Error;
    final store1 = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store1.dispose);

    final errors2 = <Object>[];
    final store2 = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store2.dispose);

    final emitted3 = <List<Show>>[];
    Object? cancel3Error;
    final store3 = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store3.dispose);

    final done = Completer<void>();
    runZonedGuarded(() async {
      try {
        // 1. Cancelled before VendorNotEnrolled resolves (would throw StateError).
        final gate1 = Completer<VendorAccess>();
        final repo1 = FirestoreShowsRepository(
          _FakeFirestore(store1),
          vendorAccess: _FakeVendorAccessRepository(
            VendorNotEnrolled(uid: 'anon-1'),
            onCheck: () => gate1.future,
          ),
        );
        final sub1 = repo1
            .watchVendorShows('vendor-a')
            .listen((_) {}, onError: errors1.add);
        await pumpEventQueue();
        final cancel1 = sub1.cancel();
        gate1.complete(VendorNotEnrolled(uid: 'anon-1'));
        try {
          await cancel1;
        } catch (error) {
          cancel1Error = error;
        }
        await pumpEventQueue();

        // 2. Unawaited cancel before VendorAccess check fails with error.
        final gate2 = Completer<VendorAccess>();
        final repo2 = FirestoreShowsRepository(
          _FakeFirestore(store2),
          vendorAccess: _FakeVendorAccessRepository(
            VendorNotEnrolled(uid: 'anon-1'),
            onCheck: () => gate2.future,
          ),
        );
        final sub2 = repo2
            .watchVendorShows('vendor-a')
            .listen((_) {}, onError: errors2.add);
        await pumpEventQueue();
        unawaited(sub2.cancel());
        gate2.completeError(StateError('auth check failed'));
        await pumpEventQueue();

        // 3. Cancelled before VendorAllowed resolves -> must not subscribe to Firestore.
        final gate3 = Completer<VendorAccess>();
        final repo3 = FirestoreShowsRepository(
          _FakeFirestore(store3),
          vendorAccess: _FakeVendorAccessRepository(
            VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
            onCheck: () => gate3.future,
          ),
        );
        final sub3 = repo3.watchVendorShows('vendor-a').listen(emitted3.add);
        await pumpEventQueue();
        final cancel3 = sub3.cancel();
        gate3.complete(VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'));
        try {
          await cancel3;
        } catch (error) {
          cancel3Error = error;
        }
        await pumpEventQueue();
      } finally {
        if (!done.isCompleted) done.complete();
      }
    }, (error, _) => uncaught.add(error));
    await done.future;

    expect(uncaught, isEmpty);
    expect(cancel1Error, isNull);
    expect(errors1, isEmpty);
    expect(store1.whereCalls, isEmpty);
    expect(store1.snapshotCalls, isEmpty);

    expect(errors2, isEmpty);
    expect(store2.whereCalls, isEmpty);
    expect(store2.snapshotCalls, isEmpty);

    expect(cancel3Error, isNull);
    expect(emitted3, isEmpty);
    expect(store3.whereCalls, isEmpty);
    expect(store3.snapshotCalls, isEmpty);
    expect(store3.showsQueryStreamController.hasListener, isFalse);

    // 4. Active subscription tears down cleanly and ignores subsequent snapshots.
    final store4 = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store4.dispose);
    final repo4 = FirestoreShowsRepository(
      _FakeFirestore(store4),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
    );
    final emitted4 = <List<Show>>[];
    final sub4 = repo4.watchVendorShows('vendor-a').listen(emitted4.add);
    await pumpEventQueue();
    expect(store4.showsQueryStreamController.hasListener, isTrue);

    await sub4.cancel();
    expect(store4.showsQueryStreamController.hasListener, isFalse);

    store4.showsQueryStreamController.add(
      _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
        _FakeQueryDocumentSnapshot('show-late', <String, dynamic>{
          'vendorId': 'vendor-a',
          'title': 'Late Show',
          'description': 'Desc',
          'showDate': '2026-12-22',
          'imageId': 'show-late',
          'status': 'active',
          'bookedCount': 0,
          'lastBookingId': '',
        }),
      ]),
    );
    await pumpEventQueue();
    expect(emitted4, isEmpty);
  });

  test('watchVendorShows forwards pending and active pause/resume and closes cleanly on upstream onDone', () async {
    var pauseCount = 0;
    var resumeCount = 0;
    final upstream = StreamController<QuerySnapshot<Map<String, dynamic>>>(
      onPause: () => pauseCount++,
      onResume: () => resumeCount++,
    );
    final store = _ShowStore(
      deletingShows: <String, Map<String, dynamic>>{},
      showsQueryStreamController: upstream,
    );
    addTearDown(store.dispose);

    final accessGate = Completer<VendorAccess>();
    final repo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
        onCheck: () => accessGate.future,
      ),
    );

    final emitted = <List<Show>>[];
    var done = false;
    final sub = repo
        .watchVendorShows('vendor-a')
        .listen(emitted.add, onDone: () => done = true);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    // Pause while _requireVendor is still pending -> pauses immediately upon attach.
    sub.pause();
    expect(pauseCount, 0);

    accessGate.complete(VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'));
    await pumpEventQueue();
    expect(pauseCount, 1);
    expect(upstream.isPaused, isTrue);

    QuerySnapshot<Map<String, dynamic>> showSnap(String id) =>
        _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
          _FakeQueryDocumentSnapshot(id, <String, dynamic>{
            'vendorId': 'vendor-a',
            'title': 'Show $id',
            'description': 'Desc',
            'showDate': '2026-12-22',
            'imageId': id,
            'status': 'active',
            'bookedCount': 0,
            'lastBookingId': '',
          }),
        ]);

    upstream.add(showSnap('s1'));
    await pumpEventQueue();
    expect(emitted, isEmpty);

    sub.resume();
    await pumpEventQueue();
    expect(resumeCount, 1);
    expect(upstream.isPaused, isFalse);
    expect(emitted, hasLength(1));
    expect(emitted.single.single.id, 's1');

    // Post-attach pause and resume forward cleanly.
    sub.pause();
    await pumpEventQueue();
    expect(pauseCount, 2);
    expect(upstream.isPaused, isTrue);

    upstream.add(showSnap('s2'));
    await pumpEventQueue();
    expect(emitted, hasLength(1));

    sub.resume();
    await pumpEventQueue();
    expect(resumeCount, 2);
    expect(upstream.isPaused, isFalse);
    expect(emitted, hasLength(2));
    expect(emitted.last.single.id, 's2');

    // Closing upstream closes returned stream cleanly.
    await upstream.close();
    await pumpEventQueue();
    expect(done, isTrue);
  });
}

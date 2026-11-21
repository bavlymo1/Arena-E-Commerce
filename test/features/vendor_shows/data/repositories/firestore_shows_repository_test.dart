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
  _FakeVendorAccessRepository(this.access);

  final VendorAccess access;

  @override
  Future<VendorAccess> check() async => access;
}

class _ShowStore {
  _ShowStore({required this.deletingShows, this.failShowId});

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
  final List<String> updatedShowPaths = <String>[];
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
  Future<void> Function(String showId)? onBeforeShowGet;
  Future<void> Function(String showId)? onBeforePosterGet;
  final StreamController<DocumentSnapshot<Map<String, dynamic>>>
  showStreamController =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
  final StreamController<QuerySnapshot<Map<String, dynamic>>>
  showsQueryStreamController =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
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
    store.updatedShowPaths.add(path);
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

  test('addShow validates inputs, enforces vendor enrollment, and writes atomic 3-collection show transaction', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    final jpegBytes = File('assets/demo/skyline_jam.jpg').readAsBytesSync();
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
    expect(store.updatedShowPaths, <String>['shows/show-del']);
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
}

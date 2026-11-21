import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/data/repositories/firestore_shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
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
  final List<String> posterFetchIds = <String>[];
  final List<(String showId, GetOptions? options)> posterGetCalls =
      <(String, GetOptions?)>[];
  Future<void> Function(String showId)? onBeforeShowGet;
  Future<void> Function(String showId)? onBeforePosterGet;
  final StreamController<DocumentSnapshot<Map<String, dynamic>>>
  showStreamController =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
  final StreamController<QuerySnapshot<Map<String, dynamic>>>
  sessionsStreamController =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

  Future<void> dispose() async {
    await showStreamController.close();
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
      posterFetchIds.add(id);
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
}

final class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this.path, this.store);

  @override
  final String path;
  final _ShowStore store;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocumentReference(this.path, path ?? 'auto', store);

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
  }) => _FakeQuery(path, store);

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store.sessionsStreamController.stream;

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
  }) => this;

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store.sessionsStreamController.stream;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
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
  }) => store.showStreamController.stream;

  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.updatedShowPaths.add(path);
    if (collectionPath == 'shows' && store.deletingShows[id] != null) {
      store.deletingShows[id] = <String, dynamic>{
        ...store.deletingShows[id]!,
        ...data.map((k, v) => MapEntry(k.toString(), v)),
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

  test('watchActiveShows rejects non-positive limit', () {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    final repo = FirestoreShowsRepository(_FakeFirestore(store));

    expect(() => repo.watchActiveShows(limit: 0), throwsArgumentError);
  });

  test('watchShow suppresses cache-only missing snapshot and decodes server-confirmed docs', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    final repo = FirestoreShowsRepository(_FakeFirestore(store));

    final emitted = <Show?>[];
    final sub = repo.watchShow('show-1').listen(emitted.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

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

      final emitted = <dynamic>[];
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

  test('loadPoster fetches from server, returns defensive copy, enforces 32-entry LRU, and guards clear/dispose', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    for (var i = 0; i < 33; i++) {
      store.showImages['s$i'] = <String, dynamic>{
        'poster': Blob(Uint8List.fromList(<int>[i, 2, 3])),
      };
    }
    final repo = FirestoreShowsRepository(_FakeFirestore(store));

    final first = await repo.loadPoster('s0');
    expect(first, <int>[0, 2, 3]);
    expect(store.posterGetCalls.single.$2?.source, Source.server);
    first![0] = 99;
    final cached = await repo.loadPoster('s0');
    expect(cached, <int>[0, 2, 3]);
    expect(store.posterFetchIds, <String>['s0']);

    // Load s1..s32 so total unique keys = 33; s0 should be evicted (LRU).
    for (var i = 1; i < 33; i++) {
      await repo.loadPoster('s$i');
    }
    expect(store.posterFetchIds, hasLength(33));

    // Re-reading s1 hits cache (no fetch), whereas s0 was evicted and re-fetches.
    await repo.loadPoster('s1');
    expect(store.posterFetchIds, hasLength(33));
    await repo.loadPoster('s0');
    expect(store.posterFetchIds, hasLength(34));

    // Mid-flight clearPosterCache discards in-flight loadPoster result.
    final gate = Completer<void>();
    store.onBeforePosterGet = (_) => gate.future;
    final inFlight = repo.loadPoster('s2');
    await pumpEventQueue();
    repo.clearPosterCache();
    gate.complete();
    expect(await inFlight, isNull);

    repo.dispose();
    expect(await repo.loadPoster('s1'), isNull);
  });

  test('addShow rejects invalid title, description, JPEG header, and oversized poster', () async {
    final store = _ShowStore(deletingShows: <String, Map<String, dynamic>>{});
    addTearDown(store.dispose);
    final repo = FirestoreShowsRepository(
      _FakeFirestore(store),
      vendorAccess: _FakeVendorAccessRepository(
        VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
    );
    NewShow validShow({String? title, String? description}) => NewShow(
      vendorId: 'vendor-a',
      title: title ?? 'Show',
      description: description ?? 'Desc',
      showDate: '2026-12-20',
      sessions: <SessionTime>[SessionTime('19:00')],
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
  });
}

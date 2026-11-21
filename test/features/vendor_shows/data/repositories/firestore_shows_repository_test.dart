import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/data/repositories/firestore_shows_repository.dart';
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

  Future<QuerySnapshot<Map<String, dynamic>>> fetchDeletingShows() async {
    return _FakeQuerySnapshot(<QueryDocumentSnapshot<Map<String, dynamic>>>[
      for (final entry in deletingShows.entries)
        _FakeQueryDocumentSnapshot(entry.key, entry.value),
    ]);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchDoc(
    String collection,
    String id,
  ) async {
    if (collection == 'shows') {
      attemptedShowIds.add(id);
      if (id == failShowId) {
        return _failingShowRead();
      }
      final data = deletingShows[id];
      return _FakeDocumentSnapshot(id, data);
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
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (path == 'shows') {
      return store.fetchDeletingShows();
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
      store.fetchDoc(collectionPath, id);

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

final class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

final class _FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;
}

final class _FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

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
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/features/vendor_access/data/repositories/firebase_vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: subtype_of_sealed_class

final class _FakeUser extends Fake implements User {
  _FakeUser({required this.uid, this.isAnonymous = true});

  @override
  final String uid;

  @override
  final bool isAnonymous;
}

final class _FakeUserCredential extends Fake implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;
}

final class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  _FakeFirebaseAuth({this.user, this.signInUser});

  User? user;
  User? signInUser;
  int signInCalls = 0;

  @override
  User? get currentUser => user;

  @override
  Future<UserCredential> signInAnonymously() async {
    signInCalls++;
    final signedIn = signInUser;
    user = signedIn;
    return _FakeUserCredential(signedIn);
  }
}

final class _Store {
  final List<(String collection, String docId, GetOptions? options)> getCalls =
      <(String, String, GetOptions?)>[];
  final Map<String, Map<String, dynamic>?> docs =
      <String, Map<String, dynamic>?>{};
  Future<void> Function()? onBeforeGet;
}

final class _FakeFirestore extends Fake implements FirebaseFirestore {
  _FakeFirestore(this.store);

  final _Store store;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollectionReference(collectionPath, store);
}

final class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this.path, this.store);

  @override
  final String path;
  final _Store store;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocumentReference(this.path, path ?? 'auto', store);
}

final class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference(this.collectionPath, this.id, this.store);

  final String collectionPath;

  @override
  final String id;
  final _Store store;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.getCalls.add((collectionPath, id, options));
    await store.onBeforeGet?.call();
    final data = store.docs['$collectionPath/$id'];
    return _FakeDocumentSnapshot(id, data);
  }
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
  test('reuses existing anonymous user, reads vendorDevices from server, and returns VendorAllowed', () async {
    final auth = _FakeFirebaseAuth(user: _FakeUser(uid: 'anon-1'));
    final store = _Store()
      ..docs['vendorDevices/anon-1'] = <String, dynamic>{
        'enabled': true,
        'vendorId': 'arena',
      };
    final repository = FirebaseVendorAccessRepository(
      auth,
      _FakeFirestore(store),
    );

    final result = await repository.check();

    expect(auth.signInCalls, 0);
    expect(store.getCalls, hasLength(1));
    expect(store.getCalls.single.$1, 'vendorDevices');
    expect(store.getCalls.single.$2, 'anon-1');
    expect(store.getCalls.single.$3?.source, Source.server);
    expect(result, isA<VendorAllowed>());
    final allowed = result as VendorAllowed;
    expect(allowed.uid, 'anon-1');
    expect(allowed.vendorId, 'arena');
  });

  test(
    'signs in anonymously when currentUser is null before checking enrollment',
    () async {
      final auth = _FakeFirebaseAuth(
        user: null,
        signInUser: _FakeUser(uid: 'anon-new'),
      );
      final store = _Store()
        ..docs['vendorDevices/anon-new'] = <String, dynamic>{
          'enabled': true,
          'vendorId': 'arena-east',
        };
      final repository = FirebaseVendorAccessRepository(
        auth,
        _FakeFirestore(store),
      );

      final result = await repository.check();

      expect(auth.signInCalls, 1);
      expect(store.getCalls.single.$2, 'anon-new');
      expect(store.getCalls.single.$3?.source, Source.server);
      expect(result, isA<VendorAllowed>());
      final allowed = result as VendorAllowed;
      expect(allowed.uid, 'anon-new');
      expect(allowed.vendorId, 'arena-east');
    },
  );

  test('returns VendorNotEnrolled without reading Firestore when current user is not anonymous', () async {
    final auth = _FakeFirebaseAuth(
      user: _FakeUser(uid: 'cust-1', isAnonymous: false),
    );
    final store = _Store();
    final repository = FirebaseVendorAccessRepository(
      auth,
      _FakeFirestore(store),
    );

    final result = await repository.check();

    expect(auth.signInCalls, 0);
    expect(store.getCalls, isEmpty);
    expect(result, isA<VendorNotEnrolled>());
    expect(result.uid, 'cust-1');
  });

  test('returns VendorNotEnrolled for missing doc, disabled entry, or invalid vendorId', () async {
    final auth = _FakeFirebaseAuth(user: _FakeUser(uid: 'anon-1'));
    final store = _Store();
    final repository = FirebaseVendorAccessRepository(
      auth,
      _FakeFirestore(store),
    );

    expect(await repository.check(), isA<VendorNotEnrolled>());

    store.docs['vendorDevices/anon-1'] = <String, dynamic>{
      'enabled': false,
      'vendorId': 'arena',
    };
    expect(await repository.check(), isA<VendorNotEnrolled>());

    store.docs['vendorDevices/anon-1'] = <String, dynamic>{'enabled': true};
    expect(await repository.check(), isA<VendorNotEnrolled>());

    store.docs['vendorDevices/anon-1'] = <String, dynamic>{
      'enabled': true,
      'vendorId': 123,
    };
    expect(await repository.check(), isA<VendorNotEnrolled>());

    store.docs['vendorDevices/anon-1'] = <String, dynamic>{
      'enabled': true,
      'vendorId': '   ',
    };
    expect(await repository.check(), isA<VendorNotEnrolled>());
  });

  test('throws StateError when auth identity changes mid-flight during enrollment check', () async {
    final auth = _FakeFirebaseAuth(user: _FakeUser(uid: 'anon-1'));
    final store = _Store()
      ..docs['vendorDevices/anon-1'] = <String, dynamic>{
        'enabled': true,
        'vendorId': 'arena',
      }
      ..onBeforeGet = () async {
        auth.user = _FakeUser(uid: 'anon-2');
      };
    final repository = FirebaseVendorAccessRepository(
      auth,
      _FakeFirestore(store),
    );

    await expectLater(repository.check(), throwsStateError);
  });

  test(
    'throws StateError when user signs out mid-flight during enrollment check',
    () async {
      final auth = _FakeFirebaseAuth(user: _FakeUser(uid: 'anon-1'));
      final store = _Store()
        ..docs['vendorDevices/anon-1'] = <String, dynamic>{
          'enabled': true,
          'vendorId': 'arena',
        }
        ..onBeforeGet = () async {
          auth.user = null;
        };
      final repository = FirebaseVendorAccessRepository(
        auth,
        _FakeFirestore(store),
      );

      await expectLater(repository.check(), throwsStateError);
    },
  );
}

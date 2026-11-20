import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/data/repositories/firestore_booking_events_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: subtype_of_sealed_class

final class _FakeVendorAccessRepository implements VendorAccessRepository {
  _FakeVendorAccessRepository(this.handler);

  final Future<VendorAccess> Function() handler;
  int checkCalls = 0;

  @override
  Future<VendorAccess> check() {
    checkCalls++;
    return handler();
  }
}

final class _QueryRecorder {
  final controller =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  final requestedCollections = <String>[];
  final whereCalls = <(Object, Object?)>[];
  final orderByCalls = <(Object, bool)>[];
  final limitCalls = <int>[];
  final includeMetadataCalls = <bool>[];
  bool subscribed = false;

  Future<void> dispose() => controller.close();
}

final class _FakeFirestore extends Fake implements FirebaseFirestore {
  _FakeFirestore(this.recorder);

  final _QueryRecorder recorder;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    recorder.requestedCollections.add(collectionPath);
    return _FakeCollectionReference(recorder);
  }
}

final class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this.recorder);

  final _QueryRecorder recorder;

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
  }) => _FakeQuery(recorder).where(
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

final class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery(this.recorder);

  final _QueryRecorder recorder;

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
    recorder.whereCalls.add((field, isEqualTo));
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    recorder.orderByCalls.add((field, descending));
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    recorder.limitCalls.add(limit);
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    recorder.subscribed = true;
    recorder.includeMetadataCalls.add(includeMetadataChanges);
    return recorder.controller.stream;
  }
}

final class _FakeSnapshotMetadata extends Fake implements SnapshotMetadata {
  _FakeSnapshotMetadata({
    this.hasPendingWrites = false,
    this.isFromCache = false,
  });

  @override
  final bool hasPendingWrites;

  @override
  final bool isFromCache;
}

final class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(
    this.docs, {
    bool hasPendingWrites = false,
    bool isFromCache = false,
  }) : metadata = _FakeSnapshotMetadata(
         hasPendingWrites: hasPendingWrites,
         isFromCache: isFromCache,
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
}

Map<String, dynamic> _validEventData({
  String bookingId = 'booking-1',
  String vendorId = 'vendor-a',
  String showId = 'show-1',
  String sessionId = '1900',
  List<Object?> seats = const <int>[4, 1],
  String showTitle = 'Apex Finals',
  String slotTime = '19:00',
  Object? slotTotal = 2,
  Object? showTotal = 5,
  Object? kind = 'booked',
  Object? createdAt,
}) {
  return <String, dynamic>{
    'bookingId': bookingId,
    'vendorId': vendorId,
    'showId': showId,
    'sessionId': sessionId,
    'seats': seats,
    'showTitle': showTitle,
    'slotTime': slotTime,
    'slotTotal': slotTotal,
    'showTotal': showTotal,
    'kind': kind,
    'createdAt':
        createdAt ?? Timestamp.fromDate(DateTime.utc(2026, 11, 20, 12, 0)),
  };
}

void main() {
  test('validates constructor limit and empty vendorId synchronously', () {
    final recorder = _QueryRecorder();
    addTearDown(recorder.dispose);
    final firestore = _FakeFirestore(recorder);
    final access = _FakeVendorAccessRepository(
      () async => VendorAllowed(uid: 'u1', vendorId: 'vendor-a'),
    );

    expect(
      () => FirestoreBookingEventsRepository(firestore, access, limit: 0),
      throwsArgumentError,
    );

    final repository = FirestoreBookingEventsRepository(firestore, access);
    expect(() => repository.watchEvents('  '), throwsArgumentError);
  });

  test(
    'rejects unenrolled and mismatched-vendor access before subscribing',
    () async {
      final recorder1 = _QueryRecorder();
      addTearDown(recorder1.dispose);
      final notEnrolledRepo = FirestoreBookingEventsRepository(
        _FakeFirestore(recorder1),
        _FakeVendorAccessRepository(
          () async => VendorNotEnrolled(uid: 'anon-1'),
        ),
      );

      await expectLater(
        notEnrolledRepo.watchEvents('vendor-a').first,
        throwsStateError,
      );
      expect(recorder1.subscribed, isFalse);

      final recorder2 = _QueryRecorder();
      addTearDown(recorder2.dispose);
      final wrongVendorRepo = FirestoreBookingEventsRepository(
        _FakeFirestore(recorder2),
        _FakeVendorAccessRepository(
          () async => VendorAllowed(uid: 'anon-2', vendorId: 'vendor-b'),
        ),
      );

      await expectLater(
        wrongVendorRepo.watchEvents('vendor-a').first,
        throwsStateError,
      );
      expect(recorder2.subscribed, isFalse);
    },
  );

  test('queries bookingEvents, skips pending/empty-cache snapshots, and decodes descending with tie-break', () async {
    final recorder = _QueryRecorder();
    addTearDown(recorder.dispose);
    final repository = FirestoreBookingEventsRepository(
      _FakeFirestore(recorder),
      _FakeVendorAccessRepository(
        () async => VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
      ),
      limit: 25,
    );

    final emitted = <List<BookingEvent>>[];
    final sub = repository.watchEvents('vendor-a').listen(emitted.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    expect(recorder.requestedCollections, <String>['bookingEvents']);
    expect(recorder.whereCalls, <(Object, Object?)>[('vendorId', 'vendor-a')]);
    expect(recorder.orderByCalls, <(Object, bool)>[('createdAt', true)]);
    expect(recorder.limitCalls, <int>[25]);
    expect(recorder.includeMetadataCalls, <bool>[true]);

    // Ignored: empty cache snapshot before server confirmation.
    recorder.controller.add(_FakeQuerySnapshot(const [], isFromCache: true));
    await pumpEventQueue();
    expect(emitted, isEmpty);

    // Ignored: pending local writes.
    recorder.controller.add(
      _FakeQuerySnapshot([
        _FakeQueryDocumentSnapshot(
          'b-pending',
          _validEventData(bookingId: 'b-pending'),
        ),
      ], hasPendingWrites: true),
    );
    await pumpEventQueue();
    expect(emitted, isEmpty);

    // Accepted: confirmed empty server snapshot.
    recorder.controller.add(_FakeQuerySnapshot(const [], isFromCache: false));
    await pumpEventQueue();
    expect(emitted, hasLength(1));
    expect(emitted.single, isEmpty);

    final tiedStamp = Timestamp.fromDate(DateTime.utc(2026, 11, 20, 12, 0));
    final newerStamp = Timestamp.fromDate(DateTime.utc(2026, 11, 20, 12, 5));

    recorder.controller.add(
      _FakeQuerySnapshot([
        _FakeQueryDocumentSnapshot(
          'b-tie-z',
          _validEventData(bookingId: 'b-tie-z', createdAt: tiedStamp),
        ),
        _FakeQueryDocumentSnapshot(
          'b-newer',
          _validEventData(
            bookingId: 'b-newer',
            seats: const <int>[10, 2],
            slotTotal: 4,
            showTotal: 19,
            createdAt: newerStamp,
          ),
        ),
        _FakeQueryDocumentSnapshot(
          'b-tie-a',
          _validEventData(bookingId: 'b-tie-a', createdAt: tiedStamp),
        ),
      ]),
    );
    await pumpEventQueue();

    expect(emitted, hasLength(2));
    expect(emitted.last.map((e) => e.bookingId).toList(), <String>[
      'b-newer',
      'b-tie-a',
      'b-tie-z',
    ]);
    final first = emitted.last.first;
    expect(first.bookingId, 'b-newer');
    expect(first.seats, <int>{2, 10});
    expect(first.slotTime, SessionTime('19:00'));
    expect(first.slotTotal, 4);
    expect(first.showTotal, 19);
  });

  test('rejects malformed event documents cleanly', () async {
    Future<void> expectRejectedDoc(
      String id,
      Map<String, dynamic> payload,
      Matcher matcher,
    ) async {
      final recorder = _QueryRecorder();
      addTearDown(recorder.dispose);
      final repository = FirestoreBookingEventsRepository(
        _FakeFirestore(recorder),
        _FakeVendorAccessRepository(
          () async => VendorAllowed(uid: 'anon-1', vendorId: 'vendor-a'),
        ),
      );
      final future = repository.watchEvents('vendor-a').first;
      await pumpEventQueue();
      recorder.controller.add(
        _FakeQuerySnapshot([_FakeQueryDocumentSnapshot(id, payload)]),
      );
      await expectLater(future, throwsA(matcher));
    }

    await expectRejectedDoc(
      'b1',
      _validEventData(bookingId: 'b1', kind: 'cancelled'),
      isA<FormatException>(),
    );
    await expectRejectedDoc(
      'b1',
      _validEventData(bookingId: 'other-id'),
      isA<FormatException>(),
    );
    await expectRejectedDoc(
      'b1',
      _validEventData(bookingId: 'b1', vendorId: 'vendor-other'),
      isA<FormatException>(),
    );
    await expectRejectedDoc(
      'b1',
      _validEventData(bookingId: 'b1', seats: const <Object?>['1']),
      isA<FormatException>(),
    );
    await expectRejectedDoc(
      'b1',
      _validEventData(bookingId: 'b1', createdAt: 'not-a-timestamp'),
      isA<FormatException>(),
    );
    await expectRejectedDoc(
      'b1',
      _validEventData(bookingId: 'b1', slotTotal: '2'),
      isA<FormatException>(),
    );
  });
}

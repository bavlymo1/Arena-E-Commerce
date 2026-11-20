import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../vendor_shows/domain/models/session.dart';
import '../../../vendor_shows/domain/models/session_time.dart';
import '../../../vendor_shows/domain/repositories/shows_repository.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/booking_recovery.dart';
import '../../domain/models/booking_request.dart';
import '../../domain/models/booking_result.dart';
import '../../domain/repositories/booking_repository.dart';

typedef _Snapshot = DocumentSnapshot<Map<String, dynamic>>;

final class FirestoreBookingRepository implements BookingRepository {
  FirestoreBookingRepository(this._db, this._auth, this._shows);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ShowsRepository _shows;
  static const _server = GetOptions(source: Source.server);
  static const _unknown = 'Check this booking reference before trying again.';

  bool _owns(String uid) => _auth.currentUser?.uid == uid;
  static bool _authoritative(_Snapshot doc) =>
      !doc.metadata.isFromCache && !doc.metadata.hasPendingWrites;

  static (Object?, Object?) _revision(_Snapshot doc) =>
      (doc['lastBookingId'], doc['updatedAt']);

  @override
  Stream<Session?> watchSession(String showId, String sessionId) => _shows
      .watchSessions(showId)
      .map((slots) => slots.where((slot) => slot.id == sessionId).firstOrNull);

  @override
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId) =>
      _db
          .collection('bookings')
          .where('customerUid', isEqualTo: uid)
          .where('showId', isEqualTo: showId)
          .where('sessionId', isEqualTo: sessionId)
          .where('status', isEqualTo: 'confirmed')
          .snapshots(includeMetadataChanges: true)
          .where((s) => !s.metadata.hasPendingWrites && !s.metadata.isFromCache)
          .map((s) {
            if (!_owns(uid)) throw StateError('Customer changed');
            return {
              for (final doc in s.docs) ...(doc['seats'] as List).cast<int>(),
            };
          });

  @override
  Future<BookingRecovery> recover({
    required String bookingId,
    required String customerUid,
  }) async {
    final unknown = RecoveryUnresolved(
      bookingId: bookingId,
      customerUid: customerUid,
      reason: _unknown,
    );
    if (!_owns(customerUid)) return unknown;
    try {
      final doc = await _db.collection('bookings').doc(bookingId).get(_server);
      if (!_owns(customerUid) || !_authoritative(doc)) return unknown;
      if (!doc.exists) {
        return RecoveryAuthoritativelyAbsent(
          bookingId: bookingId,
          customerUid: customerUid,
        );
      }
      if (doc['customerUid'] != customerUid || doc['status'] != 'confirmed') {
        return unknown;
      }
      return RecoveryConfirmed(
        bookingId: bookingId,
        customerUid: customerUid,
        booking: Booking(
          request: BookingRequest(
            bookingId: bookingId,
            customerUid: customerUid,
            showId: doc['showId'] as String,
            sessionId: doc['sessionId'] as String,
            seats: (doc['seats'] as List).cast<int>(),
          ),
          showTitle: doc['showTitle'] as String,
          showDate: doc['showDate'] as String,
          slotTime: SessionTime(doc['slotTime'] as String),
          vendorId: doc['vendorId'] as String,
          createdAt: (doc['createdAt'] as Timestamp).toDate(),
        ),
      );
    } catch (_) {
      return unknown;
    }
  }

  @override
  Future<BookingResult> confirm(BookingRequest request) async {
    final unknown = BookingUnconfirmed(request, reason: _unknown);
    final uid = request.customerUid;
    final show = _db.collection('shows').doc(request.showId);
    final slot = show.collection('sessions').doc(request.sessionId);
    final booking = _db.collection('bookings').doc(request.bookingId);
    final seats = request.seats;
    for (var attempt = 1; attempt <= 3 && _owns(uid); attempt++) {
      (_Snapshot, _Snapshot)? inputs;
      try {
        final result = await _db.runTransaction<BookingResult>((tx) async {
          inputs = null;
          if (!_owns(uid)) return unknown;
          final prior = await tx.get(booking);
          if (prior.exists) {
            final stored = (prior['seats'] as List).cast<int>().toSet();
            final matches =
                prior['status'] == 'confirmed' &&
                prior['customerUid'] == uid &&
                prior['showId'] == request.showId &&
                prior['sessionId'] == request.sessionId &&
                stored.length == seats.length &&
                stored.containsAll(seats);
            return matches && _authoritative(prior)
                ? BookingConfirmed(request)
                : unknown;
          }
          final showDoc = await tx.get(show);
          final slotDoc = await tx.get(slot);
          if (!_owns(uid) ||
              !_authoritative(showDoc) ||
              !_authoritative(slotDoc)) {
            return unknown;
          }
          if (!showDoc.exists ||
              !slotDoc.exists ||
              showDoc['status'] != 'active') {
            return BookingUnavailable(request);
          }
          inputs = (showDoc, slotDoc);
          return _writeBooking(tx, request, booking, showDoc, slotDoc);
        });
        return _owns(uid) ? result : unknown;
      } on FirebaseException catch (error) {
        final before = inputs;
        if (error.code != 'permission-denied' ||
            attempt == 3 ||
            before == null ||
            !_owns(uid)) {
          return unknown;
        }
        // Rules may reject stale totals before the SDK reports contention.
        // Retry only with server evidence of absence and changed inputs.
        try {
          final (existing, latestShow, latestSlot) = await (
            booking.get(_server),
            show.get(_server),
            slot.get(_server),
          ).wait;
          if (!_owns(uid) ||
              ![existing, latestShow, latestSlot].every(_authoritative) ||
              existing.exists ||
              !latestShow.exists ||
              !latestSlot.exists ||
              (_revision(latestShow) == _revision(before.$1) &&
                  _revision(latestSlot) == _revision(before.$2))) {
            return unknown;
          }
        } catch (_) {
          return unknown;
        }
      } catch (_) {
        return unknown;
      }
    }
    return unknown;
  }

  BookingResult _writeBooking(
    Transaction tx,
    BookingRequest request,
    DocumentReference<Map<String, dynamic>> booking,
    _Snapshot showDoc,
    _Snapshot slotDoc,
  ) {
    final seats = request.seats.toList()..sort();
    final taken = (slotDoc['bookedSeats'] as List).cast<int>();
    final conflicts = request.seats.intersection(taken.toSet());
    if (conflicts.isNotEmpty) return BookingConflict(request, conflicts);
    final showTotal = (showDoc['bookedCount'] as int) + seats.length;
    final stamp = FieldValue.serverTimestamp();
    final common = {
      'showId': request.showId,
      'sessionId': request.sessionId,
      'seats': seats,
      'vendorId': showDoc['vendorId'],
      'showTitle': showDoc['title'],
      'slotTime': slotDoc['time'],
      'createdAt': stamp,
    };
    final link = {'lastBookingId': request.bookingId, 'updatedAt': stamp};
    tx.update(showDoc.reference, {...link, 'bookedCount': showTotal});
    tx.update(slotDoc.reference, {
      ...link,
      'bookedSeats': [...taken, ...seats],
    });
    tx.set(booking, {
      ...common,
      'customerUid': request.customerUid,
      'showDate': showDoc['showDate'],
      'status': 'confirmed',
    });
    tx.set(_db.collection('bookingEvents').doc(request.bookingId), {
      ...common,
      'bookingId': request.bookingId,
      'kind': 'booked',
      'slotTotal': taken.length + seats.length,
      'showTotal': showTotal,
    });
    return BookingConfirmed(request);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../vendor_access/domain/models/vendor_access.dart';
import '../../../vendor_access/domain/repositories/vendor_access_repository.dart';
import '../../../vendor_shows/domain/models/session_time.dart';
import '../../domain/models/booking_event.dart';
import '../../domain/repositories/booking_events_repository.dart';

/// Streams enrolled vendor-owned booking events from Firestore.
final class FirestoreBookingEventsRepository
    implements BookingEventsRepository {
  FirestoreBookingEventsRepository(
    this._firestore,
    this._vendorAccess, {
    int limit = 100,
  }) : _limit = limit < 1 ? throw ArgumentError.value(limit, 'limit') : limit;

  final FirebaseFirestore _firestore;
  final VendorAccessRepository _vendorAccess;
  final int _limit;

  @override
  Stream<List<BookingEvent>> watchEvents(String vendorId) {
    if (vendorId.trim().isEmpty) {
      throw ArgumentError.value(vendorId, 'vendorId', 'Must not be empty');
    }
    return _watchEvents(vendorId);
  }

  Stream<List<BookingEvent>> _watchEvents(String vendorId) async* {
    await _requireVendor(vendorId);
    yield* _firestore
        .collection('bookingEvents')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .limit(_limit)
        .snapshots(includeMetadataChanges: true)
        .where(
          (snapshot) =>
              !snapshot.metadata.hasPendingWrites &&
              (snapshot.docs.isNotEmpty || !snapshot.metadata.isFromCache),
        )
        .map((snapshot) => _decodeSnapshot(snapshot, vendorId));
  }

  Future<void> _requireVendor(String vendorId) async {
    final access = await _vendorAccess.check();
    if (access is VendorAllowed && access.vendorId == vendorId) return;
    throw StateError('Vendor is not enrolled for this account');
  }

  static List<BookingEvent> _decodeSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String expectedVendorId,
  ) {
    final events =
        snapshot.docs
            .map((doc) => _decodeEvent(doc, expectedVendorId))
            .toList(growable: false)
          ..sort((a, b) {
            final byTime = b.createdAt.compareTo(a.createdAt);
            return byTime != 0 ? byTime : a.bookingId.compareTo(b.bookingId);
          });
    return List<BookingEvent>.unmodifiable(events);
  }

  static BookingEvent _decodeEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String expectedVendorId,
  ) {
    final data = doc.data();
    if (data['kind'] != 'booked') {
      throw const FormatException('Unsupported booking event kind');
    }
    final bookingId = _requireString(data, 'bookingId');
    if (bookingId != doc.id) {
      throw const FormatException('Mismatched booking event ID');
    }
    final vendorId = _requireString(data, 'vendorId');
    if (vendorId != expectedVendorId) {
      throw const FormatException('Unexpected booking event vendor');
    }
    final rawSeats = data['seats'];
    if (rawSeats is! List) {
      throw const FormatException('Invalid booking event seats');
    }
    final seats = <int>[];
    for (final seat in rawSeats) {
      if (seat is! int) {
        throw const FormatException('Invalid booking event seat entry');
      }
      seats.add(seat);
    }
    final slotTotal = data['slotTotal'];
    final showTotal = data['showTotal'];
    if (slotTotal is! int || showTotal is! int) {
      throw const FormatException('Invalid booking event totals');
    }
    final createdAt = data['createdAt'];
    if (createdAt is! Timestamp) {
      throw const FormatException('Invalid booking event timestamp');
    }

    return BookingEvent(
      bookingId: bookingId,
      vendorId: vendorId,
      showId: _requireString(data, 'showId'),
      sessionId: _requireString(data, 'sessionId'),
      seats: seats,
      showTitle: _requireString(data, 'showTitle'),
      slotTime: SessionTime(_requireString(data, 'slotTime')),
      slotTotal: slotTotal,
      showTotal: showTotal,
      createdAt: createdAt.toDate(),
    );
  }

  static String _requireString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String) {
      throw FormatException('Invalid booking event $key');
    }
    return value;
  }
}

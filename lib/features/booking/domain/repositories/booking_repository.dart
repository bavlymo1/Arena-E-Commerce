import '../../../vendor_shows/domain/models/session.dart';
import '../models/booking_recovery.dart';
import '../models/booking_request.dart';
import '../models/booking_result.dart';

abstract interface class BookingRepository {
  Stream<Session?> watchSession(String showId, String sessionId);

  /// Query by UID, show, session AND confirmed status; never an unscoped query.
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId);

  /// All requested seats or none; callbacks have no notification side effects.
  Future<BookingResult> confirm(BookingRequest request);

  /// Only a server-confirmed missing document without pending writes proves
  /// absence. Cached, pending or failed reads remain unresolved. Existing data
  /// can confirm only this reference and original UID, never another owner.
  Future<BookingRecovery> recover({
    required String bookingId,
    required String customerUid,
  });
}

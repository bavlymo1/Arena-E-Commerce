import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/domain/repositories/booking_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';

/// Scripted outcomes for consumer tests; this does not simulate transactions.
final class FakeBookingRepository implements BookingRepository {
  final requests = <BookingRequest>[];
  final sessions = <(String, String), Session>{};
  final ownSeats = <(String, String, String), Set<int>>{};
  final recoveries = <(String, String), BookingRecovery>{};
  Future<BookingResult> Function(BookingRequest)? onConfirm;

  @override
  Stream<Session?> watchSession(String showId, String sessionId) =>
      Stream.value(sessions[(showId, sessionId)]);

  @override
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId) =>
      Stream.value(Set.unmodifiable(ownSeats[(uid, showId, sessionId)] ?? {}));

  @override
  Future<BookingResult> confirm(BookingRequest request) async {
    requests.add(request);
    return onConfirm == null
        ? BookingUnconfirmed(request, reason: 'No fake outcome configured')
        : await onConfirm!(request);
  }

  @override
  Future<BookingRecovery> recover({
    required String bookingId,
    required String customerUid,
  }) async =>
      recoveries[(bookingId, customerUid)] ??
      RecoveryUnresolved(
        bookingId: bookingId,
        customerUid: customerUid,
        reason: 'No authoritative fake evidence configured',
      );
}

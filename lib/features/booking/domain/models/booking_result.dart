import '../../../../shared/seating/seat_numbers.dart';
import 'booking_request.dart';

sealed class BookingResult {
  const BookingResult(this.request);
  final BookingRequest request;
}

/// Only a committed transaction or authoritative recovery can produce success.
final class BookingConfirmed extends BookingResult {
  const BookingConfirmed(super.request);
}

final class BookingConflict extends BookingResult {
  BookingConflict(super.request, Iterable<int> conflictSeats)
    : conflictSeats = checkedSeats(conflictSeats, allowEmpty: false) {
    if (!request.seats.containsAll(this.conflictSeats)) {
      throw ArgumentError('Conflict seats must belong to the request');
    }
  }

  final Set<int> conflictSeats;
}

final class BookingUnavailable extends BookingResult {
  const BookingUnavailable(super.request);
}

/// A definitive refusal, never an ambiguous network/permission/cache response.
final class BookingRejected extends BookingResult {
  const BookingRejected(super.request, {required this.reason});
  final String reason;
}

final class BookingUnconfirmed extends BookingResult {
  const BookingUnconfirmed(super.request, {required this.reason});
  final String reason;
}

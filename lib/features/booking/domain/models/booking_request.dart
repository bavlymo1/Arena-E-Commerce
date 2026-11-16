import '../../../../shared/seating/seat_numbers.dart';

final class BookingRequest {
  BookingRequest({
    required this.bookingId,
    required this.customerUid,
    required this.showId,
    required this.sessionId,
    required Iterable<int> seats,
  }) : seats = checkedSeats(seats, allowEmpty: false) {
    if ([
      bookingId,
      customerUid,
      showId,
      sessionId,
    ].any((value) => value.trim().isEmpty)) {
      throw ArgumentError('Booking identity and context are required');
    }
  }

  /// Generated once by the caller before the transaction; retained if uncertain.
  final String bookingId;
  final String customerUid;
  final String showId;
  final String sessionId;
  final Set<int> seats;
}

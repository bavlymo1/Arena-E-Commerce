import 'package:equatable/equatable.dart';

import '../../../../shared/seating/seat_numbers.dart';
import '../../../vendor_shows/domain/models/new_show.dart';
import '../../../vendor_shows/domain/models/session_time.dart';

final class BookingEvent extends Equatable {
  BookingEvent({
    required this.bookingId,
    required this.vendorId,
    required this.showId,
    required this.sessionId,
    required Iterable<int> seats,
    required this.showTitle,
    required this.slotTime,
    required this.slotTotal,
    required this.showTotal,
    required this.createdAt,
  }) : seats = checkedSeats(seats, allowEmpty: false) {
    if ([
          bookingId,
          vendorId,
          showId,
          sessionId,
          showTitle,
        ].any((value) => value.trim().isEmpty) ||
        sessionId != slotTime.id ||
        slotTotal < this.seats.length ||
        slotTotal > seatCapacity ||
        showTotal < slotTotal ||
        showTotal > maxShowBookedCount) {
      throw ArgumentError('Invalid event context or event-time seat totals');
    }
  }

  String get id => bookingId;
  String get kind => 'booked';
  final String bookingId;
  final String vendorId;
  final String showId;
  final String sessionId;
  final Set<int> seats;
  final String showTitle;
  final SessionTime slotTime;

  /// Exact event-time totals supplied by the atomic writer, not listener sums.
  final int slotTotal;
  final int showTotal;
  final DateTime createdAt;

  static int compareNewestFirst(BookingEvent a, BookingEvent b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    return byTime != 0 ? byTime : a.bookingId.compareTo(b.bookingId);
  }

  static int compareOldestFirst(BookingEvent a, BookingEvent b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.bookingId.compareTo(b.bookingId);
  }

  @override
  List<Object?> get props => <Object?>[
    bookingId,
    vendorId,
    showId,
    sessionId,
    seats,
    showTitle,
    slotTime,
    slotTotal,
    showTotal,
    createdAt,
  ];
}

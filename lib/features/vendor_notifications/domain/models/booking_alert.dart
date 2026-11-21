import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../../core/formatting/date_time_formatting.dart';
import '../../../../shared/seating/seat_numbers.dart';
import '../../../vendor_shows/domain/models/new_show.dart';
import '../../../vendor_shows/domain/models/session_time.dart';
import 'booking_event.dart';

/// Immutable notification payload sourced directly from a [BookingEvent].
final class BookingAlert extends Equatable {
  BookingAlert({
    required this.bookingId,
    required this.showId,
    required this.sessionId,
    required this.showTitle,
    required this.slotTime,
    required this.slotTotal,
    required this.showTotal,
    required Iterable<int> seats,
    required this.createdAt,
  }) : seats = checkedSeats(seats, allowEmpty: false) {
    if (<String>[
          bookingId,
          showId,
          sessionId,
          showTitle,
        ].any((value) => value.trim().isEmpty) ||
        sessionId != slotTime.id ||
        slotTotal < this.seats.length ||
        slotTotal > seatCapacity ||
        showTotal < slotTotal ||
        showTotal > maxShowBookedCount) {
      throw ArgumentError('Invalid booking alert context or seat totals');
    }
  }

  factory BookingAlert.fromEvent(BookingEvent event) {
    return BookingAlert(
      bookingId: event.bookingId,
      showId: event.showId,
      sessionId: event.sessionId,
      showTitle: event.showTitle,
      slotTime: event.slotTime,
      slotTotal: event.slotTotal,
      showTotal: event.showTotal,
      seats: event.seats,
      createdAt: event.createdAt,
    );
  }

  final String bookingId;
  final String showId;
  final String sessionId;
  final String showTitle;
  final SessionTime slotTime;

  /// Atomic commit-time totals from [BookingEvent], never listener sums.
  final int slotTotal;
  final int showTotal;
  final Set<int> seats;
  final DateTime createdAt;

  String get formattedSlotTime => formatTime12Hour(slotTime.value);

  String get seatsLabel => formatBookedSeatsLabel(seats);

  String get sessionSummary =>
      'Session $formattedSlotTime: $slotTotal/$seatCapacity booked';

  String get showTotalSummary => 'Show total across slots: $showTotal booked';

  String get notificationTitle => showTitle;

  String get notificationBody => '$sessionSummary\n$showTotalSummary';

  String get payload => jsonEncode(<String, String>{
    'bookingId': bookingId,
    'showId': showId,
    'sessionId': sessionId,
  });

  @override
  List<Object?> get props => <Object?>[
    bookingId,
    showId,
    sessionId,
    showTitle,
    slotTime,
    slotTotal,
    showTotal,
    seats,
    createdAt,
  ];
}

import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../../shared/seating/seat_numbers.dart';
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
        showTotal > 235) {
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

  String get formattedSlotTime => formatSlotTime12Hour(slotTime.value);

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

/// Formats `HH:mm` into 12-hour display text (e.g. `19:00` -> `7:00 PM`).
String formatSlotTime12Hour(String hhMm) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(hhMm);
  if (match == null) return hhMm;
  final hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  final period = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:$minute $period';
}

/// Formats sorted seat numbers as `Seat 9 booked` or `Seats 2, 5 booked`.
String formatBookedSeatsLabel(Set<int> seats) {
  final sorted = seats.toList()..sort();
  final noun = sorted.length == 1 ? 'Seat' : 'Seats';
  return '$noun ${sorted.join(', ')} booked';
}

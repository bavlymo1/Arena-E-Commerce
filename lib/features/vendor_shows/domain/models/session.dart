import '../../../../shared/seating/seat_numbers.dart';
import 'session_time.dart';

final class Session {
  Session({
    required this.id,
    required this.time,
    this.label,
    Iterable<int> bookedSeats = const [],
    this.lastBookingId = '',
    this.updatedAt,
  }) : bookedSeats = checkedSeats(bookedSeats) {
    if (id != time.id) {
      throw ArgumentError('Session ID must equal its HHmm time');
    }
  }

  final String id;
  final SessionTime time;
  final String? label;
  final Set<int> bookedSeats;
  final String lastBookingId;
  final DateTime? updatedAt;
  int get capacity => seatCapacity;
}

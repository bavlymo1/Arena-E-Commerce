import '../../../vendor_shows/domain/models/session_time.dart';
import 'booking_request.dart';

final class Booking {
  Booking({
    required this.request,
    required this.showTitle,
    required this.showDate,
    required this.slotTime,
    required this.vendorId,
    required this.createdAt,
  }) {
    if (showTitle.trim().isEmpty || vendorId.trim().isEmpty) {
      throw ArgumentError('Booking show title and vendor are required');
    }
    validateShowDate(showDate);
    if (request.sessionId != slotTime.id) {
      throw ArgumentError('Booking session and time must agree');
    }
  }

  final BookingRequest request;
  final String showTitle;
  final String showDate;
  final SessionTime slotTime;
  final String vendorId;
  final DateTime createdAt;
  String get status => 'confirmed';
}

import '../models/alert_permission.dart';
import '../models/booking_alert.dart';

/// Platform boundary for notification permission and local OS alert delivery.
abstract interface class LocalAlertPresenter {
  Future<AlertPermission> requestPermission();

  Future<void> showBookingAlert(BookingAlert alert);

  Future<void> showGroupedAlert(int count);
}

import '../models/booking_event.dart';

abstract interface class BookingEventsRepository {
  /// Descending event time; consumers must not skip unseen catch-up events or
  /// timestamp ties when advancing a notification watermark.
  Stream<List<BookingEvent>> watchEvents(String vendorId);
}

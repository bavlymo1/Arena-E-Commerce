import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter_test/flutter_test.dart';

BookingEvent event({
  int slotTotal = 2,
  int showTotal = 49,
  Iterable<int> seats = const [1, 47],
}) => BookingEvent(
  bookingId: 'stable-reference',
  vendorId: 'arena',
  showId: 'show-a',
  sessionId: '1900',
  seats: seats,
  showTitle: 'Show',
  slotTime: SessionTime('19:00'),
  slotTotal: slotTotal,
  showTotal: showTotal,
  createdAt: DateTime.utc(2026, 11, 16),
);

void main() {
  test(
    'event retains immutable exact supplied totals and booking identity',
    () {
      final seats = [1, 47];
      final value = event(seats: seats);
      seats.clear();
      expect(value.id, value.bookingId);
      expect(value.kind, 'booked');
      expect(value.slotTotal, 2);
      expect(value.showTotal, 49);
      expect(value.seats, {1, 47});
      expect(() => value.seats.clear(), throwsUnsupportedError);
    },
  );

  test('event rejects inconsistent or out-of-bounds totals', () {
    expect(() => event(slotTotal: 1), throwsArgumentError);
    expect(() => event(slotTotal: 48), throwsArgumentError);
    expect(() => event(showTotal: 1), throwsArgumentError);
    expect(() => event(showTotal: 236), throwsArgumentError);
  });

  test('compareNewestFirst and compareOldestFirst break timestamp ties by bookingId', () {
    BookingEvent build(String id, DateTime createdAt) => BookingEvent(
      bookingId: id,
      vendorId: 'arena',
      showId: 'show-a',
      sessionId: '1900',
      seats: const [1],
      showTitle: 'Show',
      slotTime: SessionTime('19:00'),
      slotTotal: 1,
      showTotal: 1,
      createdAt: createdAt,
    );

    final t1 = DateTime.utc(2026, 11, 20, 10, 0);
    final t2 = DateTime.utc(2026, 11, 20, 10, 5);
    final a = build('b-a', t1);
    final b = build('b-b', t1);
    final c = build('b-c', t2);

    final newestFirst = [a, b, c]..sort(BookingEvent.compareNewestFirst);
    expect(newestFirst.map((e) => e.bookingId), ['b-c', 'b-a', 'b-b']);

    final oldestFirst = [c, b, a]..sort(BookingEvent.compareOldestFirst);
    expect(oldestFirst.map((e) => e.bookingId), ['b-a', 'b-b', 'b-c']);
  });
}

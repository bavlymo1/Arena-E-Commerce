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

  test('BookingEvent compares by value with order-independent seats and checks every field', () {
    final createdAt = DateTime.utc(2026, 11, 20, 10, 0);
    BookingEvent build({
      String bookingId = 'ref-1',
      String vendorId = 'arena',
      String showId = 'show-a',
      String slot = '19:00',
      Iterable<int> seats = const [1, 47],
      String showTitle = 'Show',
      int slotTotal = 2,
      int showTotal = 49,
      DateTime? created,
    }) {
      final slotTime = SessionTime(slot);
      return BookingEvent(
        bookingId: bookingId,
        vendorId: vendorId,
        showId: showId,
        sessionId: slotTime.id,
        seats: seats,
        showTitle: showTitle,
        slotTime: slotTime,
        slotTotal: slotTotal,
        showTotal: showTotal,
        createdAt: created ?? createdAt,
      );
    }

    final baseline = build(seats: const [1, 47]);
    final reordered = build(seats: const [47, 1]);
    expect(baseline, reordered);
    expect(baseline.hashCode, reordered.hashCode);

    expect(baseline, isNot(build(bookingId: 'ref-2')));
    expect(baseline, isNot(build(vendorId: 'arena-2')));
    expect(baseline, isNot(build(showId: 'show-b')));
    expect(baseline, isNot(build(slot: '14:00')));
    expect(baseline, isNot(build(seats: const [1, 46])));
    expect(baseline, isNot(build(showTitle: 'Other Show')));
    expect(baseline, isNot(build(slotTotal: 3)));
    expect(baseline, isNot(build(showTotal: 50)));
    expect(
      baseline,
      isNot(build(created: createdAt.add(const Duration(seconds: 1)))),
    );
    expect(baseline, isNot(build(created: createdAt.toLocal())));
  });
}

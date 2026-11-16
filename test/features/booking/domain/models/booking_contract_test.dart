import 'package:e_commerce_project/features/booking/domain/models/booking.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_booking_repository.dart';

BookingRequest request({
  String uid = 'customer-a',
  String showId = 'show-a',
  Iterable<int> seats = const [1, 47],
}) => BookingRequest(
  bookingId: 'stable-reference',
  customerUid: uid,
  showId: showId,
  sessionId: '1900',
  seats: seats,
);

Booking booking(BookingRequest request) => Booking(
  request: request,
  showTitle: 'Show',
  showDate: '2026-11-16',
  slotTime: SessionTime('19:00'),
  vendorId: 'arena',
  createdAt: DateTime.utc(2026, 11, 16),
);

void main() {
  test('request rejects empty, duplicate and out-of-range seats', () {
    for (final seats in [
      <int>[],
      [1, 1],
      [0],
      [48],
    ]) {
      expect(() => request(seats: seats), throwsArgumentError);
    }
  });

  test('request snapshots input and cannot be mutated', () {
    final input = [1, 47];
    final value = request(seats: input);
    input.clear();
    expect(value.seats, {1, 47});
    expect(() => value.seats.add(2), throwsUnsupportedError);
  });

  test('unknown outcome and retry retain the same logical reference', () async {
    final fake = FakeBookingRepository();
    final original = request();
    final first = await fake.confirm(original);
    expect(first, isA<BookingUnconfirmed>());
    fake.onConfirm = (value) async => BookingConfirmed(value);
    final second = await fake.confirm(original);
    expect(second, isA<BookingConfirmed>());
    expect(fake.requests, [same(original), same(original)]);
    expect(first.request.bookingId, second.request.bookingId);
  });

  test('unconfigured recovery never claims absence or success', () async {
    final fake = FakeBookingRepository();
    final result = await fake.recover(
      bookingId: 'stable-reference',
      customerUid: 'customer-a',
    );
    expect(result, isA<RecoveryUnresolved>());
  });

  test('recovery cannot confirm another owner or reference', () {
    final value = booking(request());
    expect(
      () => RecoveryConfirmed(
        bookingId: 'stable-reference',
        customerUid: 'customer-b',
        booking: value,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecoveryConfirmed(
        bookingId: 'different-reference',
        customerUid: 'customer-a',
        booking: value,
      ),
      throwsArgumentError,
    );
  });

  test(
    'fake recovery and own-seat fixtures are UID/show/session scoped',
    () async {
      final fake = FakeBookingRepository();
      fake.recoveries[('stable-reference', 'customer-a')] = RecoveryConfirmed(
        bookingId: 'stable-reference',
        customerUid: 'customer-a',
        booking: booking(request()),
      );
      fake.ownSeats[('customer-a', 'show-a', '1900')] = {1};
      expect(
        await fake.recover(
          bookingId: 'stable-reference',
          customerUid: 'customer-a',
        ),
        isA<RecoveryConfirmed>(),
      );
      expect(
        await fake.recover(
          bookingId: 'stable-reference',
          customerUid: 'customer-b',
        ),
        isA<RecoveryUnresolved>(),
      );
      expect(await fake.watchMySeats('customer-a', 'show-a', '1900').first, {
        1,
      });
      expect(
        await fake.watchMySeats('customer-b', 'show-a', '1900').first,
        isEmpty,
      );
      expect(
        await fake.watchMySeats('customer-a', 'show-b', '1900').first,
        isEmpty,
      );
      expect(
        await fake.watchMySeats('customer-a', 'show-a', '1400').first,
        isEmpty,
      );
    },
  );

  test('conflict contains only requested seats and is immutable', () {
    final value = BookingConflict(request(), [47]);
    expect(value.conflictSeats, {47});
    expect(() => value.conflictSeats.clear(), throwsUnsupportedError);
    expect(() => BookingConflict(request(), [2]), throwsArgumentError);
  });
}

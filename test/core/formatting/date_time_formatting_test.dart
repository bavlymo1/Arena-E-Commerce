import 'package:e_commerce_project/core/formatting/date_time_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'tryParseIsoDateParts validates strict yyyy-MM-dd UTC calendar dates',
    () {
      expect(tryParseIsoDateParts('2028-02-29'), (2028, 2, 29));
      expect(tryParseIsoDateParts('2026-11-18'), (2026, 11, 18));
      expect(tryParseIsoDateParts('2027-02-29'), isNull);
      expect(tryParseIsoDateParts('2026-02-30'), isNull);
      expect(tryParseIsoDateParts('2026-13-01'), isNull);
      expect(tryParseIsoDateParts('0000-01-01'), isNull);
      expect(tryParseIsoDateParts('2026-1-1'), isNull);
      expect(tryParseIsoDateParts('invalid'), isNull);
    },
  );

  test('tryParseHourMinute validates strict 24-hour HH:mm strings', () {
    expect(tryParseHourMinute('00:05'), (0, 5));
    expect(tryParseHourMinute('23:59'), (23, 59));
    expect(tryParseHourMinute('24:00'), isNull);
    expect(tryParseHourMinute('12:60'), isNull);
    expect(tryParseHourMinute('9:00'), isNull);
    expect(tryParseHourMinute('12:00Z'), isNull);
  });

  test(
    'formatShowDateLabel and formatTime12Hour format or preserve raw fallback',
    () {
      expect(formatShowDateLabel('2026-11-18'), 'Nov 18, 2026');
      expect(formatShowDateLabel('2026-02-30'), '2026-02-30');
      expect(formatShowDateLabel('invalid'), 'invalid');

      expect(formatTime12Hour('00:05'), '12:05 AM');
      expect(formatTime12Hour('12:00'), '12:00 PM');
      expect(formatTime12Hour('12:30'), '12:30 PM');
      expect(formatTime12Hour('14:00'), '2:00 PM');
      expect(formatTime12Hour('19:00'), '7:00 PM');
      expect(formatTime12Hour('99:00'), '99:00');
    },
  );

  test('formatLocalTimestamp and formatBookedSeatsLabel format display copy cleanly', () {
    final morning = DateTime(2026, 11, 20, 0, 5).toUtc();
    final noon = DateTime(2026, 11, 20, 12, 30).toUtc();
    final evening = DateTime(2026, 11, 20, 19, 0).toUtc();

    expect(formatLocalTimestamp(morning), 'Nov 20, 12:05 AM');
    expect(formatLocalTimestamp(noon), 'Nov 20, 12:30 PM');
    expect(formatLocalTimestamp(evening), 'Nov 20, 7:00 PM');

    expect(formatBookedSeatsLabel(<int>{9}), 'Seat 9 booked');
    expect(formatBookedSeatsLabel(<int>{21, 14}), 'Seats 14, 21 booked');
  });
}

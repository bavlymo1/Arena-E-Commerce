final RegExp _isoDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _hourMinutePattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Parses an ISO `yyyy-MM-dd` calendar date strictly in UTC, or returns `null`.
(int year, int month, int day)? tryParseIsoDateParts(String value) {
  final match = _isoDatePattern.firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return (year, month, day);
}

/// Parses a 24-hour `HH:mm` string, or returns `null`.
(int hour, int minute)? tryParseHourMinute(String value) {
  final match = _hourMinutePattern.firstMatch(value);
  if (match == null) return null;
  return (int.parse(match.group(1)!), int.parse(match.group(2)!));
}

String _format12HourClock(int hour, int minute) {
  final period = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final paddedMinute = minute.toString().padLeft(2, '0');
  return '$displayHour:$paddedMinute $period';
}

/// Formats an ISO `yyyy-MM-dd` show date into a concise UTC calendar label,
/// falling back to [isoDate] if the input is malformed.
String formatShowDateLabel(String isoDate) {
  final parts = tryParseIsoDateParts(isoDate);
  if (parts == null) return isoDate;
  return '${_monthAbbreviations[parts.$2 - 1]} ${parts.$3}, ${parts.$1}';
}

/// Formats a 24-hour `HH:mm` string into 12-hour display text (e.g. `7:00 PM`),
/// falling back to [hhMm] if the input is malformed.
String formatTime12Hour(String hhMm) {
  final parsed = tryParseHourMinute(hhMm);
  if (parsed == null) return hhMm;
  return _format12HourClock(parsed.$1, parsed.$2);
}

/// Formats [timestamp] in local time as `Nov 20, 7:00 PM`.
String formatLocalTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  return '${_monthAbbreviations[local.month - 1]} ${local.day}, '
      '${_format12HourClock(local.hour, local.minute)}';
}

/// Formats sorted seat numbers as `Seat 9 booked` or `Seats 2, 5 booked`.
String formatBookedSeatsLabel(Set<int> seats) {
  final sorted = seats.toList()..sort();
  final noun = sorted.length == 1 ? 'Seat' : 'Seats';
  return '$noun ${sorted.join(', ')} booked';
}

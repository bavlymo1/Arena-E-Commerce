import '../../../../core/formatting/date_time_formatting.dart';

final class SessionTime {
  SessionTime(this.value) {
    if (tryParseHourMinute(value) == null) {
      throw ArgumentError.value(value, 'time', 'Expected HH:mm');
    }
  }

  final String value;
  String get id => value.replaceAll(':', '');

  @override
  bool operator ==(Object other) =>
      other is SessionTime && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// A calendar date without an invented booking cutoff or timezone.
void validateShowDate(String value) {
  if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'showDate', 'Expected yyyy-MM-dd');
  }
  if (tryParseIsoDateParts(value) == null) {
    throw ArgumentError.value(value, 'showDate', 'Invalid calendar date');
  }
}

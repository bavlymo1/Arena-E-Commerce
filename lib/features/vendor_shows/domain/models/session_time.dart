final class SessionTime {
  SessionTime(this.value) {
    if (!RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
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
  final parts = value.split('-').map(int.parse).toList();
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parts[0] < 1 ||
      parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw ArgumentError.value(value, 'showDate', 'Invalid calendar date');
  }
}

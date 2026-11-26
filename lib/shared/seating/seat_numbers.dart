const seatCapacity = 47;

Set<int> checkedSeats(Iterable<int> seats, {bool allowEmpty = true}) {
  final values = seats.toList(growable: false);
  if ((!allowEmpty && values.isEmpty) ||
      values.any((seat) => seat < 1 || seat > seatCapacity) ||
      values.toSet().length != values.length) {
    throw ArgumentError.value(seats, 'seats', 'Expected distinct seats 1–47');
  }
  return Set<int>.unmodifiable(values);
}

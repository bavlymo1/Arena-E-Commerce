import 'seat_numbers.dart';

enum SeatVisualStatus {
  available('Available'),
  selected('Selected'),
  mineConfirmed('Your confirmed seat'),
  bookedByOther('Booked');

  const SeatVisualStatus(this.label);

  final String label;

  bool get isInteractive =>
      this == SeatVisualStatus.available || this == SeatVisualStatus.selected;
}

final class SeatRowSpec {
  const SeatRowSpec({
    required this.rowNumber,
    required this.seats,
    this.aisleAfterIndex,
  });

  final int rowNumber;
  final List<int> seats;
  final int? aisleAfterIndex;

  bool get hasCentralAisle => aisleAfterIndex != null;

  List<int> get leadingSeats =>
      aisleAfterIndex == null ? seats : seats.sublist(0, aisleAfterIndex!);

  List<int> get trailingSeats =>
      aisleAfterIndex == null ? const <int>[] : seats.sublist(aisleAfterIndex!);
}

abstract final class SeatLayout {
  static const int totalSeats = seatCapacity;
  static const int rowCount = 5;

  static const List<SeatRowSpec> rows = <SeatRowSpec>[
    SeatRowSpec(
      rowNumber: 1,
      seats: <int>[1, 2, 3, 4, 5, 6, 7, 8, 9],
      aisleAfterIndex: 4,
    ),
    SeatRowSpec(
      rowNumber: 2,
      seats: <int>[10, 11, 12, 13, 14, 15, 16, 17, 18],
      aisleAfterIndex: 4,
    ),
    SeatRowSpec(
      rowNumber: 3,
      seats: <int>[19, 20, 21, 22, 23, 24, 25, 26, 27],
      aisleAfterIndex: 4,
    ),
    SeatRowSpec(
      rowNumber: 4,
      seats: <int>[28, 29, 30, 31, 32, 33, 34, 35, 36],
      aisleAfterIndex: 4,
    ),
    SeatRowSpec(
      rowNumber: 5,
      seats: <int>[37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47],
    ),
  ];

  static final List<int> allSeats = List<int>.unmodifiable(
    List<int>.generate(totalSeats, (index) => index + 1),
  );

  static void checkSeatNumber(int seatNumber) {
    if (seatNumber < 1 || seatNumber > totalSeats) {
      throw RangeError.range(seatNumber, 1, totalSeats, 'seatNumber');
    }
  }

  static int rowForSeat(int seatNumber) {
    checkSeatNumber(seatNumber);
    return seatNumber >= 37 ? 5 : ((seatNumber - 1) ~/ 9) + 1;
  }

  static SeatRowSpec rowSpec(int rowNumber) {
    if (rowNumber < 1 || rowNumber > rowCount) {
      throw RangeError.range(rowNumber, 1, rowCount, 'rowNumber');
    }
    return rows[rowNumber - 1];
  }

  static SeatVisualStatus statusForSeat(
    int seatNumber, {
    required Set<int> bookedSeats,
    Set<int> myConfirmedSeats = const <int>{},
    Set<int> selectedSeats = const <int>{},
    bool vendorMode = false,
  }) {
    checkSeatNumber(seatNumber);
    if (vendorMode) {
      return bookedSeats.contains(seatNumber) ||
              myConfirmedSeats.contains(seatNumber)
          ? SeatVisualStatus.bookedByOther
          : SeatVisualStatus.available;
    }
    if (myConfirmedSeats.contains(seatNumber)) {
      return SeatVisualStatus.mineConfirmed;
    }
    if (bookedSeats.contains(seatNumber)) {
      return SeatVisualStatus.bookedByOther;
    }
    if (selectedSeats.contains(seatNumber)) {
      return SeatVisualStatus.selected;
    }
    return SeatVisualStatus.available;
  }

  static String semanticsLabelForSeat(int seatNumber, SeatVisualStatus status) {
    final row = rowForSeat(seatNumber);
    return 'Seat $seatNumber, row $row, ${status.label}';
  }
}

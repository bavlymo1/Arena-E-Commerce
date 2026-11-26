import 'package:e_commerce_project/shared/seating/seat_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('layout defines exactly unique seats 1 through 47', () {
    final flattened = SeatLayout.rows.expand((row) => row.seats).toList();
    expect(SeatLayout.totalSeats, 47);
    expect(SeatLayout.rowCount, 5);
    expect(SeatLayout.allSeats, List<int>.generate(47, (i) => i + 1));
    expect(flattened, SeatLayout.allSeats);
    expect(flattened.toSet().length, 47);
  });

  test('rows 1-4 have 9 seats with central aisle and row 5 has 37-47 without aisle', () {
    for (var rowNumber = 1; rowNumber <= 4; rowNumber++) {
      final spec = SeatLayout.rowSpec(rowNumber);
      expect(spec.seats.length, 9);
      expect(spec.hasCentralAisle, isTrue);
      expect(spec.leadingSeats.length, 4);
      expect(spec.trailingSeats.length, 5);
      expect(spec.leadingSeats.first, (rowNumber - 1) * 9 + 1);
      expect(spec.trailingSeats.last, rowNumber * 9);
    }

    final row5 = SeatLayout.rowSpec(5);
    expect(row5.seats, List<int>.generate(11, (i) => 37 + i));
    expect(row5.hasCentralAisle, isFalse);
    expect(row5.leadingSeats, row5.seats);
    expect(row5.trailingSeats, isEmpty);
  });

  test('rowForSeat and range checks map boundaries accurately', () {
    expect(SeatLayout.rowForSeat(1), 1);
    expect(SeatLayout.rowForSeat(9), 1);
    expect(SeatLayout.rowForSeat(10), 2);
    expect(SeatLayout.rowForSeat(18), 2);
    expect(SeatLayout.rowForSeat(19), 3);
    expect(SeatLayout.rowForSeat(27), 3);
    expect(SeatLayout.rowForSeat(28), 4);
    expect(SeatLayout.rowForSeat(36), 4);
    expect(SeatLayout.rowForSeat(37), 5);
    expect(SeatLayout.rowForSeat(47), 5);

    expect(() => SeatLayout.rowForSeat(0), throwsRangeError);
    expect(() => SeatLayout.rowForSeat(48), throwsRangeError);
    expect(() => SeatLayout.rowSpec(0), throwsRangeError);
    expect(() => SeatLayout.rowSpec(6), throwsRangeError);
  });

  test(
    'statusForSeat enforces customer precedence and vendor read-only mapping',
    () {
      expect(
        SeatLayout.statusForSeat(
          14,
          bookedSeats: const {14, 21},
          myConfirmedSeats: const {14},
          selectedSeats: const {14, 15},
        ),
        SeatVisualStatus.mineConfirmed,
      );
      expect(
        SeatLayout.statusForSeat(
          21,
          bookedSeats: const {14, 21},
          myConfirmedSeats: const {14},
          selectedSeats: const {15},
        ),
        SeatVisualStatus.bookedByOther,
      );
      expect(
        SeatLayout.statusForSeat(
          15,
          bookedSeats: const {14, 21},
          myConfirmedSeats: const {14},
          selectedSeats: const {15},
        ),
        SeatVisualStatus.selected,
      );
      expect(
        SeatLayout.statusForSeat(
          1,
          bookedSeats: const {14, 21},
          myConfirmedSeats: const {14},
          selectedSeats: const {15},
        ),
        SeatVisualStatus.available,
      );

      expect(
        SeatLayout.statusForSeat(
          14,
          bookedSeats: const {21},
          myConfirmedSeats: const {14},
          selectedSeats: const {15},
          vendorMode: true,
        ),
        SeatVisualStatus.bookedByOther,
      );
      expect(
        SeatLayout.statusForSeat(
          15,
          bookedSeats: const {21},
          myConfirmedSeats: const {14},
          selectedSeats: const {15},
          vendorMode: true,
        ),
        SeatVisualStatus.available,
      );

      expect(
        SeatLayout.semanticsLabelForSeat(37, SeatVisualStatus.available),
        'Seat 37, row 5, Available',
      );
      expect(
        SeatLayout.semanticsLabelForSeat(14, SeatVisualStatus.mineConfirmed),
        'Seat 14, row 2, Your confirmed seat',
      );
    },
  );
}

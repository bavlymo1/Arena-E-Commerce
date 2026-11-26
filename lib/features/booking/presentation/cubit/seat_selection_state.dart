import 'package:equatable/equatable.dart';

import '../../../../shared/seating/seat_layout.dart';
import '../../../../shared/seating/seat_numbers.dart';
import '../../../vendor_shows/domain/models/session.dart';

enum SeatSelectionStatus { loading, ready, unavailable, error }

final class SeatSelectionState extends Equatable {
  SeatSelectionState({
    required this.customerUid,
    required this.showId,
    required this.sessionId,
    this.status = SeatSelectionStatus.loading,
    this.session,
    Iterable<int> bookedSeats = const <int>[],
    Iterable<int> myConfirmedSeats = const <int>[],
    Iterable<int> selectedSeats = const <int>[],
    Iterable<int> droppedByConflict = const <int>[],
    this.submitting = false,
    this.conflictMessage,
    this.errorMessage,
  }) : bookedSeats = checkedSeats(bookedSeats),
       myConfirmedSeats = checkedSeats(myConfirmedSeats),
       selectedSeats = checkedSeats(selectedSeats),
       droppedByConflict = checkedSeats(droppedByConflict);

  const SeatSelectionState._({
    required this.customerUid,
    required this.showId,
    required this.sessionId,
    required this.status,
    required this.session,
    required this.bookedSeats,
    required this.myConfirmedSeats,
    required this.selectedSeats,
    required this.droppedByConflict,
    required this.submitting,
    required this.conflictMessage,
    required this.errorMessage,
  });

  final String customerUid;
  final String showId;
  final String sessionId;
  final SeatSelectionStatus status;
  final Session? session;
  final Set<int> bookedSeats;
  final Set<int> myConfirmedSeats;
  final Set<int> selectedSeats;
  final Set<int> droppedByConflict;
  final bool submitting;
  final String? conflictMessage;
  final String? errorMessage;

  int get totalBookedCount => bookedSeats.union(myConfirmedSeats).length;

  bool get isSoldOut =>
      status == SeatSelectionStatus.ready && totalBookedCount >= seatCapacity;

  bool get canSubmit =>
      status == SeatSelectionStatus.ready &&
      !submitting &&
      selectedSeats.isNotEmpty &&
      !isSoldOut;

  SeatVisualStatus visualStatusFor(int seatNumber, {bool vendorMode = false}) =>
      SeatLayout.statusForSeat(
        seatNumber,
        bookedSeats: bookedSeats,
        myConfirmedSeats: myConfirmedSeats,
        selectedSeats: selectedSeats,
        vendorMode: vendorMode,
      );

  SeatSelectionState copyWith({
    SeatSelectionStatus? status,
    Session? session,
    bool clearSession = false,
    Iterable<int>? bookedSeats,
    Iterable<int>? myConfirmedSeats,
    Iterable<int>? selectedSeats,
    Iterable<int>? droppedByConflict,
    bool? submitting,
    String? conflictMessage,
    bool clearConflictMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SeatSelectionState._(
      customerUid: customerUid,
      showId: showId,
      sessionId: sessionId,
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      bookedSeats: bookedSeats == null
          ? this.bookedSeats
          : checkedSeats(bookedSeats),
      myConfirmedSeats: myConfirmedSeats == null
          ? this.myConfirmedSeats
          : checkedSeats(myConfirmedSeats),
      selectedSeats: selectedSeats == null
          ? this.selectedSeats
          : checkedSeats(selectedSeats),
      droppedByConflict: droppedByConflict == null
          ? this.droppedByConflict
          : checkedSeats(droppedByConflict),
      submitting: submitting ?? this.submitting,
      conflictMessage: clearConflictMessage
          ? null
          : (conflictMessage ?? this.conflictMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    customerUid,
    showId,
    sessionId,
    status,
    session,
    bookedSeats,
    myConfirmedSeats,
    selectedSeats,
    droppedByConflict,
    submitting,
    conflictMessage,
    errorMessage,
  ];
}

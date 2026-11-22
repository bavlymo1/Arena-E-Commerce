import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/seating/seat_numbers.dart';
import '../../../vendor_shows/domain/models/session.dart';
import '../../domain/repositories/booking_repository.dart';
import 'seat_selection_state.dart';

final class SeatSelectionCubit extends Cubit<SeatSelectionState> {
  SeatSelectionCubit({
    required this._bookingRepository,
    required String customerUid,
    required String showId,
    required String sessionId,
    bool autoStart = true,
  }) : super(
         SeatSelectionState(
           customerUid: _requireNonEmpty(customerUid, 'customerUid'),
           showId: _requireNonEmpty(showId, 'showId'),
           sessionId: _requireNonEmpty(sessionId, 'sessionId'),
         ),
       ) {
    if (autoStart) {
      unawaited(start());
    }
  }

  final BookingRepository _bookingRepository;
  StreamSubscription<Session?>? _sessionSubscription;
  StreamSubscription<Set<int>>? _mySeatsSubscription;
  Future<void> _cancellation = Future<void>.value();

  int _listenGeneration = 0;
  bool _hasSessionSnapshot = false;
  bool _hasMySeatsSnapshot = false;
  Session? _latestSession;
  Set<int> _latestMySeats = const <int>{};

  static String _requireNonEmpty(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be empty');
    }
    return value;
  }

  Future<void> start() async {
    if (isClosed) return;
    final generation = ++_listenGeneration;
    _hasSessionSnapshot = false;
    _hasMySeatsSnapshot = false;
    _latestSession = null;
    _latestMySeats = const <int>{};

    emit(
      state.copyWith(
        status: SeatSelectionStatus.loading,
        submitting: false,
        clearErrorMessage: true,
      ),
    );

    try {
      await _cancelSubscriptions();
      if (isClosed || generation != _listenGeneration) return;
      _sessionSubscription = _bookingRepository
          .watchSession(state.showId, state.sessionId)
          .listen(
            (session) => _onSessionSnapshot(generation, session),
            onError: (Object _) =>
                _onStreamError(generation, sessionFailed: true),
          );

      _mySeatsSubscription = _bookingRepository
          .watchMySeats(state.customerUid, state.showId, state.sessionId)
          .listen(
            (seats) => _onMySeatsSnapshot(generation, seats),
            onError: (Object _) =>
                _onStreamError(generation, ownSeatsFailed: true),
          );
    } catch (_) {
      _onStreamError(generation, sessionFailed: true, ownSeatsFailed: true);
      await _cancelSubscriptions();
    }
  }

  Future<void> retry() => start();

  void _onSessionSnapshot(int generation, Session? session) {
    if (isClosed || generation != _listenGeneration) return;
    _hasSessionSnapshot = true;
    _latestSession = session;
    if (session == null) {
      emit(
        state.copyWith(
          status: SeatSelectionStatus.unavailable,
          clearSession: true,
          selectedSeats: const <int>{},
          droppedByConflict: const <int>{},
          submitting: false,
          clearConflictMessage: true,
          errorMessage: 'This show or session no longer accepts bookings.',
        ),
      );
      return;
    }
    _reconcileSnapshots();
  }

  void _onMySeatsSnapshot(int generation, Set<int> seats) {
    if (isClosed || generation != _listenGeneration) return;
    try {
      _latestMySeats = checkedSeats(seats);
    } on ArgumentError {
      _onStreamError(generation, ownSeatsFailed: true);
      return;
    }
    _hasMySeatsSnapshot = true;
    _reconcileSnapshots();
  }

  void _reconcileSnapshots() {
    if (!_hasSessionSnapshot) return;
    final session = _latestSession;
    if (session == null) return;
    if (!_hasMySeatsSnapshot) return;

    final booked = session.bookedSeats;
    final mine = _latestMySeats;
    final currentSelected = state.selectedSeats;

    final newlyMine = currentSelected.intersection(mine);
    final newlyBookedByOthers = currentSelected
        .difference(newlyMine)
        .intersection(booked);

    final remainingSelected =
        currentSelected.difference(booked).difference(mine).toList()..sort();

    final updatedDropped =
        state.droppedByConflict
            .union(newlyBookedByOthers)
            .difference(mine)
            .toList()
          ..sort();
    final hasConflict = updatedDropped.isNotEmpty;
    final conflictMessage = hasConflict
        ? _formatConflictMessage(updatedDropped)
        : null;

    emit(
      state.copyWith(
        status: SeatSelectionStatus.ready,
        session: session,
        bookedSeats: booked,
        myConfirmedSeats: mine,
        selectedSeats: remainingSelected,
        droppedByConflict: updatedDropped,
        conflictMessage: conflictMessage,
        clearConflictMessage: !hasConflict,
        clearErrorMessage: true,
      ),
    );
  }

  void _onStreamError(
    int generation, {
    bool sessionFailed = false,
    bool ownSeatsFailed = false,
  }) {
    if (isClosed || generation != _listenGeneration) return;
    if (sessionFailed) _hasSessionSnapshot = false;
    if (ownSeatsFailed) _hasMySeatsSnapshot = false;
    emit(
      state.copyWith(
        status: SeatSelectionStatus.error,
        submitting: false,
        errorMessage: 'Unable to load seat availability. Your existing choices are preserved.',
      ),
    );
  }

  void toggleSeat(int seatNumber) {
    if (isClosed ||
        state.status != SeatSelectionStatus.ready ||
        state.submitting ||
        seatNumber < 1 ||
        seatNumber > seatCapacity) {
      return;
    }
    if (state.bookedSeats.contains(seatNumber) ||
        state.myConfirmedSeats.contains(seatNumber)) {
      return;
    }

    final updated = state.selectedSeats.toSet();
    if (!updated.remove(seatNumber)) {
      updated.add(seatNumber);
    }
    final sorted = updated.toList()..sort();

    emit(
      state.copyWith(
        selectedSeats: sorted,
        droppedByConflict: const <int>{},
        clearConflictMessage: true,
      ),
    );
  }

  void clearSelection() {
    if (isClosed ||
        state.status != SeatSelectionStatus.ready ||
        state.submitting) {
      return;
    }
    emit(
      state.copyWith(
        selectedSeats: const <int>{},
        droppedByConflict: const <int>{},
        clearConflictMessage: true,
      ),
    );
  }

  void clearConflictNotice() {
    if (isClosed) return;
    emit(
      state.copyWith(
        droppedByConflict: const <int>{},
        clearConflictMessage: true,
      ),
    );
  }

  void setSubmitting(bool submitting) {
    if (isClosed) return;
    if (submitting && state.status != SeatSelectionStatus.ready) return;
    emit(state.copyWith(submitting: submitting));
  }

  static String _formatConflictMessage(List<int> droppedSeats) {
    if (droppedSeats.length == 1) {
      return 'Seat ${droppedSeats.first} was just booked by another customer. Review remaining selection.';
    }
    return 'Seats ${droppedSeats.join(', ')} were just booked by another customer. Review remaining selection.';
  }

  Future<void> _cancelSubscriptions() {
    final sessionSub = _sessionSubscription;
    final mySeatsSub = _mySeatsSubscription;
    _sessionSubscription = null;
    _mySeatsSubscription = null;
    if (sessionSub == null && mySeatsSub == null) return _cancellation;
    return _cancellation = Future.wait<void>(<Future<void>>[
      _cancellation,
      if (sessionSub != null)
        Future<void>.sync(sessionSub.cancel).catchError((Object _) {}),
      if (mySeatsSub != null)
        Future<void>.sync(mySeatsSub.cancel).catchError((Object _) {}),
    ]).then((_) {});
  }

  @override
  Future<void> close() async {
    _listenGeneration++;
    await Future.wait<void>([_cancelSubscriptions(), super.close()]);
  }
}

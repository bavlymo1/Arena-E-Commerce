import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/booking_recovery.dart';
import '../../domain/models/booking_request.dart';
import '../../domain/models/booking_result.dart';
import '../../domain/repositories/booking_repository.dart';

enum BookingPhase {
  ready,
  submitting,
  confirmed,
  conflict,
  unavailable,
  rejected,
  unconfirmed,
  recovering,
  absent,
}

final class BookingState {
  const BookingState(
    this.phase, {
    this.request,
    this.message,
    this.conflicts = const {},
  });
  final BookingPhase phase;
  final BookingRequest? request;
  final String? message;
  final Set<int> conflicts;
  bool get unresolved =>
      phase == BookingPhase.unconfirmed || phase == BookingPhase.recovering;
  bool get busy =>
      phase == BookingPhase.submitting || phase == BookingPhase.recovering;
}

/// One logical request per route; uncertain outcomes can only be reconciled.
final class BookingCubit extends Cubit<BookingState> {
  BookingCubit({
    required this._repository,
    required this.customerUid,
    required this.showId,
    required this.sessionId,
    required this._newBookingId,
  }) : super(const BookingState(BookingPhase.ready));

  final BookingRepository _repository;
  final String Function() _newBookingId;
  final String customerUid, showId, sessionId;

  Future<void> submit(Set<int> seats) async {
    if (isClosed || state.phase != BookingPhase.ready || seats.isEmpty) return;
    final request = BookingRequest(
      bookingId: _newBookingId(),
      customerUid: customerUid,
      showId: showId,
      sessionId: sessionId,
      seats: seats,
    );
    emit(BookingState(BookingPhase.submitting, request: request));
    try {
      final result = await _repository.confirm(request);
      if (isClosed) return;
      if (!_sameRequest(request, result.request)) {
        _unconfirmed(
          request,
          'The response did not match this request. Check its status.',
        );
        return;
      }
      switch (result) {
        case BookingConfirmed():
          emit(BookingState(BookingPhase.confirmed, request: request));
        case BookingConflict():
          emit(
            BookingState(
              BookingPhase.conflict,
              request: request,
              conflicts: result.conflictSeats,
              message: 'Some seats were just booked. Review the map.',
            ),
          );
        case BookingUnavailable():
          emit(
            BookingState(
              BookingPhase.unavailable,
              request: request,
              message: 'This show or session is unavailable.',
            ),
          );
        case BookingRejected():
          emit(
            BookingState(
              BookingPhase.rejected,
              request: request,
              message: result.reason,
            ),
          );
        case BookingUnconfirmed():
          _unconfirmed(request, result.reason);
      }
    } catch (_) {
      if (!isClosed) {
        _unconfirmed(
          request,
          'The response was interrupted. Check this reference before trying again.',
        );
      }
    }
  }

  void _unconfirmed(BookingRequest request, String message) => emit(
    BookingState(BookingPhase.unconfirmed, request: request, message: message),
  );

  Future<void> recover() async {
    if (isClosed || state.phase != BookingPhase.unconfirmed) return;
    final request = state.request!;
    emit(BookingState(BookingPhase.recovering, request: request));
    try {
      final recovery = await _repository.recover(
        bookingId: request.bookingId,
        customerUid: request.customerUid,
      );
      if (isClosed) return;
      if (recovery.bookingId != request.bookingId ||
          recovery.customerUid != request.customerUid) {
        _unconfirmed(
          request,
          'The status response did not match this reference.',
        );
        return;
      }
      switch (recovery) {
        case RecoveryConfirmed():
          if (_sameRequest(request, recovery.booking.request)) {
            emit(BookingState(BookingPhase.confirmed, request: request));
          } else {
            _unconfirmed(
              request,
              'The recovered seats did not match this request.',
            );
          }
        case RecoveryAuthoritativelyAbsent():
          emit(
            BookingState(
              BookingPhase.absent,
              request: request,
              message: 'The server confirmed this reference was not booked. Review the map before a new attempt.',
            ),
          );
        case RecoveryUnresolved():
          _unconfirmed(request, recovery.reason);
      }
    } catch (_) {
      if (!isClosed) {
        _unconfirmed(
          request,
          'Status is still unknown. Keep this reference and check again.',
        );
      }
    }
  }

  /// Called only by a deliberate return to the map after definitive resolution.
  void newAttempt() {
    if (isClosed ||
        state.busy ||
        state.unresolved ||
        state.phase == BookingPhase.confirmed) {
      return;
    }
    emit(const BookingState(BookingPhase.ready));
  }

  static bool _sameRequest(BookingRequest a, BookingRequest b) =>
      a.bookingId == b.bookingId &&
      a.customerUid == b.customerUid &&
      a.showId == b.showId &&
      a.sessionId == b.sessionId &&
      a.seats.length == b.seats.length &&
      a.seats.containsAll(b.seats);
}

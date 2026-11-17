import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/seating/widgets/seat_map_view.dart';
import '../cubit/booking_cubit.dart';
import '../cubit/seat_selection_cubit.dart';
import '../cubit/seat_selection_state.dart';

class SeatSelectionScreen extends StatelessWidget {
  const SeatSelectionScreen({
    required this.onResult,
    required this.onDetails,
    super.key,
  });
  final ValueChanged<String> onResult;
  final VoidCallback onDetails;

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<BookingCubit, BookingState>(
    listener: (context, booking) {
      if (!booking.busy && booking.request != null) {
        onResult(booking.request!.bookingId);
      }
    },
    builder: (context, booking) =>
        BlocBuilder<SeatSelectionCubit, SeatSelectionState>(
          builder: (context, selection) {
            final cubit = context.read<SeatSelectionCubit>();
            return PopScope(
              canPop: !booking.busy && !booking.unresolved,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Choose your seats'),
                  leading: IconButton(
                    tooltip: 'Back to details',
                    onPressed: booking.busy || booking.unresolved
                        ? null
                        : onDetails,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (selection.session case final session?)
                      Text(
                        '${session.time.value} · ${session.label ?? 'Session'}',
                      ),
                    SeatMapView(
                      bookedSeats: selection.bookedSeats,
                      myConfirmedSeats: selection.myConfirmedSeats,
                      selectedSeats: selection.selectedSeats,
                      onSeatTap: cubit.toggleSeat,
                      busy: booking.busy || booking.unresolved,
                      loadState: switch (selection.status) {
                        SeatSelectionStatus.loading => SeatMapLoadState.loading,
                        SeatSelectionStatus.ready => SeatMapLoadState.ready,
                        SeatSelectionStatus.unavailable =>
                          SeatMapLoadState.unavailable,
                        SeatSelectionStatus.error => SeatMapLoadState.error,
                      },
                      conflictMessage: selection.conflictMessage,
                      errorMessage: selection.errorMessage,
                      onRetry: cubit.retry,
                    ),
                  ],
                ),
                bottomNavigationBar: SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed:
                        selection.canSubmit &&
                            booking.phase == BookingPhase.ready
                        ? () {
                            cubit.setSubmitting(true);
                            context.read<BookingCubit>().submit(
                              selection.selectedSeats,
                            );
                          }
                        : null,
                    child: Text(
                      booking.busy
                          ? 'Confirming…'
                          : 'Confirm ${selection.selectedSeats.length} seats',
                    ),
                  ),
                ),
              ),
            );
          },
        ),
  );
}

import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/seating/seat_layout.dart';
import '../../../../shared/seating/widgets/seat_map_view.dart';
import '../../../vendor_shows/domain/models/session.dart';
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

  String _formatSessionBanner(BuildContext context, Session session) {
    final parts = session.time.value.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final localTime = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
    final label = session.label?.trim();
    final timePart = localTime == session.time.value
        ? session.time.value
        : '${session.time.value} · $localTime';
    return label != null && label.isNotEmpty ? '$timePart · $label' : timePart;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<BookingCubit, BookingState>(
      listenWhen: (prev, curr) =>
          !curr.busy &&
          curr.request != null &&
          (prev.busy || prev.request?.bookingId != curr.request?.bookingId),
      listener: (context, booking) {
        final request = booking.request;
        if (!booking.busy && request != null) {
          onResult(request.bookingId);
        }
      },
      builder: (context, booking) =>
          BlocBuilder<SeatSelectionCubit, SeatSelectionState>(
            buildWhen: (prev, curr) =>
                prev.status != curr.status ||
                prev.session != curr.session ||
                !setEquals(prev.bookedSeats, curr.bookedSeats) ||
                !setEquals(prev.myConfirmedSeats, curr.myConfirmedSeats) ||
                prev.conflictMessage != curr.conflictMessage ||
                prev.errorMessage != curr.errorMessage ||
                prev.submitting != curr.submitting,
            builder: (context, selection) {
              final cubit = context.read<SeatSelectionCubit>();
              final isBusy =
                  booking.busy || booking.unresolved || selection.submitting;

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
                  body: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      children: <Widget>[
                        if (selection.session case final session?) ...<Widget>[
                          Container(
                            key: const ValueKey<String>(
                              'seat-selection-session-header',
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formatSessionBanner(context, session),
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const <FontFeature>[
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SeatMapView(
                          bookedSeats: selection.bookedSeats,
                          myConfirmedSeats: selection.myConfirmedSeats,
                          selectedSeats: selection.selectedSeats,
                          onSeatTap: cubit.toggleSeat,
                          busy: isBusy,
                          loadState: switch (selection.status) {
                            SeatSelectionStatus.loading =>
                              SeatMapLoadState.loading,
                            SeatSelectionStatus.ready => SeatMapLoadState.ready,
                            SeatSelectionStatus.unavailable =>
                              SeatMapLoadState.unavailable,
                            SeatSelectionStatus.error => SeatMapLoadState.error,
                          },
                          conflictMessage: selection.conflictMessage,
                          errorMessage: selection.errorMessage,
                          onRetry: cubit.retry,
                          seatSelectorBuilder:
                              (context, seatNumber, buildTile) {
                                return BlocSelector<
                                  SeatSelectionCubit,
                                  SeatSelectionState,
                                  (SeatVisualStatus, bool)
                                >(
                                  selector: (s) => (
                                    s.visualStatusFor(seatNumber),
                                    s.submitting ||
                                        booking.busy ||
                                        booking.unresolved,
                                  ),
                                  builder: (context, tuple) =>
                                      buildTile(context, tuple.$1, tuple.$2),
                                );
                              },
                          selectedSummaryBuilder: (context) {
                            return BlocSelector<
                              SeatSelectionCubit,
                              SeatSelectionState,
                              Set<int>
                            >(
                              selector: (s) => s.selectedSeats,
                              builder: (context, selected) {
                                final sorted = selected.toList()..sort();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: <Widget>[
                                      Text(
                                        'Selected seats',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        sorted.isEmpty
                                            ? 'None'
                                            : sorted.join(', '),
                                        key: const ValueKey<String>(
                                          'seat-selected-summary',
                                        ),
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: const <FontFeature>[
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  bottomNavigationBar: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        top: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: SafeArea(
                      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child:
                          BlocSelector<
                            SeatSelectionCubit,
                            SeatSelectionState,
                            ({bool canSubmit, int count})
                          >(
                            selector: (s) => (
                              canSubmit: s.canSubmit,
                              count: s.selectedSeats.length,
                            ),
                            builder: (context, summary) => FilledButton(
                              key: const ValueKey<String>(
                                'seat-confirm-button',
                              ),
                              onPressed:
                                  summary.canSubmit &&
                                      booking.phase == BookingPhase.ready
                                  ? () {
                                      cubit.setSubmitting(true);
                                      unawaited(
                                        context.read<BookingCubit>().submit(
                                          cubit.state.selectedSeats,
                                        ),
                                      );
                                    }
                                  : null,
                              child: Text(
                                booking.busy
                                    ? 'Confirming…'
                                    : 'Confirm ${summary.count} seats',
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}

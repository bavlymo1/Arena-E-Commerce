import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/booking_cubit.dart';

class BookingResultScreen extends StatelessWidget {
  const BookingResultScreen({
    required this.bookingId,
    required this.onDetails,
    required this.onReviewMap,
    super.key,
  });
  final String bookingId;
  final VoidCallback onDetails, onReviewMap;

  @override
  Widget build(BuildContext context) => BlocBuilder<BookingCubit, BookingState>(
    builder: (context, state) {
      final request = state.request;
      final matches = request?.bookingId == bookingId;
      final confirmed = matches && state.phase == BookingPhase.confirmed;
      final unresolved = state.unresolved;
      final pending = state.busy || unresolved;
      final seats = request?.seats.toList()?..sort();
      return PopScope(
        canPop: !state.busy && !unresolved,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Booking result'),
            automaticallyImplyLeading: false,
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                confirmed ? Icons.check_circle_outline : Icons.info_outline,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                state.phase == BookingPhase.submitting
                    ? 'Confirming booking'
                    : unresolved
                    ? 'Confirmation unknown'
                    : !matches
                    ? 'Reference unavailable in this session'
                    : confirmed
                    ? 'Booking confirmed'
                    : 'Not booked',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              SelectableText(
                'Reference: ${pending ? request!.bookingId : bookingId}',
              ),
              if (matches || pending) ...[
                Text('Seats: ${seats!.join(', ')}'),
                if (state.message case final message?) Text(message),
                if (state.conflicts.isNotEmpty)
                  Text('Conflicting seats: ${state.conflicts.join(', ')}'),
              ],
              const SizedBox(height: 24),
              if (state.phase == BookingPhase.submitting)
                const Center(child: CircularProgressIndicator())
              else if (unresolved) ...[
                const Text(
                  'Keep this reference. Do not start another booking while its status is unknown.',
                ),
                FilledButton(
                  onPressed: state.busy
                      ? null
                      : context.read<BookingCubit>().recover,
                  child: Text(state.busy ? 'Checking…' : 'Check status'),
                ),
              ] else if (matches && !confirmed) ...[
                FilledButton(
                  onPressed: onReviewMap,
                  child: const Text('Review seat map'),
                ),
                TextButton(
                  onPressed: onDetails,
                  child: const Text('Back to details'),
                ),
              ] else
                FilledButton(
                  onPressed: onDetails,
                  child: const Text('Back to details'),
                ),
            ],
          ),
        ),
      );
    },
  );
}

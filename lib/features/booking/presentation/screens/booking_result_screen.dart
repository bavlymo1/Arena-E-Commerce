import 'dart:async';

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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<BookingCubit, BookingState>(
      builder: (context, state) {
        final request = state.request;
        final matches = request?.bookingId == bookingId;
        final confirmed = matches && state.phase == BookingPhase.confirmed;
        final unresolved = state.unresolved;
        final pending = state.busy || unresolved;
        final seats = request?.seats.toList()?..sort();
        final statusTone = confirmed
            ? colorScheme.secondary
            : state.phase == BookingPhase.submitting
            ? colorScheme.primary
            : colorScheme.error;

        return PopScope(
          canPop: !state.busy && !unresolved,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Booking result'),
              automaticallyImplyLeading: false,
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: <Widget>[
                  Text(
                    'ArenaPass',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      key: const ValueKey<String>('booking-result-badge'),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: statusTone.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: statusTone.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Icon(
                        confirmed
                            ? Icons.check_circle_outline
                            : state.phase == BookingPhase.submitting
                            ? Icons.hourglass_top_outlined
                            : Icons.info_outline,
                        size: 32,
                        color: statusTone,
                      ),
                    ),
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
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    key: const ValueKey<String>('booking-result-details-card'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SelectableText(
                          'Reference: ${pending ? request!.bookingId : bookingId}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        if (matches || pending) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'Seats: ${seats!.join(', ')}',
                            style: textTheme.bodyMedium?.copyWith(
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (matches || pending) ...<Widget>[
                    if (state.message case final message?) ...<Widget>[
                      const SizedBox(height: 12),
                      _ResultNoticeBanner(
                        icon: confirmed
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        message: message,
                        isError: !confirmed && !unresolved,
                      ),
                    ],
                    if (state.conflicts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      _ResultNoticeBanner(
                        icon: Icons.warning_amber_rounded,
                        message:
                            'Conflicting seats: ${state.conflicts.join(', ')}',
                        isError: true,
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  if (state.phase == BookingPhase.submitting)
                    const Center(child: CircularProgressIndicator())
                  else if (unresolved) ...<Widget>[
                    const _ResultNoticeBanner(
                      icon: Icons.info_outline,
                      message: 'Keep this reference. Do not start another booking while its status is unknown.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey<String>(
                        'booking-result-check-button',
                      ),
                      onPressed: state.busy
                          ? null
                          : () => unawaited(
                              context.read<BookingCubit>().recover(),
                            ),
                      child: Text(state.busy ? 'Checking…' : 'Check status'),
                    ),
                  ] else if (matches && !confirmed) ...<Widget>[
                    FilledButton(
                      key: const ValueKey<String>(
                        'booking-result-review-map-button',
                      ),
                      onPressed: onReviewMap,
                      child: const Text('Review seat map'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      key: const ValueKey<String>(
                        'booking-result-back-details-button',
                      ),
                      onPressed: onDetails,
                      child: const Text('Back to details'),
                    ),
                  ] else
                    FilledButton(
                      key: const ValueKey<String>(
                        'booking-result-back-details-button',
                      ),
                      onPressed: onDetails,
                      child: const Text('Back to details'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResultNoticeBanner extends StatelessWidget {
  const _ResultNoticeBanner({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? colorScheme.error.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 18,
            color: isError ? colorScheme.error : colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

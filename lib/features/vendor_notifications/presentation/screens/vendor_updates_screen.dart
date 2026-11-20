import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/seating/seat_numbers.dart';
import '../../domain/models/booking_alert.dart';
import '../../domain/models/booking_event.dart';
import '../cubit/vendor_notifications_cubit.dart';
import '../cubit/vendor_notifications_state.dart';
import '../widgets/alert_permission_banner.dart';

/// Displays reverse-chronological booking updates and exact booked totals.
class VendorUpdatesScreen extends StatelessWidget {
  const VendorUpdatesScreen({
    this.onBackToShows,
    this.onEventSelected,
    super.key,
  });

  final VoidCallback? onBackToShows;
  final ValueChanged<BookingEvent>? onEventSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canGoBack = onBackToShows != null || Navigator.canPop(context);
    void handleBack() =>
        onBackToShows != null ? onBackToShows!() : Navigator.maybePop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking updates'),
        leading: canGoBack
            ? IconButton(
                key: const ValueKey<String>('vendor-updates-back-button'),
                tooltip: 'Back to My shows',
                onPressed: handleBack,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: SafeArea(
        child: BlocBuilder<VendorNotificationsCubit, VendorNotificationsState>(
          builder: (context, state) {
            final cubit = context.read<VendorNotificationsCubit>();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                Text(
                  'ArenaPass Console',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booking updates',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Confirmed bookings and exact booked-seat totals at commit time.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (state.unreadCount > 0) ...<Widget>[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        '${state.unreadCount} unread',
                        key: const ValueKey<String>(
                          'vendor-updates-unread-summary',
                        ),
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey<String>(
                          'vendor-updates-mark-all-read-button',
                        ),
                        onPressed: cubit.markAllRead,
                        child: const Text('Mark all read'),
                      ),
                    ],
                  ),
                ],
                if (state.isAlertPermissionDenied) ...<Widget>[
                  const SizedBox(height: 12),
                  AlertPermissionBanner(
                    key: const ValueKey<String>(
                      'vendor-updates-permission-denied-banner',
                    ),
                    onRetryPermission: cubit.requestAlertPermission,
                  ),
                ],
                const SizedBox(height: 20),
                if (state.isLoading && state.events.isEmpty)
                  const Center(
                    key: ValueKey<String>('vendor-updates-loading'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading booking updates…'),
                        ],
                      ),
                    ),
                  )
                else if (state.hasError && state.events.isEmpty)
                  _UpdatesStatusPanel(
                    key: const ValueKey<String>('vendor-updates-error-state'),
                    icon: Icons.error_outline,
                    title: 'Unable to load booking updates',
                    message:
                        state.errorMessage ??
                        'Unable to load booking updates. Try again.',
                    actionLabel: 'Try again',
                    actionKey: const ValueKey<String>(
                      'vendor-updates-retry-button',
                    ),
                    onAction: cubit.retry,
                    isError: true,
                  )
                else if (state.isEmpty)
                  const _UpdatesStatusPanel(
                    key: ValueKey<String>('vendor-updates-empty-state'),
                    icon: Icons.notifications_none_outlined,
                    title: 'No updates yet',
                    message: 'Confirmed bookings will appear here.',
                  )
                else ...<Widget>[
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _UpdatesInlineErrorBanner(
                        key: const ValueKey<String>(
                          'vendor-updates-inline-error',
                        ),
                        message:
                            state.errorMessage ??
                            'Unable to refresh booking updates.',
                        onRetry: cubit.retry,
                      ),
                    ),
                  for (final event in state.events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _BookingEventCard(
                        event: event,
                        unread: state.unreadEventIds.contains(event.id),
                        onTap: onEventSelected != null
                            ? () {
                                cubit.markEventRead(event.id);
                                onEventSelected!(event);
                              }
                            : null,
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookingEventCard extends StatelessWidget {
  const _BookingEventCard({
    required this.event,
    required this.unread,
    this.onTap,
  });

  final BookingEvent event;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final slotLabel = formatSlotTime12Hour(event.slotTime.value);
    final timestampLabel = _formatLocalTimestamp(event.createdAt);
    final seatsLabel = formatBookedSeatsLabel(event.seats);
    final slotTotalLabel = 'Session ${event.slotTotal} / $seatCapacity booked';
    final showTotalLabel = 'Show total: ${event.showTotal} booked';

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (unread)
                Container(
                  key: ValueKey<String>('vendor-update-unread-${event.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Unread',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                slotLabel,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              Text(
                timestampLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.showTitle,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            seatsLabel,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              Text(
                slotTotalLabel,
                key: ValueKey<String>('vendor-update-slot-total-${event.id}'),
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              Text(
                showTotalLabel,
                key: ValueKey<String>('vendor-update-show-total-${event.id}'),
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final semanticLabel =
        '${unread ? 'Unread, ' : ''}${event.showTitle}, $slotLabel, '
        '$timestampLabel, $seatsLabel, $slotTotalLabel, $showTotalLabel';

    return Material(
      key: ValueKey<String>('vendor-update-card-${event.id}'),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unread ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? Semantics(
              container: true,
              button: true,
              label: semanticLabel,
              onTap: onTap,
              excludeSemantics: true,
              child: InkWell(onTap: onTap, child: body),
            )
          : Semantics(container: true, child: body),
    );
  }
}

class _UpdatesInlineErrorBanner extends StatelessWidget {
  const _UpdatesInlineErrorBanner({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, size: 18, color: colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              key: const ValueKey<String>('vendor-updates-inline-retry-button'),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdatesStatusPanel extends StatelessWidget {
  const _UpdatesStatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.isError = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 26,
              color: isError ? colorScheme.error : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: actionKey,
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatLocalTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  final period = local.hour < 12 ? 'AM' : 'PM';
  final displayHour = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_months[local.month - 1]} ${local.day}, $displayHour:$minute $period';
}

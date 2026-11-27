import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/formatting/date_time_formatting.dart';
import '../../../../shared/seating/seat_numbers.dart';
import '../../../../shared/widgets/arena_notice_banner.dart';
import '../../../../shared/widgets/arena_poster_banner.dart';
import '../../domain/models/new_show.dart';
import '../../domain/models/session.dart';
import '../../domain/models/show.dart';
import 'delete_show_dialog.dart';

/// Returns a bounded `X / capacity booked` summary for a vendor session.
String formatVendorSessionBookedSummary(Session session) {
  final booked = session.bookedSeats.length.clamp(0, session.capacity);
  return '$booked / ${session.capacity} booked';
}

/// Returns the vendor-facing show-wide booked seat summary.
String formatVendorShowBookedSummary(Show show) =>
    '${show.bookedCount} booked total';

bool _hasValidSessionCount(Show show) {
  final count = show.sessionCount;
  return count != null && count >= 1 && count <= maxShowSessions;
}

/// Returns total capacity across daily sessions (`sessionCount * seatCapacity`),
/// or `null` when session count is missing or outside `1..maxShowSessions`.
int? computeVendorShowCapacity(Show show) {
  if (!_hasValidSessionCount(show)) return null;
  return show.sessionCount! * seatCapacity;
}

/// Formats the daily session count line for a vendor show card.
String formatVendorShowSessionCount(Show show) {
  if (!_hasValidSessionCount(show)) return 'Sessions unavailable';
  final count = show.sessionCount!;
  return count == 1 ? '1 daily session' : '$count daily sessions';
}

/// Formats `booked / capacity` when capacity is valid and consistent with
/// `bookedCount`, or falls back to the authoritative `'bookedCount booked'`
/// without fabricating or modifying seat totals.
String formatVendorShowOccupancyCount(Show show) {
  final capacity = computeVendorShowCapacity(show);
  if (capacity == null || show.bookedCount < 0 || show.bookedCount > capacity) {
    return '${show.bookedCount} booked';
  }
  return '${show.bookedCount} / $capacity';
}

/// Computes `[0.0, 1.0]` occupancy progress for `LinearProgressIndicator`, or
/// returns `null` when capacity is unavailable or `bookedCount` is inconsistent.
double? computeVendorShowOccupancyProgress(Show show) {
  final capacity = computeVendorShowCapacity(show);
  if (capacity == null || show.bookedCount < 0 || show.bookedCount > capacity) {
    return null;
  }
  return show.bookedCount / capacity;
}

/// Status pill indicating whether a vendor show is active or finishing deletion.
class VendorShowStatusBadge extends StatelessWidget {
  const VendorShowStatusBadge({required this.isDeleting, super.key});

  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background = isDeleting
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = isDeleting
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isDeleting ? 'Finishing delete' : 'Active',
        style: textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Operational vendor show card with thumbnail poster, metadata, occupancy
/// progress, top-right compact delete action, and deletion status banners.
class VendorShowCard extends StatelessWidget {
  const VendorShowCard({
    required this.show,
    required this.posterBytes,
    required this.isDeleting,
    required this.deleteErrorMessage,
    required this.onOpenDetails,
    required this.onDeleteShow,
    required this.onRetryDelete,
    super.key,
  });

  final Show show;
  final Uint8List? posterBytes;
  final bool isDeleting;
  final String? deleteErrorMessage;
  final VoidCallback? onOpenDetails;
  final VoidCallback onDeleteShow;
  final VoidCallback onRetryDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showDeletingStatus = show.status == ShowStatus.deleting;
    final badgeDeleting = showDeletingStatus || isDeleting;
    final effectiveOpenDetails = badgeDeleting ? null : onOpenDetails;
    final showTopDeleteAction = !showDeletingStatus;
    final dateLabel = formatShowDateLabel(show.showDate);
    final sessionLabel = formatVendorShowSessionCount(show);
    final occupancyCountLabel = formatVendorShowOccupancyCount(show);
    final occupancyProgress = computeVendorShowOccupancyProgress(show);

    final Widget summaryBody = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 72,
                height: 92,
                child: ArenaPosterBanner(
                  posterBytes: posterBytes,
                  title: show.title,
                  height: 92,
                  borderRadius: BorderRadius.circular(10),
                  fallbackLabel: '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: showTopDeleteAction ? 44 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        show.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ShowMetaRow(
                        icon: Icons.calendar_today_outlined,
                        label: dateLabel,
                      ),
                      const SizedBox(height: 4),
                      _ShowMetaRow(
                        icon: Icons.schedule_outlined,
                        label: sessionLabel,
                        labelKey: ValueKey<String>(
                          'vendor-show-sessions-${show.id}',
                        ),
                      ),
                      if (badgeDeleting) ...<Widget>[
                        const SizedBox(height: 6),
                        const VendorShowStatusBadge(isDeleting: true),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Booked seats',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                occupancyCountLabel,
                key: ValueKey<String>('vendor-show-booked-${show.id}'),
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          if (occupancyProgress != null) ...<Widget>[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              key: ValueKey<String>('vendor-show-occupancy-bar-${show.id}'),
              value: occupancyProgress,
              minHeight: 5,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary.withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );

    final Widget interactiveSummary = effectiveOpenDetails != null
        ? Semantics(
            container: true,
            button: true,
            label:
                '${show.title}, $dateLabel, $sessionLabel, Booked seats $occupancyCountLabel',
            onTap: effectiveOpenDetails,
            excludeSemantics: true,
            child: InkWell(onTap: effectiveOpenDetails, child: summaryBody),
          )
        : summaryBody;

    return Card(
      key: ValueKey<String>('vendor-show-card-${show.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: badgeDeleting
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.error.withValues(alpha: 0.45),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            children: <Widget>[
              interactiveSummary,
              if (showTopDeleteAction)
                Positioned(
                  top: 4,
                  right: 4,
                  child: AbsorbPointer(
                    absorbing: isDeleting,
                    child: IconButton(
                      key: ValueKey<String>('vendor-show-delete-${show.id}'),
                      tooltip: 'Delete show',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.padded,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: isDeleting ? null : onDeleteShow,
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ),
                ),
            ],
          ),
          if (isDeleting)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: VendorDeletingProgressBanner(
                key: ValueKey<String>(
                  'vendor-show-deleting-progress-${show.id}',
                ),
                message: 'Finishing delete…',
              ),
            )
          else if (showDeletingStatus)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ArenaNoticeBanner(
                key: ValueKey<String>('vendor-show-deleting-notice-${show.id}'),
                icon: Icons.warning_amber_rounded,
                message: deleteErrorMessage == null
                    ? 'Deletion interrupted. Bookings closed.'
                    : 'Deletion interrupted. Bookings closed. $deleteErrorMessage',
                isError: true,
                actionLabel: 'Resume delete',
                actionKey: ValueKey<String>('vendor-show-delete-${show.id}'),
                onAction: onDeleteShow,
              ),
            )
          else if (deleteErrorMessage case final error?)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ArenaNoticeBanner(
                key: ValueKey<String>('vendor-show-delete-error-${show.id}'),
                icon: Icons.error_outline,
                message: error,
                isError: true,
                actionLabel: 'Retry delete',
                actionKey: ValueKey<String>(
                  'vendor-show-retry-delete-${show.id}',
                ),
                onAction: onRetryDelete,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShowMetaRow extends StatelessWidget {
  const _ShowMetaRow({required this.icon, required this.label, this.labelKey});

  final IconData icon;
  final String label;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            key: labelKey,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

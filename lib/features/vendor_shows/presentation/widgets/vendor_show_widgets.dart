import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/formatting/date_time_formatting.dart';
import '../../../../shared/widgets/arena_icon_label.dart';
import '../../../../shared/widgets/arena_notice_banner.dart';
import '../../../../shared/widgets/arena_poster_banner.dart';
import '../../../../shared/widgets/arena_show_date_row.dart';
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

/// Vendor show summary card with delete status and retry actions.
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
    final dateLabel = formatShowDateLabel(show.showDate);
    final bookedSummary = formatVendorShowBookedSummary(show);

    final Widget summaryBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ArenaPosterBanner(
          posterBytes: posterBytes,
          title: show.title,
          height: 142,
          borderRadius: BorderRadius.zero,
          fallbackLabel: 'ARENA CONSOLE',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ArenaShowDateRow(
                showDate: show.showDate,
                trailing: VendorShowStatusBadge(isDeleting: badgeDeleting),
              ),
              const SizedBox(height: 8),
              Text(
                show.title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (show.description.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  show.description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                bookedSummary,
                key: ValueKey<String>('vendor-show-booked-${show.id}'),
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final Widget interactiveSummary = onOpenDetails != null
        ? Semantics(
            container: true,
            button: true,
            label: '${show.title}, $dateLabel, $bookedSummary',
            onTap: onOpenDetails,
            excludeSemantics: true,
            child: InkWell(onTap: onOpenDetails, child: summaryBody),
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
          interactiveSummary,
          if (isDeleting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: VendorDeletingProgressBanner(
                key: ValueKey<String>(
                  'vendor-show-deleting-progress-${show.id}',
                ),
                message: 'Finishing delete…',
              ),
            )
          else if (showDeletingStatus)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          else ...<Widget>[
            if (deleteErrorMessage case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  key: ValueKey<String>('vendor-show-delete-${show.id}'),
                  onPressed: onDeleteShow,
                  child: const ArenaIconLabel(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

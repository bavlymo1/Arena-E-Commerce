import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/formatting/date_time_formatting.dart';
import '../../../../shared/seating/widgets/seat_map_view.dart';
import '../../../../shared/widgets/arena_icon_label.dart';
import '../../../../shared/widgets/arena_notice_banner.dart';
import '../../../../shared/widgets/arena_poster_banner.dart';
import '../../../../shared/widgets/arena_show_date_row.dart';
import '../../domain/models/session.dart';
import '../../domain/models/show.dart';
import 'delete_show_dialog.dart';
import 'vendor_show_widgets.dart';

/// Header block with show artwork, formatted show date, status badge, and description.
class VendorShowDetailsHeader extends StatelessWidget {
  const VendorShowDetailsHeader({
    required this.show,
    required this.posterBytes,
    required this.isDeletingBadge,
    super.key,
  });

  final Show show;
  final Uint8List? posterBytes;
  final bool isDeletingBadge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ArenaPosterBanner(
          posterBytes: posterBytes,
          title: show.title,
          height: 184,
          borderRadius: BorderRadius.circular(16),
          fallbackLabel: 'ARENA CONSOLE',
        ),
        const SizedBox(height: 16),
        ArenaShowDateRow(
          showDate: show.showDate,
          showIcon: true,
          prominent: true,
          dateLabelKey: const ValueKey<String>('vendor-show-details-date'),
          trailing: VendorShowStatusBadge(isDeleting: isDeletingBadge),
        ),
        const SizedBox(height: 8),
        Text(
          show.title,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (show.description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            show.description.trim(),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Booking total summary and deletion controls card for a vendor show.
class VendorShowSummaryCard extends StatelessWidget {
  const VendorShowSummaryCard({
    required this.show,
    required this.isDeletingShow,
    required this.hasDeleteFailed,
    required this.deleteErrorMessage,
    required this.onDelete,
    required this.onRetryDelete,
    super.key,
  });

  final Show show;
  final bool isDeletingShow;
  final bool hasDeleteFailed;
  final String? deleteErrorMessage;
  final VoidCallback onDelete;
  final VoidCallback onRetryDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Show total',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                formatVendorShowBookedSummary(show),
                key: const ValueKey<String>('vendor-show-details-total-booked'),
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          if (isDeletingShow) ...<Widget>[
            const SizedBox(height: 12),
            const VendorDeletingProgressBanner(
              key: ValueKey<String>('vendor-show-details-deleting-progress'),
              message: 'Deleting show and removing bookings…',
            ),
          ] else if (hasDeleteFailed) ...<Widget>[
            const SizedBox(height: 12),
            ArenaNoticeBanner(
              key: const ValueKey<String>('vendor-show-details-delete-error'),
              icon: Icons.error_outline,
              message:
                  deleteErrorMessage ?? 'Unable to delete show. Try again.',
              isError: true,
              actionLabel: 'Retry delete',
              actionKey: const ValueKey<String>(
                'vendor-show-details-delete-retry-button',
              ),
              onAction: onRetryDelete,
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey<String>('vendor-show-details-delete-button'),
            onPressed: isDeletingShow ? null : onDelete,
            child: ArenaIconLabel(
              icon: Icons.delete_outline,
              label: isDeletingShow ? 'Deleting…' : 'Delete show',
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily sessions picker section for inspecting per-session occupancy.
class VendorShowSessionsSection extends StatelessWidget {
  const VendorShowSessionsSection({
    required this.sessions,
    required this.selectedSessionId,
    required this.isDeletingShow,
    required this.onSelectSession,
    super.key,
  });

  final List<Session> sessions;
  final String? selectedSessionId;
  final bool isDeletingShow;
  final ValueChanged<String> onSelectSession;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey<String>('vendor-show-details-sessions-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Daily sessions',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Select a session to inspect seats',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            const ArenaNoticeBanner(
              key: ValueKey<String>('vendor-show-details-empty-sessions'),
              icon: Icons.schedule_outlined,
              message: 'No sessions are available for this show right now.',
            )
          else
            for (final session in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VendorSessionOptionTile(
                  session: session,
                  selected: selectedSessionId == session.id,
                  onTap: isDeletingShow
                      ? null
                      : () => onSelectSession(session.id),
                ),
              ),
        ],
      ),
    );
  }
}

/// Read-only live seat map section for the currently selected session.
class VendorSessionSeatMapSection extends StatelessWidget {
  const VendorSessionSeatMapSection({
    required this.selectedSession,
    required this.onRetry,
    super.key,
  });

  final Session selectedSession;
  final VoidCallback onRetry;

  static String _selectedSessionSubtitle(Session session) {
    final label = session.label?.trim();
    final timeLabel = formatTime12Hour(session.time.value);
    return label != null && label.isNotEmpty
        ? '${session.time.value} · $timeLabel · $label'
        : '${session.time.value} · $timeLabel';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey<String>('vendor-show-details-seat-map-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Session seat map',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Read-only live view',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _selectedSessionSubtitle(selectedSession),
            key: const ValueKey<String>(
              'vendor-show-details-selected-session-subtitle',
            ),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          SeatMapView(
            key: const ValueKey<String>('vendor-session-seat-map'),
            bookedSeats: selectedSession.bookedSeats,
            vendorMode: true,
            loadState: SeatMapLoadState.ready,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}

class _VendorSessionOptionTile extends StatelessWidget {
  const _VendorSessionOptionTile({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final Session session;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final time24 = session.time.value;
    final time12 = formatTime12Hour(time24);
    final label = session.label?.trim();
    final hasLabel = label != null && label.isNotEmpty;
    final bookedLabel = formatVendorSessionBookedSummary(session);
    final semanticsText = <String>[
      '$time24 ($time12)',
      if (hasLabel) label,
      bookedLabel,
      if (selected) 'Selected',
    ].join(', ');

    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: semanticsText,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        key: ValueKey<String>('vendor-session-option-${session.id}'),
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            time24,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            time12,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (hasLabel) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        bookedLabel,
                        key: ValueKey<String>(
                          'vendor-session-booked-${session.id}',
                        ),
                        style: textTheme.labelMedium?.copyWith(
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
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

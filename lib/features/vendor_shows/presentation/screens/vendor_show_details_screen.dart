import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/seating/widgets/seat_map_view.dart';
import '../../domain/models/session.dart';
import '../cubit/vendor_show_details_cubit.dart';
import '../cubit/vendor_show_details_state.dart';
import '../widgets/vendor_show_poster_banner.dart';

/// Displays vendor-owned show details, daily sessions, and a read-only seat map.
class VendorShowDetailsScreen extends StatelessWidget {
  const VendorShowDetailsScreen({
    this.onBackToShows,
    this.onDeleteShow,
    super.key,
  });

  final VoidCallback? onBackToShows;
  final ValueChanged<String>? onDeleteShow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canGoBack = onBackToShows != null || Navigator.canPop(context);
    void handleBack() =>
        onBackToShows != null ? onBackToShows!() : Navigator.maybePop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Show details'),
        leading: canGoBack
            ? IconButton(
                key: const ValueKey<String>('vendor-show-details-back-button'),
                tooltip: 'Back to My shows',
                onPressed: handleBack,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: SafeArea(
        child: BlocBuilder<VendorShowDetailsCubit, VendorShowDetailsState>(
          builder: (context, state) {
            final cubit = context.read<VendorShowDetailsCubit>();

            if (state.isLoading) {
              return const Center(
                key: ValueKey<String>('vendor-show-details-loading'),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading show details…'),
                    ],
                  ),
                ),
              );
            }

            if (state.hasError) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: <Widget>[
                  VendorStatusPanel(
                    key: const ValueKey<String>(
                      'vendor-show-details-error-state',
                    ),
                    icon: Icons.error_outline,
                    title: 'Unable to load show details',
                    message: state.errorMessage ?? 'Unable to load show details. Your existing data is preserved.',
                    actionLabel: 'Try again',
                    actionKey: const ValueKey<String>(
                      'vendor-show-details-retry-button',
                    ),
                    onAction: cubit.retry,
                    isError: true,
                  ),
                ],
              );
            }

            if (state.isUnavailable || state.show == null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: <Widget>[
                  VendorStatusPanel(
                    key: const ValueKey<String>(
                      'vendor-show-details-unavailable-state',
                    ),
                    icon: Icons.event_busy_outlined,
                    title: 'Show unavailable',
                    message:
                        state.errorMessage ??
                        'This show no longer accepts bookings.',
                    actionLabel: 'Back to My shows',
                    actionKey: const ValueKey<String>(
                      'vendor-show-details-unavailable-back-button',
                    ),
                    onAction: handleBack,
                  ),
                ],
              );
            }

            final show = state.show!;
            final dateLabel = formatVendorShowDateLabel(show.showDate);
            final selectedSession = state.selectedSession;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: <Widget>[
                VendorShowPosterBanner(
                  posterBytes: state.posterBytes,
                  title: show.title,
                  height: 184,
                  borderRadius: BorderRadius.circular(16),
                  isLoading: state.posterLoading,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    Text(
                      dateLabel,
                      key: const ValueKey<String>('vendor-show-details-date'),
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    Text(
                      show.showDate,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Active',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  show.title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                const SizedBox(height: 16),
                Container(
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
                            key: const ValueKey<String>(
                              'vendor-show-details-total-booked',
                            ),
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
                      if (onDeleteShow != null) ...<Widget>[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          key: const ValueKey<String>(
                            'vendor-show-details-delete-button',
                          ),
                          onPressed: () => onDeleteShow!(show.id),
                          child: const VendorButtonContent(
                            icon: Icons.delete_outline,
                            label: 'Delete show',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  key: const ValueKey<String>(
                    'vendor-show-details-sessions-section',
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
                      if (state.sessions.isEmpty)
                        const VendorNoticeBanner(
                          key: ValueKey<String>(
                            'vendor-show-details-empty-sessions',
                          ),
                          icon: Icons.schedule_outlined,
                          message: 'No sessions are available for this show right now.',
                        )
                      else
                        for (final session in state.sessions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _VendorSessionOptionTile(
                              session: session,
                              selected: selectedSession?.id == session.id,
                              onTap: () => cubit.selectSession(session.id),
                            ),
                          ),
                    ],
                  ),
                ),
                if (selectedSession != null) ...<Widget>[
                  const SizedBox(height: 18),
                  Container(
                    key: const ValueKey<String>(
                      'vendor-show-details-seat-map-section',
                    ),
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
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SeatMapView(
                          key: const ValueKey<String>(
                            'vendor-session-seat-map',
                          ),
                          bookedSeats: selectedSession.bookedSeats,
                          vendorMode: true,
                          loadState: SeatMapLoadState.ready,
                          onRetry: cubit.retry,
                        ),
                      ],
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

  static String _selectedSessionSubtitle(Session session) {
    final label = session.label?.trim();
    final timeLabel = formatVendorSessionTime12Hour(session.time.value);
    return label != null && label.isNotEmpty
        ? '${session.time.value} · $timeLabel · $label'
        : '${session.time.value} · $timeLabel';
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final time24 = session.time.value;
    final time12 = formatVendorSessionTime12Hour(time24);
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

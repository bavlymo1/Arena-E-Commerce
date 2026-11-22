import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatting/date_time_formatting.dart';
import '../../../../shared/widgets/arena_notice_banner.dart';
import '../../../../shared/widgets/arena_poster_banner.dart';
import '../../../../shared/widgets/arena_status_panel.dart';
import '../../../vendor_shows/domain/models/session.dart';
import '../cubit/show_details_cubit.dart';
import '../cubit/show_details_state.dart';

/// Returns a singular/plural remaining-seat count label bounded to capacity.
String formatRemainingSeatsLabel(Session session) {
  final remaining = session.remainingSeats;
  return remaining == 1 ? '1 seat left' : '$remaining seats left';
}

class ShowDetailsScreen extends StatelessWidget {
  const ShowDetailsScreen({
    required this.onSessionSelected,
    this.onBackToDiscover,
    super.key,
  });

  final ValueChanged<String> onSessionSelected;
  final VoidCallback? onBackToDiscover;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canGoBack = onBackToDiscover != null || Navigator.canPop(context);
    void handleBack() => onBackToDiscover != null
        ? onBackToDiscover!()
        : Navigator.maybePop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Show details'),
        leading: canGoBack
            ? IconButton(
                tooltip: 'Back to Discover',
                onPressed: handleBack,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: SafeArea(
        child: BlocBuilder<ShowDetailsCubit, ShowDetailsState>(
          builder: (context, state) {
            final cubit = context.read<ShowDetailsCubit>();

            if (state.isLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading…'),
                    ],
                  ),
                ),
              );
            }

            if (state.hasError) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: <Widget>[
                  ArenaStatusPanel(
                    icon: Icons.error_outline,
                    title: 'Unable to load',
                    message: state.errorMessage ?? 'Unable to load show details. Your existing choices are preserved.',
                    actionLabel: 'Try again',
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
                  ArenaStatusPanel(
                    icon: Icons.event_busy_outlined,
                    title: 'Show unavailable',
                    message:
                        state.errorMessage ??
                        'This show no longer accepts bookings.',
                    actionLabel: 'Back to Discover',
                    onAction: handleBack,
                  ),
                ],
              );
            }

            final show = state.show!;
            final dateLabel = formatShowDateLabel(show.showDate);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: <Widget>[
                ArenaPosterBanner(
                  posterBytes: state.posterBytes,
                  title: show.title,
                  height: 176,
                  borderRadius: BorderRadius.circular(16),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    Text(
                      dateLabel,
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
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      'Sessions',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '47 seats per session',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.isAllSessionsSoldOut)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ArenaNoticeBanner(
                      icon: Icons.info_outline,
                      message: 'Sold out. All seats booked.',
                    ),
                  ),
                if (state.sessions.isEmpty)
                  const ArenaNoticeBanner(
                    icon: Icons.schedule_outlined,
                    message: 'No sessions available for this show.',
                  )
                else
                  for (final session in state.sessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SessionTile(
                        session: session,
                        onTap: () => onSessionSelected(session.id),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSoldOut = session.isSoldOut;
    final time24 = session.time.value;
    final time12 = formatTime12Hour(time24);
    final label = session.label?.trim();
    final hasLabel = label != null && label.isNotEmpty;
    final seatsLabel = formatRemainingSeatsLabel(session);
    final semanticsText = <String>[
      '$time24 ($time12)',
      if (hasLabel) label,
      seatsLabel,
      if (isSoldOut) 'Sold out',
    ].join(', ');

    return Semantics(
      container: true,
      button: true,
      enabled: !isSoldOut,
      label: semanticsText,
      onTap: isSoldOut ? null : onTap,
      excludeSemantics: true,
      child: Material(
        key: ValueKey<String>('session-chip-${session.id}'),
        color: isSoldOut
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isSoldOut ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSoldOut
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            time12,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (hasLabel)
                            Text(
                              '· $label',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        seatsLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isSoldOut)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      'Sold out',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

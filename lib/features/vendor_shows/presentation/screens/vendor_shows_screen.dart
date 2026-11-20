import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/show.dart';
import '../cubit/vendor_shows_cubit.dart';
import '../cubit/vendor_shows_state.dart';
import '../widgets/delete_show_dialog.dart';
import '../widgets/vendor_show_poster_banner.dart';

/// Displays the vendor-owned list of active and deleting shows.
class VendorShowsScreen extends StatelessWidget {
  const VendorShowsScreen({
    required this.onShowSelected,
    this.onAddShow,
    this.onDeleteShow,
    this.onOpenUpdates,
    this.unreadUpdatesCount = 0,
    super.key,
  });

  final ValueChanged<String> onShowSelected;
  final VoidCallback? onAddShow;
  final ValueChanged<String>? onDeleteShow;
  final VoidCallback? onOpenUpdates;
  final int unreadUpdatesCount;

  Future<void> _confirmAndDelete(
    BuildContext context,
    VendorShowsCubit cubit,
    Show show,
  ) async {
    final confirmed = await showDeleteShowConfirmDialog(context, show);
    if (!confirmed || !context.mounted) return;
    await cubit.deleteShow(show.id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            _VendorBrandMark(
              background: colorScheme.primary,
              foreground: colorScheme.onPrimary,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ArenaPass Console',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (onOpenUpdates != null)
            IconButton(
              key: const ValueKey<String>('vendor-shows-appbar-updates-button'),
              tooltip: unreadUpdatesCount > 0
                  ? 'Booking updates ($unreadUpdatesCount unread)'
                  : 'Booking updates',
              onPressed: onOpenUpdates,
              icon: Badge(
                isLabelVisible: unreadUpdatesCount > 0,
                label: Text('$unreadUpdatesCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<VendorShowsCubit, VendorShowsState>(
          builder: (context, state) {
            final cubit = context.read<VendorShowsCubit>();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    'My shows',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Live seat totals update as customers book.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (onAddShow != null || onOpenUpdates != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        if (onAddShow != null)
                          FilledButton(
                            key: const ValueKey<String>(
                              'vendor-shows-add-button',
                            ),
                            onPressed: onAddShow,
                            child: const VendorButtonContent(
                              icon: Icons.add,
                              label: 'Add show',
                            ),
                          ),
                        if (onOpenUpdates != null)
                          OutlinedButton(
                            key: const ValueKey<String>(
                              'vendor-shows-open-updates-button',
                            ),
                            onPressed: onOpenUpdates,
                            child: VendorButtonContent(
                              icon: Icons.notifications_outlined,
                              label: unreadUpdatesCount > 0
                                  ? 'Booking updates ($unreadUpdatesCount)'
                                  : 'Booking updates',
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (state.isLoading && state.shows.isEmpty)
                    const Center(
                      key: ValueKey<String>('vendor-shows-loading'),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading shows…'),
                          ],
                        ),
                      ),
                    )
                  else if (state.hasError && state.shows.isEmpty)
                    VendorStatusPanel(
                      key: const ValueKey<String>('vendor-shows-error-state'),
                      icon: Icons.error_outline,
                      title: 'Unable to load shows',
                      message: state.errorMessage ?? 'Unable to load shows. Your existing data is preserved.',
                      actionLabel: 'Try again',
                      actionKey: const ValueKey<String>(
                        'vendor-shows-retry-button',
                      ),
                      onAction: cubit.retry,
                      isError: true,
                    )
                  else if (state.isEmpty)
                    VendorStatusPanel(
                      key: const ValueKey<String>('vendor-shows-empty-state'),
                      icon: Icons.event_note_outlined,
                      title: 'No shows here yet',
                      message: 'Add a show with its date, artwork, and up to five daily sessions.',
                      actionLabel: onAddShow != null ? 'Add show' : null,
                      actionKey: onAddShow != null
                          ? const ValueKey<String>(
                              'vendor-shows-empty-add-button',
                            )
                          : null,
                      onAction: onAddShow,
                    )
                  else ...<Widget>[
                    if (state.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: VendorNoticeBanner(
                          key: const ValueKey<String>(
                            'vendor-shows-inline-error',
                          ),
                          icon: Icons.error_outline,
                          message: state.errorMessage ?? 'Unable to refresh shows. Showing last loaded shows.',
                          isError: true,
                          actionLabel: 'Try again',
                          actionKey: const ValueKey<String>(
                            'vendor-shows-inline-retry-button',
                          ),
                          onAction: cubit.retry,
                        ),
                      ),
                    if (state.isResumingDeletes)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: VendorDeletingProgressBanner(
                          key: ValueKey<String>('vendor-shows-resuming-banner'),
                          message: 'Finishing pending show deletions…',
                        ),
                      )
                    else if (state.resumeDeleteErrorMessage
                        case final resumeError?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: VendorNoticeBanner(
                          key: const ValueKey<String>(
                            'vendor-shows-resume-error-banner',
                          ),
                          icon: Icons.error_outline,
                          message: resumeError,
                          isError: true,
                          actionLabel: 'Try again',
                          actionKey: const ValueKey<String>(
                            'vendor-shows-resume-retry-button',
                          ),
                          onAction: () => unawaited(cubit.resumeDeletes()),
                        ),
                      ),
                    for (final show in state.shows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _VendorShowCard(
                          show: show,
                          posterBytes: state.posters[show.id],
                          posterLoading: state.loadingPosterIds.contains(
                            show.id,
                          ),
                          isDeleting:
                              state.isDeletingShow(show.id) ||
                              (show.status == ShowStatus.deleting &&
                                  state.isResumingDeletes),
                          deleteErrorMessage: state.deleteErrorFor(show.id),
                          onOpenDetails:
                              show.status == ShowStatus.active &&
                                  !state.isDeletingShow(show.id)
                              ? () => onShowSelected(show.id)
                              : null,
                          onDeleteShow: onDeleteShow != null
                              ? () => onDeleteShow!(show.id)
                              : show.status == ShowStatus.deleting
                              ? () => unawaited(cubit.deleteShow(show.id))
                              : () => unawaited(
                                  _confirmAndDelete(context, cubit, show),
                                ),
                          onRetryDelete: onDeleteShow != null
                              ? () => onDeleteShow!(show.id)
                              : () => unawaited(cubit.deleteShow(show.id)),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VendorBrandMark extends StatelessWidget {
  const _VendorBrandMark({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'A',
        style: TextStyle(
          color: foreground,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _VendorShowCard extends StatelessWidget {
  const _VendorShowCard({
    required this.show,
    required this.posterBytes,
    required this.posterLoading,
    required this.isDeleting,
    required this.deleteErrorMessage,
    required this.onOpenDetails,
    required this.onDeleteShow,
    required this.onRetryDelete,
  });

  final Show show;
  final Uint8List? posterBytes;
  final bool posterLoading;
  final bool isDeleting;
  final String? deleteErrorMessage;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onDeleteShow;
  final VoidCallback? onRetryDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showDeletingStatus = show.status == ShowStatus.deleting;
    final badgeDeleting = showDeletingStatus || isDeleting;
    final dateLabel = formatVendorShowDateLabel(show.showDate);
    final bookedSummary = formatVendorShowBookedSummary(show);

    final Widget summaryBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        VendorShowPosterBanner(
          posterBytes: posterBytes,
          title: show.title,
          height: 142,
          borderRadius: BorderRadius.zero,
          isLoading: posterLoading,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    dateLabel,
                    style: textTheme.labelMedium?.copyWith(
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
                  _ShowStatusBadge(isDeleting: badgeDeleting),
                ],
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

    return Material(
      key: ValueKey<String>('vendor-show-card-${show.id}'),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: badgeDeleting
              ? colorScheme.error.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
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
              child: VendorNoticeBanner(
                key: ValueKey<String>('vendor-show-deleting-notice-${show.id}'),
                icon: Icons.warning_amber_rounded,
                message: deleteErrorMessage == null
                    ? 'Deletion interrupted. Bookings closed.'
                    : 'Deletion interrupted. Bookings closed. $deleteErrorMessage',
                isError: true,
                actionLabel: onDeleteShow != null ? 'Resume delete' : null,
                actionKey: onDeleteShow != null
                    ? ValueKey<String>('vendor-show-delete-${show.id}')
                    : null,
                onAction: onDeleteShow,
              ),
            )
          else ...<Widget>[
            if (deleteErrorMessage case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: VendorNoticeBanner(
                  key: ValueKey<String>('vendor-show-delete-error-${show.id}'),
                  icon: Icons.error_outline,
                  message: error,
                  isError: true,
                  actionLabel: onRetryDelete != null ? 'Retry delete' : null,
                  actionKey: onRetryDelete != null
                      ? ValueKey<String>('vendor-show-retry-delete-${show.id}')
                      : null,
                  onAction: onRetryDelete,
                ),
              ),
            if (onDeleteShow != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    key: ValueKey<String>('vendor-show-delete-${show.id}'),
                    onPressed: onDeleteShow,
                    child: const VendorButtonContent(
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

class _ShowStatusBadge extends StatelessWidget {
  const _ShowStatusBadge({required this.isDeleting});

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

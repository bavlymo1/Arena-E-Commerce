import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/arena_brand_app_bar_title.dart';
import '../../../../shared/widgets/arena_loading_view.dart';
import '../../../../shared/widgets/arena_notice_banner.dart';
import '../../../../shared/widgets/arena_status_panel.dart';
import '../../domain/models/show.dart';
import '../cubit/vendor_shows_cubit.dart';
import '../cubit/vendor_shows_state.dart';
import '../widgets/delete_show_dialog.dart';
import '../widgets/vendor_show_widgets.dart';

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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const ArenaBrandAppBarTitle(title: 'My shows'),
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
      floatingActionButton: onAddShow != null
          ? FloatingActionButton(
              key: const ValueKey<String>('vendor-shows-add-fab'),
              tooltip: 'Add show',
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              onPressed: onAddShow,
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: BlocBuilder<VendorShowsCubit, VendorShowsState>(
          builder: (context, state) {
            final cubit = context.read<VendorShowsCubit>();

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                onAddShow != null ? 96 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (state.isLoading && state.shows.isEmpty)
                    const ArenaLoadingView(
                      key: ValueKey<String>('vendor-shows-loading'),
                      label: 'Loading shows…',
                      padding: EdgeInsets.symmetric(vertical: 48),
                    )
                  else if (state.hasError && state.shows.isEmpty)
                    ArenaStatusPanel(
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
                    ArenaStatusPanel(
                      key: const ValueKey<String>('vendor-shows-empty-state'),
                      icon: Icons.event_note_outlined,
                      title: 'No shows here yet',
                      message: onAddShow != null
                          ? 'Use the + button to add a show with its date, artwork, and up to five daily sessions.'
                          : 'Shows added for this vendor will appear here.',
                    )
                  else ...<Widget>[
                    if (state.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ArenaNoticeBanner(
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
                        child: ArenaNoticeBanner(
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
                        child: VendorShowCard(
                          show: show,
                          posterBytes: state.posters[show.id],
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

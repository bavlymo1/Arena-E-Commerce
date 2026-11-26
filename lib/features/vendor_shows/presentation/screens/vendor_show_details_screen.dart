import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/arena_loading_view.dart';
import '../../../../shared/widgets/arena_status_panel.dart';
import '../../domain/models/show.dart';
import '../cubit/vendor_show_details_cubit.dart';
import '../cubit/vendor_show_details_state.dart';
import '../widgets/delete_show_dialog.dart';
import '../widgets/vendor_show_details_sections.dart';

/// Displays vendor-owned show details, daily sessions, and a read-only seat map.
class VendorShowDetailsScreen extends StatelessWidget {
  const VendorShowDetailsScreen({
    this.onBackToShows,
    this.onDeleteShow,
    super.key,
  });

  final VoidCallback? onBackToShows;
  final ValueChanged<String>? onDeleteShow;

  Future<void> _confirmAndDelete(
    BuildContext context,
    VendorShowDetailsCubit cubit,
    Show show,
  ) async {
    final confirmed = await showDeleteShowConfirmDialog(context, show);
    if (!confirmed || !context.mounted) return;
    await cubit.deleteShow();
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = onBackToShows != null || Navigator.canPop(context);
    void handleBack() =>
        onBackToShows != null ? onBackToShows!() : Navigator.maybePop(context);

    return BlocConsumer<VendorShowDetailsCubit, VendorShowDetailsState>(
      listenWhen: (previous, current) =>
          previous.deleteStatus != current.deleteStatus &&
          current.isDeleteCompleted,
      listener: (context, _) => handleBack(),
      builder: (context, state) {
        final cubit = context.read<VendorShowDetailsCubit>();

        return PopScope(
          canPop: !state.isDeletingShow,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Show details'),
              leading: canGoBack
                  ? IconButton(
                      key: const ValueKey<String>(
                        'vendor-show-details-back-button',
                      ),
                      tooltip: 'Back to My shows',
                      onPressed: state.isDeletingShow ? null : handleBack,
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
            ),
            body: SafeArea(
              child: Builder(
                builder: (context) {
                  if (state.isLoading) {
                    return const ArenaLoadingView(
                      key: ValueKey<String>('vendor-show-details-loading'),
                      label: 'Loading show details…',
                    );
                  }

                  if (state.hasError) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      children: <Widget>[
                        ArenaStatusPanel(
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
                        ArenaStatusPanel(
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
                  final selectedSession = state.selectedSession;
                  final isDeletingBadge =
                      show.status == ShowStatus.deleting ||
                      state.isDeletingShow;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: <Widget>[
                      VendorShowDetailsHeader(
                        show: show,
                        posterBytes: state.posterBytes,
                        isDeletingBadge: isDeletingBadge,
                      ),
                      const SizedBox(height: 16),
                      VendorShowSummaryCard(
                        show: show,
                        isDeletingShow: state.isDeletingShow,
                        hasDeleteFailed: state.hasDeleteFailed,
                        deleteErrorMessage: state.deleteErrorMessage,
                        onDelete: onDeleteShow != null
                            ? () => onDeleteShow!(show.id)
                            : () => unawaited(
                                _confirmAndDelete(context, cubit, show),
                              ),
                        onRetryDelete: onDeleteShow != null
                            ? () => onDeleteShow!(show.id)
                            : () => unawaited(cubit.deleteShow()),
                      ),
                      const SizedBox(height: 24),
                      VendorShowSessionsSection(
                        sessions: state.sessions,
                        selectedSessionId: selectedSession?.id,
                        isDeletingShow: state.isDeletingShow,
                        onSelectSession: cubit.selectSession,
                      ),
                      if (selectedSession != null) ...<Widget>[
                        const SizedBox(height: 18),
                        VendorSessionSeatMapSection(
                          selectedSession: selectedSession,
                          onRetry: cubit.retry,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

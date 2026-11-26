import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatting/date_time_formatting.dart';
import '../../../../shared/widgets/arena_brand_app_bar_title.dart';
import '../../../../shared/widgets/arena_loading_view.dart';
import '../../../../shared/widgets/arena_poster_banner.dart';
import '../../../../shared/widgets/arena_show_date_row.dart';
import '../../../../shared/widgets/arena_status_panel.dart';
import '../../../vendor_shows/domain/models/show.dart';
import '../cubit/discovery_cubit.dart';
import '../cubit/discovery_state.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({
    required this.onShowSelected,
    this.onAccount,
    super.key,
  });

  final ValueChanged<String> onShowSelected;
  final VoidCallback? onAccount;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initialQuery = context.read<DiscoveryCubit>().state.searchQuery;
    _searchController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.onAccount != null)
            IconButton(
              tooltip: 'Account',
              onPressed: widget.onAccount,
              icon: const Icon(Icons.account_circle_outlined),
            ),
        ],
        titleSpacing: 16,
        title: const ArenaBrandAppBarTitle(title: 'Discover shows'),
      ),
      body: SafeArea(
        child: BlocConsumer<DiscoveryCubit, DiscoveryState>(
          listenWhen: (previous, current) =>
              previous.searchQuery != current.searchQuery,
          listener: (context, state) {
            if (_searchController.text != state.searchQuery) {
              _searchController.value = TextEditingValue(
                text: state.searchQuery,
                selection: TextSelection.collapsed(
                  offset: state.searchQuery.length,
                ),
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<DiscoveryCubit>();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: <Widget>[
                TextField(
                  key: const ValueKey<String>('discovery-search-field'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: cubit.updateSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search by title',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey<String>(
                              'discovery-search-clear',
                            ),
                            tooltip: 'Clear search',
                            onPressed: cubit.clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (state.isLoading)
                  const ArenaLoadingView(
                    label: 'Loading…',
                    padding: EdgeInsets.symmetric(vertical: 48),
                  )
                else if (state.hasError)
                  ArenaStatusPanel(
                    icon: Icons.error_outline,
                    title: 'Unable to load',
                    message: state.errorMessage ?? 'Unable to load shows. Your existing choices are preserved.',
                    actionLabel: 'Try again',
                    onAction: cubit.retry,
                    isError: true,
                  )
                else if (state.isEmpty)
                  const ArenaStatusPanel(
                    icon: Icons.event_outlined,
                    title: 'No shows here yet',
                    message: 'New shows will appear here.',
                  )
                else if (state.isNoMatch)
                  ArenaStatusPanel(
                    icon: Icons.search_off_outlined,
                    title: 'No matching shows',
                    message: 'Try another title.',
                    actionLabel: 'Clear search',
                    onAction: cubit.clearSearch,
                    useOutlinedAction: true,
                  )
                else ...<Widget>[
                  for (final show in state.filteredShows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DiscoverShowCard(
                        show: show,
                        posterBytes: state.posters[show.id],
                        onTap: () => widget.onShowSelected(show.id),
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

class _DiscoverShowCard extends StatelessWidget {
  const _DiscoverShowCard({
    required this.show,
    required this.posterBytes,
    required this.onTap,
  });

  final Show show;
  final Uint8List? posterBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final dateLabel = formatShowDateLabel(show.showDate);

    return Semantics(
      container: true,
      button: true,
      label: '${show.title}, $dateLabel',
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        key: ValueKey<String>('discover-show-card-${show.id}'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ArenaPosterBanner(
                posterBytes: posterBytes,
                title: show.title,
                height: 142,
                borderRadius: BorderRadius.zero,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ArenaShowDateRow(showDate: show.showDate),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

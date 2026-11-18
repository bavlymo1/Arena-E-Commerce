import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../vendor_shows/domain/models/show.dart';
import '../cubit/discovery_cubit.dart';
import '../cubit/discovery_state.dart';
import '../widgets/show_poster_banner.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
        title: Row(
          children: <Widget>[
            _ArenaBrandMark(
              background: colorScheme.primary,
              foreground: colorScheme.onPrimary,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ArenaPass',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
                Text(
                  'ArenaPass',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover shows',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
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
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Showing newest active shows · search filters loaded shows',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (state.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading…'),
                        ],
                      ),
                    ),
                  )
                else if (state.hasError)
                  DiscoveryStatusPanel(
                    icon: Icons.error_outline,
                    title: 'Unable to load',
                    message: state.errorMessage ?? 'Unable to load shows. Your existing choices are preserved.',
                    actionLabel: 'Try again',
                    onAction: cubit.retry,
                    isError: true,
                  )
                else if (state.isEmpty)
                  const DiscoveryStatusPanel(
                    icon: Icons.event_outlined,
                    title: 'No shows here yet',
                    message: 'New shows will appear here.',
                  )
                else if (state.isNoMatch)
                  DiscoveryStatusPanel(
                    icon: Icons.search_off_outlined,
                    title: 'No matching shows',
                    message: 'Try another title.',
                    actionLabel: 'Clear search',
                    onAction: cubit.clearSearch,
                    useOutlinedAction: true,
                  )
                else ...<Widget>[
                  Text(
                    'Recently added',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final show in state.filteredShows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DiscoverShowCard(
                        show: show,
                        posterBytes: state.posters[show.id],
                        posterLoading: state.loadingPosterIds.contains(show.id),
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

class _ArenaBrandMark extends StatelessWidget {
  const _ArenaBrandMark({required this.background, required this.foreground});

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

class _DiscoverShowCard extends StatelessWidget {
  const _DiscoverShowCard({
    required this.show,
    required this.posterBytes,
    required this.posterLoading,
    required this.onTap,
  });

  final Show show;
  final Uint8List? posterBytes;
  final bool posterLoading;
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
      child: Material(
        key: ValueKey<String>('discover-show-card-${show.id}'),
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ShowPosterBanner(
                posterBytes: posterBytes,
                title: show.title,
                height: 142,
                borderRadius: BorderRadius.zero,
                isLoading: posterLoading,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
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

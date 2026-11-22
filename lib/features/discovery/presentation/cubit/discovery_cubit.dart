import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../vendor_shows/domain/models/show.dart';
import '../../../vendor_shows/domain/repositories/shows_repository.dart';
import 'discovery_state.dart';

final class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(this._repository, {bool autoStart = true})
    : super(DiscoveryState()) {
    if (autoStart) {
      unawaited(start());
    }
  }

  static const int feedLimit = 100;

  final ShowsRepository _repository;
  StreamSubscription<List<Show>>? _showsSubscription;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _activeStartFuture;
  int _listenGeneration = 0;
  bool _awaitingInitialEvent = false;
  bool _openingSubscription = false;
  final _posterRequests = <String, Object>{};

  Future<void> start() {
    if (isClosed) return Future<void>.value();
    if (_awaitingInitialEvent && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening();
  }

  Future<void> retry() {
    if (isClosed) return Future<void>.value();
    if (_openingSubscription && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening(retryMissingPosters: true);
  }

  Future<void> _startListening({bool retryMissingPosters = false}) {
    final generation = ++_listenGeneration;
    _awaitingInitialEvent = true;
    _openingSubscription = true;
    _posterRequests.clear();

    final nextPosters = retryMissingPosters
        ? <String, Uint8List?>{}
        : state.posters;

    emit(
      state.copyWith(
        status: DiscoveryStatus.loading,
        posters: nextPosters,
        loadingPosterIds: const <String>{},
        clearErrorMessage: true,
      ),
    );

    final startFuture = _openSubscription(
      generation,
      refreshPosters: retryMissingPosters,
    );
    _activeStartFuture = startFuture;
    return startFuture;
  }

  Future<void> _openSubscription(
    int generation, {
    required bool refreshPosters,
  }) async {
    try {
      await _cancelSubscription();
      if (isClosed || generation != _listenGeneration) return;
      if (refreshPosters) _repository.clearPosterCache();
      _showsSubscription = _repository
          .watchActiveShows(limit: feedLimit)
          .listen(
            (shows) => _onShowsSnapshot(generation, shows),
            onError: (Object _) => _onStreamError(generation),
            onDone: () {
              if (generation == _listenGeneration) {
                _showsSubscription = null;
                _awaitingInitialEvent = false;
              }
            },
          );
    } catch (_) {
      if (generation == _listenGeneration) _openingSubscription = false;
      _onStreamError(generation);
      await _cancelSubscription();
    } finally {
      if (generation == _listenGeneration) _openingSubscription = false;
    }
  }

  void updateSearchQuery(String query) {
    if (isClosed || state.searchQuery == query) return;
    emit(
      state.copyWith(
        searchQuery: query,
        filteredShows: _filterShows(state.shows, query),
      ),
    );
  }

  void clearSearch() => updateSearchQuery('');

  void _onShowsSnapshot(int generation, List<Show> rawShows) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;

    final activeShows =
        rawShows.where((show) => show.status == ShowStatus.active).toList()
          ..sort(Show.compareNewestFirst);
    final activeIds = activeShows.map((show) => show.id).toSet();
    final previous = {for (final show in state.shows) show.id: show};
    final changedIds = {
      for (final show in activeShows)
        if (previous[show.id] case final old?
            when old.posterRevision != show.posterRevision)
          show.id,
    };
    final removedIds = previous.keys.toSet().difference(activeIds);
    for (final id in {...changedIds, ...removedIds}) {
      _posterRequests.remove(id);
      _repository.invalidatePoster(id);
    }

    final retainedPosters = <String, Uint8List?>{
      for (final entry in state.posters.entries)
        if (activeIds.contains(entry.key) && !changedIds.contains(entry.key))
          entry.key: entry.value,
    };
    final updatedLoading = state.loadingPosterIds
        .where((id) => activeIds.contains(id) && !changedIds.contains(id))
        .toSet();

    final idsToLoad = <String>[];
    for (final show in activeShows) {
      if (!retainedPosters.containsKey(show.id) &&
          updatedLoading.add(show.id)) {
        idsToLoad.add(show.id);
      }
    }

    emit(
      state.copyWith(
        status: DiscoveryStatus.ready,
        shows: activeShows,
        filteredShows: _filterShows(activeShows, state.searchQuery),
        posters: retainedPosters,
        loadingPosterIds: updatedLoading,
        clearErrorMessage: true,
      ),
    );

    for (final showId in idsToLoad) {
      unawaited(_loadPoster(generation, showId));
    }
  }

  Future<void> _loadPoster(int generation, String showId) async {
    final request = Object();
    _posterRequests[showId] = request;
    Uint8List? bytes;
    try {
      bytes = await _repository.loadPoster(showId);
    } catch (_) {
      bytes = null;
    }
    if (isClosed ||
        generation != _listenGeneration ||
        !identical(_posterRequests[showId], request)) {
      return;
    }

    final updatedLoading = state.loadingPosterIds.toSet()..remove(showId);
    final stillPresent = state.shows.any((show) => show.id == showId);
    if (!stillPresent) {
      if (updatedLoading.length != state.loadingPosterIds.length) {
        emit(state.copyWith(loadingPosterIds: updatedLoading));
      }
      return;
    }

    final updatedPosters = Map<String, Uint8List?>.from(state.posters)
      ..[showId] = bytes;
    emit(
      state.copyWith(posters: updatedPosters, loadingPosterIds: updatedLoading),
    );
  }

  void _onStreamError(int generation) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;
    emit(
      state.copyWith(
        status: DiscoveryStatus.error,
        loadingPosterIds: const <String>{},
        errorMessage:
            'Unable to load shows. Your existing choices are preserved.',
      ),
    );
  }

  static List<Show> _filterShows(List<Show> shows, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return shows;
    return List<Show>.unmodifiable(
      shows.where((show) => show.titleSearch.contains(normalized)),
    );
  }

  Future<void> _cancelSubscription() {
    final subscription = _showsSubscription;
    _showsSubscription = null;
    if (subscription == null) return _cancellation;
    return _cancellation = Future.wait<void>(<Future<void>>[
      _cancellation,
      Future<void>.sync(subscription.cancel).catchError((Object _) {}),
    ]).then((_) {});
  }

  @override
  Future<void> close() async {
    _listenGeneration++;
    _awaitingInitialEvent = false;
    await Future.wait<void>(<Future<void>>[
      _cancelSubscription(),
      super.close(),
    ]);
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../vendor_shows/domain/models/show.dart';
import '../../../vendor_shows/domain/repositories/shows_repository.dart';
import '../../../vendor_shows/domain/services/show_poster_coordination.dart';
import 'discovery_state.dart';

final class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(this._repository, {bool autoStart = true})
    : _posterCoordinator = ShowFeedPosterCoordinator(_repository),
      super(DiscoveryState()) {
    if (autoStart) {
      unawaited(start());
    }
  }

  static const int feedLimit = 100;

  final ShowsRepository _repository;
  final ShowFeedPosterCoordinator _posterCoordinator;
  StreamSubscription<List<Show>>? _showsSubscription;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _activeStartFuture;
  int _listenGeneration = 0;
  bool _awaitingInitialEvent = false;
  bool _openingSubscription = false;

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
    _posterCoordinator.reset();

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
    final posterPlan = _posterCoordinator.reconcileSnapshot(
      previousShows: state.shows,
      nextShows: activeShows,
      currentPosters: state.posters,
      currentLoadingIds: state.loadingPosterIds,
    );

    emit(
      state.copyWith(
        status: DiscoveryStatus.ready,
        shows: activeShows,
        filteredShows: _filterShows(activeShows, state.searchQuery),
        posters: posterPlan.retainedPosters,
        loadingPosterIds: posterPlan.loadingPosterIds,
        clearErrorMessage: true,
      ),
    );

    for (final showId in posterPlan.idsToLoad) {
      unawaited(_loadPoster(generation, showId));
    }
  }

  Future<void> _loadPoster(int generation, String showId) async {
    final result = await _posterCoordinator.loadPoster(
      showId: showId,
      isActive: () => !isClosed && generation == _listenGeneration,
    );
    if (result == null || isClosed || generation != _listenGeneration) {
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
      ..[showId] = result.bytes;
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

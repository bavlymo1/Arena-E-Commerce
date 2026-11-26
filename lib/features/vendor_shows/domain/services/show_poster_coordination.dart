import 'dart:typed_data';

import '../models/new_show.dart';
import '../models/session.dart';
import '../models/show.dart';
import '../repositories/shows_repository.dart';

/// Sorts [sessions] chronologically and caps the result to [maxSessions].
List<Session> sortAndBoundSessions(
  Iterable<Session> sessions, {
  int maxSessions = maxShowSessions,
}) {
  final ordered = List<Session>.of(sessions)
    ..sort((a, b) => a.time.value.compareTo(b.time.value));
  return List<Session>.unmodifiable(ordered.take(maxSessions));
}

/// Result of reconciling a feed snapshot against retained and loading posters.
final class ShowFeedPosterPlan {
  const ShowFeedPosterPlan({
    required this.retainedPosters,
    required this.loadingPosterIds,
    required this.idsToLoad,
  });

  final Map<String, Uint8List?> retainedPosters;
  final Set<String> loadingPosterIds;
  final List<String> idsToLoad;
}

/// Completed poster load payload for a still-current feed request.
final class ShowFeedPosterLoadResult {
  const ShowFeedPosterLoadResult({required this.showId, required this.bytes});

  final String showId;
  final Uint8List? bytes;
}

/// Coordinates per-show poster cache invalidation and in-flight request tokens
/// across show-feed snapshots.
final class ShowFeedPosterCoordinator {
  ShowFeedPosterCoordinator(this._repository);

  final ShowsRepository _repository;
  final Map<String, Object> _requests = <String, Object>{};

  int get pendingRequestCount => _requests.length;

  bool hasPendingRequest(String showId) => _requests.containsKey(showId);

  /// Clears all active request tokens when restarting stream subscriptions.
  void reset() {
    _requests.clear();
  }

  /// Diffs [previousShows] against [nextShows], invalidates changed or removed
  /// poster entries, and returns retained, loading, and newly requested IDs.
  ShowFeedPosterPlan reconcileSnapshot({
    required List<Show> previousShows,
    required List<Show> nextShows,
    required Map<String, Uint8List?> currentPosters,
    required Set<String> currentLoadingIds,
  }) {
    final nextIds = nextShows.map((show) => show.id).toSet();
    final previousById = <String, Show>{
      for (final show in previousShows) show.id: show,
    };
    final changedIds = <String>{
      for (final show in nextShows)
        if (previousById[show.id] case final old?
            when old.posterRevision != show.posterRevision)
          show.id,
    };
    final removedIds = previousById.keys.toSet().difference(nextIds);
    for (final id in <String>{...changedIds, ...removedIds}) {
      _requests.remove(id);
      _repository.invalidatePoster(id);
    }

    final retainedPosters = <String, Uint8List?>{
      for (final entry in currentPosters.entries)
        if (nextIds.contains(entry.key) && !changedIds.contains(entry.key))
          entry.key: entry.value,
    };
    final updatedLoading = currentLoadingIds
        .where((id) => nextIds.contains(id) && !changedIds.contains(id))
        .toSet();

    final idsToLoad = <String>[];
    for (final show in nextShows) {
      if (!retainedPosters.containsKey(show.id) &&
          updatedLoading.add(show.id)) {
        idsToLoad.add(show.id);
      }
    }

    return ShowFeedPosterPlan(
      retainedPosters: retainedPosters,
      loadingPosterIds: updatedLoading,
      idsToLoad: idsToLoad,
    );
  }

  /// Loads [showId]'s poster with token verification and removes the completed
  /// token from [_requests] when it is still the active request for [showId].
  Future<ShowFeedPosterLoadResult?> loadPoster({
    required String showId,
    required bool Function() isActive,
  }) async {
    final request = Object();
    _requests[showId] = request;
    Uint8List? bytes;
    try {
      bytes = await _repository.loadPoster(showId);
    } catch (_) {
      bytes = null;
    }
    if (!identical(_requests[showId], request)) {
      return null;
    }
    _requests.remove(showId);
    if (!isActive()) {
      return null;
    }
    return ShowFeedPosterLoadResult(showId: showId, bytes: bytes);
  }
}

/// Coordinates single-show poster revision invalidation, loading state, and
/// stale-completion filtering for show details Cubits.
final class SingleShowPosterCoordinator {
  SingleShowPosterCoordinator(this._repository, {required this.showId});

  final ShowsRepository _repository;
  final String showId;

  bool _requestStarted = false;
  bool _loading = false;
  Uint8List? _bytes;
  Object? _revision;
  int _requestId = 0;

  bool get isLoading => _loading;
  Uint8List? get bytes => _bytes;

  /// Invalidates in-flight poster loads and resets cached bytes/revision state.
  void reset({bool invalidateCache = false}) {
    _requestId++;
    if (invalidateCache) {
      _repository.invalidatePoster(showId);
    }
    _requestStarted = false;
    _loading = false;
    _bytes = null;
    _revision = null;
  }

  /// Clears the loading flag on stream error while retaining cached bytes.
  void cancelLoadingState() {
    _loading = false;
  }

  /// Tracks [revision] for an active show and returns a request token when a
  /// new poster load should start, or `null` if cached/in-flight work suffices.
  int? prepareLoadForRevision(Object revision) {
    if (_revision != null && _revision != revision) {
      _requestId++;
      _requestStarted = false;
      _bytes = null;
      _repository.invalidatePoster(showId);
    }
    _revision = revision;

    if (_requestStarted || _bytes != null) {
      return null;
    }
    _requestStarted = true;
    _loading = true;
    return ++_requestId;
  }

  /// Loads the poster for [requestId], returning `true` only if the completion
  /// is still current and the show remains valid.
  Future<bool> completeLoad(
    int requestId, {
    required bool Function() isActive,
    required bool Function() isShowValid,
  }) async {
    Uint8List? loadedBytes;
    try {
      loadedBytes = await _repository.loadPoster(showId);
    } catch (_) {
      loadedBytes = null;
    }
    if (!isActive() || requestId != _requestId) {
      return false;
    }

    _loading = false;
    if (!isShowValid()) {
      return false;
    }
    _bytes = loadedBytes;
    return true;
  }
}

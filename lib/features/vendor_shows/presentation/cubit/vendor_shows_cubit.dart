import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/show.dart';
import '../../domain/repositories/shows_repository.dart';
import '../../domain/services/show_poster_coordination.dart';
import 'vendor_shows_state.dart';

/// Manages the vendor-owned list of active and deleting shows plus posters.
final class VendorShowsCubit extends Cubit<VendorShowsState> {
  VendorShowsCubit(
    this._repository, {
    required String vendorId,
    bool autoStart = true,
  }) : _posterCoordinator = ShowFeedPosterCoordinator(_repository),
       super(VendorShowsState(vendorId: _requireNonEmpty(vendorId))) {
    if (autoStart) {
      unawaited(start());
    }
  }

  final ShowsRepository _repository;
  final ShowFeedPosterCoordinator _posterCoordinator;
  StreamSubscription<List<Show>>? _showsSubscription;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _activeStartFuture;
  Future<void>? _activeResumeFuture;
  int _listenGeneration = 0;
  bool _awaitingInitialEvent = false;
  bool _openingSubscription = false;

  static String _requireNonEmpty(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'vendorId', 'Must not be empty');
    }
    return value;
  }

  /// Begins watching shows owned by `state.vendorId` and resumes pending deletes.
  Future<void> start() {
    if (isClosed) return Future<void>.value();
    if (_awaitingInitialEvent && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    final future = _startListening();
    unawaited(resumeDeletes());
    return future;
  }

  /// Re-subscribes after an error and refreshes cached show posters.
  Future<void> retry() {
    if (isClosed) return Future<void>.value();
    if (_openingSubscription && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    final future = _startListening(retryPosters: true);
    unawaited(resumeDeletes());
    return future;
  }

  /// Resumes any interrupted show deletions for [VendorShowsState.vendorId].
  Future<void> resumeDeletes() {
    if (isClosed) return Future<void>.value();
    if (_activeResumeFuture != null) return _activeResumeFuture!;
    final future = _runResumeDeletes();
    _activeResumeFuture = future;
    return future;
  }

  Future<void> _runResumeDeletes() async {
    emit(
      state.copyWith(
        isResumingDeletes: true,
        clearResumeDeleteErrorMessage: true,
      ),
    );
    try {
      await _repository.resumeDeletes(state.vendorId);
      if (isClosed) return;
      emit(
        state.copyWith(
          isResumingDeletes: false,
          clearResumeDeleteErrorMessage: true,
        ),
      );
    } on UnsupportedError {
      if (isClosed) return;
      emit(
        state.copyWith(
          isResumingDeletes: false,
          clearResumeDeleteErrorMessage: true,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isResumingDeletes: false,
          resumeDeleteErrorMessage:
              'Unable to finish pending deletions. Try again.',
        ),
      );
    } finally {
      _activeResumeFuture = null;
    }
  }

  /// Deletes [showId] and all child/paired records, ignoring duplicate taps while active.
  Future<void> deleteShow(String showId) async {
    if (isClosed || showId.trim().isEmpty) return;
    if (state.deletingShowIds.contains(showId)) return;

    final nextDeleting = Set<String>.from(state.deletingShowIds)..add(showId);
    final nextErrors = Map<String, String>.from(state.deleteErrors)
      ..remove(showId);
    emit(
      state.copyWith(deletingShowIds: nextDeleting, deleteErrors: nextErrors),
    );

    try {
      await _repository.deleteShow(showId);
      if (isClosed) return;
      final remainingDeleting = Set<String>.from(state.deletingShowIds)
        ..remove(showId);
      final remainingErrors = Map<String, String>.from(state.deleteErrors)
        ..remove(showId);
      emit(
        state.copyWith(
          deletingShowIds: remainingDeleting,
          deleteErrors: remainingErrors,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      final remainingDeleting = Set<String>.from(state.deletingShowIds)
        ..remove(showId);
      final remainingErrors = Map<String, String>.from(state.deleteErrors)
        ..[showId] = error is UnsupportedError
            ? 'Show deletion is not configured in this preview.'
            : 'Unable to delete show. Try again.';
      emit(
        state.copyWith(
          deletingShowIds: remainingDeleting,
          deleteErrors: remainingErrors,
        ),
      );
    }
  }

  Future<void> _startListening({bool retryPosters = false}) {
    final generation = ++_listenGeneration;
    _awaitingInitialEvent = true;
    _openingSubscription = true;
    _posterCoordinator.reset();

    final nextPosters = retryPosters ? <String, Uint8List?>{} : state.posters;
    emit(
      state.copyWith(
        status: VendorShowsStatus.loading,
        posters: nextPosters,
        loadingPosterIds: const <String>{},
        clearErrorMessage: true,
      ),
    );

    final startFuture = _openSubscription(
      generation,
      refreshPosters: retryPosters,
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
          .watchVendorShows(state.vendorId)
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

  void _onShowsSnapshot(int generation, List<Show> rawShows) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;

    final ownedShows =
        rawShows
            .where(
              (show) =>
                  show.vendorId == state.vendorId &&
                  (show.status == ShowStatus.active ||
                      show.status == ShowStatus.deleting),
            )
            .toList()
          ..sort(Show.compareNewestFirst);
    final ownedIds = ownedShows.map((show) => show.id).toSet();
    final posterPlan = _posterCoordinator.reconcileSnapshot(
      previousShows: state.shows,
      nextShows: ownedShows,
      currentPosters: state.posters,
      currentLoadingIds: state.loadingPosterIds,
    );
    final retainedErrors = <String, String>{
      for (final entry in state.deleteErrors.entries)
        if (ownedIds.contains(entry.key)) entry.key: entry.value,
    };

    emit(
      state.copyWith(
        status: VendorShowsStatus.ready,
        shows: ownedShows,
        posters: posterPlan.retainedPosters,
        loadingPosterIds: posterPlan.loadingPosterIds,
        deleteErrors: retainedErrors,
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
        status: VendorShowsStatus.error,
        loadingPosterIds: const <String>{},
        errorMessage: 'Unable to load shows. Your existing data is preserved.',
      ),
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

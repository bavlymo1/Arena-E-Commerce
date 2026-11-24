import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../vendor_shows/domain/models/new_show.dart';
import '../../../vendor_shows/domain/models/session.dart';
import '../../../vendor_shows/domain/models/show.dart';
import '../../../vendor_shows/domain/repositories/shows_repository.dart';
import '../../../vendor_shows/domain/services/show_poster_coordination.dart';
import 'show_details_state.dart';

final class ShowDetailsCubit extends Cubit<ShowDetailsState> {
  ShowDetailsCubit(
    this._repository, {
    required String showId,
    bool autoStart = true,
  }) : _poster = SingleShowPosterCoordinator(
         _repository,
         showId: _requireNonEmpty(showId),
       ),
       super(ShowDetailsState(showId: _requireNonEmpty(showId))) {
    if (autoStart) {
      unawaited(start());
    }
  }

  static const int maxSessions = maxShowSessions;

  final ShowsRepository _repository;
  final SingleShowPosterCoordinator _poster;
  StreamSubscription<Show?>? _showSubscription;
  StreamSubscription<List<Session>>? _sessionsSubscription;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _activeStartFuture;

  int _listenGeneration = 0;
  bool _awaitingInitialEvent = false;
  bool _hasShowSnapshot = false;
  bool _hasSessionsSnapshot = false;
  Show? _latestShow;
  List<Session> _latestSessions = const <Session>[];
  bool _openingSubscriptions = false;

  static String _requireNonEmpty(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'showId', 'Must not be empty');
    }
    return value;
  }

  Future<void> start() {
    if (isClosed) return Future<void>.value();
    if (_awaitingInitialEvent && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening();
  }

  Future<void> retry() {
    if (isClosed) return Future<void>.value();
    if (_openingSubscriptions && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening(refreshPoster: true);
  }

  Future<void> _startListening({bool refreshPoster = false}) {
    final generation = ++_listenGeneration;
    _awaitingInitialEvent = true;
    _openingSubscriptions = true;
    _hasShowSnapshot = false;
    _hasSessionsSnapshot = false;
    _latestShow = null;
    _latestSessions = const <Session>[];
    _poster.reset();

    emit(
      state.copyWith(
        status: ShowDetailsStatus.loading,
        posterLoading: _poster.isLoading,
        clearPosterBytes: true,
        clearErrorMessage: true,
      ),
    );

    final startFuture = _openSubscriptions(
      generation,
      refreshPoster: refreshPoster,
    );
    _activeStartFuture = startFuture;
    return startFuture;
  }

  Future<void> _openSubscriptions(
    int generation, {
    required bool refreshPoster,
  }) async {
    try {
      await _cancelSubscriptions();
      if (isClosed || generation != _listenGeneration) return;
      if (refreshPoster) _repository.invalidatePoster(state.showId);
      _showSubscription = _repository
          .watchShow(state.showId)
          .listen(
            (show) => _onShowSnapshot(generation, show),
            onError: (Object _) => _onStreamError(generation, showFailed: true),
            onDone: () {
              if (generation == _listenGeneration) {
                _showSubscription = null;
                _awaitingInitialEvent = false;
              }
            },
          );

      _sessionsSubscription = _repository
          .watchSessions(state.showId)
          .listen(
            (sessions) => _onSessionsSnapshot(generation, sessions),
            onError: (Object _) =>
                _onStreamError(generation, sessionsFailed: true),
            onDone: () {
              if (generation == _listenGeneration) {
                _sessionsSubscription = null;
                _awaitingInitialEvent = false;
              }
            },
          );
    } catch (_) {
      if (generation == _listenGeneration) _openingSubscriptions = false;
      _onStreamError(generation, showFailed: true, sessionsFailed: true);
      await _cancelSubscriptions();
    } finally {
      if (generation == _listenGeneration) _openingSubscriptions = false;
    }
  }

  void _onShowSnapshot(int generation, Show? show) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;
    _hasShowSnapshot = true;
    _latestShow = show;

    if (show == null || show.status != ShowStatus.active) {
      _hasSessionsSnapshot = false;
      _latestSessions = const <Session>[];
      _poster.reset(invalidateCache: true);
      emit(
        state.copyWith(
          status: ShowDetailsStatus.unavailable,
          clearShow: true,
          sessions: const <Session>[],
          clearPosterBytes: true,
          posterLoading: false,
          errorMessage: 'This show no longer accepts bookings.',
        ),
      );
      return;
    }

    final posterRequestId = _poster.prepareLoadForRevision(show.posterRevision);

    if (state.isUnavailable && !_hasSessionsSnapshot) {
      emit(
        state.copyWith(
          status: ShowDetailsStatus.error,
          show: show,
          errorMessage:
              'Show is available again. Refresh to load its sessions.',
        ),
      );
    }

    if (posterRequestId != null) {
      unawaited(_loadPoster(generation, posterRequestId));
    }

    _reconcileSnapshots();
  }

  void _onSessionsSnapshot(int generation, List<Session> sessions) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;
    _hasSessionsSnapshot = true;
    _latestSessions = sessions;
    _reconcileSnapshots();
  }

  void _reconcileSnapshots() {
    if (!_hasShowSnapshot) return;
    final show = _latestShow;
    if (show == null || show.status != ShowStatus.active) return;
    if (!_hasSessionsSnapshot) return;

    final bounded = sortAndBoundSessions(
      _latestSessions,
      maxSessions: maxSessions,
    );

    emit(
      state.copyWith(
        status: ShowDetailsStatus.ready,
        show: show,
        sessions: bounded,
        posterBytes: _poster.bytes,
        clearPosterBytes: _poster.bytes == null,
        posterLoading: _poster.isLoading,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _loadPoster(int generation, int requestId) async {
    final applied = await _poster.completeLoad(
      requestId,
      isActive: () => !isClosed && generation == _listenGeneration,
      isShowValid: () {
        final show = _latestShow;
        return show != null && show.status == ShowStatus.active;
      },
    );
    if (!applied) return;

    if (state.status == ShowDetailsStatus.ready) {
      emit(
        state.copyWith(
          posterBytes: _poster.bytes,
          clearPosterBytes: _poster.bytes == null,
          posterLoading: _poster.isLoading,
        ),
      );
    }
  }

  void _onStreamError(
    int generation, {
    bool showFailed = false,
    bool sessionsFailed = false,
  }) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;
    if (showFailed) _hasShowSnapshot = false;
    if (sessionsFailed) _hasSessionsSnapshot = false;
    _poster.cancelLoadingState();
    emit(
      state.copyWith(
        status: ShowDetailsStatus.error,
        posterLoading: _poster.isLoading,
        errorMessage:
            'Unable to load show details. Your existing choices are preserved.',
      ),
    );
  }

  Future<void> _cancelSubscriptions() {
    final showSub = _showSubscription;
    final sessionsSub = _sessionsSubscription;
    _showSubscription = null;
    _sessionsSubscription = null;
    if (showSub == null && sessionsSub == null) return _cancellation;
    return _cancellation = Future.wait<void>(<Future<void>>[
      _cancellation,
      if (showSub != null)
        Future<void>.sync(showSub.cancel).catchError((Object _) {}),
      if (sessionsSub != null)
        Future<void>.sync(sessionsSub.cancel).catchError((Object _) {}),
    ]).then((_) {});
  }

  @override
  Future<void> close() async {
    _listenGeneration++;
    _awaitingInitialEvent = false;
    await Future.wait<void>(<Future<void>>[
      _cancelSubscriptions(),
      super.close(),
    ]);
  }
}

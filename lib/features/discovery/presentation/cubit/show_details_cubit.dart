import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../vendor_shows/domain/models/session.dart';
import '../../../vendor_shows/domain/models/show.dart';
import '../../../vendor_shows/domain/repositories/shows_repository.dart';
import 'show_details_state.dart';
import 'poster_revision.dart';

final class ShowDetailsCubit extends Cubit<ShowDetailsState> {
  ShowDetailsCubit(
    this._repository, {
    required String showId,
    bool autoStart = true,
  }) : super(ShowDetailsState(showId: _requireNonEmpty(showId))) {
    if (autoStart) {
      unawaited(start());
    }
  }

  static const int maxSessions = 5;

  final ShowsRepository _repository;
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
  bool _posterRequestStarted = false;
  bool _posterLoading = false;
  Uint8List? _latestPosterBytes;
  bool _openingSubscriptions = false;
  Object? _posterRevision;
  int _posterRequest = 0;

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
    _posterRequest++;
    _hasShowSnapshot = false;
    _hasSessionsSnapshot = false;
    _latestShow = null;
    _latestSessions = const <Session>[];
    _latestPosterBytes = null;
    _posterRequestStarted = false;
    _posterLoading = false;
    _posterRevision = null;

    emit(
      state.copyWith(
        status: ShowDetailsStatus.loading,
        posterLoading: _posterLoading,
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
      if (refreshPoster) _repository.clearPosterCache();
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
      _onStreamError(generation, showFailed: true, sessionsFailed: true);
      await _cancelSubscriptions().catchError((Object _) {});
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
      _posterRequest++;
      _posterRevision = null;
      _repository.clearPosterCache();
      _posterRequestStarted = false;
      _posterLoading = false;
      _latestPosterBytes = null;
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

    final revision = posterRevision(show);
    if (_posterRevision != null && _posterRevision != revision) {
      _posterRequest++;
      _posterRequestStarted = false;
      _latestPosterBytes = null;
      _repository.clearPosterCache();
    }
    _posterRevision = revision;

    if (state.isUnavailable && !_hasSessionsSnapshot) {
      emit(
        state.copyWith(
          status: ShowDetailsStatus.loading,
          show: show,
          clearErrorMessage: true,
        ),
      );
    }

    if (!_posterRequestStarted && _latestPosterBytes == null) {
      _posterRequestStarted = true;
      _posterLoading = true;
      unawaited(_loadPoster(generation, ++_posterRequest));
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

    final ordered = List<Session>.of(_latestSessions)
      ..sort((a, b) => a.time.value.compareTo(b.time.value));
    final bounded = List<Session>.unmodifiable(ordered.take(maxSessions));

    emit(
      state.copyWith(
        status: ShowDetailsStatus.ready,
        show: show,
        sessions: bounded,
        posterBytes: _latestPosterBytes,
        clearPosterBytes: _latestPosterBytes == null,
        posterLoading: _posterLoading,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _loadPoster(int generation, int request) async {
    Uint8List? bytes;
    try {
      bytes = await _repository.loadPoster(state.showId);
    } catch (_) {
      bytes = null;
    }
    if (isClosed ||
        generation != _listenGeneration ||
        request != _posterRequest) {
      return;
    }

    _posterLoading = false;
    final show = _latestShow;
    if (show == null || show.status != ShowStatus.active) {
      return;
    }

    _latestPosterBytes = bytes;
    if (state.status == ShowDetailsStatus.ready) {
      emit(
        state.copyWith(
          posterBytes: bytes,
          clearPosterBytes: bytes == null,
          posterLoading: false,
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
    _posterLoading = false;
    emit(
      state.copyWith(
        status: ShowDetailsStatus.error,
        posterLoading: false,
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
    return _cancellation = Future.wait<void>(<Future<void>>[
      _cancellation,
      if (showSub != null) showSub.cancel(),
      if (sessionsSub != null) sessionsSub.cancel(),
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

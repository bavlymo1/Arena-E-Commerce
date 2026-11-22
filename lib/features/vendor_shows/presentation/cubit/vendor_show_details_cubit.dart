import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/new_show.dart';
import '../../domain/models/session.dart';
import '../../domain/models/show.dart';
import '../../domain/repositories/shows_repository.dart';
import 'vendor_show_details_state.dart';

/// Manages vendor-owned show metadata, daily sessions, poster, and selected session.
final class VendorShowDetailsCubit extends Cubit<VendorShowDetailsState> {
  VendorShowDetailsCubit(
    this._repository, {
    required String vendorId,
    required String showId,
    String? initialSessionId,
    bool autoStart = true,
  }) : _preferredSessionId = _normalizeOptionalId(initialSessionId),
       super(
         VendorShowDetailsState(
           vendorId: _requireNonEmpty(vendorId, 'vendorId'),
           showId: _requireNonEmpty(showId, 'showId'),
           selectedSessionId: _normalizeOptionalId(initialSessionId),
         ),
       ) {
    if (autoStart) {
      unawaited(start());
    }
  }

  static const int maxSessions = maxShowSessions;

  final ShowsRepository _repository;
  StreamSubscription<Show?>? _showSubscription;
  StreamSubscription<List<Session>>? _sessionsSubscription;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _activeStartFuture;

  int _listenGeneration = 0;
  bool _awaitingInitialEvent = false;
  bool _openingSubscriptions = false;
  bool _hasShowSnapshot = false;
  bool _hasSessionsSnapshot = false;
  Show? _latestShow;
  List<Session> _latestSessions = const <Session>[];
  String? _preferredSessionId;
  bool _posterRequestStarted = false;
  bool _posterLoading = false;
  Uint8List? _latestPosterBytes;
  Object? _posterRevision;
  int _posterRequest = 0;

  static String _requireNonEmpty(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be empty');
    }
    return value;
  }

  static String? _normalizeOptionalId(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  /// Begins watching the show document and its daily sessions.
  Future<void> start() {
    if (isClosed) return Future<void>.value();
    if (_awaitingInitialEvent && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening();
  }

  /// Re-subscribes after an error and refreshes the cached show poster.
  Future<void> retry() {
    if (isClosed || state.isDeletingShow || state.isDeleteCompleted) {
      return Future<void>.value();
    }
    if (_openingSubscriptions && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening(refreshPoster: true);
  }

  /// Switches the inspected session for the read-only seat map.
  void selectSession(String sessionId) {
    if (isClosed ||
        !state.isReady ||
        state.isDeletingShow ||
        state.isDeleteCompleted) {
      return;
    }
    if (!state.sessions.any((session) => session.id == sessionId)) return;
    _preferredSessionId = sessionId;
    if (state.selectedSessionId == sessionId) return;
    emit(state.copyWith(selectedSessionId: sessionId));
  }

  /// Deletes this show and emits [VendorShowDeleteStatus.completed] on cleanup.
  Future<void> deleteShow() async {
    if (isClosed ||
        state.deleteStatus == VendorShowDeleteStatus.deleting ||
        state.deleteStatus == VendorShowDeleteStatus.completed) {
      return;
    }
    if (state.status == VendorShowDetailsStatus.unavailable &&
        state.deleteStatus == VendorShowDeleteStatus.idle) {
      return;
    }

    emit(
      state.copyWith(
        deleteStatus: VendorShowDeleteStatus.deleting,
        clearDeleteErrorMessage: true,
      ),
    );

    try {
      await _repository.deleteShow(state.showId);
      if (isClosed) return;
      emit(
        state.copyWith(
          deleteStatus: VendorShowDeleteStatus.completed,
          clearDeleteErrorMessage: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          deleteStatus: VendorShowDeleteStatus.failed,
          deleteErrorMessage: error is UnsupportedError
              ? 'Show deletion is not configured in this preview.'
              : 'Unable to delete show. Try again.',
        ),
      );
    }
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
        status: VendorShowDetailsStatus.loading,
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
      await _cancelSubscriptions();
    } finally {
      if (generation == _listenGeneration) _openingSubscriptions = false;
    }
  }

  bool _isOwnedActiveShow(Show? show) =>
      show != null &&
      show.vendorId == state.vendorId &&
      show.status == ShowStatus.active;

  void _onShowSnapshot(int generation, Show? show) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;
    _hasShowSnapshot = true;
    _latestShow = show;

    if (!_isOwnedActiveShow(show)) {
      // Preserve own delete lifecycle (deleting/failed/completed) instead of
      // flipping to unavailable when our own write marks deleting or removes the doc.
      if (state.deleteStatus != VendorShowDeleteStatus.idle) {
        if (show != null && show.vendorId == state.vendorId) {
          emit(state.copyWith(show: show));
        }
        return;
      }
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
          status: VendorShowDetailsStatus.unavailable,
          clearShow: true,
          sessions: const <Session>[],
          clearSelectedSessionId: true,
          clearPosterBytes: true,
          posterLoading: false,
          errorMessage: 'This show no longer accepts bookings.',
        ),
      );
      return;
    }

    final ownedShow = show!;
    final revision = ownedShow.posterRevision;
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
          status: VendorShowDetailsStatus.error,
          show: ownedShow,
          errorMessage:
              'Show is available again. Refresh to load its sessions.',
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
    if (!_isOwnedActiveShow(show)) return;
    if (!_hasSessionsSnapshot) return;

    final ordered = List<Session>.of(_latestSessions)
      ..sort((a, b) => a.time.value.compareTo(b.time.value));
    final bounded = List<Session>.unmodifiable(ordered.take(maxSessions));

    String? resolvedSessionId;
    if (bounded.isNotEmpty) {
      final preferred = _preferredSessionId;
      if (preferred != null && bounded.any((s) => s.id == preferred)) {
        resolvedSessionId = preferred;
      } else {
        resolvedSessionId = bounded.first.id;
        _preferredSessionId = resolvedSessionId;
      }
    }

    emit(
      state.copyWith(
        status: VendorShowDetailsStatus.ready,
        show: show,
        sessions: bounded,
        selectedSessionId: resolvedSessionId,
        clearSelectedSessionId: resolvedSessionId == null,
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
    if (!_isOwnedActiveShow(show)) {
      return;
    }

    _latestPosterBytes = bytes;
    if (state.status == VendorShowDetailsStatus.ready) {
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
    if (isClosed ||
        generation != _listenGeneration ||
        state.deleteStatus != VendorShowDeleteStatus.idle) {
      return;
    }
    _awaitingInitialEvent = false;
    if (showFailed) _hasShowSnapshot = false;
    if (sessionsFailed) _hasSessionsSnapshot = false;
    _posterLoading = false;
    emit(
      state.copyWith(
        status: VendorShowDetailsStatus.error,
        posterLoading: false,
        errorMessage:
            'Unable to load show details. Your existing data is preserved.',
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

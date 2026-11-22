import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/alert_permission.dart';
import '../../domain/models/booking_alert.dart';
import '../../domain/models/booking_event.dart';
import '../../domain/models/notification_watermark.dart';
import '../../domain/repositories/booking_events_repository.dart';
import '../../domain/repositories/local_alert_presenter.dart';
import '../../domain/repositories/watermark_store.dart';
import 'vendor_notifications_state.dart';

/// Streams vendor booking events, persists watermarks, and triggers local alerts.
final class VendorNotificationsCubit extends Cubit<VendorNotificationsState> {
  VendorNotificationsCubit(
    this._repository, {
    required String vendorId,
    WatermarkStore? watermarkStore,
    this._alertPresenter,
    bool autoStart = true,
  }) : _watermarkStore = watermarkStore ?? InMemoryWatermarkStore(),
       super(VendorNotificationsState(vendorId: _requireNonEmpty(vendorId))) {
    if (autoStart) {
      unawaited(start());
    }
  }

  final BookingEventsRepository _repository;
  final WatermarkStore _watermarkStore;
  final LocalAlertPresenter? _alertPresenter;

  StreamSubscription<List<BookingEvent>>? _eventsSubscription;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _activeStartFuture;
  Future<void>? _watermarkLoadFuture;
  Future<void>? _permissionRequestFuture;
  Future<void> _alertPipeline = Future<void>.value();
  int _listenGeneration = 0;
  bool _awaitingInitialEvent = false;
  bool _openingSubscription = false;
  bool _watermarkLoaded = false;
  bool _initialPermissionRequested = false;
  bool _initialSnapshotProcessed = false;
  NotificationWatermark _watermark = const NotificationWatermark.empty();

  static String _requireNonEmpty(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'vendorId', 'Must not be empty');
    }
    return value;
  }

  /// Loads watermark, checks alert permission, and watches vendor events.
  Future<void> start() {
    if (isClosed) return Future<void>.value();
    if (_awaitingInitialEvent && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening();
  }

  /// Re-subscribes after an error while preserving already loaded events.
  Future<void> retry() {
    if (isClosed) return Future<void>.value();
    if (_openingSubscription && _activeStartFuture != null) {
      return _activeStartFuture!;
    }
    return _startListening();
  }

  /// Requests OS notification permission and updates [VendorNotificationsState].
  Future<void> requestAlertPermission() {
    if (isClosed) return Future<void>.value();
    final presenter = _alertPresenter;
    if (presenter == null) return Future<void>.value();
    final inFlight = _permissionRequestFuture;
    if (inFlight != null) return inFlight;

    late final Future<void> requestFuture;
    requestFuture = _performPermissionRequest(presenter).whenComplete(() {
      if (identical(_permissionRequestFuture, requestFuture)) {
        _permissionRequestFuture = null;
      }
    });
    _permissionRequestFuture = requestFuture;
    return requestFuture;
  }

  /// Clears unread status for a single event without removing history.
  void markEventRead(String eventId) {
    if (isClosed || !state.unreadEventIds.contains(eventId)) return;
    final updated = Set<String>.from(state.unreadEventIds)..remove(eventId);
    emit(state.copyWith(unreadEventIds: updated));
  }

  /// Clears all currently unread event badges without removing history.
  void markAllRead() {
    if (isClosed || state.unreadEventIds.isEmpty) return;
    emit(state.copyWith(unreadEventIds: const <String>{}));
  }

  Future<void> _performPermissionRequest(LocalAlertPresenter presenter) async {
    AlertPermission resolved;
    try {
      resolved = await presenter.requestPermission();
    } catch (_) {
      resolved = AlertPermission.denied;
    }
    if (isClosed) return;
    if (state.alertPermission != resolved) {
      emit(state.copyWith(alertPermission: resolved));
    }
  }

  Future<void> _ensureInitialPermissionRequested() {
    if (_initialPermissionRequested || _alertPresenter == null) {
      return _permissionRequestFuture ?? Future<void>.value();
    }
    _initialPermissionRequested = true;
    return requestAlertPermission();
  }

  Future<void> _ensureWatermarkLoaded() {
    if (_watermarkLoaded) return Future<void>.value();
    final inFlight = _watermarkLoadFuture;
    if (inFlight != null) return inFlight;

    late final Future<void> loadFuture;
    loadFuture = _loadWatermark().whenComplete(() {
      if (identical(_watermarkLoadFuture, loadFuture)) {
        _watermarkLoadFuture = null;
      }
    });
    _watermarkLoadFuture = loadFuture;
    return loadFuture;
  }

  Future<void> _loadWatermark() async {
    try {
      final loaded = await _watermarkStore.load(state.vendorId);
      if (isClosed) return;
      if (loaded != null && loaded.lastSeenEventAtMs != null) {
        _watermark = loaded;
      }
    } catch (_) {
      // Recover with empty watermark so stream updates remain available.
    } finally {
      _watermarkLoaded = true;
    }
  }

  Future<void> _startListening() {
    final generation = ++_listenGeneration;
    _awaitingInitialEvent = true;
    _openingSubscription = true;
    emit(
      state.copyWith(
        status: VendorNotificationsStatus.loading,
        clearErrorMessage: true,
      ),
    );
    final startFuture = _openSubscription(generation);
    _activeStartFuture = startFuture;
    return startFuture;
  }

  Future<void> _openSubscription(int generation) async {
    final permissionFuture = _ensureInitialPermissionRequested();
    try {
      await Future.wait<void>(<Future<void>>[
        _cancelSubscription(),
        _ensureWatermarkLoaded(),
      ]);
      if (isClosed || generation != _listenGeneration) return;
      _eventsSubscription = _repository
          .watchEvents(state.vendorId)
          .listen(
            (events) => _onEventsSnapshot(generation, events),
            onError: (Object _) => _onStreamError(generation),
            onDone: () {
              if (generation == _listenGeneration) {
                _eventsSubscription = null;
                _awaitingInitialEvent = false;
              }
            },
          );
    } catch (_) {
      _onStreamError(generation);
      await _cancelSubscription();
    } finally {
      if (generation == _listenGeneration) _openingSubscription = false;
    }
    await permissionFuture;
  }

  void _onEventsSnapshot(int generation, List<BookingEvent> rawEvents) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;

    final sortedNewestFirst =
        rawEvents
            .where((event) => event.vendorId == state.vendorId)
            .toList(growable: false)
          ..sort(BookingEvent.compareNewestFirst);
    final seenIds = <String>{};
    final ownedEvents = <BookingEvent>[
      for (final event in sortedNewestFirst)
        if (seenIds.add(event.bookingId)) event,
    ];
    final ownedIds = ownedEvents.map((event) => event.id).toSet();

    final isInitial = !_initialSnapshotProcessed;
    _initialSnapshotProcessed = true;

    late final Set<String> nextUnread;
    late final List<BookingEvent> alertsToFire;
    late final bool isCatchUp;
    NotificationWatermark? watermarkToPersist;

    if (isInitial && _watermark.isEmpty) {
      // First-time launch with no watermark: seed cursor without alerts.
      nextUnread = const <String>{};
      alertsToFire = const <BookingEvent>[];
      isCatchUp = false;
      var cursor = ownedEvents.isEmpty
          ? NotificationWatermark(lastSeenEventAtMs: 0)
          : _watermark;
      for (final event in ownedEvents.reversed) {
        cursor = cursor.advance(
          createdAtMs: event.createdAt.millisecondsSinceEpoch,
          eventId: event.id,
        );
      }
      _watermark = cursor;
      watermarkToPersist = cursor;
    } else {
      nextUnread = state.unreadEventIds.where(ownedIds.contains).toSet();
      final oldestFirst = ownedEvents.toList(growable: false)
        ..sort(BookingEvent.compareOldestFirst);
      final unseen = <BookingEvent>[];
      var nextWatermark = _watermark;

      for (final event in oldestFirst) {
        final ms = event.createdAt.millisecondsSinceEpoch;
        if (nextWatermark.isUnseen(ms, event.id)) {
          unseen.add(event);
          nextUnread.add(event.id);
          nextWatermark = nextWatermark.advance(
            createdAtMs: ms,
            eventId: event.id,
          );
        }
      }

      _watermark = nextWatermark;
      alertsToFire = unseen;
      isCatchUp = isInitial;
      if (unseen.isNotEmpty) {
        watermarkToPersist = nextWatermark;
      }
    }

    emit(
      state.copyWith(
        status: VendorNotificationsStatus.ready,
        events: ownedEvents,
        unreadEventIds: nextUnread,
        clearErrorMessage: true,
      ),
    );

    if (watermarkToPersist != null || alertsToFire.isNotEmpty) {
      _enqueueAlertAndPersist(
        events: alertsToFire,
        isCatchUp: isCatchUp,
        watermarkToPersist: watermarkToPersist ?? _watermark,
      );
    }
  }

  void _enqueueAlertAndPersist({
    required List<BookingEvent> events,
    required bool isCatchUp,
    required NotificationWatermark watermarkToPersist,
  }) {
    _alertPipeline = _alertPipeline.then((_) async {
      if (isClosed) return;
      final pendingPermission = _permissionRequestFuture;
      if (events.isNotEmpty && pendingPermission != null) {
        await pendingPermission;
        if (isClosed) return;
      }

      final presenter = _alertPresenter;
      if (presenter != null &&
          events.isNotEmpty &&
          state.alertPermission == AlertPermission.granted) {
        if (isCatchUp && events.length > 1) {
          try {
            await presenter.showGroupedAlert(events.length);
          } catch (_) {
            // Presenter failures must not prevent watermark progression.
          }
        } else {
          for (final event in events) {
            if (isClosed) return;
            try {
              await presenter.showBookingAlert(BookingAlert.fromEvent(event));
            } catch (_) {
              // Continue delivering remaining alerts and persisting watermark.
            }
          }
        }
      }

      if (isClosed) return;
      try {
        await _watermarkStore.save(state.vendorId, watermarkToPersist);
      } catch (_) {
        // Store write failures must not break the event stream.
      }
    });
  }

  void _onStreamError(int generation) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;
    emit(
      state.copyWith(
        status: VendorNotificationsStatus.error,
        errorMessage: state.events.isEmpty
            ? 'Unable to load booking updates. Try again.'
            : 'Unable to refresh booking updates. Showing last loaded updates.',
      ),
    );
  }

  Future<void> _cancelSubscription() {
    final subscription = _eventsSubscription;
    _eventsSubscription = null;
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

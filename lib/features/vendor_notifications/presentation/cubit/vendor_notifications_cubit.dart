import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/booking_event.dart';
import '../../domain/repositories/booking_events_repository.dart';
import 'vendor_notifications_state.dart';

/// Streams vendor-scoped booking events and tracks unseen updates by watermark.
final class VendorNotificationsCubit extends Cubit<VendorNotificationsState> {
  VendorNotificationsCubit(
    this._repository, {
    required String vendorId,
    bool autoStart = true,
  }) : super(VendorNotificationsState(vendorId: _requireNonEmpty(vendorId))) {
    if (autoStart) {
      unawaited(start());
    }
  }

  final BookingEventsRepository _repository;
  StreamSubscription<List<BookingEvent>>? _eventsSubscription;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _activeStartFuture;
  int _listenGeneration = 0;
  bool _awaitingInitialEvent = false;
  bool _openingSubscription = false;

  // shortcut: watermark state is held in memory until shared_preferences is wired by lead, upgrade to SharedPreferencesAsync persistence for lastSeenEventAtMs and seenEventIdsAtWatermark when OS alerts or FCM are enabled
  bool _watermarkSeeded = false;
  int? _lastSeenEventAtMs;
  final Set<String> _seenEventIdsAtWatermark = <String>{};

  static String _requireNonEmpty(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'vendorId', 'Must not be empty');
    }
    return value;
  }

  /// Begins watching booking events owned by `state.vendorId`.
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
    try {
      await _cancelSubscription();
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
      await _cancelSubscription().catchError((Object _) {});
    } finally {
      if (generation == _listenGeneration) _openingSubscription = false;
    }
  }

  void _onEventsSnapshot(int generation, List<BookingEvent> rawEvents) {
    if (isClosed || generation != _listenGeneration) return;
    _awaitingInitialEvent = false;

    final sortedRaw =
        rawEvents
            .where((event) => event.vendorId == state.vendorId)
            .toList(growable: false)
          ..sort(_compareEventsNewestFirst);
    final seenIds = <String>{};
    final ownedEvents = <BookingEvent>[
      for (final event in sortedRaw)
        if (seenIds.add(event.bookingId)) event,
    ];
    final ownedIds = ownedEvents.map((event) => event.id).toSet();

    late final Set<String> nextUnread;
    if (!_watermarkSeeded) {
      _watermarkSeeded = true;
      _seedWatermark(ownedEvents);
      nextUnread = const <String>{};
    } else {
      nextUnread = state.unreadEventIds.where(ownedIds.contains).toSet();
      _advanceWatermark(ownedEvents, nextUnread);
    }

    emit(
      state.copyWith(
        status: VendorNotificationsStatus.ready,
        events: ownedEvents,
        unreadEventIds: nextUnread,
        clearErrorMessage: true,
      ),
    );
  }

  void _seedWatermark(List<BookingEvent> events) {
    _seenEventIdsAtWatermark.clear();
    if (events.isEmpty) {
      _lastSeenEventAtMs = null;
      return;
    }
    final maxMs = events
        .map((event) => event.createdAt.millisecondsSinceEpoch)
        .reduce((a, b) => a > b ? a : b);
    _lastSeenEventAtMs = maxMs;
    for (final event in events) {
      if (event.createdAt.millisecondsSinceEpoch == maxMs) {
        _seenEventIdsAtWatermark.add(event.id);
      }
    }
  }

  void _advanceWatermark(
    List<BookingEvent> newestFirstEvents,
    Set<String> nextUnread,
  ) {
    var watermarkMs = _lastSeenEventAtMs;
    final tieIds = Set<String>.from(_seenEventIdsAtWatermark);
    for (final event in newestFirstEvents.reversed) {
      final ms = event.createdAt.millisecondsSinceEpoch;
      final isUnseen =
          watermarkMs == null ||
          ms > watermarkMs ||
          (ms == watermarkMs && !tieIds.contains(event.id));
      if (!isUnseen) continue;
      nextUnread.add(event.id);
      if (watermarkMs == null || ms > watermarkMs) {
        watermarkMs = ms;
        tieIds
          ..clear()
          ..add(event.id);
      } else if (ms == watermarkMs) {
        tieIds.add(event.id);
      }
    }
    _lastSeenEventAtMs = watermarkMs;
    _seenEventIdsAtWatermark
      ..clear()
      ..addAll(tieIds);
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

  static int _compareEventsNewestFirst(BookingEvent a, BookingEvent b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    return byTime != 0 ? byTime : a.bookingId.compareTo(b.bookingId);
  }

  Future<void> _cancelSubscription() {
    final subscription = _eventsSubscription;
    _eventsSubscription = null;
    return _cancellation = Future.wait<void>(<Future<void>>[
      _cancellation,
      if (subscription != null) subscription.cancel(),
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

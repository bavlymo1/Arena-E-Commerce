import 'package:equatable/equatable.dart';

/// Persisted cursor and same-millisecond tie IDs for alert deduplication.
final class NotificationWatermark extends Equatable {
  NotificationWatermark({
    this.lastSeenEventAtMs,
    Iterable<String> seenEventIdsAtWatermark = const <String>{},
  }) : seenEventIdsAtWatermark = Set<String>.unmodifiable(
         seenEventIdsAtWatermark,
       ) {
    if (lastSeenEventAtMs == null && this.seenEventIdsAtWatermark.isNotEmpty) {
      throw ArgumentError.value(
        seenEventIdsAtWatermark,
        'seenEventIdsAtWatermark',
        'Must be empty when lastSeenEventAtMs is null',
      );
    }
  }

  const NotificationWatermark.empty()
    : lastSeenEventAtMs = null,
      seenEventIdsAtWatermark = const <String>{};

  final int? lastSeenEventAtMs;
  final Set<String> seenEventIdsAtWatermark;

  bool get isEmpty => lastSeenEventAtMs == null;

  bool isUnseen(int createdAtMs, String eventId) {
    final watermarkMs = lastSeenEventAtMs;
    if (watermarkMs == null) return true;
    if (createdAtMs > watermarkMs) return true;
    if (createdAtMs < watermarkMs) return false;
    return !seenEventIdsAtWatermark.contains(eventId);
  }

  NotificationWatermark advance({
    required int createdAtMs,
    required String eventId,
  }) {
    final watermarkMs = lastSeenEventAtMs;
    if (watermarkMs == null || createdAtMs > watermarkMs) {
      return NotificationWatermark(
        lastSeenEventAtMs: createdAtMs,
        seenEventIdsAtWatermark: <String>{eventId},
      );
    }
    if (createdAtMs == watermarkMs) {
      return NotificationWatermark(
        lastSeenEventAtMs: watermarkMs,
        seenEventIdsAtWatermark: <String>{...seenEventIdsAtWatermark, eventId},
      );
    }
    return this;
  }

  @override
  List<Object?> get props => <Object?>[
    lastSeenEventAtMs,
    seenEventIdsAtWatermark,
  ];
}

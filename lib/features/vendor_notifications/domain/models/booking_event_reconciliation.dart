import 'package:equatable/equatable.dart';

import 'booking_event.dart';
import 'notification_watermark.dart';

/// Deterministic outcome of evaluating a vendor booking-events snapshot.
final class BookingEventReconciliation extends Equatable {
  BookingEventReconciliation({
    required Iterable<BookingEvent> events,
    required Iterable<String> unreadEventIds,
    required Iterable<BookingEvent> alertsToFire,
    required this.isCatchUp,
    required this.nextWatermark,
    this.watermarkToPersist,
  }) : events = List<BookingEvent>.unmodifiable(events),
       unreadEventIds = Set<String>.unmodifiable(unreadEventIds),
       alertsToFire = List<BookingEvent>.unmodifiable(alertsToFire);

  final List<BookingEvent> events;
  final Set<String> unreadEventIds;
  final List<BookingEvent> alertsToFire;
  final bool isCatchUp;
  final NotificationWatermark nextWatermark;
  final NotificationWatermark? watermarkToPersist;

  bool get shouldGroupAlerts => isCatchUp && alertsToFire.length > 1;

  @override
  List<Object?> get props => <Object?>[
    events,
    unreadEventIds,
    alertsToFire,
    isCatchUp,
    nextWatermark,
    watermarkToPersist,
  ];
}

/// Evaluates [rawEvents] for [vendorId] against [watermark] and unread IDs.
BookingEventReconciliation reconcileBookingEventsSnapshot({
  required List<BookingEvent> rawEvents,
  required String vendorId,
  required NotificationWatermark watermark,
  required bool isInitialSnapshot,
  required Set<String> previousUnreadIds,
}) {
  if (vendorId.trim().isEmpty) {
    throw ArgumentError.value(vendorId, 'vendorId', 'Must not be empty');
  }

  final sortedNewestFirst =
      rawEvents
          .where((event) => event.vendorId == vendorId)
          .toList(growable: false)
        ..sort(BookingEvent.compareNewestFirst);
  final ownedIds = <String>{};
  final ownedEvents = <BookingEvent>[
    for (final event in sortedNewestFirst)
      if (ownedIds.add(event.bookingId)) event,
  ];

  if (isInitialSnapshot && watermark.isEmpty) {
    // First-time launch with no watermark: seed cursor without firing alerts.
    var cursor = ownedEvents.isEmpty
        ? NotificationWatermark(lastSeenEventAtMs: 0)
        : watermark;
    for (final event in ownedEvents.reversed) {
      cursor = cursor.advance(
        createdAtMs: event.createdAt.millisecondsSinceEpoch,
        eventId: event.id,
      );
    }
    return BookingEventReconciliation(
      events: ownedEvents,
      unreadEventIds: const <String>{},
      alertsToFire: const <BookingEvent>[],
      isCatchUp: false,
      nextWatermark: cursor,
      watermarkToPersist: cursor,
    );
  }

  final nextUnread = previousUnreadIds.where(ownedIds.contains).toSet();
  final oldestFirst = ownedEvents.toList(growable: false)
    ..sort(BookingEvent.compareOldestFirst);
  final unseen = <BookingEvent>[];
  var nextWatermark = watermark;

  for (final event in oldestFirst) {
    final ms = event.createdAt.millisecondsSinceEpoch;
    if (nextWatermark.isUnseen(ms, event.id)) {
      unseen.add(event);
      nextUnread.add(event.id);
      nextWatermark = nextWatermark.advance(createdAtMs: ms, eventId: event.id);
    }
  }

  return BookingEventReconciliation(
    events: ownedEvents,
    unreadEventIds: nextUnread,
    alertsToFire: unseen,
    isCatchUp: isInitialSnapshot,
    nextWatermark: nextWatermark,
    watermarkToPersist: unseen.isNotEmpty ? nextWatermark : null,
  );
}

import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event_reconciliation.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/notification_watermark.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter_test/flutter_test.dart';

BookingEvent _event({
  required String bookingId,
  String vendorId = 'vendor-a',
  Iterable<int> seats = const <int>[1],
  int slotTotal = 1,
  int showTotal = 1,
  required DateTime createdAt,
}) {
  final slot = SessionTime('19:00');
  return BookingEvent(
    bookingId: bookingId,
    vendorId: vendorId,
    showId: 'show-1',
    sessionId: slot.id,
    seats: seats,
    showTitle: 'Apex Finals',
    slotTime: slot,
    slotTotal: slotTotal,
    showTotal: showTotal,
    createdAt: createdAt,
  );
}

void main() {
  test('rejects blank vendorId', () {
    expect(
      () => reconcileBookingEventsSnapshot(
        rawEvents: const <BookingEvent>[],
        vendorId: '   ',
        watermark: const NotificationWatermark.empty(),
        isInitialSnapshot: true,
        previousUnreadIds: const <String>{},
      ),
      throwsArgumentError,
    );
  });

  test(
    'first-launch empty snapshot persists epoch-0 baseline with no alerts',
    () {
      final result = reconcileBookingEventsSnapshot(
        rawEvents: const <BookingEvent>[],
        vendorId: 'vendor-a',
        watermark: const NotificationWatermark.empty(),
        isInitialSnapshot: true,
        previousUnreadIds: const <String>{'stale'},
      );

      expect(result.events, isEmpty);
      expect(result.unreadEventIds, isEmpty);
      expect(result.alertsToFire, isEmpty);
      expect(result.isCatchUp, isFalse);
      expect(result.shouldGroupAlerts, isFalse);
      expect(result.nextWatermark, NotificationWatermark(lastSeenEventAtMs: 0));
      expect(
        result.watermarkToPersist,
        NotificationWatermark(lastSeenEventAtMs: 0),
      );
    },
  );

  test('first-launch non-empty snapshot filters vendors, deduplicates IDs, and seeds watermark without alerts', () {
    final t0 = DateTime.utc(2026, 11, 20, 10, 0);
    final t1 = DateTime.utc(2026, 11, 20, 11, 0);
    final result = reconcileBookingEventsSnapshot(
      rawEvents: <BookingEvent>[
        _event(bookingId: 'other', vendorId: 'vendor-b', createdAt: t1),
        _event(bookingId: 'h1', createdAt: t0, seats: const <int>[1]),
        _event(bookingId: 'h2-tie-b', createdAt: t1, seats: const <int>[2]),
        _event(bookingId: 'h3-tie-a', createdAt: t1, seats: const <int>[3]),
        _event(bookingId: 'h3-tie-a', createdAt: t1, seats: const <int>[3]),
      ],
      vendorId: 'vendor-a',
      watermark: const NotificationWatermark.empty(),
      isInitialSnapshot: true,
      previousUnreadIds: const <String>{},
    );

    expect(result.events.map((e) => e.id).toList(), <String>[
      'h2-tie-b',
      'h3-tie-a',
      'h1',
    ]);
    expect(result.unreadEventIds, isEmpty);
    expect(result.alertsToFire, isEmpty);
    expect(result.isCatchUp, isFalse);
    expect(result.shouldGroupAlerts, isFalse);
    final expectedWatermark = NotificationWatermark(
      lastSeenEventAtMs: t1.millisecondsSinceEpoch,
      seenEventIdsAtWatermark: const <String>{'h2-tie-b', 'h3-tie-a'},
    );
    expect(result.nextWatermark, expectedWatermark);
    expect(result.watermarkToPersist, expectedWatermark);
  });

  test('catch-up distinguishes single vs >1 grouped alerts and deduplicates same-millisecond ties', () {
    final t0 = DateTime.utc(2026, 11, 20, 12, 0);
    final tOlder = DateTime.utc(2026, 11, 20, 11, 59);
    final tNewer = DateTime.utc(2026, 11, 20, 12, 1);

    // Single unseen tie event on catch-up -> individual alert.
    final singleCatchUp = reconcileBookingEventsSnapshot(
      rawEvents: <BookingEvent>[
        _event(bookingId: 'older', createdAt: tOlder),
        _event(bookingId: 'tie-seen', createdAt: t0),
        _event(bookingId: 'tie-unseen', createdAt: t0),
      ],
      vendorId: 'vendor-a',
      watermark: NotificationWatermark(
        lastSeenEventAtMs: t0.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'tie-seen'},
      ),
      isInitialSnapshot: true,
      previousUnreadIds: const <String>{},
    );

    expect(singleCatchUp.alertsToFire.map((e) => e.id).toList(), <String>[
      'tie-unseen',
    ]);
    expect(singleCatchUp.isCatchUp, isTrue);
    expect(singleCatchUp.shouldGroupAlerts, isFalse);
    expect(singleCatchUp.unreadEventIds, <String>{'tie-unseen'});
    expect(
      singleCatchUp.nextWatermark,
      NotificationWatermark(
        lastSeenEventAtMs: t0.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'tie-seen', 'tie-unseen'},
      ),
    );
    expect(singleCatchUp.watermarkToPersist, singleCatchUp.nextWatermark);

    // Multiple unseen events on catch-up -> grouped alert, oldest-first order.
    final multiCatchUp = reconcileBookingEventsSnapshot(
      rawEvents: <BookingEvent>[
        _event(bookingId: 'tie-seen', createdAt: t0),
        _event(bookingId: 'u2', createdAt: tNewer),
        _event(bookingId: 'u1-tie', createdAt: t0),
      ],
      vendorId: 'vendor-a',
      watermark: NotificationWatermark(
        lastSeenEventAtMs: t0.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'tie-seen'},
      ),
      isInitialSnapshot: true,
      previousUnreadIds: const <String>{},
    );

    expect(multiCatchUp.alertsToFire.map((e) => e.id).toList(), <String>[
      'u1-tie',
      'u2',
    ]);
    expect(multiCatchUp.isCatchUp, isTrue);
    expect(multiCatchUp.shouldGroupAlerts, isTrue);
    expect(multiCatchUp.unreadEventIds, <String>{'u1-tie', 'u2'});
    expect(
      multiCatchUp.nextWatermark,
      NotificationWatermark(
        lastSeenEventAtMs: tNewer.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'u2'},
      ),
    );

    // Multiple unseen events on live snapshot -> individual alerts (not catch-up).
    final multiLive = reconcileBookingEventsSnapshot(
      rawEvents: <BookingEvent>[
        _event(bookingId: 'u2', createdAt: tNewer),
        _event(bookingId: 'u1-tie', createdAt: t0),
      ],
      vendorId: 'vendor-a',
      watermark: NotificationWatermark(
        lastSeenEventAtMs: t0.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'tie-seen'},
      ),
      isInitialSnapshot: false,
      previousUnreadIds: const <String>{},
    );
    expect(multiLive.isCatchUp, isFalse);
    expect(multiLive.shouldGroupAlerts, isFalse);
  });

  test('duplicate snapshots are idempotent with no alerts/saves and prune vanished unread IDs', () {
    final t0 = DateTime.utc(2026, 11, 20, 12, 0);
    final t1 = DateTime.utc(2026, 11, 20, 12, 1);

    final first = reconcileBookingEventsSnapshot(
      rawEvents: <BookingEvent>[
        _event(
          bookingId: 'e1',
          seats: const <int>[1, 2],
          slotTotal: 2,
          showTotal: 2,
          createdAt: t0,
        ),
        _event(
          bookingId: 'e2',
          seats: const <int>[3, 4],
          slotTotal: 4,
          showTotal: 4,
          createdAt: t1,
        ),
      ],
      vendorId: 'vendor-a',
      watermark: NotificationWatermark(lastSeenEventAtMs: 0),
      isInitialSnapshot: false,
      previousUnreadIds: const <String>{'removed-id'},
    );
    expect(first.unreadEventIds, <String>{'e1', 'e2'});
    expect(first.alertsToFire.map((e) => e.id).toList(), <String>['e1', 'e2']);
    expect(first.watermarkToPersist, isNotNull);

    // Re-evaluate duplicate snapshot with new BookingEvent instances & reordered seats.
    final duplicate = reconcileBookingEventsSnapshot(
      rawEvents: <BookingEvent>[
        _event(
          bookingId: 'e2',
          seats: const <int>[4, 3],
          slotTotal: 4,
          showTotal: 4,
          createdAt: t1,
        ),
        _event(
          bookingId: 'e1',
          seats: const <int>[2, 1],
          slotTotal: 2,
          showTotal: 2,
          createdAt: t0,
        ),
      ],
      vendorId: 'vendor-a',
      watermark: first.nextWatermark,
      isInitialSnapshot: false,
      previousUnreadIds: first.unreadEventIds,
    );

    expect(duplicate.events, first.events);
    expect(duplicate.unreadEventIds, first.unreadEventIds);
    expect(duplicate.alertsToFire, isEmpty);
    expect(duplicate.nextWatermark, first.nextWatermark);
    expect(duplicate.watermarkToPersist, isNull);
  });
}

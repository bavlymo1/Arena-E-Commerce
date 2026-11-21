import 'dart:convert';

import 'package:e_commerce_project/core/formatting/date_time_formatting.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_alert.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/notification_watermark.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookingAlert', () {
    test(
      'formats merged plan §3 strings and preserves atomic totals from event',
      () {
        final createdAt = DateTime.utc(2026, 11, 20, 19, 0);
        final event = BookingEvent(
          bookingId: 'b-1',
          vendorId: 'arena',
          showId: 'show-1',
          sessionId: '1900',
          seats: const <int>[14, 21],
          showTitle: 'Apex Legends Invitational',
          slotTime: SessionTime('19:00'),
          slotTotal: 4,
          showTotal: 9,
          createdAt: createdAt,
        );

        final alert = BookingAlert.fromEvent(event);

        expect(alert.bookingId, 'b-1');
        expect(alert.showId, 'show-1');
        expect(alert.sessionId, '1900');
        expect(alert.showTitle, 'Apex Legends Invitational');
        expect(alert.slotTime, SessionTime('19:00'));
        expect(alert.slotTotal, 4);
        expect(alert.showTotal, 9);
        expect(alert.seats, <int>{14, 21});
        expect(() => alert.seats.clear(), throwsUnsupportedError);
        expect(alert.createdAt, createdAt);

        expect(alert.formattedSlotTime, '7:00 PM');
        expect(alert.seatsLabel, 'Seats 14, 21 booked');
        expect(alert.sessionSummary, 'Session 7:00 PM: 4/47 booked');
        expect(alert.showTotalSummary, 'Show total across slots: 9 booked');
        expect(alert.notificationTitle, 'Apex Legends Invitational');
        expect(
          alert.notificationBody,
          'Session 7:00 PM: 4/47 booked\nShow total across slots: 9 booked',
        );
        expect(jsonDecode(alert.payload), <String, dynamic>{
          'bookingId': 'b-1',
          'showId': 'show-1',
          'sessionId': '1900',
        });

        final identical = BookingAlert.fromEvent(event);
        expect(alert, identical);
      },
    );

    test(
      'formats 12-hour boundary times and validates seat/total invariants',
      () {
        expect(formatTime12Hour('00:05'), '12:05 AM');
        expect(formatTime12Hour('12:30'), '12:30 PM');
        expect(formatTime12Hour('14:00'), '2:00 PM');
        expect(formatBookedSeatsLabel(<int>{9}), 'Seat 9 booked');

        expect(
          () => BookingAlert(
            bookingId: 'b1',
            showId: 's1',
            sessionId: '1900',
            showTitle: 'Show',
            slotTime: SessionTime('19:00'),
            slotTotal: 1,
            showTotal: 2,
            seats: const <int>[1, 2],
            createdAt: DateTime.utc(2026, 11, 20),
          ),
          throwsArgumentError,
        );
        expect(
          () => BookingAlert(
            bookingId: 'b1',
            showId: 's1',
            sessionId: '1400',
            showTitle: 'Show',
            slotTime: SessionTime('19:00'),
            slotTotal: 2,
            showTotal: 2,
            seats: const <int>[1, 2],
            createdAt: DateTime.utc(2026, 11, 20),
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('NotificationWatermark', () {
    test(
      'supports Equatable value comparison and rejects invalid null-ms tie IDs',
      () {
        final a = NotificationWatermark(
          lastSeenEventAtMs: 1000,
          seenEventIdsAtWatermark: <String>{'b1', 'b2'},
        );
        final b = NotificationWatermark(
          lastSeenEventAtMs: 1000,
          seenEventIdsAtWatermark: <String>{'b2', 'b1'},
        );
        expect(a, b);
        expect(
          () => a.seenEventIdsAtWatermark.add('b3'),
          throwsUnsupportedError,
        );
        expect(
          () => NotificationWatermark(seenEventIdsAtWatermark: <String>{'b1'}),
          throwsArgumentError,
        );
      },
    );

    test(
      'evaluates unseen events and advances ties/newer timestamps cleanly',
      () {
        const empty = NotificationWatermark.empty();
        expect(empty.isEmpty, isTrue);
        expect(empty.isUnseen(500, 'b0'), isTrue);

        final w1 = empty.advance(createdAtMs: 1000, eventId: 'b1');
        expect(w1.lastSeenEventAtMs, 1000);
        expect(w1.seenEventIdsAtWatermark, <String>{'b1'});
        expect(w1.isUnseen(999, 'b0'), isFalse);
        expect(w1.isUnseen(1000, 'b1'), isFalse);
        expect(w1.isUnseen(1000, 'b2'), isTrue);
        expect(w1.isUnseen(1001, 'b0'), isTrue);

        final w2 = w1.advance(createdAtMs: 1000, eventId: 'b2');
        expect(w2.lastSeenEventAtMs, 1000);
        expect(w2.seenEventIdsAtWatermark, <String>{'b1', 'b2'});

        // Older event never moves cursor backward.
        expect(w2.advance(createdAtMs: 500, eventId: 'old'), w2);

        final w3 = w2.advance(createdAtMs: 2000, eventId: 'b3');
        expect(w3.lastSeenEventAtMs, 2000);
        expect(w3.seenEventIdsAtWatermark, <String>{'b3'});
      },
    );
  });
}

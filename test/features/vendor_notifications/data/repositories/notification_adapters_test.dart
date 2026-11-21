import 'dart:convert';

import 'package:e_commerce_project/features/vendor_notifications/data/repositories/flutter_local_alert_presenter.dart';
import 'package:e_commerce_project/features/vendor_notifications/data/repositories/shared_preferences_watermark_store.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/alert_permission.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_alert.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/notification_watermark.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'persists timestamp and ties together and isolates vendor cursors',
    () async {
      final prefs = _Preferences();
      final store = SharedPreferencesWatermarkStore(preferences: prefs);
      final watermark = NotificationWatermark(
        lastSeenEventAtMs: 12,
        seenEventIdsAtWatermark: ['b', 'a'],
      );
      expect(await store.load('vendor-a'), isNull);
      await store.save('vendor-a', watermark);
      expect(prefs.values.length, 1);
      final restarted = SharedPreferencesWatermarkStore(preferences: prefs);
      expect(await restarted.load('vendor-a'), watermark);
      expect(await restarted.load('vendor-b'), isNull);
      await restarted.save(
        'vendor-b',
        NotificationWatermark(lastSeenEventAtMs: 0),
      );
      await restarted.save('vendor-a', const NotificationWatermark.empty());
      expect(await restarted.load('vendor-a'), isNull);
      expect((await restarted.load('vendor-b'))?.lastSeenEventAtMs, 0);
      await expectLater(store.load('  '), throwsArgumentError);
    },
  );

  test('Android adapter creates the channel, reports permission and posts actual totals and grouped count', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    bool permission = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'requestNotificationsPermission' => permission,
        'initialize' => true,
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final presenter = FlutterLocalAlertPresenter();
    expect(await presenter.requestPermission(), AlertPermission.denied);
    permission = true;
    expect(await presenter.requestPermission(), AlertPermission.granted);
    expect(calls.where((call) => call.method == 'initialize').length, 1);
    expect(
      calls.where((call) => call.method == 'createNotificationChannel').length,
      1,
    );
    final alert = BookingAlert(
      bookingId: 'booking',
      showId: 'show',
      sessionId: '1900',
      showTitle: 'Arena final',
      slotTime: SessionTime('19:00'),
      slotTotal: 2,
      showTotal: 8,
      seats: const <int>[2],
      createdAt: DateTime.utc(2026),
    );
    await presenter.showBookingAlert(alert);
    await presenter.showGroupedAlert(2);
    final shown = calls
        .where((call) => call.method == 'show')
        .map((call) => call.arguments as Map)
        .toList();
    expect(
      shown.first['body'],
      'Session 7:00 PM: 2/47 booked\nShow total across slots: 8 booked',
    );
    expect(
      jsonDecode(shown.first['payload'] as String)['bookingId'],
      'booking',
    );
    expect(jsonDecode(shown.last['payload'] as String)['count'], 2);
    await expectLater(presenter.showGroupedAlert(0), throwsArgumentError);
  });
}

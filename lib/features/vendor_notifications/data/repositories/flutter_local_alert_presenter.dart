import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/alert_permission.dart';
import '../../domain/models/booking_alert.dart';
import '../../domain/repositories/local_alert_presenter.dart';

typedef AlertTapCallback = void Function({
  required String showId,
  required String sessionId,
  String? bookingId,
});

/// Android/OS local notification adapter implementing [LocalAlertPresenter].
///
/// Designed for `flutter_local_notifications: ^23.0.2` (named arguments on
/// `initialize` and `show`).
final class FlutterLocalAlertPresenter implements LocalAlertPresenter {
  FlutterLocalAlertPresenter({
    FlutterLocalNotificationsPlugin? plugin,
    this.androidSmallIcon = 'ic_stat_arenapass',
    this.onAlertTapped,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'arenapass_booking_alerts';
  static const String channelName = 'Booking alerts';
  static const String channelDescription =
      'Per-booking seat totals and catch-up notifications for ArenaPass Vendor';
  static const int groupedNotificationId = 0x41500000;

  final FlutterLocalNotificationsPlugin _plugin;
  final String androidSmallIcon;
  final AlertTapCallback? onAlertTapped;

  Future<void>? _initFuture;

  Future<void> ensureInitialized() => _initFuture ??= _initialize().catchError((
    Object error,
    StackTrace stack,
  ) {
    _initFuture = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _initialize() async {
    final androidSettings = AndroidInitializationSettings(androidSmallIcon);
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final androidPlugin = _resolveAndroidPlugin();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
    }
  }

  @override
  Future<AlertPermission> requestPermission() async {
    final androidPlugin = _resolveAndroidPlugin();
    if (androidPlugin != null) {
      await ensureInitialized();
      // On Android 13+ (API 33+) prompts runtime POST_NOTIFICATIONS; on
      // Android 12L and below (including RMX2001 Android 11 / API 30) returns
      // whether notifications are enabled for the app package.
      final granted =
          await androidPlugin.requestNotificationsPermission() ??
          await androidPlugin.areNotificationsEnabled() ??
          false;
      return granted ? AlertPermission.granted : AlertPermission.denied;
    }
    return AlertPermission.denied;
  }

  @override
  Future<void> showBookingAlert(BookingAlert alert) async {
    await ensureInitialized();
    await _plugin.show(
      id: _notificationIdForBooking(alert.bookingId),
      title: alert.notificationTitle,
      body: alert.notificationBody,
      notificationDetails: _notificationDetails(
        bigText: '${alert.seatsLabel}\n${alert.notificationBody}',
      ),
      payload: alert.payload,
    );
  }

  @override
  Future<void> showGroupedAlert(int count) async {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'Must be at least 1');
    }
    await ensureInitialized();
    final summary = '$count new booking updates arrived while closed.';
    await _plugin.show(
      id: groupedNotificationId,
      title: 'ArenaPass booking updates',
      body: '$summary Open Booking updates to review totals.',
      notificationDetails: _notificationDetails(
        bigText:
            '$summary Open Booking updates to review slot and show totals.',
      ),
      payload: jsonEncode(<String, Object>{'kind': 'grouped', 'count': count}),
    );
  }

  NotificationDetails _notificationDetails({required String bigText}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        icon: androidSmallIcon,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(bigText),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? _resolveAndroidPlugin() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final rawPayload = response.payload;
    if (rawPayload == null || rawPayload.isEmpty || onAlertTapped == null) {
      return;
    }
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        final showId = decoded['showId'];
        final sessionId = decoded['sessionId'];
        final bookingId = decoded['bookingId'];
        if (showId is String &&
            showId.isNotEmpty &&
            sessionId is String &&
            sessionId.isNotEmpty) {
          onAlertTapped!(
            showId: showId,
            sessionId: sessionId,
            bookingId: bookingId is String ? bookingId : null,
          );
        }
      }
    } catch (_) {
      // Ignore malformed notification payloads.
    }
  }

  static int _notificationIdForBooking(String bookingId) =>
      bookingId.hashCode & 0x7fffffff;
}

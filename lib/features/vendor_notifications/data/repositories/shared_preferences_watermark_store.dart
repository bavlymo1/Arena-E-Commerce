import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/notification_watermark.dart';
import '../../domain/repositories/watermark_store.dart';

final class SharedPreferencesWatermarkStore implements WatermarkStore {
  SharedPreferencesWatermarkStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  String _key(String vendorId) {
    if (vendorId.trim().isEmpty) {
      throw ArgumentError.value(vendorId, 'vendorId', 'Must not be empty');
    }
    return 'vendor_notifications.watermark.$vendorId';
  }

  @override
  Future<NotificationWatermark?> load(String vendorId) async {
    final raw = await _preferences.getString(_key(vendorId));
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return NotificationWatermark(
      lastSeenEventAtMs: decoded['lastSeenEventAtMs'] as int,
      seenEventIdsAtWatermark:
          (decoded['seenEventIdsAtWatermark'] as List<dynamic>).cast<String>(),
    );
  }

  @override
  Future<void> save(String vendorId, NotificationWatermark watermark) async {
    final key = _key(vendorId);
    if (watermark.isEmpty) {
      await _preferences.remove(key);
      return;
    }
    // A single write keeps the timestamp and its tie IDs consistent on restart.
    await _preferences.setString(
      key,
      jsonEncode({
        'lastSeenEventAtMs': watermark.lastSeenEventAtMs,
        'seenEventIdsAtWatermark': watermark.seenEventIdsAtWatermark.toList()
          ..sort(),
      }),
    );
  }
}

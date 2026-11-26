import '../models/notification_watermark.dart';

/// Persists vendor notification watermark cursors across app launches.
abstract interface class WatermarkStore {
  Future<NotificationWatermark?> load(String vendorId);

  Future<void> save(String vendorId, NotificationWatermark watermark);
}

/// Process-local [WatermarkStore] used when no persistent store is injected.
final class InMemoryWatermarkStore implements WatermarkStore {
  final Map<String, NotificationWatermark> _watermarks =
      <String, NotificationWatermark>{};

  @override
  Future<NotificationWatermark?> load(String vendorId) async {
    _requireVendorId(vendorId);
    return _watermarks[vendorId];
  }

  @override
  Future<void> save(String vendorId, NotificationWatermark watermark) async {
    _requireVendorId(vendorId);
    _watermarks[vendorId] = NotificationWatermark(
      lastSeenEventAtMs: watermark.lastSeenEventAtMs,
      seenEventIdsAtWatermark: watermark.seenEventIdsAtWatermark,
    );
  }

  static void _requireVendorId(String vendorId) {
    if (vendorId.trim().isEmpty) {
      throw ArgumentError.value(vendorId, 'vendorId', 'Must not be empty');
    }
  }
}

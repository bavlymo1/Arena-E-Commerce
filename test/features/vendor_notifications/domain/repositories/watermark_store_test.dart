import 'package:e_commerce_project/features/vendor_notifications/domain/models/notification_watermark.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/watermark_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'InMemoryWatermarkStore persists per vendorId and rejects empty IDs',
    () async {
      final store = InMemoryWatermarkStore();
      expect(await store.load('vendor-a'), isNull);

      final ids = <String>{'b1'};
      await store.save(
        'vendor-a',
        NotificationWatermark(
          lastSeenEventAtMs: 1234,
          seenEventIdsAtWatermark: ids,
        ),
      );
      ids.add('mutated');

      final loadedA = await store.load('vendor-a');
      expect(
        loadedA,
        NotificationWatermark(
          lastSeenEventAtMs: 1234,
          seenEventIdsAtWatermark: const <String>{'b1'},
        ),
      );
      expect(await store.load('vendor-b'), isNull);

      expect(() => store.load('  '), throwsArgumentError);
      expect(
        () => store.save(' ', const NotificationWatermark.empty()),
        throwsArgumentError,
      );
    },
  );
}

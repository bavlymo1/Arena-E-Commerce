# Vendor Notifications

**Status: event stream, watermark persistence adapters, local alert orchestration, Updates screen, permission fallback, and app DI/route wiring implemented; physical-device notification verification and optional Tier 2 approved FCM sender pending.**

Implemented files:
- `domain/models/booking_event.dart`: immutable booking event record with atomic commit-time `slotTotal` and `showTotal`.
- `domain/models/notification_watermark.dart`: `NotificationWatermark` (`lastSeenEventAtMs` + `seenEventIdsAtWatermark`) with same-millisecond tie awareness.
- `domain/models/alert_permission.dart`, `domain/models/booking_alert.dart`: permission state, `BookingAlert` payload model, and 12-hour/seat formatting helpers matching merged plan §3.
- `domain/repositories/booking_events_repository.dart`: vendor-scoped event stream contract.
- `domain/repositories/watermark_store.dart`: `WatermarkStore` contract and `InMemoryWatermarkStore` fallback.
- `domain/repositories/local_alert_presenter.dart`: `LocalAlertPresenter` contract for permission requests and individual/grouped local alerts.
- `data/repositories/firestore_booking_events_repository.dart`: enrolled-vendor `bookingEvents` Firestore query (`vendorId` + `createdAt` desc) decoding immutable `BookingEvent` records.
- `data/repositories/shared_preferences_watermark_store.dart`: `SharedPreferences` watermark persistence adapter.
- `data/repositories/flutter_local_alert_presenter.dart`: `flutter_local_notifications` OS permission and local notification adapter.
- `presentation/cubit/vendor_notifications_state.dart`, `presentation/cubit/vendor_notifications_cubit.dart`: stream lifecycle, vendor isolation filter, first-launch watermark seeding, oldest-to-newest catch-up grouping (>1 -> grouped alert), live individual alerts, lifetime ID deduplication, serialized advance-after-handle persistence, and error/close guards.
- `presentation/screens/vendor_updates_screen.dart`, `presentation/widgets/alert_permission_banner.dart`: Loading, empty, error/retry, inline refresh error, visible permission-denied fallback banner with retry, unread badges/mark-read actions, and reverse-chronological update cards.

Remaining work:
- Physical-device notification verification (including Android release/debug delivery and backgrounded reopen catch-up).
- Optional Tier 2 approved FCM sender (dependencies, Android manifest/Gradle desugaring, and app DI/route wiring in `lib/app/di/vendor_registration.dart` and `lib/app/vendor/` are implemented).

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports. Cubits receive dependencies through constructors. GetIt resolution belongs to app composition, not this feature. Cross-feature use is through domain contracts; do not import another feature's presentation/data.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13; Tier 2 plan §5 for extensions. These paths are relative to the full workspace; they are intentionally not public Markdown links.

# Vendor Notifications

**Status: event stream, Cubit, and Updates screen implemented; app wiring, persistent watermark, and device/FCM alerts pending.**

Implemented files:
- `data/repositories/firestore_booking_events_repository.dart`: enrolled-vendor `bookingEvents` Firestore query (`vendorId` + `createdAt` desc) decoding immutable `BookingEvent` records with exact `slotTotal` and `showTotal` from the booking transaction.
- `presentation/cubit/vendor_notifications_state.dart`, `presentation/cubit/vendor_notifications_cubit.dart`: stream lifecycle, vendor isolation filter, watermark + tie-set unread tracking, and retry/close guards.
- `presentation/screens/vendor_updates_screen.dart`: Loading, empty, error/retry, inline refresh error, unread badges/mark-read actions, and reverse-chronological update cards.

Remaining work:
- Lead DI/route wiring (`VendorRegistration`, `VendorDemoApp` / `VendorApp` connecting `VendorShowsScreen.onOpenUpdates`, `unreadUpdatesCount`, and event selection to show details).
- `SharedPreferencesAsync` persistence for `lastSeenEventAtMs` and `seenEventIdsAtWatermark`.
- Local OS alerts (`POST_NOTIFICATIONS` permission fallback + foreground/catch-up notification delivery) and optional Tier 2 approved FCM sender.

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports. Cubits receive dependencies through constructors. GetIt resolution belongs to app composition, not this feature. Cross-feature use is through domain contracts; do not import another feature's presentation/data.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13; Tier 2 plan §5 for extensions. These paths are relative to the full workspace; they are intentionally not public Markdown links.

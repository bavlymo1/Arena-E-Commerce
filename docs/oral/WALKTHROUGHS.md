# ArenaPass Oral Exam Walkthroughs (M1–M6)

> **Scope:** Reflects the Android-only Tier 1 implementation in `e_commerce_project/` (`lib/main_customer.dart`, `lib/main_vendor.dart`, Firebase project `arenapass-demo`). Production code contains no demo fixtures or emulator bindings (`test/support/` and `integration_test/support/` isolate test/emulator setup). `kVendorD01Approved` in `lib/main_vendor.dart` remains `false` (`Setup pending`) until `D01` doctor acceptance and live `arenapass-demo` deployment verification.

---

## M1 — Vendor Shows, Images, Deletion & Poster Cache

1. **Domain Contracts (`lib/features/vendor_shows/domain/`):**
   - `Show` (`ShowStatus { active, deleting }`), `NewShow` (1–5 distinct `SessionTime` slots `HH:mm` -> `HHmm`), `Session` (`capacity => 47`), `ShowsRepository`, and `SingleShowPosterCoordinator`.
2. **Data, Poster Cache & Batch Delete (`lib/features/vendor_shows/data/repositories/firestore_shows_repository.dart`):**
   - `addShow(NewShow, Uint8List)`: checks title (`<= 80`), description (`<= 1000`), JPEG header (`0xff 0xd8 0xff`), `<= 204,800` bytes, and decoded image dimensions; verifies vendor ownership; writes `shows/{id}` (with `sessionIds` manifest), `showImages/{id}`, and `shows/{id}/sessions/{slotId}` atomically.
   - `loadPoster(showId)`: 32-entry bounded cache (`Source.server` fetch on miss), generation-guarded against delete/logout clears.
   - `deleteShow` & `resumeDeletes`: marks `status = 'deleting'` first to hide from Discover and block bookings, cleans paired `bookings`/`bookingEvents` in `<= 3` pairs per batch (`<= 18 <= 20` uncached Rules access calls), removes sessions + poster, and removes parent `shows/{id}` last. Resumes interrupted deletes on Vendor startup.
3. **Presentation & Native Image Picker (`lib/features/vendor_shows/presentation/`):**
   - `ImagePickerShowPosterAdapter` (`900x900`, quality `75`) exposes `pickPoster` and single-shot Android `retrieveLostPoster()`.
   - `ShowFormCubit` / `AddShowScreen`, `VendorShowsCubit` / `VendorShowsScreen`, `VendorShowDetailsCubit` / `VendorShowDetailsScreen` (with read-only `SeatMapView(vendorMode: true)`), and `DeleteShowDialog`.

---

## M2 — Customer Auth, Discovery & Show Details

1. **Auth Domain & Data (`lib/features/customer_auth/`):**
   - `FirebaseCustomerAuthRepository` maps `authStateChanges()` to `AppUser?`, restricts sign-in to `providerId == 'password'` accounts, and sanitizes Firebase errors.
2. **Auth Presentation & Route Gate:**
   - `CustomerAuthCubit` manages `checking`, `signedOut`, `signedIn`, and `error` states with generation/sequence guards. `LoginScreen`, `RegisterScreen`, and `AccountScreen` manage controllers cleanly.
   - `CustomerJourneyApp` (`lib/app/customer/customer_journey_app.dart`) clears the poster cache and increments `_sessionEpoch` on sign-out or UID switch so protected routes rebuild cleanly and Android Back stays on `/login`.
3. **Discovery Presentation (`lib/features/discovery/presentation/`):**
   - `DiscoveryCubit` / `DiscoveryScreen`: watches active shows newest-first (`createdAt` desc) and filters case-insensitively on `titleSearch`.
   - `ShowDetailsCubit` / `ShowDetailsScreen`: combines `watchShow` and `watchSessions` (up to 5 slots), handling deletion/removal cleanly via `ShowDetailsStatus.unavailable`.

---

## M3 — Android Flavors, DI, Router & Vendor Access

1. **Android Flavors & Live Entry Points:**
   - Customer (`com.arenapass.customer`): `lib/main_customer.dart` (`firebase_options_customer.dart`, `arenapass-demo`), with retryable `Startup failed` fallback via `createStartupErrorServices`.
   - Vendor (`com.arenapass.vendor`): `lib/main_vendor.dart` (`firebase_options_vendor.dart`, `arenapass-demo`), gated by `kVendorD01Approved` (`defaultValue: false` -> `Setup pending`) and backed by the same retryable startup-error fallback when active.
2. **Separated GetIt Composition (`lib/app/di/`):**
   - `shared_registration.dart`, `customer_registration.dart`, and `vendor_registration.dart`. Zero `GetIt` imports exist under `lib/features/**` or `lib/shared/**`. Route Cubits are registered as factories (`BlocProvider(create: ...)` owns `close()`).
3. **Vendor Access (`lib/features/vendor_access/`):**
   - `FirebaseVendorAccessRepository` signs in anonymously and reads `vendorDevices/{uid}` from server (`enabled == true` + non-empty `vendorId`). `VendorEnrolledApp` delegates gating directly to `VendorAccessGate` (`AccessChecking`, `VendorNotEnrolledScreen` with `Copy Device ID` + `Retry`, error retry, and `AccessAllowed`).

---

## M4 — Shared 47-Seat Layout & Live Seat Selection

1. **Canonical Seating (`lib/shared/seating/`):**
   - `SeatLayout` defines rows `1..4` (9 seats each with central aisle after index 4) and row `5` (`37..47`, no aisle).
   - `SeatTile` enforces exact grading colors (`available = #FFFFFF`, `bookedByOther = #766E78`, `selected`/`mineConfirmed = #9AE5B5` with `✓`), non-color semantic labels, single-tap toggle in customer mode, and non-interactive read-only display in vendor mode.
   - `SeatMapView` prevents horizontal overflow via `FittedBox(fit: BoxFit.scaleDown)` and offers an accessible `Row list` toggle.
2. **Seat Selection (`lib/features/booking/presentation/cubit/seat_selection_cubit.dart`):**
   - Reconciles `watchSession` and `watchMySeats`, moving newly taken seats to `droppedByConflict` with immediate conflict feedback while keeping per-seat `BlocSelector` rebuilds isolated (`SeatSelectionScreen`).

---

## M5 — Atomic Booking, Recovery & Security Rules

1. **Atomic Transaction (`FirestoreBookingRepository`):**
   - Pre-generated `bookingId` (`Random.secure()` hex in `registerCustomerBooking`) is preserved across retries and uncertain-response recovery.
   - `confirm` updates `shows/{id}`, `shows/{id}/sessions/{slotId}`, `bookings/{id}`, and `bookingEvents/{id}` atomically inside `runTransaction`, with up to 3 outer retries only on server-verified stale reads when `booking` is absent and parent revisions changed.
   - `recover` uses `Source.server` (`!isFromCache && !hasPendingWrites`) to distinguish confirmed (`RecoveryConfirmed`), authoritatively absent (`RecoveryAuthoritativelyAbsent`), and unresolved (`RecoveryUnresolved`).
2. **Security Rules (`firebase/firestore.rules`, `firebase/firestore.indexes.json`):**
   - Verified by 105 local emulator tests covering password-only customers, enrolled vendors, integer-only seat/counter checks, calendar date validation, 1–5 session manifests, `bookings/{id}` missing-doc recovery vs cross-owner denial, and `<= 3`-pair delete budgets.

---

## M6 — Vendor Notifications & Watermark Catch-Up

1. **Event Feed & Watermark (`lib/features/vendor_notifications/`):**
   - `FirestoreBookingEventsRepository` streams vendor-scoped `bookingEvents` ordered newest-first.
   - `SharedPreferencesWatermarkStore` persists `{lastSeenEventAtMs, seenEventIdsAtWatermark}` per vendor UID.
   - `FlutterLocalAlertPresenter` configures the `arenapass_booking_alerts` channel (`flutter_local_notifications`), requests `POST_NOTIFICATIONS` permission cleanly, and posts individual or grouped local alerts.
   - `VendorNotificationsCubit` performs silent baseline seeding on first launch, oldest-to-newest catch-up alert grouping on reopen, live individual notifications while active, lifetime ID deduplication, and alert-strictly-before-watermark save ordering.

# ArenaPass Oral Exam Walkthroughs (M1–M6)

> **Baseline:** Grounded strictly in repository commit `96ae618`. Each walkthrough states what is **Implemented & wired** on `96ae618` versus **Pending integration** (in-flight feature work or cloud setup).

---

## M1 — Vendor Shows, Images, Deletion & Poster Cache

### Implemented on `96ae618`

1. **Domain Contracts (`lib/features/vendor_shows/domain/`):**
   - `Show` (`models/show.dart`): `ShowStatus { active, deleting }`, validates non-empty IDs, `imageId == id`, `0 <= bookedCount <= 235`, `validateShowDate(showDate)` (`yyyy-MM-dd` real calendar date), and derives `titleSearch => title.toLowerCase()`.
   - `NewShow` (`models/new_show.dart`): enforces 1–5 distinct `SessionTime` items (`HH:mm` -> `id` `HHmm`, e.g., `'19:00'` -> `'1900'`).
   - `Session` (`models/session.dart`): enforces `id == time.id`, `capacity => seatCapacity` (`47`), and validated `bookedSeats`.
   - `ShowsRepository` (`repositories/shows_repository.dart`): defines `watchActiveShows`, `watchVendorShows`, `watchShow`, `watchSessions`, `addShow`, `deleteShow`, `resumeDeletes`, `loadPoster`, `clearPosterCache`, and `dispose`.
2. **Data & Poster Cache (`lib/features/vendor_shows/data/repositories/firestore_shows_repository.dart`):**
   - `addShow(NewShow, Uint8List)`: checks title (`<= 80`), description (`<= 1000`), JPEG SOI (`0xff 0xd8 0xff`) and `<= 204800` bytes; decodes `_jpegDimensions` via `dart:ui`; verifies enrolled vendor via `_requireVendor(show.vendorId)`; and runs `_firestore.runTransaction` writing `shows/{id}` (including `sessionIds` manifest), `showImages/{id}` (`Blob`), and `shows/{id}/sessions/{slotId}`.
   - `loadPoster(showId)`: maintains an in-memory `_posters` cache bounded at 32 entries (`Source.server` fetch on miss), invalidated via `_posterGeneration++` in `clearPosterCache()` / `dispose()`.
3. **Presentation & Native Image Picker (`lib/features/vendor_shows/presentation/`):**
   - `ImagePickerShowPosterAdapter` (`adapters/image_picker_show_poster_adapter.dart`): wraps `image_picker` (`900x900`, quality `75`), rejects non-JPEG headers (`FormatException`), and exposes single-shot Android `retrieveLostPoster()` (`retrieveLostData()`).
   - `ShowFormCubit` / `ShowFormState`: invokes optional `recoverPoster` on construction (discarded if a manual pick already occurred via `_acceptStartupRecovery = false`), manages up to 5 slots, validates all fields, and saves via `ShowsRepository.addShow`.
   - `VendorShowsCubit` / `VendorShowsScreen`: subscribes to `watchVendorShows(vendorId)`, sorts newest-first, invalidates poster cache using `vendorPosterRevision(show)`, and renders loading/empty/error/deleting states.
   - `VendorShowDetailsCubit` / `VendorShowDetailsScreen`: combines `watchShow` + `watchSessions`, filters out wrong-vendor/non-active shows as unavailable, switches sessions, and embeds read-only `SeatMapView(vendorMode: true)`.
   - `AddShowScreen`: owns `TextEditingController`s, `PopScope(canPop: !state.isSubmitting)`, and date/time pickers.
4. **DI & Routing (`lib/app/di/vendor_registration.dart`, `lib/app/vendor/vendor_demo_app.dart`):**
   - `registerVendorJourney` registers `ShowFormCubit`, `VendorShowsCubit`, and `VendorShowDetailsCubit` as GetIt factories owned by route `BlocProvider(create: ...)` in `VendorDemoApp` (`main_vendor_demo.dart` uses `DemoCustomerRepository` with `canAddShow: false`).
5. **Security Rules (`firebase/firestore.rules`):**
   - `shows/{id}` `allow create`: checks `vendorOwns`, `checkManifest(id, sessionIds, false)` (1–5 unique `HHmm` slots verified via `getAfter`), `validShow`, `bookedCount == 0`, `lastBookingId == ''`, and `getAfter(showImages/{id})`.
   - `showImages/{id}`: `validImage` enforces `poster is bytes`, `<= 204800`, `mimeType == 'image/jpeg'`, integer `width > 0`, `height > 0`, `vendorId`.

### Pending Integration on `96ae618`

- `FirestoreShowsRepository.deleteShow` and `resumeDeletes` currently throw `UnsupportedError('Show deletion is not configured')` (being implemented on the show-deletion branch).
- `main_vendor.dart` -> `createVendorApp()` currently renders `ArenaPassApp` ("Setup pending") until vendor access/live emulator composition is wired.

---

## M2 — Customer Auth, Discovery & Show Details

### Implemented on `96ae618`

1. **Auth Domain & Data (`lib/features/customer_auth/`):**
   - `AppUser(uid, email)` and `CustomerAuthRepository` (`authChanges`, `register`, `login`, `logout`).
   - `FirebaseCustomerAuthRepository` (`data/repositories/firebase_customer_auth_repository.dart`): maps `FirebaseAuth.authStateChanges()` to `AppUser?`, rejecting anonymous or non-`password` providers (`providerData.any((p) => p.providerId == 'password')`), and maps `FirebaseAuthException` to a generic `StateError('Customer authentication failed.')`.
   - `createLocalAuthRepository()` (`data/local_auth_emulator.dart`): initializes default Firebase app (`demo-arenapass`) on loopback Auth Emulator `127.0.0.1:9099`.
2. **Auth Presentation (`lib/features/customer_auth/presentation/`):**
   - `CustomerAuthCubit` / `CustomerAuthState`: `CustomerAuthStatus { checking, signedOut, signedIn, error }`; guards concurrent/stale actions with `_listenGeneration`, `_authEventSequence`, and `_activeOperation`; never stores passwords in state.
   - `LoginScreen`, `RegisterScreen`, `AccountScreen`: own/dispose `TextEditingController`s and `FocusNode`s; validate email/password/confirm-password; display busy/error banners.
3. **Discovery Presentation (`lib/features/discovery/presentation/`):**
   - `DiscoveryCubit` / `DiscoveryScreen`: watches `watchActiveShows(limit: 100)`, sorts newest-first (`createdAt` desc), filters loaded records client-side via `show.titleSearch.contains(normalized)`, and tracks poster revisions via `posterRevision`.
   - `ShowDetailsCubit` / `ShowDetailsScreen`: watches `watchShow(showId)` + `watchSessions(showId)` independently, keeps at most 5 sorted sessions, handles `ShowStatus.deleting` / missing docs via `ShowDetailsStatus.unavailable`, and renders loading/error/sold-out states.
4. **Root Auth Composition & Cache Isolation (`lib/app/di/customer_registration.dart`, `lib/app/customer/customer_journey_app.dart`):**
   - `createAuthenticatedCustomerServices` registers `CustomerAuthRepository` + `ShowsRepository` singletons and `CustomerAuthCubit`, `DiscoveryCubit`, `ShowDetailsCubit` factories.
   - `CustomerJourneyApp` owns root `BlocProvider(create: (_) => graph<CustomerAuthCubit>())` (via `createCustomerApp`), uses `GoRouter` with `refreshListenable: _authRefresh`, increments `_sessionEpoch` + calls `ShowsRepository.clearPosterCache()` on UID change/logout, keys protected subtrees by `_sessionEpoch`, and wraps `/login` with `PopScope(canPop: false)`.
   - `lib/main_customer_auth_emulator.dart` wires `createLocalAuthRepository()` + `createLocalShowsRepository()` + `FirestoreBookingRepository`.
5. **Rules & Indexes:**
   - `users/{uid}`: `customer()` owner-only `get`/`create`/`update` restricting keys to `['email','displayName','createdAt']`.
   - `shows/{id}`: `allow get: if signedIn()` (lets open `ShowDetailsScreen` read `status == 'deleting'` cleanly); `allow list` enforces `status == 'active'` for customers, backed by composite index `shows (status ASC, createdAt DESC)` in `firebase/firestore.indexes.json`.

### Pending Integration on `96ae618`

- `main_customer.dart` (`createCustomerApp()` with default `createCustomerServices()`) stays on `ArenaPassApp` ("Setup pending") pending cloud Firebase configuration.
- Tier 2 `my_bookings/` and `profile/` feature directories are structural scaffolds only.

---

## M3 — Foundation, Flavors, DI, Router & Vendor Access

### Implemented on `96ae618`

1. **Android Flavors & Entrypoints:**
   - `android/app/build.gradle.kts` defines `flavorDimensions += "app"` with `customer` (`com.arenapass.customer`) and `vendor` (`com.arenapass.vendor`).
   - `lib/main.dart` dispatches on `appFlavor == 'vendor'` to `main_vendor.dart` or `main_customer.dart`.
   - `lib/app/startup/{app_variant,arena_pass_app,startup_cubit,startup_screen}.dart` and `lib/app/theme/app_theme.dart` (`ColorScheme.fromSeed(seedColor: Color(0xffd52f65))`) provide the shared shell and startup retry flow.
2. **Separated GetIt Composition (`lib/app/di/`):**
   - `shared_registration.dart` (`registerShared`), `customer_registration.dart` (`createCustomerServices`, `createAuthenticatedCustomerServices`), `customer_journey_registration.dart` (`createDemoCustomerServices`, `registerCustomerJourney`, `registerCustomerBooking`, `registerCustomerDiscovery`), and `vendor_registration.dart` (`createVendorServices`, `registerVendorJourney`, `createDemoVendorServices`).
   - Feature classes never import `GetIt`; `sl<T>()` / `services<T>()` calls stay exclusively inside `lib/app/**` and `main_*.dart`.
3. **Vendor Access Domain & Data (`lib/features/vendor_access/`):**
   - `VendorAccess` (`VendorAllowed(uid, vendorId)`, `VendorNotEnrolled(uid)`), `VendorAccessRepository.check()`.
   - `FirebaseVendorAccessRepository` (`data/firebase_vendor_access_repository.dart`): signs in anonymously if `_auth.currentUser == null`, verifies `user.isAnonymous`, server-reads `vendorDevices/{uid}`, verifies UID stability, and checks `enabled == true` with non-empty `vendorId`.
   - Rules: `vendorDevices/{uid}` `allow get: if signedIn() && request.auth.uid == uid; allow write, list: if false;`.

### Pending Integration on `96ae618`

- `vendor_access/presentation/**` (`VendorAccessCubit`, `VendorAccessGate`, `VendorNotEnrolledScreen` with Copy Device ID) and `vendor_access_registration.dart` are not yet integrated on `96ae618` (in flight on the vendor-access branch).
- `android/app/build.gradle.kts` uses `flutter.compileSdkVersion` without `compileSdk = 37` or core library desugaring; per-flavor `google-services.json` and `firebase_options_*.dart` remain pending cloud setup.

---

## M4 — Shared 47-Seat Layout & Live Seat Selection

### Implemented on `96ae618`

1. **Canonical Seating Model & Layout (`lib/shared/seating/`):**
   - `seat_numbers.dart`: `seatCapacity = 47`, `checkedSeats(Iterable<int>, {bool allowEmpty = true})`.
   - `seat_layout.dart`: `SeatVisualStatus { available, selected, mineConfirmed, bookedByOther }`; `SeatLayout.rows` defines rows 1–4 as 9 seats each with `aisleAfterIndex: 4` and row 5 as seats `37..47` with no aisle (`aisleAfterIndex: null`); `statusForSeat` and `semanticsLabelForSeat` (`Seat N, row R, <Label>`).
2. **Shared Seating Widgets (`lib/shared/seating/widgets/`):**
   - `SeatMapView`: renders "Arena floor", `FittedBox(fit: BoxFit.scaleDown)` (prevents horizontal overflow), `Row list` / `Show map` mode toggle (`ChoiceChip`s per row for accessibility), `SeatLegend`, sold-out/conflict/busy/unavailable/error/loading states, and `vendorMode` read-only enforcement.
   - `SeatTile` (`seat_tile.dart`): `SeatColors` (`availableFill = #FFFFFF`, `bookedFill = #766E78`, `greenFill = #9AE5B5` with `✓` on `mineConfirmed`), direct single-tap toggle (`_canTap => !readOnly && !busy && status.isInteractive && onTap != null`), and `Semantics` actions.
3. **Seat Selection Cubit & Screen (`lib/features/booking/presentation/`):**
   - `SeatSelectionCubit` / `SeatSelectionState`: watches `BookingRepository.watchSession` and `watchMySeats`; `_reconcileSnapshots()` strips seats in `bookedSeats` or `myConfirmedSeats` from `selectedSeats` and moves newly stolen seats into `droppedByConflict` with a conflict message; cancels both subscriptions in `close()`.
   - `SeatSelectionScreen`: combines `BlocConsumer<BookingCubit, BookingState>` (navigates on non-busy request completion) and `BlocBuilder<SeatSelectionCubit, SeatSelectionState>`, disables back navigation (`PopScope(canPop: !booking.busy && !booking.unresolved)`), and docks the Confirm button inside `bottomNavigationBar: SafeArea(...)`.

### Pending Integration on `96ae618`

- `SeatSelectionScreen` currently builds `SeatMapView` inside a `BlocBuilder<SeatSelectionCubit, SeatSelectionState>` rather than passing a per-seat `seatSelectorBuilder` (`BlocSelector`).
- `FirestoreBookingRepository.watchSession` delegates to `_shows.watchSessions(showId)` without watching `watchShow(showId)` for `status == 'deleting'`.
- Tier 2 `tickets/` (per-seat QR) is a scaffold only.

---

## M5 — Atomic Booking, Recovery & Security Rules

### Implemented on `96ae618`

1. **Booking Domain (`lib/features/booking/domain/`):**
   - `BookingRequest` (pre-generated `bookingId`, `customerUid`, `showId`, `sessionId`, `seats`), `Booking`, `BookingResult` (`BookingConfirmed`, `BookingConflict`, `BookingUnavailable`, `BookingRejected`, `BookingUnconfirmed`), `BookingRecovery` (`RecoveryConfirmed`, `RecoveryAuthoritativelyAbsent`, `RecoveryUnresolved`), `BookingRepository`.
2. **Firestore Transaction & Recovery (`lib/features/booking/data/repositories/firestore_booking_repository.dart`):**
   - `confirm(BookingRequest)`: loops up to 3 outer attempts on `permission-denied` when server reads (`booking.get`, `show.get`, `slot.get` with `Source.server`) prove `!isFromCache && !hasPendingWrites`, booking absence, active parent/slot existence, and changed `(lastBookingId, updatedAt)`. Inside `runTransaction`: checks `prior.exists` first for idempotent same-payload replay (`BookingConfirmed`) vs mismatch (`BookingUnconfirmed`), validates active show & slot, checks seat conflicts (`BookingConflict`), and calls `_writeBooking` updating `shows/{showId}`, `shows/{showId}/sessions/{sessionId}`, `bookings/{bookingId}`, and `bookingEvents/{bookingId}` atomically.
   - `recover`: checks `_owns(customerUid)` and server-only `bookings/{bookingId}` (`RecoveryAuthoritativelyAbsent` only when `!doc.exists && _authoritative(doc)`).
   - `watchMySeats`: queries `bookings` with all 4 equality filters (`customerUid`, `showId`, `sessionId`, `status == 'confirmed'`) and filters `!hasPendingWrites && !isFromCache`.
3. **Booking Cubit & Result UI (`lib/features/booking/presentation/`):**
   - `BookingCubit`: state machine `BookingPhase { ready, submitting, confirmed, conflict, unavailable, rejected, unconfirmed, recovering, absent }`; prevents duplicate submits and blocks `newAttempt()` while `busy`, `unresolved`, or `confirmed`.
   - `BookingResultScreen`: renders reference, seats, conflict list, `Check status` (`recover()`), `Review seat map`, and `PopScope` lock while `busy` or `unresolved`.
4. **Security Rules & Tests (`firebase/firestore.rules`, `firebase/rules_test/baseline.test.mjs`, `integration_test/customer_booking_emulator_test.dart`):**
   - Enforces `customer()` (`sign_in_provider == 'password'`), `validSeats`, `calendarDate`, `checkManifest` (1–5 `HHmm` slots), integer-only guards (`is int`), `showCounter` + `sessionBooking` + `createBooking` + `createEvent` cross-checked via `getAfter`/`existsAfter`, `bookings/{bookingId}` `allow get` with `resource == null`, and `deletingOwner` cleanup rules (`maxDeletePairsPerBatch = 3` for guaranteed `<= 18 <= 20` uncached access calls).

### Pending Integration on `96ae618`

- `registerCustomerBooking` generates IDs via `Random.secure()` (`uuid` is not in `pubspec.yaml`).
- Tier 2 `cancellation/` and durable SQLite `pending_bookings` recovery across process kill/logout remain scaffolds only.

---

## M6 — Vendor Notifications, Watermark Catch-Up & Demo Integration

### Implemented on `96ae618`

1. **Domain Contract (`lib/features/vendor_notifications/domain/`):**
   - `BookingEvent` (`models/booking_event.dart`): immutable event model validating `bookingId`, `vendorId`, `showId`, `sessionId == slotTime.id`, non-empty `seats`, `showTitle`, `slotTime`, and atomic event-time `slotTotal` (`seats.length..47`) and `showTotal` (`slotTotal..235`), with `kind => 'booked'`.
   - `BookingEventsRepository` (`repositories/booking_events_repository.dart`): `Stream<List<BookingEvent>> watchEvents(String vendorId)` (descending event time).
2. **Backend Event Producer & Index (`firebase/firestore.rules`, `firebase/firestore.indexes.json`):**
   - `bookingEvents/{id}` is written atomically inside `FirestoreBookingRepository._writeBooking` with `slotTotal` and `showTotal` validated by `createEvent()` in `firestore.rules` (forbids `customerUid`, checks `s.vendorId`, `slot.bookedSeats.size()`, and `s.bookedCount`).
   - `allow read: if vendorOwns(resource.data.vendorId);` isolates events per vendor ID.
   - `firebase/firestore.indexes.json` declares `bookingEvents (vendorId ASC, createdAt DESC)`.

### Pending Integration on `96ae618`

- `vendor_notifications/data/repositories/`, `vendor_notifications/presentation/` (`VendorNotificationsCubit`, `VendorUpdatesScreen`, permission fallback), watermark store (`SharedPreferencesAsync` `lastSeenEventAtMs` + `seenEventIdsAtWatermark`), and local notification presenter (`flutter_local_notifications`) are still `.gitkeep` scaffolds on `96ae618` (being built on `feat/p3-vendor-alerts-m6`).
- `pubspec.yaml` does not yet include `shared_preferences` or `flutter_local_notifications`, and `android/` does not yet configure `compileSdk = 37`, desugaring, or `POST_NOTIFICATIONS`.

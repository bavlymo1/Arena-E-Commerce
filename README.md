# ArenaPass (`e_commerce_project`)

ArenaPass is a Tier 1 Android event-seat-booking Flutter workspace built with Firebase Auth and Cloud Firestore. A single Flutter codebase produces two separately installable Android applications (`customer` and `vendor` product flavors) for real-time 47-seat arena reservations and vendor monitoring.

> **Release Status:** Verified **Tier 1 Development Release** (single-device live acceptance completed on `arenapass-demo`). This is **not** unconditional final Tier 1 acceptance; no `tier1-demo` release tag has been created yet.

---

## 1. Applications

### Customer App (`com.arenapass.customer` — `lib/main_customer.dart`)
- **Email/Password Authentication**: registration, sign-in, session persistence, account view, and guarded logout (Back button cannot re-enter authenticated routes).
- **Discovery & Search**: active show feed ordered newest-first via real-time Firestore streams, case-insensitive title filtering, empty-search state, and show details (poster, date, 1–5 daily sessions, remaining seat counts).
- **47-Seat Selection & Atomic Booking**:
  - Exact 47-seat arena geometry (`rows 1–4` = 9 seats per row with a central aisle; `row 5` = contiguous seats `37–47` without an aisle) plus an accessible **Row list** toggle.
  - Direct single-tap toggling for available seats and color + icon legend (`White` = Available, `Grey` = Booked by others, `Green` = Selected / `✓` Confirmed own seats).
  - Atomic 4-document Firestore booking transaction (`bookings/{id}`, `shows/{showId}/sessions/{slotId}`, `shows/{showId}`, and `bookingEvents/{id}`) with client-generated booking ID and authoritative missing-document recovery (`bookings/{id}` `get`).

### Vendor App (`com.arenapass.vendor` — `lib/main_vendor.dart`)
- **No Visible Login Screen (`D01` Gate + Allowlist)**: silent Firebase Anonymous Authentication paired with a server-enforced `vendorDevices/{uid}` allowlist (`allow write, list: if false` in Firestore Security Rules).
- **Show Management**: create shows with required show date, poster artwork (`Gallery` or `Camera` JPEG validated at `<= 200 KB` in `showImages/{showId}`), and `1–5` distinct daily sessions (`47` seats each); restart-safe cascading show deletion (`<= 3` booking/event pairs per batch with `resumeDeletes` on relaunch).
- **Read-Only Live Seat Map**: inspect booked seat positions and totals per session without modifying customer reservations.
- **Real-Time Booking Alerts & Catch-Up**: listens to `bookingEvents` via Firestore streams, displays unread counts and exact commit-time session/show totals on **Booking updates**, posts local Android alerts (`arenapass_booking_alerts` channel with `ic_stat_arenapass` kept intact across R8 release shrinking via `android/app/src/vendor/res/raw/keep.xml`), and issues one grouped catch-up notification when missed bookings arrive while closed (without duplicate replays on subsequent restarts).

---

## 2. Technology Stack

- **Flutter / Dart**: Flutter `3.47.7` (stable) / Dart SDK `^3.13.5`
- **State Management & Navigation**: `flutter_bloc` (`Cubit` + `Equatable`), `go_router`, `get_it`
- **Firebase Client SDKs**: `firebase_core`, `firebase_auth`, `cloud_firestore` (initialized via Dart `DefaultFirebaseOptions.currentPlatform` without `com.google.gms.google-services` Gradle auto-init so local emulator suites remain isolated)
- **Device & Platform Plugins**: `image_picker`, `flutter_local_notifications`, `shared_preferences`
- **Firebase Rules & Tooling**: Node.js `22`, `@firebase/rules-unit-testing`, `firebase` JS SDK, `firebase-tools` (`15.35.0`), Java `21` (for local Firestore Emulator runs)

---

## 3. Architecture Overview

- **Feature-First Layout**:
  - `lib/features/customer_auth/` — Email/Password auth, account profile, and auth state lifecycle
  - `lib/features/discovery/` — customer active-show catalog, title search, and show/session details
  - `lib/features/booking/` — seat selection state, atomic Firestore booking transaction, and missing-doc recovery
  - `lib/features/vendor_access/` — silent anonymous sign-in and fail-closed `vendorDevices/{uid}` enrollment gate
  - `lib/features/vendor_shows/` — vendor show creation, media picking, read-only show inspection, and restart-safe deletion
  - `lib/features/vendor_notifications/` — live `bookingEvents` listener, `SharedPreferences` watermark, grouped catch-up reconciliation, and Android local notifications
- **Shared & App Layers**:
  - `lib/shared/seating/` — shared 47-seat geometry helpers (`seat_layout.dart`, `seat_numbers.dart`) and `SeatMapView` used by both apps
  - `lib/shared/widgets/` — reusable UI building blocks (`ArenaPosterBanner`, `ArenaStatusPanel`, `ArenaNoticeBanner`, etc.)
  - `lib/core/formatting/` — shared date/session time formatters
  - `lib/app/di/` (`shared_registration.dart`, `customer_registration.dart`, `vendor_registration.dart`) — manual `GetIt` composition (`GetIt` lookups remain confined to app DI/router setup; Cubits and repositories use constructor injection)
  - `lib/app/customer/`, `lib/app/vendor/`, `lib/app/startup/`, `lib/app/theme/` — flavor shells, routers, retryable startup error wrapper, and Light/Dark Material themes
- **Firebase Configuration & Harnesses**:
  - `firebase/firestore.rules` & `firebase/firestore.indexes.json`
  - `firebase/rules_test/` — 105-test Security Rules & concurrency specification against local Firestore Emulator
  - `firebase/seed/` — 7-test deterministic seed fixture verifier for local `demo-arenapass` emulator runs

Production builds (`lib/main_customer.dart`, `lib/main_vendor.dart`) contain zero emulator bindings or demo fixtures (`test/support/` and `test/fixtures/posters/` are test-only).

---

## 4. Setup Prerequisites

1. **Flutter `3.47.7`** (`Dart 3.13.5`) on `PATH` and **Android SDK** configured (`compileSdk = 37` in `android/app/build.gradle.kts`, minSdk per Android default).
2. **Java `21` (Temurin/OpenJDK)**, **Node.js `22`**, and **Firebase CLI** (`npm install -g firebase-tools@15.35.0`) if running the Firestore Rules emulator suite (`firebase/rules_test`).
3. Install Dart/Flutter packages from repository root:
   ```powershell
   flutter pub get
   ```
4. Install Rules test dependencies (if running Firestore Security Rules tests):
   ```powershell
   cd firebase/rules_test
   npm ci
   cd ../..
   ```

---

## 5. Official Firebase Configuration

Live flavor builds bind directly to project **`arenapass-demo`** (project number **`167616601158`**):
- **Customer (`com.arenapass.customer`)**: `lib/firebase_options_customer.dart` & `android/app/src/customer/google-services.json`
- **Vendor (`com.arenapass.vendor`)**: `lib/firebase_options_vendor.dart` & `android/app/src/vendor/google-services.json`
- **Firestore Rules & Indexes (`firebase.json`)**:
  - Rules: `firebase/firestore.rules`
  - Composite Indexes (all 3 required for live queries): `firebase/firestore.indexes.json`
    1. `shows`: `status ASC, createdAt DESC`
    2. `shows`: `vendorId ASC, createdAt DESC`
    3. `bookingEvents`: `vendorId ASC, createdAt DESC`
- **Firebase Auth Providers**: **Email/Password** and **Anonymous** providers must be enabled in Firebase Console (`Authentication -> Sign-in method`).

---

## 6. Customer Run & Build Commands

Run from repository root:

```powershell
# Run Customer app on connected Android device (live arenapass-demo)
flutter run --flavor customer -t lib/main_customer.dart -d <device-id>

# Build Customer debug APK
flutter build apk --debug --flavor customer -t lib/main_customer.dart

# Build Customer release APK
flutter build apk --release --flavor customer -t lib/main_customer.dart
```

---

## 7. Vendor Run, Build & Device Enrollment (`VENDOR_D01_APPROVED`)

### Why the `VENDOR_D01_APPROVED` Flag Exists
In `lib/main_vendor.dart`, `kVendorD01Approved` defaults to `false` (`Setup pending` screen) pending formal `D01` approval of silent anonymous authentication plus admin `vendorDevices/{uid}` enrollment. The fail-closed `VendorAccessGate` and `vendorDevices/{uid}` rules remain preserved; **do not bypass authorization**.

Pass `--dart-define=VENDOR_D01_APPROVED=true` for authorized live Vendor runs and builds against `arenapass-demo`:

```powershell
# Run Vendor app on connected Android device (live arenapass-demo)
flutter run --flavor vendor -t lib/main_vendor.dart --dart-define=VENDOR_D01_APPROVED=true -d <device-id>

# Build Vendor debug APK with approved live startup
flutter build apk --debug --flavor vendor -t lib/main_vendor.dart --dart-define=VENDOR_D01_APPROVED=true

# Build Vendor release APK with approved live startup
flutter build apk --release --flavor vendor -t lib/main_vendor.dart --dart-define=VENDOR_D01_APPROVED=true
```

### Required Vendor Device Enrollment (`vendorDevices/{uid}`)
Every newly installed Vendor device receives a Firebase Anonymous Auth UID and stays gated on **Device not enrolled** until an administrator authorizes it:
1. Launch the Vendor app on the device and tap **Copy Device ID** to copy the device's Firebase Anonymous Auth UID.
2. In Firebase Console (`arenapass-demo` -> **Firestore Database**), create document:
   - **Collection**: `vendorDevices`
   - **Document ID**: `<exact-copied-anonymous-uid>`
   - **Fields**:
     - `enabled`: `true` (`boolean`)
     - `vendorId`: `"arena"` (`string`)
3. Tap **Retry** in the Vendor app; it opens directly into **My shows** and remembers the enrollment across cold restarts.
   - Use `adb install -r` when upgrading an already-enrolled test device so the local Firebase Auth session (and enrolled UID) is preserved.

---

## 8. Verification & Test Commands

Run from repository root (except Rules tests inside `firebase/rules_test`):

```powershell
# Formatting & static analysis
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub

# Full Flutter unit & widget test suite (333 tests)
flutter test --no-pub

# Firebase seed contract tests (7 tests)
node --test firebase/seed/seed.test.mjs

# Firestore Security Rules & concurrency suite (105 tests, requires Java 21 + Firebase CLI)
cd firebase/rules_test
npm run test:emulator
cd ../..
```

### Local Firebase Emulator Integration Suites (`integration_test/`)
For isolated local device integration runs (`integration_test/customer_booking_emulator_test.dart`, `integration_test/vendor_show_delete_emulator_test.dart`):
1. Start local Auth (`9099`) and Firestore (`8180`):
   ```powershell
   firebase --config firebase.json --project demo-arenapass emulators:start --only auth,firestore
   ```
2. Forward device ports over ADB:
   ```powershell
   adb reverse tcp:9099 tcp:9099
   adb reverse tcp:8180 tcp:8180
   ```
3. Run an integration suite (omit `--no-pub` on the first run after any `--release` build so `IntegrationTestPlugin` is regenerated):
   ```powershell
   flutter test integration_test/customer_booking_emulator_test.dart --flavor customer -d <device-id>
   ```
4. Clear temporary emulator port forwards before resuming live `arenapass-demo` device testing (`adb reverse --remove tcp:9099; adb reverse --remove tcp:8180`).

---

## 9. Known Limitations & Remaining Acceptance Items

This release is a **development release** intended for team code review, multi-device setup, and completion of remaining acceptance gates. The following items remain open before final Tier 1 sign-off and `tier1-demo` tagging:

- **`LAT-11B`**: Live simultaneous two-device pre-selection eviction (when Customer A confirms seats currently selected on Customer B's open screen).
- **`LAT-12`**: Live two-device concurrent booking conflict (two physical Customer handsets tapping **Confirm** simultaneously on the same available seat).
- **`LAT-02` (Android 13+ runtime dialog)**: Live OS `POST_NOTIFICATIONS` permission prompt behavior on Android 13+ / API 33+ hardware (single-device live acceptance ran on Android 11 / API 30; release notification channel `arenapass_booking_alerts` and live/catch-up OS alerts are verified).
- **`D01`**: Final doctor/instructor confirmation of silent anonymous Vendor startup plus `vendorDevices/{uid}` admin enrollment (keeps `kVendorD01Approved` default `false` until resolved).
- **`D03`**: Formal confirmation of Tier 1 foreground/background Firestore-stream local notifications + grouped catch-up scope (background terminated FCM push remains deferred to Tier 2).
- **Final UI/UX audit & improvements**: Visual polish and UX audit pass across Customer and Vendor flows.
- **Team Walkthrough & Sign-Off**: Full six-member (`M1`–`M6`) code walkthrough and acceptance sign-off before any `tier1-demo` tag or Tier 2 feature work.

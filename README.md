# ArenaPass (`e_commerce_project`)

Android-only Tier 1 event-seat-booking Flutter workspace delivering two separately installable applications from one codebase:

- **Customer** (`com.arenapass.customer`): `lib/main_customer.dart` — email/password authentication, show discovery, show details, live 47-seat booking map, atomic 4-document Firestore bookings, and authoritative missing-document recovery.
- **Vendor** (`com.arenapass.vendor`): `lib/main_vendor.dart` — fail-closed `vendorDevices/{uid}` enrollment gate (`kVendorD01Approved`), show creation/deletion (`<= 3` pairs per batch, restart-safe `resumeDeletes`), read-only 47-seat inspection, and Firestore-driven real-time booking alerts (`flutter_local_notifications` + watermark catch-up).

Both live entry points bind directly to the `arenapass-demo` Firebase project (`lib/firebase_options_customer.dart` and `lib/firebase_options_vendor.dart`), with a retryable startup-error screen if `Firebase.initializeApp` fails. Production builds contain zero demo fixtures, emulator bindings, or unused assets (`test/support/` and `test/fixtures/posters/` hold test-only fixtures).

## Common Commands (from `e_commerce_project/`)

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
node --test firebase/seed/seed.test.mjs

# Firestore Security Rules suite (from firebase/rules_test/)
npm run test:emulator

# Debug & release Android APK builds
flutter build apk --debug --flavor customer -t lib/main_customer.dart
flutter build apk --release --flavor customer -t lib/main_customer.dart
flutter build apk --debug --flavor vendor -t lib/main_vendor.dart
flutter build apk --release --flavor vendor -t lib/main_vendor.dart
```

For local Firebase Emulator integration tests (`integration_test/*_test.dart`):
1. Start local Auth (`9099`) and Firestore (`8180`): `firebase --config firebase.json --project demo-arenapass emulators:start --only auth,firestore`
2. Forward device ports over ADB: `adb reverse tcp:9099 tcp:9099` and `adb reverse tcp:8180 tcp:8180`
3. Run each integration test (`flutter test integration_test/<suite>.dart --flavor customer -d <device-id>`).

Note on Vendor live flag: `kVendorD01Approved` in `lib/main_vendor.dart` defaults to `false` (`Setup pending`) until `D01` doctor acceptance and live `arenapass-demo` Security Rules, composite indexes (`firebase/firestore.indexes.json`), and `vendorDevices/{uid}` enrollment are deployed and verified. Override locally only for authorized validation (`--dart-define=VENDOR_D01_APPROVED=true`).

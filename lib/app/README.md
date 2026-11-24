# Application composition

**Status: live Customer and gated Vendor Android roots implemented (`kVendorD01Approved` defaults to `false`).**

- `customer/`: `createCustomerApp` and `CustomerJourneyApp` (email/password auth redirect gate, poster cache clearing + `_sessionEpoch` rebuild on logout, discovery, details, seat selection, and booking result routes).
- `vendor/`: `createVendorApp` (`Setup pending` gate while `kVendorD01Approved == false`), `VendorEnrolledApp` (`VendorAccessGate` -> `VendorNotificationsCubit` + `VendorJourneyRouter` for shows, add-show, show details, and booking updates).
- `di/`: separated `shared_registration.dart` (`createStartupErrorServices`), `customer_registration.dart` (`createCustomerServices`, `createLiveCustomerServices`, booking/discovery factories), and `vendor_registration.dart` (`createVendorServices`, `createLiveVendorServices`, access/shows/notifications factories).
- `startup/`: `ArenaPassApp`, `StartupCubit`, `StartupScreen`, `wrapWithEnvironmentBanner`, and `AppVariant` — used by Customer `/startup` (`CustomerJourneyApp`), `VendorJourneyRouter` banner support, the `kVendorD01Approved == false` setup gate (`createVendorApp`), and retryable `Firebase.initializeApp` startup failures (`createStartupErrorServices`). Once `D01` and live cloud setup are accepted, drop the `'Setup pending'` gate branch in `lib/main_vendor.dart` while keeping `StartupScreen` / `wrapWithEnvironmentBanner` / error fallback as needed.
- `theme/`: `buildAppTheme` light/dark Material 3 `ThemeData` aligned with the approved prototype.

Invariants:
- GetIt registrations and lookups belong exclusively to `lib/app/**` and `lib/main_*.dart`.
- Route Cubits are registered as factories (`BlocProvider(create: ...)` owns `close()`); app-scoped repositories remain reusable after logout.
- Demo apps/repositories (`customer_demo_app.dart`, `vendor_demo_app.dart`, `demo_customer_repository.dart`, `customer_test_services.dart`) live exclusively under `test/support/`.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1/6; merged plan §5.

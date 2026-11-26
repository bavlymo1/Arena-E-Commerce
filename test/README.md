# Tests

**Status: Tier 1 unit, Cubit, widget, and composition tests implemented.**

Structure mirrors `lib/` across `features/*/`, `app/` (DI/customer/vendor journey suites), `core/formatting/`, and `shared/` (canonical 47-seat map and shared widget catalog). Test-only demo apps/repositories and poster fixtures live under `test/support/` and `test/fixtures/posters/`.

Use `*_test.dart` names and direct constructor-injected fakes for Cubits (no `GetIt` inside feature tests). `widget_test.dart` verifies `createCustomerApp()` and `createVendorApp()` start in the `Setup pending` shell and never grant access on Retry. Run `flutter test --no-pub` from `e_commerce_project/`.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §8; merged plan §19; Tier 2 item tests.

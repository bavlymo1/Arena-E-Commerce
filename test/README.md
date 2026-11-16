# Tests

**Status: scaffold only.** No feature behavior/configuration is implemented here.

Mirror lib feature domain/models, domain/repositories, data/repositories and presentation/cubit/screens/widgets under features/. app/ mirrors composition/startup/DI/theme; core/ mirrors errors/formatting/storage; shared/seating/ covers the canonical layout.

Use *_test.dart names and direct constructor-injected fakes for Cubits, not GetIt in unit tests. Data integration uses explicit emulators/test databases; app DI tests own registration reset. Test UID isolation, stable booking recovery and single-writer transactions without duplicating production models. Existing widget_test.dart remains the counter smoke test, not ArenaPass verification. Empty markers are not runnable tests.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §8; merged plan §19; Tier 2 item tests. These paths are relative to the full workspace; they are intentionally not public Markdown links.

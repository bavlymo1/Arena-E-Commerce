# Customer Auth

**Status: email/password Firebase Auth adapter, gate Cubit, and Login/Register/Account screens implemented.**

Implemented components:
- `domain/`: `AppUser` and `CustomerAuthRepository`.
- `data/repositories/firebase_customer_auth_repository.dart`: restricts accepted accounts to email/password (`providerId == 'password'`) and sanitizes auth errors.
- `presentation/cubit/customer_auth_cubit.dart`: root session lifecycle with stale-operation sequence guards.
- `presentation/screens/`: `LoginScreen`, `RegisterScreen`, and `AccountScreen`. Root composition (`CustomerJourneyApp`) clears the poster cache and rebuilds the protected session subtree on logout or user switch.

Emulator testing uses `integration_test/support/emulator_support.dart` (`createLocalAuthRepository`) with `integration_test/customer_auth_adapter_test.dart` and `integration_test/customer_auth_journey_test.dart`.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13.

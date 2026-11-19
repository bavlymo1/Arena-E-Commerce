# Customer Auth

**Status: Customer auth presentation and Firebase Auth adapter implemented.** Login/register/account and one root CustomerAuthCubit are composed behind an auth-driven route gate. Firebase Auth operations are verified against the local Auth Emulator; live project configuration remains pending.

Customer identity and register/login/logout.

Contracts: AppUser and CustomerAuthRepository.

FirebaseCustomerAuthRepository implements the unchanged domain contract, maps SDK users to password-provider AppUser values and keeps SDK errors out of operation failures. Root composition clears poster display cache and replaces protected route state when identity ends or changes. Route/Cubit teardown cancels subscriptions; logout leaves the repository reusable.

Start the local backends from the app directory with `firebase --config firebase.json --project demo-arenapass emulators:start --only auth,firestore`. The explicit `lib/main_customer_auth_emulator.dart` entrypoint uses loopback Auth port 9099 and Firestore port 8180 on the same demo project. On a USB Android device run `adb reverse tcp:9099 tcp:9099` and `adb reverse tcp:8180 tcp:8180`.

The preview reads shows from Firestore and leaves booking unavailable until a booking adapter exists. `main_customer_demo.dart` runs the in-memory booking fixture. The Android regression `integration_test/customer_firestore_reads_test.dart` seeds two dated shows and checks sorting, search, posters, session updates and removal through the Customer UI. Run it with `flutter test integration_test/customer_firestore_reads_test.dart --no-pub --flavor customer -d <device-id>`.

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports. Cubits receive dependencies through constructors. GetIt resolution belongs to app composition, not this feature. Cross-feature use is through domain contracts; do not import another feature's presentation/data. Use snake_case files, capability_repository.dart, backend-specific implementations, *_cubit.dart, *_state.dart, *_screen.dart and *_test.dart names only when content is implemented.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13; Tier 2 plan §5 for extensions. These paths are relative to the full workspace; they are intentionally not public Markdown links.

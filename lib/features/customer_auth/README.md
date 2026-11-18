# Customer Auth

**Status: Customer auth presentation and Firebase Auth adapter implemented.** Login/register/account and one root CustomerAuthCubit are composed behind an auth-driven route gate. Firebase Auth operations are verified against the local Auth Emulator; live project configuration remains pending.

Customer identity and register/login/logout.

Contracts: AppUser and CustomerAuthRepository.

FirebaseCustomerAuthRepository implements the unchanged domain contract, maps SDK users to password-provider AppUser values and keeps SDK errors out of operation failures. Root composition clears poster display cache and replaces protected route state when identity ends or changes. Route/Cubit teardown cancels subscriptions; logout leaves the repository reusable.

The explicit `lib/main_customer_auth_emulator.dart` entrypoint connects only to `demo-arenapass` Auth on `127.0.0.1:9099`. For a USB Android device use `adb reverse tcp:9099 tcp:9099`. Start the local emulator with `firebase --config firebase.json --project demo-arenapass emulators:start --only auth` from the app directory. Debug network policy permits HTTP only to loopback; release policy is unchanged. No live setup is required for this preview.

This auth preview uses sample shows and leaves booking unavailable until a real booking adapter exists. `main_customer_demo.dart` still runs the separate complete in-memory booking fixture. Native tests under `integration_test/` exercise adapter operations and the auth UI against the emulator; ordinary Flutter tests use injected fakes. None of these tests proves live Firestore, persistent pending recovery or TalkBack operation.

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports. Cubits receive dependencies through constructors. GetIt resolution belongs to app composition, not this feature. Cross-feature use is through domain contracts; do not import another feature's presentation/data. Use snake_case files, capability_repository.dart, backend-specific implementations, *_cubit.dart, *_state.dart, *_screen.dart and *_test.dart names only when content is implemented.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13; Tier 2 plan §5 for extensions. These paths are relative to the full workspace; they are intentionally not public Markdown links.

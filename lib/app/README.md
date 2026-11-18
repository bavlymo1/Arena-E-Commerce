# Application composition

**Status: startup shells and opt-in local Customer/Vendor journeys implemented.** Normal entrypoints remain setup pending. The explicit `main_customer_demo.dart` and `main_vendor_demo.dart` targets use in-memory fixtures that reset on restart; they do not authenticate or share state between installed apps.

`main_customer_auth_emulator.dart` adds real local Firebase Auth to Customer login/register/Discover/account/logout. One root auth Cubit owns the subscription; redirects keep checking on startup and prevent protected navigation after logout. Identity exit clears posters and replaces protected route state. Its shows are samples and booking stays setup pending; it does not enable a live Firebase project.

Customer/vendor roots and routers live in customer/ and vendor/; router files such as customer_router.dart belong there, not a second routing hierarchy. Startup/splash and startup retry states belong in startup/. DI registration is shared/customer/vendor under di/; theme tokens/component themes stay under app/theme/.

GetIt registrations/lookups belong to composition and route/provider creation. Inject repositories into Cubit constructors; route Cubits are factories owned by BlocProvider(create: ...), never factory-created BlocProvider.value. Root providers own auth/access/notification lifetimes. App-scoped repositories remain usable after logout. Routes pass IDs, not mutable models. Composition imports concrete data implementations and domain contracts; features do not import app composition.

Customer composition wires discovery/details/selection/result. Vendor composition wires shows/details/read-only session maps. Both use GetIt factory Cubits and go_router; future authorized repositories can use the journey registration functions with explicit customer/vendor scope. Firebase startup, auth/access gates and trusted notification delivery remain pending.

Local preview builds:

```powershell
flutter build apk --debug --no-pub --flavor customer -t lib/main_customer_demo.dart
flutter build apk --debug --no-pub --flavor vendor -t lib/main_vendor_demo.dart
flutter build apk --debug --no-pub --flavor customer -t lib/main_customer_auth_emulator.dart
```

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1/6; merged plan §5. These paths are relative to the full workspace; they are intentionally not public Markdown links.

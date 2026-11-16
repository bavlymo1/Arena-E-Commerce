# Application composition

**Status: scaffold only.** No feature behavior/configuration is implemented here.

Customer/vendor roots and routers live in customer/ and vendor/; router files such as customer_router.dart belong there, not a second routing hierarchy. Startup/splash and startup retry states belong in startup/. DI registration is shared/customer/vendor under di/; theme tokens/component themes stay under app/theme/.

GetIt registrations/lookups belong to composition and route/provider creation. Inject repositories into Cubit constructors; route Cubits are factories owned by BlocProvider(create: ...), never factory-created BlocProvider.value. Root providers own auth/access/notification lifetimes. App-scoped repositories remain usable after logout. Routes pass IDs, not mutable models. Composition imports concrete data implementations and domain contracts; features do not import app composition.

Future names: customer_app.dart, customer_router.dart, vendor_app.dart, vendor_router.dart, shared_dependencies.dart and app_theme.dart. No registrations or entry-point Dart stubs are added. Reuse canonical Show/Session/Booking/seat mapping; extract branded splash widget only on real reuse.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1/6; merged plan §5. These paths are relative to the full workspace; they are intentionally not public Markdown links.

# Vendor Access

**Status: implemented locally (`D01` doctor acceptance of the silent anonymous device + enrolled `vendorDevices/{uid}` proposal remains pending).**

Implemented files:
- `domain/models/vendor_access.dart`, `domain/repositories/vendor_access_repository.dart`: `VendorAccess` (`VendorAllowed`, `VendorNotEnrolled`) and `VendorAccessRepository` contracts.
- `data/repositories/firebase_vendor_access_repository.dart`: server-verified `vendorDevices/{uid}` lookup after anonymous auth (`clients` never self-enroll).
- `presentation/cubit/vendor_access_cubit.dart`, `presentation/cubit/vendor_access_state.dart`, `presentation/vendor_access_strings.dart`: enrollment check lifecycle and status strings.
- `presentation/screens/vendor_access_gate.dart`, `presentation/screens/vendor_not_enrolled_screen.dart`, `presentation/widgets/vendor_access_widgets.dart`: startup gate with Copy Device ID and retry.

DI registration lives in app composition (`lib/app/di/vendor_registration.dart`).

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports. Cubits receive dependencies through constructors. GetIt resolution belongs to app composition, not this feature. Cross-feature use is through domain contracts; do not import another feature's presentation/data. Use snake_case files, capability_repository.dart, backend-specific implementations, *_cubit.dart, *_state.dart, *_screen.dart and *_test.dart names only when content is implemented.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13; Tier 2 plan §5 for extensions. These paths are relative to the full workspace; they are intentionally not public Markdown links.

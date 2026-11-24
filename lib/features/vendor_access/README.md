# Vendor Access

**Status: fail-closed anonymous UID + admin-enrolled `vendorDevices/{uid}` gate implemented (`kVendorD01Approved` in `lib/main_vendor.dart` remains `false` pending doctor acceptance and live cloud setup).**

Implemented files:
- `domain/models/vendor_access.dart`, `domain/repositories/vendor_access_repository.dart`: `VendorAccess` (`VendorAllowed`, `VendorNotEnrolled`) and `VendorAccessRepository`.
- `data/repositories/firebase_vendor_access_repository.dart`: server-verified `vendorDevices/{uid}` lookup after anonymous auth (`clients` never self-enroll).
- `presentation/cubit/vendor_access_cubit.dart`, `presentation/cubit/vendor_access_state.dart`, `presentation/vendor_access_strings.dart`: checking/allowed/not-enrolled/error lifecycle.
- `presentation/screens/vendor_access_gate.dart`, `presentation/screens/vendor_not_enrolled_screen.dart`, `presentation/widgets/vendor_access_widgets.dart`: single `VendorAccessGate` with Copy Device ID and retry.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13.

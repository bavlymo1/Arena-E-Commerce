# My Bookings

**Status: scaffold only.** No feature behavior/configuration is implemented here.

Owner-scoped booking history and detail views.

Contracts: Consumes canonical Booking from booking/domain; owner-only history read contract as needed.

Intended implementation: MyBookingsCubit and history/detail screens; close listeners on logout and do not expose another UID. Read-only history is not a second booking writer.

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports. Cubits receive dependencies through constructors. GetIt resolution belongs to app composition, not this feature. Cross-feature use is through domain contracts; do not import another feature's presentation/data. Use snake_case files, capability_repository.dart, backend-specific implementations, *_cubit.dart, *_state.dart, *_screen.dart and *_test.dart names only when content is implemented.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13; Tier 2 plan §5 for extensions. These paths are relative to the full workspace; they are intentionally not public Markdown links.

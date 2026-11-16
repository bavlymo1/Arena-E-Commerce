# Booking

**Status: scaffold only.** No feature behavior/configuration is implemented here.

All-or-none confirmation and pending-request persistence/recovery.

Contracts: Canonical Booking, BookingRequest, BookingResult and BookingRepository; history consumes this model.

Intended implementation: BookingCubit, SeatSelectionCubit and pending screens; one authoritative booking writer owns show/session/booking/event transaction. booking/data owns journal SQL using injected core/storage connection. Preserve stable reference and original UID across logout; never recover one account as another.

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports. Cubits receive dependencies through constructors. GetIt resolution belongs to app composition, not this feature. Cross-feature use is through domain contracts; do not import another feature's presentation/data. Use snake_case files, capability_repository.dart, backend-specific implementations, *_cubit.dart, *_state.dart, *_screen.dart and *_test.dart names only when content is implemented.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13; Tier 2 plan §5 for extensions. These paths are relative to the full workspace; they are intentionally not public Markdown links.

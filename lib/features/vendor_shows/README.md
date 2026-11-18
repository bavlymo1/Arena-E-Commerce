# Vendor Shows

**Status: read-only presentation implemented and tested with local fixtures.** Vendor-scoped list, details, session selection and the shared 47-seat map are composed by the explicit Vendor demo. Normal startup still reports setup pending.

Show metadata, images, sessions and restart-safe real deletion.

Contracts: Canonical Show, Session, NewShow and ShowsRepository; other features consume these models.

Implemented: VendorShowsCubit and VendorShowDetailsCubit, including stream cleanup, retry and poster invalidation. Pending: ShowFormCubit, FirebaseShowsRepository, image acquisition, add/delete/resume writes and real authorized access. Optional action callbacks do not implement those operations.

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports. Cubits receive dependencies through constructors. GetIt resolution belongs to app composition, not this feature. Cross-feature use is through domain contracts; do not import another feature's presentation/data. Use snake_case files, capability_repository.dart, backend-specific implementations, *_cubit.dart, *_state.dart, *_screen.dart and *_test.dart names only when content is implemented.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13; Tier 2 plan §5 for extensions. These paths are relative to the full workspace; they are intentionally not public Markdown links.

# Vendor Shows

**Status: Tier 1 live Firestore show management, image acquisition, and restart-safe batch deletion implemented.**

Implemented components:
- `domain/`: `Show` (`ShowStatus { active, deleting }`), `NewShow`, `Session`, `SessionTime`, `ShowsRepository`, and `SingleShowPosterCoordinator` poster cache/invalidation coordinator.
- `data/repositories/firestore_shows_repository.dart`: enrolled-vendor creation (`shows/{id}`, `showImages/{id}` JPEG `<= 204,800` bytes with decoded dimensions, and 1–5 `sessions`), 32-entry poster LRU cache, and restart-safe chunked delete (`maxDeletePairsPerBatch = 3`, `resumeDeletes`).
- `presentation/adapters/image_picker_show_poster_adapter.dart`: gallery/camera `pickPoster` (`900x900` @ 75% quality) and single-shot Android `retrieveLostPoster()`.
- `presentation/`: `VendorShowsCubit`, `VendorShowDetailsCubit`, `ShowFormCubit`, `VendorShowsScreen`, `VendorShowDetailsScreen`, `AddShowScreen`, and `DeleteShowDialog`.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13.

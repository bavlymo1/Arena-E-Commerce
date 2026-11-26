# Discovery

**Status: newest-first customer show feed, search filter, and show details/session selection implemented.**

Implemented components:
- `presentation/cubit/discovery_cubit.dart`: watches `ShowsRepository.watchActiveShows(limit: 100)`, sorts newest-first, filters case-insensitively on loaded `titleSearch`, and manages bounded poster loading.
- `presentation/cubit/show_details_cubit.dart`: watches `watchShow` and `watchSessions` (1–5 chronological slots), transitioning cleanly to unavailable on `ShowStatus.deleting` or removal.
- `presentation/screens/`: `DiscoveryScreen` and `ShowDetailsScreen` consuming canonical `Show`, `Session`, and `ShowsRepository` from `vendor_shows/domain`.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13.

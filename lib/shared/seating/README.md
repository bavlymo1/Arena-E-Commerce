# Shared seating & widgets

- `seating/`: canonical 47-seat model (`seat_numbers.dart`, `seat_layout.dart`), `SeatMapView`, `SeatLegend`, and `SeatTile`. Four rows of nine with central aisle; row five `37..47` without aisle. White free, grey other-booked, green selected/own-confirmed (`✓`), non-color semantic labels, read-only Vendor mode.
- `widgets/`: approved reusable presentation helpers (`ArenaBrandMark`, `ArenaBusyButtonLabel`, `ArenaLoadingView`, `ArenaNoticeBanner`, `ArenaPosterBanner`, `ArenaStatusPanel`, and consolidated UI helpers in Batch 4).

Shared components never import Firebase, repositories, Cubits, or GetIt.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1/4/7; merged plan §§2/5/19.

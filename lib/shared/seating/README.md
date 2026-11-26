# Shared seating & widgets

- `seating/`: canonical 47-seat model (`seat_numbers.dart`, `seat_layout.dart`), `SeatMapView`, `SeatLegend`, and `SeatTile`. Four rows of nine with central aisle; row five `37..47` without aisle. White free, grey other-booked, green selected/own-confirmed (`✓`), non-color semantic labels, read-only Vendor mode.
- `widgets/`: shared presentation helpers (`ArenaBrandAppBarTitle`, `ArenaBrandMark`, `ArenaBusyButtonLabel`, `ArenaIconLabel`, `ArenaLoadingView`, `ArenaNoticeBanner`, `ArenaPosterBanner`, `ArenaShowDateRow`, `ArenaStatusPanel`).

Shared components never import Firebase, repositories, Cubits, or GetIt.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1/4/7; merged plan §§2/5/19.

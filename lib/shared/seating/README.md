# Shared seating

**Status: scaffold only.** No feature behavior/configuration is implemented here.

Own the one canonical 47-seat mapping and reusable seat-state UI. Four rows of nine with aisle; row five 37–47 without aisle. White free, grey other-booked, green selected/own-confirmed, with accessible labels. Vendor rendering is read-only.

Consume seat status/value inputs from feature Cubits, not Firebase or GetIt. Do not duplicate Show, Session, Booking or seat mapping in customer/vendor features. Future seat_layout.dart, seat_visual_status.dart and seat_map.dart names are illustrative; no Dart stubs. Shared widgets do not own booking transactions or route subscriptions.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1/4/7; merged plan §§2/5/19. These paths are relative to the full workspace; they are intentionally not public Markdown links.

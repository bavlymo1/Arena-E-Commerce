# Booking

**Status: Tier 1 atomic booking, live seat selection, and server missing-document recovery implemented.**

Implemented components:
- `domain/`: `Booking`, `BookingRequest`, `BookingResult`, `BookingRecovery`, and `BookingRepository` contracts.
- `data/repositories/firestore_booking_repository.dart`: all-or-none 4-document `runTransaction` (`shows/{id}`, `shows/{id}/sessions/{sessionId}`, `bookings/{id}`, paired `bookingEvents/{id}`), bounded optimistic retry on server-verified stale reads, and authoritative `Source.server` recovery.
- `presentation/cubit/`: `SeatSelectionCubit` (live session + own-seats reconciliation with `droppedByConflict`) and `BookingCubit` (stable pre-generated `bookingId`, duplicate-submit protection, recovery flow).
- `presentation/screens/`: `SeatSelectionScreen` (`Scaffold.bottomNavigationBar` summary, `PopScope` submit lock) and `BookingResultScreen` (confirmed reference, conflict map review, unresolved recovery check).

Dependencies: presentation -> domain contracts/models; data implements domain contracts. Domain has no Firebase/UI/GetIt imports.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§1–8; merged plan §§5/9–13.

# ArenaPass Oral Exam Q&A

Answers below reflect the implemented Android-only Tier 1 codebase in `e_commerce_project/`.

---

## Common Team Questions

### 1. Why `Cubit` (`flutter_bloc`) and not full `Bloc`?
Every ArenaPass user action maps 1-to-1 to a direct method call (`CustomerAuthCubit.login`, `ShowFormCubit.submit`, `SeatSelectionCubit.toggleSeat`, `BookingCubit.submit`, `BookingCubit.recover`, `VendorShowDetailsCubit.selectSession`, `VendorNotificationsCubit.retry`), without needing separate event classes, event transformers, or complex event-to-event pipelines. Using `Cubit` eliminates boilerplate while keeping `Equatable` immutable states, `BlocBuilder`, `BlocSelector`, `BlocListener`, `BlocConsumer`, and stream subscription cancellation in `close()`.

### 2. Why manual `get_it` + constructor injection + route-scoped `BlocProvider`?
- **Compile-time safety in features:** Every Cubit and repository (`DiscoveryCubit(ShowsRepository)`, `BookingCubit(repository: BookingRepository, ...)`, `FirestoreBookingRepository(_db, _auth, _shows)`) receives explicit constructor parameters, so unit and widget tests instantiate them directly with fakes without `GetIt`.
- **Zero codegen:** Manual registration in `lib/app/di/{shared,customer,vendor}_registration.dart` keeps the full dependency graph inspectable without `build_runner`.
- **Explicit lifecycle separation:** App-scoped repositories (`ShowsRepository`, `CustomerAuthRepository`, `BookingRepository`) are registered as singletons (`ShowsRepository` disposes via `dispose: (r) => r.dispose()`), whereas route-scoped Cubits are registered as factories (`registerFactory` / `registerFactoryParam`) and instantiated via `BlocProvider(create: ...)` inside router builders so `BlocProvider` owns and calls `close()` when a route pops. `GetIt` lookups never appear inside `lib/features/**` or `lib/shared/**`.

### 3. Why a Firestore transaction across `shows`, `sessions`, `bookings`, and `bookingEvents`?
`FirestoreBookingRepository._writeBooking` updates `shows/{showId}`, updates `shows/{showId}/sessions/{sessionId}`, creates `bookings/{bookingId}`, and creates `bookingEvents/{bookingId}` inside one `runTransaction` call:
1. **All-or-none seats:** A booking either reserves all requested seats across show/session/booking/event or writes zero documents.
2. **Contention serialization:** Because every booking for a show reads and writes `shows/{showId}` and `shows/{showId}/sessions/{sessionId}`, concurrent buyers serialize cleanly and Firestore retries stale reads. At ArenaPass scale (max 5 sessions x 47 seats = 235 seats/show), `shows.bookedCount` write contention is negligible.
3. **Exact event-time totals:** Writing `bookingEvents/{bookingId}` inside the transaction records atomic commit-time `slotTotal` and `showTotal` rather than summing separately timed listeners in the Vendor client.

### 4. Why does `sessions` `allow create` use `getAfter()` while `bookings` `allow get` checks `resource == null`?
- **`sessions` `allow create` (`getAfter`):** `FirestoreShowsRepository.addShow` writes `shows/{showId}`, `showImages/{showId}`, and `shows/{showId}/sessions/{slotId}` together in one atomic transaction before `shows/{showId}` exists in storage. Checking `showAfter(id)` (`getAfter`) inspects the post-commit parent show's `status == 'active'` and `sessionIds` manifest, while `!exists(/databases/$(db)/documents/shows/$(id))` ensures sessions can only be created at initial parent creation.
- **`bookings` `allow get` (`resource == null`):** During uncertain-response recovery (`BookingRepository.recover`), `FirestoreBookingRepository` reads `bookings/{bookingId}` from the server (`Source.server`). If the booking never committed, `resource` is `null`; without `resource == null || resource.data.customerUid == request.auth.uid`, evaluating `resource.data.customerUid` on a missing document would fail with `PERMISSION_DENIED`, making genuine absence indistinguishable from unauthorized access. Existing documents belonging to another UID still return `PERMISSION_DENIED`.

### 5. Why are seat owners stored in `bookings`, not on the `sessions` document?
All signed-in users (`allow read: if signedIn()`) read `shows/{showId}/sessions/{sessionId}` to see which seats `1..47` are occupied (`bookedSeats: [int]`). Storing customer UIDs inside `bookedSeats` would leak other customers' identities to every reader. Instead, `sessions` stores only anonymous integer seat numbers, while `bookings/{bookingId}` stores `customerUid` and is readable (`get`/`list`) only by its owner (`resource.data.customerUid == request.auth.uid`). `watchMySeats` queries `bookings` filtered by all four fields (`customerUid`, `showId`, `sessionId`, `status == 'confirmed'`).

### 6. Why are Security Rules needed if the Flutter client already validates seats and roles?
Client UI checks and repository guards can be bypassed by any caller hitting Firestore REST or SDK endpoints directly with an ID token. `firebase/firestore.rules` independently enforces:
- Role isolation (`customer()` requires `sign_in_provider == 'password'`; `vendorOwns()` requires an admin-provisioned `vendorDevices/{uid}` doc with `enabled == true`).
- Integer-only counters and seat arrays (`is int`, `validSeats` whitelist `1..47`), calendar date validation (`calendarDate`), 1–5 canonical `HHmm` slots (`checkManifest`), and paired atomic booking/event totals (`slotTotal`, `showTotal`, no `customerUid` in `bookingEvents`).

### 7. How does the vendor get notified (and under what conditions)?
- **Backend event producer:** Every customer booking transaction atomically writes `bookingEvents/{bookingId}` with `vendorId`, `showId`, `sessionId`, `seats`, `showTitle`, `slotTime`, `slotTotal`, `showTotal`, `kind: 'booked'`, and `createdAt`, indexed by `(vendorId ASC, createdAt DESC)` and restricted by Rules to `vendorOwns(resource.data.vendorId)`.
- **Client alerts & catch-up (`lib/features/vendor_notifications/`):** `VendorNotificationsCubit` listens to `FirestoreBookingEventsRepository`, seeds `NotificationWatermark` (`lastSeenEventAtMs` + `seenEventIdsAtWatermark` in `SharedPreferencesWatermarkStore`) silently on first launch, presents live individual or reopen grouped catch-up local alerts via `FlutterLocalAlertPresenter` (`flutter_local_notifications`), and saves the watermark strictly after alert presentation.
- **Supported Tier 1 condition:** Foreground or alive-in-background Firestore listener + catch-up on reopen without requiring Blaze/Cloud Functions; force-stopped remote push notifications require a funded trusted sender (Tier 2).

### 8. Why are poster images stored in Firestore instead of Cloud Storage?
Storing compressed JPEGs (`<= 150 KiB` target, enforced `<= 204,800` bytes in `validImage` and `FirestoreShowsRepository.addShow`) as binary `Blob` fields in `showImages/{showId}` works on Firebase's no-card Spark plan, whereas Cloud Storage requires Blaze billing. Separating `showImages/{showId}` from `shows/{showId}` keeps discovery feed reads small; `ShowsRepository.loadPoster` caches bytes in memory (up to 32 entries, cleared on logout via `clearPosterCache()`), and widgets bound GPU memory with `cacheWidth: 720`.

---

## Core Design & Edge-Case Questions ("What happens if...")

1. **Two customers act at once (race / contention):**
   - `SeatSelectionCubit._reconcileSnapshots()` receives live `watchSession` updates, strips newly taken seats from `selectedSeats` into `droppedByConflict`, and warns the user immediately.
   - If two customers submit concurrently, `runTransaction` serializes on `shows/{showId}` and `sessions/{sessionId}`. Because Rules evaluate stale optimistic writes before returning `ABORTED`, `FirestoreBookingRepository.confirm` performs up to 3 bounded outer retries on `permission-denied` **only** when server reads (`Source.server`, non-cached, no pending writes) confirm `booking` is absent and `show`/`session` revisions (`lastBookingId`, `updatedAt`) changed. Overlapping seat requests return `BookingConflict` with zero writes; disjoint concurrent requests both succeed with exact sequential `slotTotal` and `showTotal`.
2. **Response is lost or offline (`BookingUnconfirmed` / recovery):**
   - `BookingCubit` transitions to `BookingPhase.unconfirmed` retaining the pre-generated `bookingId`, disables `PopScope` / `newAttempt()`, and lets the customer tap **Check status** (`BookingCubit.recover` -> `BookingRepository.recover`).
   - `recover` reads `bookings/{bookingId}` with `GetOptions(source: Source.server)` and requires `!isFromCache && !hasPendingWrites` before returning `RecoveryConfirmed` or `RecoveryAuthoritativelyAbsent`. Cached/offline reads stay `RecoveryUnresolved`, preventing accidental duplicate bookings.
3. **What breaks if X is removed?**
   - **Remove `sessionIds` manifest (`checkManifest`):** A forged batch could create 0 or 6 sessions, bypassing the 1–5 session rule.
   - **Remove `lastBookingId` on show/session:** Rules could not resolve `getAfter(/bookings/$(after.lastBookingId))` to verify seat deltas and ownership inside the transaction.
   - **Remove `resource == null` in `bookings` `allow get`:** Recovering an uncommitted `bookingId` would throw `PERMISSION_DENIED` instead of returning `exists == false`.
   - **Remove `sign_in_provider == 'password'` in `customer()`:** An anonymous Vendor identity could book seats or read customer collections.
   - **Remove `status == 'deleting'` & 3-pair batch ceiling (`maxDeletePairsPerBatch = 3`):** Deleting children on an active show would break live bookings, and batching 4+ booking/event pairs can exceed Firestore's 20 uncached Security Rules access-call transaction/batch limit (3 pairs = `6 deletes * 3 calls = 18 <= 20`).
   - **Remove `clearPosterCache()` or `_sessionEpoch` on logout:** User B could briefly see User A's cached Cubit state, route stack, or stale poster cache on a shared device.

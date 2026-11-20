# ArenaPass Tier 1 Acceptance Evidence Log

Copy this template for each rehearsal or grading run. Record observed results only; never copy planned expectations into `Observed` without executing the step on the target build.

## Run Metadata

| Field | Value |
| :--- | :--- |
| **Date & Timezone** | `YYYY-MM-DD HH:MM` (e.g., `Africa/Cairo`) |
| **Git Commit / Tag** | `<commit-sha>` (`tier1-demo` candidate) |
| **Customer Build / App ID** | `com.arenapass.customer` (`<debug/release>`) |
| **Vendor Build / App ID** | `com.arenapass.vendor` (`<debug/release>`) |
| **Backend Target** | `<Spark project ID or local emulator host:ports>` |
| **Customer Device A** | `<model, Android version / API level>` |
| **Customer Device B** | `<model, Android version / API level>` |
| **Vendor Device (Primary)** | `<model, Android version / API level>` |
| **Vendor Device 2 (Enrollment)** | `<model, Android version / API level>` |
| **Pre-Run Firestore Quota Check** | `<reads/writes usage snapshot>` |
| **Notification Mode Tested** | `Tier 1 foreground/alive + launch catch-up` (or `Tier 2 FCM` if enabled) |
| **Operators / Narrator** | `<names / M1–M6 slots>` |

## Step-by-Step Evidence Log

| Step | Device | Account | Expected | Observed | Notification State | Screenshot/Video | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| S01 | Vendor | Enrolled `arena` | Direct launch to My Shows; add Show 1 (date, JPEG <= 200 KB, `14:00` + `19:00`). | | | | |
| S02 | Vendor / Customer A | `arena` / `c1` | Add Show 2; Customer A Discover shows Show 2 first (newest-first). | | | | |
| S03 | Customer A | `c1` | Register/login `c1`; search Show 1 title; open `19:00` 47-seat map. | | | | |
| S04 | Customer A | `c1` | Single-tap free seats; confirm booking; green `✓` seats; non-interactive. | | | | |
| S05 | Vendor | Enrolled `arena` | Notification 1 shows Show 1, `19:00` slot total, and show total. | | | | |
| S06 | Customer A | `c1` -> `c2` | Logout `c1`, login `c2`; Back stays on Login; `c1` seats are grey (`Booked`). | | | | |
| S07 | Customer B | `c1` | Login `c1`; open `19:00`; single-tap `12` & `13` (not submitted). | | | | |
| S08 | Customer A -> B | `c2` / `c1` | `c2` confirms `12` & `13`; Device B turns `12` & `13` grey live and drops selection with conflict banner. | | | | |
| S09 | Customer B | `c1` | Submit including `12`: rejected (`BookingConflict`); zero writes. | | | | |
| S10 | Vendor | Enrolled `arena` | Notification 2 arrives with combined atomic `slotTotal` and `showTotal`. | | | | |
| S11 | Vendor | Enrolled `arena` | Read-only map on `19:00` matches both customer screens; taps ignored. | | | | |
| S12 | Customer A + B | `c2` + `c1` | Concurrent race on same seat: 1 winner, loser multi-seat writes nothing. | | | | |
| S13 | Rules / CLI | Anon, `c1`, `c2` | Anonymous write, customer show/event forgery, and cross-owner booking read fail; missing recovery `get` allowed. | | | | |
| S14 | Vendor + Customer A/B | `c1`, `c2` -> `arena` | Kill Vendor, make rapid/multi-device bookings, reopen: grouped catch-up once; 2nd reopen has 0 replays. | | | | |
| S15 | Vendor + Customer A | `arena` + `c2` | Delete booked show: open Customer updates to unavailable cleanly; kill mid-delete -> reopen finishes cleanup. | | | | |
| S16 | Vendor | Enrolled `arena` | Add show via Gallery and again via Camera; both posters load on Customer. | | | | |
| S17 | Vendor 2 | Unenrolled -> `arena` | Shows UID + Copy Device ID; enroll in Console -> Retry -> `arena` shows load. | | | | |

## Artifact Rules

- Store screenshots/videos in an untracked/private evidence folder outside the public app repository; reference filenames only in `Screenshot/Video`.
- Never record customer passwords, Firebase tokens, or local machine absolute paths in this log.

## Issues & Follow-ups

| ID | Step | Symptom / Scope | Owner | Status |
| :--- | :--- | :--- | :--- | :--- |
| | | | | |

## Six-Member Signoff (`tier1-demo`)

| Slot | Member Name | Feature Walkthrough Verified | Signature / Date |
| :--- | :--- | :--- | :--- |
| M1 | | Vendor shows, images, delete & resume | |
| M2 | | Customer auth, discovery, details & cache clear | |
| M3 | | Flavors, DI (`get_it`), router & vendor access | |
| M4 | | 47-seat map, `SeatSelectionCubit` & live conflicts | |
| M5 | | 4-doc transaction, recovery & Security Rules | |
| M6 | | Booking events, local alerts, watermark & demo | |

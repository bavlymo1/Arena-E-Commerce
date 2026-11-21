# ArenaPass Tier 1 Acceptance Demo Script

This script operationalizes the ArenaPass Tier 1 live demonstration scenario across two physical Customer devices and one Vendor device (or approved emulator).

> **Evidence Rule:** Record actual observed behavior on real builds. Never substitute HTML prototype screenshots, unit tests, or fixture-only runs for live multi-device evidence. Keep passwords, tokens, and service-account credentials out of all logs and screenshots.

## 1. Environment & Device Setup

- **Customer Device A:** Android device with `com.arenapass.customer` installed (Customer build).
- **Customer Device B:** Second physical Android device with `com.arenapass.customer` installed (required to prove simultaneous real-time seat blocking; single-device account switching is insufficient).
- **Vendor Device (or approved emulator):** Android device with `com.arenapass.vendor` installed, pre-enrolled in `vendorDevices/{uid}` (`enabled: true`, `vendorId: 'arena'`), plus a **second unenrolled Vendor device** (or cleared app data) for Step 17.
- **Backend Target:** Live Firebase Spark project (for physical demonstration) or local Firebase Auth + Firestore Emulator Suite (for rehearsal).

### Day-Before Readiness Checks

1. Verify both APKs (`customer` and `vendor` flavors) are built from the same integrated commit and note the Git SHA and build variants.
2. Check Firebase Firestore Usage tab to confirm read/write quota headroom.
3. Verify test customer accounts exist (`c1` and `c2`, email/password provider) and primary vendor device UID is enrolled.
4. Clear stale rehearsal fixtures and prepare one clean show ready to create live (with poster image `< 150 KiB`).
5. On the Vendor device: grant notification permission (`POST_NOTIFICATIONS` on Android 13+), disable Do Not Disturb, and disable aggressive battery optimization.
6. Confirm Wi-Fi stability (keep mobile hotspot ready as backup) and keep Firebase Console open for live enrollment in Step 17.
7. Record a backup screen capture of one complete end-to-end passing run.
8. **Supported Tier 1 Notification Condition:** Foreground or alive-in-background Firestore listener + local notification (`lastSeenEventAtMs` + `seenEventIdsAtWatermark` launch catch-up). Force-stopped background push requires Blaze + FCM (Tier 2 Item 8) unless explicitly promoted.

## 2. Step-by-Step Scenario & Recording Matrix

Execute steps `S01` through `S17` in order. Capture each step into a copy of `EVIDENCE_LOG_TEMPLATE.md`.

| Step | Device | Account | Expected | Observed | Notification State | Screenshot/Video | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **S01:** Open Vendor app directly (pre-enrolled). Add Show 1 with date, poster image, `14:00` (2:00 PM) and `19:00` (7:00 PM) slots. | Vendor | Enrolled `vendorId: arena` | Vendor opens `My shows` directly with no login screen; show, JPEG poster (`<= 200 KB`), and both `14:00`/`19:00` sessions save atomically and show `0 / 47` booked. | _To record_ | Baseline watermark seeded; 0 spurious alerts on first launch. | _Link / filename_ | _PASS/FAIL_ |
| **S02:** Add Show 2 on Vendor. Open Customer app Discover feed. | Vendor -> Customer A | Vendor `arena` / Customer 1 | Show 2 saves cleanly; Customer A `Discover` displays Show 2 first (newest-first `createdAt` order) without requiring app restart. | _To record_ | N/A | _Link / filename_ | _PASS/FAIL_ |
| **S03:** Register or sign in Customer 1 on Device A. Search by Show 1 title, open details, choose `19:00` slot. | Customer A | `c1` (password auth) | Search filters loaded shows case-insensitively; Show Details displays poster, date, and `19:00` chip (`47 seats left`); tapping opens 47-seat map (4x9 + aisle, row 5 = 37..47). | _To record_ | N/A | _Link / filename_ | _PASS/FAIL_ |
| **S04:** Customer 1 taps free seats (e.g., `1` and `47`) directly on map and confirms booking. | Customer A | `c1` | Each seat toggles on first tap (no zoom trap); confirm writes atomic 4-doc transaction; `BookingResultScreen` shows `Booking confirmed` + reference ID; returning to `19:00` shows seats `1✓` and `47✓` green and non-interactive (`2 / 47` booked). | _To record_ | Triggers Notification 1 to Vendor. | _Link / filename_ | _PASS/FAIL_ |
| **S05:** Verify Vendor notification 1 and Updates row. | Vendor | Enrolled `arena` | Vendor receives local alert (and Updates list item) showing Show 1 title, `19:00` slot total (`2/47 booked`), and show total (`2 booked`). | _To record_ | Alert 1 delivered; unread badge & watermark advanced. | _Link / filename_ | _PASS/FAIL_ |
| **S06:** Log out Customer 1 on Device A; sign in Customer 2 on Device A. | Customer A | `c1` -> `c2` | Logout clears poster cache and protected routes, returning to Login (Android Back stays on Login); Customer 2 sees seats `1` and `47` as grey `Booked` (zero `c1` green own-seat leakage). | _To record_ | N/A | _Link / filename_ | _PASS/FAIL_ |
| **S07:** On Device B, sign in Customer 1, open Show 1 `19:00`, single-tap seats `12` and `13` without submitting. | Customer B | `c1` | Seats `12` and `13` show green `Selected` locally on Device B (`1` and `47` show green `✓` as `c1`'s confirmed seats). | _To record_ | N/A | _Link / filename_ | _PASS/FAIL_ |
| **S08:** On Device A, Customer 2 confirms seats `12` and `13`. Observe Device B live. | Customer A -> Customer B | `c2` / `c1` | Device A confirms `12` and `13`; within seconds Device B live listener updates `12` and `13` to grey `Booked` (unselectable), drops them from local selection, and displays the conflict banner. | _To record_ | Triggers Notification 2 to Vendor. | _Link / filename_ | _PASS/FAIL_ |
| **S09:** Submit a booking from Device B that includes seat `12` (stale/raced request). | Customer B | `c1` | Transaction rejects the entire request (`BookingConflict` / `Not booked`); conflicting seat `12` listed; zero partial seats written to Firestore. | _To record_ | No duplicate or partial booking event emitted. | _Link / filename_ | _PASS/FAIL_ |
| **S10:** Verify Vendor notification 2 totals. | Vendor | Enrolled `arena` | Vendor receives Notification 2 with updated atomic slot total (`4/47`) and show total (`4 booked`) reflecting both `c1` and `c2` bookings. | _To record_ | Alert 2 delivered; both totals exact. | _Link / filename_ | _PASS/FAIL_ |
| **S11:** Open Show 1 `19:00` on Vendor Show Details. | Vendor | Enrolled `arena` | Vendor read-only seat map displays seats `1, 12, 13, 47` as grey `Booked` (`4 / 47`), matching both Customer devices; tapping any seat does nothing. | _To record_ | N/A | _Link / filename_ | _PASS/FAIL_ |
| **S12:** Two customers (`c1` on B, `c2` on A) race concurrently for the same seat (and a multi-seat overlapping request). | Customer A + Customer B | `c2` + `c1` | Exactly one transaction succeeds; the losing request writes zero seats, zero booking docs, and zero events (all-or-none). | _To record_ | Exactly 1 new notification for the winning booking. | _Link / filename_ | _PASS/FAIL_ |
| **S13:** Verify forged-write & identity isolation checks (Rules deny suite / emulator or probe). | Rules / Test Harness | Anonymous, `c1`, `c2` | Anonymous (vendor) direct session write fails; customer direct show/event forgery fails; customer read of another owner's `bookings/{id}` fails (`PERMISSION_DENIED`); missing `bookings/{missingId}` recovery `get` succeeds with `exists == false`. | _To record_ | Zero forged events appear on Vendor. | _Link / filename_ | _PASS/FAIL_ |
| **S14:** Kill Vendor app. Book from Customer A and Customer B (including rapid back-to-back bookings). Reopen Vendor app, then reopen a second time. | Vendor + Customer A/B | `c2`, `c1` -> Vendor | First Vendor reopen delivers one grouped catch-up alert covering all missed bookings via `lastSeenEventAtMs` + `seenEventIdsAtWatermark`; second reopen produces zero duplicate replays. | _To record_ | Grouped catch-up fired once; 0 replays on 2nd launch. | _Link / filename_ | _PASS/FAIL_ |
| **S15:** Delete a booked show on Vendor while Customer A has `ShowDetails` open; kill Vendor app mid-delete, then reopen. | Vendor + Customer A | Enrolled `arena` + `c2` | Marking `deleting` hides show from `Discover`, transitions open Customer `ShowDetails`/`SeatSelection` cleanly to `Show unavailable` (no permission crash), and blocks new bookings; relaunching Vendor resumes cleanup (`resumeDeletes`), removes paired `bookings`/`bookingEvents`/`sessions`/`showImages`, and deletes parent last. | _To record_ | No stale deletion crash; cleanup completes. | _Link / filename_ | _PASS/FAIL_ |
| **S16:** Repeat Vendor `Add show` image acquisition once via Gallery (`ImageSource.gallery`) and once via Camera (`ImageSource.camera`). | Vendor | Enrolled `arena` | Both Gallery and Camera previews render, stay under `200 KB` JPEG, upload cleanly, and display in Customer `Discover` and `ShowDetails` (note Android `retrieveLostData()` behavior if activity recreated). | _To record_ | N/A | _Link / filename_ | _PASS/FAIL_ |
| **S17:** Install Vendor app on an unenrolled second Android phone -> enroll UID in Console -> tap `Retry`. | Vendor 2 (unenrolled) | New anonymous UID | Launches to `AccessNotEnrolled` showing UID + working `Copy Device ID`; after adding `vendorDevices/{uid}` (`enabled: true`, `vendorId: 'arena'`), tapping `Retry` loads existing `arena` shows immediately. | _To record_ | N/A (or catch-up seeded at initial snapshot). | _Link / filename_ | _PASS/FAIL_ |

## 3. Tier 1 Exit Signoff Criteria

1. All steps `S01`–`S17` marked `PASS` with attached device/account/screenshot evidence in the completed run log.
2. Flutter checks (`dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`) and Firestore Security Rules allow/deny/budget suite green at the demonstrated commit.
3. Six-member team signoff recorded and release/demo commit tagged `tier1-demo` before beginning any Tier 2 extension work.

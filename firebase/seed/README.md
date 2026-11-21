# ArenaPass Emulator Seed Script

Node 22, zero-dependency seed script for the local Firebase Auth and Firestore Emulators only.

## Safety Guards

`seed.mjs` refuses to run (throws / exits non-zero before any HTTP request) unless **all** of the following hold:

- `FIREBASE_AUTH_EMULATOR_HOST` is set to `127.0.0.1:<port>` or `localhost:<port>`.
- `FIRESTORE_EMULATOR_HOST` is set to `127.0.0.1:<port>` or `localhost:<port>`.
- Project ID (`FIREBASE_PROJECT_ID`, `GCLOUD_PROJECT`, or `GOOGLE_CLOUD_PROJECT`, defaulting to `demo-arenapass`) starts with `demo-`.

There is no fallback to live Firebase endpoints.

## What Gets Seeded

- **Vendor device allowlist:** `vendorDevices/test-vendor-uid` (`enabled: true`, `vendorId: 'arena'`).
- **Password customers:** `c1@test.dev` and `c2@test.dev` in Auth Emulator (password `Local-demo-47`) plus `users/{uid}` profile docs.
- **Three active shows (`vendorId: 'arena'`):**
  - `seed-show-skyline-jam` (`Skyline Jam`, `2026-12-20`, slots `14:00` / `19:00`; `19:00` pre-booked seats `[1, 2, 3, 4, 5]` by `c1@test.dev` with `shows.bookedCount = 5`, `bookings/seed-booking-1`, and `bookingEvents/seed-booking-1`).
  - `seed-show-kingdom-clash` (`Kingdom Clash`, `2026-12-21`, slots `14:00` / `19:00` / `21:30`).
  - `seed-show-midnight-drift` (`Midnight Drift`, `2026-12-22`, slots `16:00` / `20:00`).
- **Posters:** `showImages/{showId}` binary `bytesValue` blobs loaded from `assets/demo/*.jpg` (`< 150 KiB`), `mimeType: 'image/jpeg'`, with integer `width` and `height`.

The first run creates the fixture documents and an emulator-only marker in one atomic commit. Later runs preserve rehearsal changes, including bookings and deleted shows. Use a fresh disposable emulator to restore the original fixtures. An older or partial seed with colliding document IDs fails without overwriting Firestore records.

## Commands

Run from `e_commerce_project/`:

```powershell
# Unit & safety-guard tests (offline, no emulator needed)
node --test firebase/seed/seed.test.mjs

# Seed a clean one-shot Auth + Firestore emulator session
firebase --config firebase.json --project demo-arenapass emulators:exec --only auth,firestore "node firebase/seed/seed.mjs"
```

If running against an already-started emulator on custom ports, set `FIREBASE_AUTH_EMULATOR_HOST` and `FIRESTORE_EMULATOR_HOST` in your shell before running `node firebase/seed/seed.mjs`.

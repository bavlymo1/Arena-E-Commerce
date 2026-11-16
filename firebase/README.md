# Firebase rules and test harness

**Status: P1-04A emulator harness baseline.** Firestore rules deliberately deny all client reads and writes. No production booking/access rules or application Firebase binding are implemented. Do not deploy this baseline.

`firestore.rules` is the fail-closed baseline; `firestore.indexes.json` is empty until actual queries are implemented. `rules_test/` contains the Node test harness. Its successful tests prove emulator wiring and baseline denial only, not feature acceptance, transaction safety or call budgets.

## Run locally

Use Node 22, Java 21 and the installed Firebase CLI (verified with 15.35.0). From `firebase/rules_test/`:

```powershell
npm ci
npm run test:emulator
```

The script explicitly selects the non-existent demo project `demo-arenapass`, reads the app-root `firebase.json`, starts only Firestore on `127.0.0.1:8180`, runs tests and stops the emulator. Port 8180 avoids a known local service on the default port 8080. No login, real project, `.firebaserc`, accounts or deployment is needed. `npm test` requires an already-running Firestore emulator at that exact loopback endpoint and fails clearly if unavailable. Auth identities are mocked by the rules-unit-testing API; the Auth emulator is reserved on loopback port 9099 for later integration work, not needed by these tests. All fixtures are cleared between tests and during teardown, and test contexts are cleaned up.

The installed Node 22 requires `@firebase/rules-unit-testing` 5.x (resolved 5.0.2) with Firebase JS 12.x (resolved 12.19.0). Version 6.0.0 requires Node >=24.12.0 and is intentionally not adopted. Exact versions and transitive dependencies are locked in `rules_test/package-lock.json`.

## Verified baseline

On 2026-11-16, Node 22.23.4, Java 21.0.12, Firebase CLI 15.35.0 and Firestore emulator 1.22.0 ran all **24 baseline tests successfully**. The command below also verified that the Auth emulator starts and stops; tests still use mocked Auth contexts, so this does not prove email/password sign-in:

```powershell
firebase --config ../../firebase.json --project demo-arenapass emulators:exec --only auth,firestore "npm test"
```

An explicit non-loopback `FIRESTORE_EMULATOR_HOST` was rejected before emulator access. The initial run exposed an invalid cleanup API; the suite now uses the resolved SDK's `clearFirestore()` and `cleanup()`. Debug logs, emulator downloads and node_modules are local artifacts and must remain untracked.

## Remaining P1-04 work

Replace the deny-all baseline only alongside reviewed allow/deny tests for vendor enrollment, owner privacy and authoritative missing-document recovery; atomic add-show and four-document booking writes; forged fields/counters/events; concurrency; restart-safe deletion; and measured Rules access-call budgets. Missing booking reads are denied now, so application recovery is not ready. Emulator tests cannot prove deployed configuration or physical-device integration.

Official API references: [Rules test environment and cleanup](https://firebase.google.com/docs/rules/unit-tests), [Firestore rules emulator testing](https://firebase.google.com/docs/firestore/security/test-rules-emulator), [demo project isolation](https://firebase.google.com/docs/emulator-suite/connect_firestore).

Rules independently constrain writes and privacy; booking/cancellation/admission each have one authoritative transaction writer, with shared show/session/booking/ticket invariants. Test missing-document recovery and deny cross-UID access. UI is not authorization. Harness fixtures target emulators with explicit project configuration and teardown. Trusted notification sender code is separate and requires backend approval; no Functions setup, server credentials, deployment or billing here.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§7/8; merged plan §§10–14/19; Tier 2 §5. These paths are relative to the full workspace; they are intentionally not public Markdown links.

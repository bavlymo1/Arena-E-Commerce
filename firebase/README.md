# Firebase rules and test harness

**Status: P1-04B candidate, not deployment ready.** The feature rules and expanded matrix replace the deny-all candidate on this task branch. The latest local run passed all 74 tests using the explicitly guarded JavaScript transaction writer described below. This does not prove that bare SDK retries or a FlutterFire repository behave the same way. Independent schema gaps below remain open. No cloud project or application Firebase binding is configured.

The candidate enforces enrolled vendor writes, password-provider customer ownership, atomic show/image/session creation, paired four-document booking, exact seats/counters/events, owner-only reads, server missing-document recovery, deleting-state authorization and reciprocal booking/event deletes. Calendar dates are validated beyond their string format. `firestore.indexes.json` declares the planned active-show and vendor-event ordered feeds; emulator tests do not prove deployed index readiness.

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

## Access-call accounting

These are static worst-case uncached counts, separate from observed emulator success. Each document operation stays within 10 and each supported atomic request within 20:

| Operation | Per-write calls | Uncached total |
| --- | --- | --- |
| Create show + image + five sessions | show2, image3, each session3 | 20 |
| Four-document booking | show3, session3, booking4, event3 | 13 |
| Delete three booking/event pairs | each record3 | 18 |
| Delete five sessions + image | each record2 | 12 |
| Remove parent after image absent | parent2 | 2 |

Four-pair deletion passed with emulator caching, but its uncached count is24. Application cleanup must use at most three pairs per batch for the guaranteed budget; no cleanup repository is implemented here. The booking show write checks that its booking did not already exist, preventing counter replay.

## Disjoint contention diagnosis and verified writer contract

On 2026-11-18, the original unmodified strict disjoint-booking test reproduced `permission-denied` on Firestore emulator 1.22.0. Earlier candidate evidence also reproduced it on 1.21.0. Coverage showed a stale optimistic write failing the session rule's exact before/after counter and seat-size checks. The JavaScript SDK sends document `updateTime` preconditions, but the emulator evaluates these Rules before returning an optimistic conflict. Its transaction runner does not automatically retry the permanent permission-denied code. A trial removing only a redundant cross-document counter check still failed the necessary seat-delta check; that trial was reverted. The candidate Rules and their permissions remain unchanged.

This is classified as a **transaction-writer retry refinement for the optimistic transaction/Rules evaluation interaction**, not a Rules relaxation or a false success assertion. The Node harness writer now:

1. Snapshots the original booking ID, owner/context and requested seats for the logical request.
2. Lets `runTransaction` perform its normal bounded retries. After a permission denial, it considers a fresh SDK invocation only when the failed callback recorded its show/session input snapshots.
3. Uses that same customer's `getDocFromServer` permissions to read the booking, show and session. Every input/evidence snapshot must be server-sourced without pending writes. The booking must be absent, both context documents must still exist, and at least one recorded input must differ from current server data.
4. Re-enters the whole transaction with the exact same ID and immutable seats, at most three SDK invocations total. The SDK's own finite retry policy still applies inside each invocation. Every new write must pass the unchanged Rules again.
5. Preserves the failure when evidence is unavailable, cached/pending, unchanged, another owner's booking is forbidden, the booking already exists, or the bound is reached. It does not treat failure as a new logical request, read forbidden events, use admin bypass for retry evidence, or claim confirmation from absence alone.

Only the test writer implements this contract. There is no FlutterFire data repository yet; its uncertainty mapping, account-switch guards, metadata evidence and same-ID retry behavior must be separately implemented and tested before live use. The observer used to schedule deterministic contention and forged payloads is harness-only, not a production callback side effect. Admin access appears only in fixture setup and independent postcondition assertions, never in the writer's retry path.

The unchanged strict disjoint assertions now force both clients to read before either writes, prove a callback was rerun, and require both stable booking/event IDs plus exact final/event-time totals. Six added tests cover unchanged permission denial without retry, forged payload rejection despite changed inputs, the three-invocation bound, immutable original seats, and existing own/other-owner references. The original overlapping-seat/all-or-none and forged-write tests remain intact.

Verification: Node 22.23.4, Java 21.0.12, Firebase CLI 15.35.0, Firestore emulator 1.22.0, demo-arenapass and loopback 8180. Eight targeted concurrency/retry regressions passed, then the full matrix passed **74/74** (15.3s test runtime), exit 0 and clean emulator shutdown. Syntax and whitespace checks passed; no package version, cloud configuration or Rules predicate changed in this retry refinement.

Primary references: [Firestore transaction guarantees](https://firebase.google.com/docs/firestore/manage-data/transactions), [optimistic mobile/web transactions](https://firebase.google.com/docs/firestore/transaction-data-contention), [REST error guidance](https://firebase.google.com/docs/firestore/use-rest-api), [JavaScript transaction runner source](https://github.com/firebase/firebase-js-sdk/blob/main/packages/firestore/src/core/transaction_runner.ts). The installed SDK source was inspected alongside the local reproduction; the bare permission-denied error is not generally classified as retryable.

## Explicit acceptance gaps

- The approved schema contains no session manifest/count. Rules cannot enforce at least one and at most five child sessions at initial creation. A test demonstrates zero and six sessions are accepted; creation of later sessions is denied. Do not claim client validation closes this forged-write gap.
- Rules cannot enumerate arbitrary children. A test demonstrates that an enrolled vendor can delete a deleting parent after removing its image while sessions/bookings/events remain. The future repository must clean children first; stronger independent parent-last authorization needs an agreed schema/contract change before deployment.
- Bare optimistic SDK transactions can still produce permission-denied before their stale-write precondition is reported as a retryable conflict. The local guarded Node writer passes the strict both-success test without changing Rules. It is not a deployed or FlutterFire implementation; preserve the evidence gates above rather than blindly retrying permission failures.
- The local harness mocks authentication and does not prove sign-in, deployed Rules/indexes, APK Firebase configuration, live automatic transaction retries, calendar cutoffs, image decodability, or restart-safe deletion. MIME/size validation cannot decode JPEG content.

The task remains in progress. Retain uncertainty mapping and authoritative recovery at the application boundary. A permission-denied response is not evidence that a logical booking reference is absent.

Official API references: [Rules test environment and cleanup](https://firebase.google.com/docs/rules/unit-tests), [Firestore rules emulator testing](https://firebase.google.com/docs/firestore/security/test-rules-emulator), [demo project isolation](https://firebase.google.com/docs/emulator-suite/connect_firestore).

Rules independently constrain writes and privacy; booking/cancellation/admission each have one authoritative transaction writer, with shared show/session/booking/ticket invariants. Test missing-document recovery and deny cross-UID access. UI is not authorization. Harness fixtures target emulators with explicit project configuration and teardown. Trusted notification sender code is separate and requires backend approval; no Functions setup, server credentials, deployment or billing here.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§7/8; merged plan §§10–14/19; Tier 2 §5. These paths are relative to the full workspace; they are intentionally not public Markdown links.

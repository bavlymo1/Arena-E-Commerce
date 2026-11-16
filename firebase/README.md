# Firebase rules and test harness

**Status: scaffold only.** No feature behavior/configuration is implemented here.

Intended files: firestore.rules and firestore.indexes.json; rules_test/ will own the Node allow/deny/call-budget harness. These configuration files are deliberately absent until valid reviewed content exists.

Rules independently constrain writes and privacy; booking/cancellation/admission each have one authoritative transaction writer, with shared show/session/booking/ticket invariants. Test missing-document recovery and deny cross-UID access. UI is not authorization. Harness fixtures target emulators with explicit project configuration and teardown. Trusted notification sender code is separate and requires backend approval; no Functions setup, server credentials, deployment or billing here.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §§7/8; merged plan §§10–14/19; Tier 2 §5. These paths are relative to the full workspace; they are intentionally not public Markdown links.

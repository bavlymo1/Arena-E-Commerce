# Integration scenarios

**Status: scaffold only.** No feature behavior/configuration is implemented here.

Future *_test.dart scenarios exercise cross-feature behavior through app boundaries: two-app startup, atomic booking races, deletion restart, UID isolation and pending/offline recovery. Reuse canonical models and constructor/composition boundaries; do not introduce another data writer. Each test owns emulator/fixture/subscription teardown. Real scanning, notifications and process loss require separate device evidence. No tests/dependencies/config added now.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §8; merged plan §§19/21; Tier 2 §5. These paths are relative to the full workspace; they are intentionally not public Markdown links.

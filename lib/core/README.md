# Shared infrastructure

Only genuinely shared formatting helpers belong here (`lib/core/formatting/date_time_formatting.dart`); do not duplicate feature models or encode unapproved business cutoffs here.

`core/` has zero dependency on feature presentation or `GetIt` lookup.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §4; merged plan §5.

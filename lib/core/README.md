# Shared infrastructure

**Status: scaffold only.** No feature behavior/configuration is implemented here.

Only genuinely shared errors and formatting belong here; do not duplicate feature models or encode business cutoffs in formatting. core/storage owns shared SQLite connection open/close, schema versions and ordered migrations, registered/injected by app composition.

Ticket-cache operations belong to tickets/data; pending persistence/recovery belongs to booking/data. Both use the injected shared connection; neither closes it on route disposal or migrates it independently. Preserve unresolved pending requests under original UID across logout; display-cache removal is a separate tickets concern. Core has no dependency on feature presentation or GetIt lookup. Future snake_case files may include app_exception.dart and local_database.dart; add only with actual implementations.

Private workspace references (not copied into the app export): `plan/FEATURE_ARCHITECTURE.md` §4 storage ownership; merged plan §5; Tier 2 Items 6–7. These paths are relative to the full workspace; they are intentionally not public Markdown links.

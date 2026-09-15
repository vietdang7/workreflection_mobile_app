# Core restart review handoff

Current edits are in-progress, not accepted or fully tested. Do not reset them. Read SPEC, INTERFACE, DECISIONS and pending messages.

Immediate priority: user requested deeper architecture/logic review before further broad edits. Refreshed graph at 03:17:56 UTC has 9463 nodes, 23101 edges, 4504 embeddings; current edits may not be indexed. Rerun query/context/impact on actual changed symbols, document d=1 caller coverage and minimal compatible path in CORE-IMPACT.md. Send findings before broad implementation resumes.

Worktree changed core symbols now in wr_content, wr_episode, wr_intelligence, wr_career_health, wr_deep_interpretation, wr_situation_picker plus assets and new importer/migration. Review necessity of CareerMemoryEvent/PatternCount changes (CRITICAL); compatibility-preserving fields do not alone prove semantic safety.

Required review points:
- Explicit v2 pillar/subgroup/mood/valence; no implicit dimensions overriding v2; unknown/custom excluded safely.
- Canonical assets override stale remote text/classification without requiring deployed schema migration or deleting history.
- Supplied JS exact content preserved; 72 real+other, 48/24, 12 per mood. C1-10 literal title suffix is editorial source issue, preserve/report.
- R2 subgroup+valence, never pillar grouping. R4 <=20% includes zero per mission SPEC; do not retain a positive-count guard. R5 mixed-valence fixture reaches fallback without prior matches.
- Picker no forced anchor, first-ten no-repeat; exhausted pool fallback documented.
- resolveStoryFor must not show unrelated story for unknown IDs.
- Historical SQL migrations immutable; new migration retires old rows/reactivates canonical records; preserve FKs/user history.
- Generic old *-sit-* test IDs differ from exact eleven prohibited IDs; keep meaningful history safety tests, migrate current-catalog fixtures deliberately.

UI owns features and two extra files test/logic/wr_chat_starters_test.dart, test/screenshots/wr_customer_case_test.dart. Coordinate model API with UI. QA stays gated until all integrated SPEC Commands pass. Lead must run final full reindex with embeddings and detect_changes.

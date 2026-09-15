# v2 integration contract

## Ownership
- core: lib/core/**, assets/**, supabase/**, scripts/**, test/core/**, test/data/**. Own data import, repositories/persistence, picker/counting, Deep Reading pure logic and their tests.
- ui: lib/features/**, lib/l10n/**, test/features/**, remaining top-level widget tests. Own providers and screens, flow integration, release demo cleanup, widget tests.
- lead: .agent-team coordination/review/memory. QA gets independent tests/report after green integration.
- Request ownership before touching another domain. No dependency additions without lead approval.

## Public contracts
Preserve existing named signatures where possible:
- pickSituationChoices({required List<WrSituation> all, Mood? mood, List<String> recentIds = const [], int count = 5, Random? random}) returns real choices only. UI appends custom option. No mandatory anchor. Mood.stressed maps stress, Mood.okay maps ok.
- WrSituation retains code, text/textVi, pillarCode, scaDimension compatibility. Add explicit String? subgroup, String? mood and explicit v2 valence using existing WrValence enum. Runtime classification uses explicit v2 data, not dimension inference; unknown/custom must be excluded. Core determines backward-compatible constructor details and sends UI exact additions before use.
- Existing buildDeepInterpretation signature and DeepInterpretation/DeepFacts public fields remain compatible; add fields only as needed, message UI. rung, leadText, situation rankings and actual trend getters drive layout. Main lead must be concrete; optional group details collapsed.
- pillarTally must distinguish all-valence appearance/classified denominator from challenge-only dominance/gap denominator. Preserve current public API where possible; communicate additions.
- Canonical v2 catalog must override stale remote catalog semantics without deleting persisted history. Unknown IDs safely excluded from classification and picker history.

## Shared requirements
Read all five authoritative inputs before implementation; extracted Word text in .agent-team/inputs is provided for convenience. JS remains exact editorial source. AI note-reading stays future-phase only.
Run GitNexus CLI with --repo appmobileworkreflection; MCP unavailable. Impact-check every existing modified symbol and report HIGH/CRITICAL before editing. Index has 4503 embeddings: preserve on analyze.
Tests with obsolete behavior must be updated to v2 semantics, not merely removed. Report every logic/spec conflict with evidence in worker report.

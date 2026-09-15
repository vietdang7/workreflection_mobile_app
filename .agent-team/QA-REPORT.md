# Independent release QA — 14 September 2026

Status: **QA GREEN — 0 BLOCKER, 0 MAJOR, 0 MINOR open.** All owner fixes independently verified; historical reproduction evidence retained below. No production edits, commit, deployment, or remote history mutation by QA.

## Findings — historical reproduction and final closure

Descriptions and line references in the initial observations below refer to the pre-fix worktree. All findings are closed; subsequent retests describe the final state.

1. **MAJOR / FIXED — R3 displays the wrong denominator for its challenge comparison.** `lib/core/logic/wr_deep_interpretation.dart:649` sets `_deepGapBody` total to `classifiedTotal`, while its numerator at line 690 is `pillarCount[dom]`, which is challenge-only. SPEC §5–6 / D7–D8 require challenge-only gap math and matching displayed denominators. Independent canonical fixture has 8 S challenges / 12 challenges, plus 6 positives, and produces **“8 trong 18”**. `test/qa/v2_release_qa_test.dart:128` fails expecting “8 trong 12”. Retest: `_deepGapBody` now uses `f.challengeTotal`; independent `flutter test test/qa/v2_release_qa_test.dart` passes **8/8, exit 0** (`/tmp/wr-qa-r3-retest.log`). Arithmetic finding closed. At this intermediate retest, wording still used generic recent look-backs; this was subsequently corrected and closed under finding 5.

2. **MAJOR / FIXED — malformed persisted recent history crashes the picker.** `lib/core/models/mobile_profile.dart:70` creates a lazy `.cast<String>()`; `lib/features/wr/wr_providers.dart:573` returns it without normalization; `lib/core/logic/wr_situation_picker.dart:104` consumes it with `take(10).toSet()`. A null member throws `type 'Null' is not a subtype of type 'String' in type cast` after the provider's try/catch has completed. PostgreSQL `text[]` permits null members; the column definition at `supabase/migrations/20260728000003_wr_growth_opportunity_v1_6.sql:20` does not prohibit those. SPEC §2/D5 require safe malformed/unknown history reads. `test/qa/persisted_history_qa_test.dart:19` reproduces the failure. Retest: eager `whereType<String>().toList(growable:false)` removes malformed members while preserving string order and unknown string IDs; no remote deletion. Independent `flutter test test/qa/persisted_history_qa_test.dart`: **1 passed, 0 failed, exit 0** (`/tmp/wr-qa-history-retest.log`). Finding closed for malformed list members.

3. **MAJOR / FIXED — D10 display em-dash scan fails.** Nine display-string literals retain U+2014 at `lib/core/logic/wr_iap_renewal.dart:103`, `lib/core/logic/wr_user_guide.dart:389`, `:696`, `:868`, `lib/core/data/wr_iap_repository.dart:359`, `lib/features/wr/presentation/wr_growth_skills_screen.dart:557`, `:559`, and `lib/features/wr/presentation/wr_journey_narrative_screen.dart:145`, `:148`. SPEC D10 / changelog B4 explicitly prohibit these display strings. The additional literal at `lib/core/logic/wr_skill_formation.dart:211` is input parsing and is not a display finding. Independent post-fix string-literal scan: **zero display U+2014 matches**, only the parsing delimiter at `wr_skill_formation.dart:211` remains. Finding closed.

4. **MAJOR / FIXED — pending comparison content is a paragraph, not one line.** `lib/features/wr/presentation/wr_sca_deep_dive_screen.dart:393` renders the waiting text without `maxLines` or overflow treatment; `lib/core/logic/wr_deep_interpretation.dart:1519` supplies a long combined explanation. Independent 375px phone widget test measures **126px** in the test font rather than one line (22px maximum at the configured style): `test/qa/deep_layout_qa_test.dart:58`. SPEC §7/D9 and source §6 require no more than one line at the bottom. The author test at `test/features/wr_sca_deep_dive_screen_test.dart:287` checks only that one widget exists, not its physical lines. The initial review also identified the separate no-Self-Check paragraph at `wr_sca_deep_dive_screen.dart:349`, which coexists with the footer. Partial retest: scored Self-Check footer now passes **1/1** (`/tmp/wr-qa-layout-retest.log`). New independent `flutter test test/qa/deep_no_self_check_qa_test.dart` fails **0 passed/1 failed** at line 52: no-Self-Check invitation remains **144px** tall at 375px width (24px single-line maximum), although duplicate footer is gone and invitation button remains. Final owner correction adds one-line ellipsis to the invitation while preserving its key and action button. Independent combined `flutter test test/qa/deep_layout_qa_test.dart test/qa/deep_no_self_check_qa_test.dart test/features/wr_sca_deep_dive_screen_test.dart`: **10 passed, 0 failed, exit 0** (`/tmp/wr-qa-layout-final.log`). Both scored/no-Self-Check phone layouts pass; finding closed.

5. **MINOR / FIXED — R2 does not rotate variants.** `lib/core/logic/wr_deep_interpretation.dart:1024` selects the only R2 paragraph solely by member count and never reads `variantSeed`. SPEC §6 requests deterministic variant rotation. Source §5.2 provides two templates with different member counts, so adaptation needs an explicit editorial decision to avoid dropping a member or fabricating a third. R3 also retains v1 wording and appends the concrete name after abstract text (`:633`), despite SPEC's concrete-first preference. Post-fix: R2 now rotates deterministically by `variantSeed % 2` while retaining actual member names/count; R3 concrete sentence now precedes abstract body. Independent combined deep + QA run: **60 passed, exit 0** (`/tmp/wr-qa-wording-retest.log`). Those two subitems are fixed. Historical intermediate MINOR observation: R3 body used the challenge denominator but still called the population generic recent look-backs/entries instead of explicitly challenge records; source inspection then confirmed no displayed challenge qualifier in R3. Final TASK7 retest: all actual R3 branches now explicitly describe challenge reflections in Vietnamese and English; finding closed. `_safeRecentSituationIds` also guards the entire field with `raw is List`, preserving eager string filtering.

## Initial executed evidence — failures subsequently fixed

The failure counts below preserve the original reproductions, not the current status. Final passing results appear in the closure notes and final evidence sections.

- `flutter test` independently executed before QA additions: **2511 passed, 27 skipped, exit 0**. Log: `/tmp/wr-qa-full-suite.log`.
- `flutter test test/qa/v2_release_qa_test.dart`: **7 passed, 1 failed**. The six mood tests each simulate ten selections across 100 random seeds: 600 runs / 6000 selections, fresh choices, 3 same-mood + 2 same-valence other-mood, five distinct codes. Unicode historical-label preservation, merge idempotency, and classified/challenge/positive denominator partition pass. R3 test fails as finding 1. Log: `/tmp/wr-qa-adversarial.log`.
- `flutter test test/qa/persisted_history_qa_test.dart`: **0 passed, 1 failed**, finding 2. Log: `/tmp/wr-qa-history.log`.
- `flutter test test/qa/deep_layout_qa_test.dart`: **0 passed, 1 failed**, finding 4. Log: `/tmp/wr-qa-layout.log`.
- `node scripts/audit_retired_situation_ids.js`: **PASS retired=11 active=72 custom=1 activeRetired=0**.
- Exact `s.dim`, `json['dim']`, eleven retired-ID scan across `lib`, `test`, `assets`: **zero matches**. Historical migrations and the explicit audit script are intentionally separate.
- Independent read-only Node VM comparison with the supplied JS: **73 source/asset rows, 72 exact paired stories, 873 situation fields checked, zero differences**. All editorial/classification fields retained. No importer regeneration was run.
- Dart string-literal scan excluding comments: ten U+2014 literals, nine display findings above and one parsing-only exemption. JSON `aha`-field scan: **zero Trust matches**.
- `git diff --check`: clean at initial review. `pubspec.yaml` adds only the two canonical asset declarations; no package dependency additions.

## D5–D11 / architecture review

- D5: twelve named library tests cover counts, valence/mood/subgroup balance, editorial fields and readable unclassified legacy rows (`test/core/wr_situation_library_coverage_test.dart:40`). Catalog boundary (`lib/core/data/wr_canonical_catalog.dart:60`) makes canonical rows win and strips axes from unknown remote rows while retaining labels. Malformed persisted recent history was finding 2, now fixed and verified, including non-list field shapes.
- D6: full-suite picker tests and independent 600-run check pass normal first-ten behavior. Author suite covers exhausted pools and no duplicate choices; the custom option remains a separate UI path. The fallback intentionally relaxes recency when a requested pool is exhausted, per DECISIONS.
- D7: `pillarTally` partitions classified rows into positive/challenge buckets and excludes custom/unknown/retired rows. Independent mixed-history conservation check passes. R3 prose denominator was finding 1, now fixed and verified.
- D8: reviewed R1/R2/R3/R4/R5 fixtures, zero/20/60-percent boundaries, strict subgroup split, mixed-valence 15-record R5 and concrete fallback. R3 mixed-valence display and R2 rotation were findings 1/5; both are fixed and verified.
- D9: main lead, repeated rows, situation-based trend, and collapsed group detail exist. Existing widget tests pass. Physical pending-footer size was finding 4; both scored and no-Self-Check states now pass independent phone-layout tests.
- D10: active retired-ID/dim/catalog checks pass; persisted demo entitlement and chat overrides are removed at production boundaries, with stale true/false regressions. Display punctuation was finding 3; the final display-literal scan is clean.
- D11: reviewed refusal path (`wr_meaning_screen.dart:139`) retaining only user text on disagreement and passing `recordInsight:false`; episode/count persistence, feedback pause, practice resume/race/reset, Journey labels/date/expansion, Self-Check invitation, and partial JD resume are exercised by the passing full suite. This is automated fake-repository/provider evidence, not an OS restart or real Supabase account walkthrough.
- Future AI: no new Edge Function or note-reader was introduced. Existing consent repository and polish guard semantic behavior remain unchanged; polish remains behind its existing flag. Existing narrative behavior stays in its existing boundary. No claim that future architecture was implemented or deployed.
- New SQL uses retirement/upsert, no destructive DELETE/TRUNCATE; historical migrations remain immutable. The migration has not been applied to a database by QA.

## Source discrepancies and manual limits

- Authoritative JS has 24 positives including C1-10; the Word positive-group heading says 23. C1-10 title literally includes `valence: tích cực`. Exact source content is intentionally preserved per DECISIONS, not silently corrected.
- The Word all-negative evenly distributed R5 example conflicts with its own zero-inclusive R4 ladder. Mission decision correctly prioritizes R4 at 0%; R5 tests use mixed share strictly between 20% and 60%.
- Twenty-seven screenshot tests are opt-in skips (`WR_SCREENSHOTS` is unset), not screenshot approval: app_store 5, wr_v1_6 13, customer_case 4, iap_review 1, guide 4. Real-device typography, long-story scrolling, actual 15-reflection account walkthrough, process-restart persistence, remote migration/FKs, StoreKit purchase and store submission remain manual/unexecuted.
- GitNexus review completed after lead graph-ready: query plus context on `_deepGapBody`, picker and catalog; upstream impacts: MobileProfile HIGH (144 impacted, 19 direct, 0 processes), pillarTally HIGH (48, 5, 3), _deepGapBody LOW (2, 1, 1), WrCanonicalCatalog MEDIUM (94, 6, 0), picker LOW (2, 2, 0). HIGH risks were sent to lead. Profile/repository and Snapshot/deep dependents were covered by the baseline full suite and the completed post-fix full-suite rerun. Graph picker context omits the known production `wr_step_screen` caller; graph results are not exhaustive. No existing production symbol was edited by QA; all QA test files were new when authored. CLI exposes no detect_changes command and no MCP tool is installed; final change-detection gate remains with lead. No pre-commit claim is made.

Latest D10 recheck after UI TASK8: zero display em-dash literals; parsing-only delimiter remains unchanged.

## Final TASK7 independent serial retests

Executed one Flutter process at a time, all exit 0:

| Command | Passed | Log |
|---|---:|---|
| `flutter test test/core/models_test.dart` | 26 | `/tmp/wr-qa-task7-0.log` |
| `flutter test test/qa/persisted_history_qa_test.dart` | 1 | `/tmp/wr-qa-task7-1.log` |
| `flutter test test/qa/v2_release_qa_test.dart` | 8 | `/tmp/wr-qa-task7-2.log` |
| `flutter test test/core/logic/wr_deep_interpretation_test.dart` | 52 | `/tmp/wr-qa-task7-3.log` |

**87 passed, zero failed; all five findings closed.** Final full-suite rerun completed successfully; see below.

## Final full-suite evidence

`flutter test` independently rerun after all owner corrections, exit **0**. Exact final output: `01:44 +2527 ~27: All tests passed!`. Log: `/tmp/wr-qa-final-full-suite.log`. All four QA files are included. Final QA formatting: four files, zero changes, exit 0. Final retired-ID/dim scan remains clean; retirement script passes. **0 BLOCKER / 0 MAJOR / 0 MINOR open.** Manual/device/store and opt-in screenshot limits above still apply. Lead retains final integration Commands and graph/change-detection release gate.

## Final graph metadata observed

Read-only inspection of `.gitnexus/meta.json` after the final refresh: indexed at **2026-09-14 05:07:50 UTC (12:07:50 Vietnam)**; **806 files, 9570 nodes, 23388 edges, 116 processes, 4568 embeddings**. These are directly observed metadata, not a QA claim that change detection or a commit was performed.

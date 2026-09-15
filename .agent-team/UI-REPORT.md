# UI report — TASK 2 handoff

Date: 2026-09-14

## Existing UI fixes in the worktree

- `wr_commit_screen.dart`: restores a saved `tinyAction`/`reflectChoice` when the Choice route is reopened. If a saved preset is no longer in the current pool, it preserves the saved text in the free-write field. A user edit made while the pool is loading now wins over delayed restoration, and a mounted route resets its choice/text state when the episode identity changes.
- `profile_screen.dart`: removes the internal Premium override row and reset affordance from the shipped Profile surface. The profile test now asserts the controls and `(Demo)` text are absent.
- `wr_paywall_screen.dart`: removes the display em dash from the StoreKit offer label and describes the current bounded, consented structured timeline narrative instead of claiming autonomous reading of all Career Memory.
- `wr_providers.dart`: `wrEntitlementProvider` no longer applies persisted demo override state. `premiumOverrideProvider`, its keys, optional chat injection parameter, and public notifier API remain available; web role and mobile entitlement records remain the only runtime entitlement sources.
- `chat_providers.dart`: the production `wrChatControllerProvider` no longer reads persisted `premiumOverrideProvider` state. `WrChatController` and `WrChatRepository` keep their optional override parameter for explicit test/compatibility injection, while production chat uses the server-returned entitlement.
- `wr_meeting_2026_07_29_test.dart`: adds stale `true` and stale `false` chat regressions proving the persisted value cannot grant Free or revoke a real Premium reply, while consented sending still works.
- `wr_reflection_flow_test.dart`: adds repository/provider resume coverage, delayed-pool typing coverage, same-mounted-route episode switching coverage, and explicit v2 picker fixtures while preserving legacy history IDs.
- Granted D10 fixtures: canonical `A1-07` and `C2-01` replace only the seven exact prohibited current-catalog matches in chat/screenshot fixtures. Legacy `*-sit-*` history IDs were not mass-replaced.

## Semantic diff versus formatter churn

The files were formatted while making the focused changes, so the raw diff is large. Ignoring whitespace, the intended runtime changes are the commit state guard, entitlement-source boundary, paywall copy, tests, and deliberate fixture migration described above. No Journey implementation was changed. Existing migration/history compatibility changes in core/assets belong to the other worker and remain outside this report.

## Verified checks

```text
flutter test test/features/profile_test.dart test/features/wr_reflection_flow_test.dart
  78 tests passed
flutter test test/features/profile_test.dart test/features/wr_reflection_flow_test.dart test/features/wr_sca_deep_dive_screen_test.dart test/features/wr_jd_builder_screen_test.dart test/features/wr_detail_screens_test.dart test/features/wr_journey_discover_link_test.dart test/features/wr_career_memory_preview_test.dart test/features/wr_payment_screen_test.dart
  191 tests passed
flutter analyze
  No issues found
git diff --check
  clean
flutter test test/features/wr_reflection_flow_test.dart
  41 tests passed, including delayed pool typing and same-mounted-route episode switch
flutter test test/features/wr_providers_test.dart
  18 tests passed, including stale override cannot grant or revoke real entitlement
flutter test test/features/wr_screens_test.dart
  64 tests passed, including bounded paywall headline/highlight copy
flutter test test/features/profile_test.dart
  41 tests passed
flutter test test/features/wr_payment_screen_test.dart test/features/wr_iap_test.dart
  51 tests passed; payment/IAP direct callers remain green
flutter test test/features/wr_meeting_2026_07_29_test.dart
  59 tests passed, including stale true/false chat override regressions
flutter test test/features/wr_chat_starters_wiring_test.dart
  3 tests passed; chat provider wiring remains green
flutter test test/logic/wr_chat_starters_test.dart
  10 tests passed
flutter test test/screenshots/wr_customer_case_test.dart
  compiles; 4 screenshot tests skipped by the environment
flutter analyze
  No issues found (ran in 8.8s)
rg -n --glob '*.dart' "S1-06|S1-09|S2-04|S2-09|C1-08|C2-08|C2-09|A1-06|A1-08|A3-07|A3-10" test/logic/wr_chat_starters_test.dart test/screenshots/wr_customer_case_test.dart || true
  no matches in the two granted current-catalog fixture files
git diff --check
  clean
dart format --output=none --set-exit-if-changed lib test
  exits 1 because 332 shared/unrelated files are formatter-dirty in the
  worktree (the command listed them without editing); all UI-owned changed
  files were individually formatted before verification
```

## Resolved architecture findings

### 1. Persisted Premium override boundary (CRITICAL impact reviewed)

Removing the Profile row previously left stale entitlement and chat override branches. The authorized smallest boundary changes removed only those two production reads. Tests now prove persisted `true` cannot grant Free entitlement or chat Premium behavior, and persisted `false` cannot revoke active mobile entitlement or chat Premium behavior. The notifier, persisted state, optional controller/repository injection parameter, and public APIs remain; no broad notifier dependency was changed.

### 1a. TASK 3 final chat boundary

`wrChatControllerProvider` now constructs `WrChatController` with a `null` override. The production factory therefore never reads persisted demo state; the backend `WrChatRepository` response remains authoritative for Premium/free behavior. The constructor and repository `premiumOverride` parameters remain available only as explicit test/compatibility seams. The final production reference check:

```text
rg -n "premiumOverrideProvider|canTogglePremiumProvider|premiumOverride:" lib/features/wr lib/core/data/wr_chat_repository.dart
  chat_providers.dart:194 is the controller's optional repository injection;
  chat_providers.dart:275 is a comment documenting the production boundary;
  wr_providers.dart declares the preserved notifier;
  iap_providers.dart and wr_payment_screen.dart only clear stale state with set(null);
  no production chat factory read remains
```

The direct caller regressions remain green: 59 meeting-flow tests, including stale forced `true`/`false`, and 3 chat-starter wiring tests. Consent was unchanged and remains granted/checked by the existing chat flow.

### 2. Saved-action restoration race

`_actionEdited` marks the fallback field authoritative. When the pool resolves, restoration preserves the typed text and keeps free-write mode. The regression test completes a pending `wrChoicePoolProvider` future after typing and asserts the field text and absence of choice tiles.

### 3. Episode switch and persistence boundaries

The reopen test crosses the fake repository/provider/route boundary: the repository returns the seeded object, `resume` hydrates `episodeFlowProvider`, and a fresh route constructs a new `_WrCommitScreenState`. The new same-mounted-route test changes from `ep-first` to `ep-second` and asserts old choice/text state is cleared. These tests do not simulate a process restart or Supabase JSON serialization; persistence is represented by repository hydration, not OS storage.

### 4. Paywall AI claim

The current copy now says Premium uses permissioned recent look-backs/recorded situations to write a structured timeline narrative. It does not claim autonomous reading of all Career Memory and no future one-note AI reader was added. The comparison row keeps the existing public `AI Insight` label for compatibility.

### 5. Exact D10 fixtures

The exact scan returns zero matches in the two granted current-catalog fixture files. The retired-list audit now lives under the scripts audit scope; the full `lib/`, `test/`, and `assets/` scan is clean. The two granted files preserve test intent with canonical current catalog titles. Legacy `*-sit-*` history fixtures remain meaningful and were not mass-replaced.

## TASK 4 formatter-only normalization (separate scope)

Temporary ownership covered all `lib/**` and `test/**` Dart files for the SPEC D2 mechanical pass. No logic, string literal, or test expectation edits were made. The pre-format inventory contained 397 Dart files; `dart format lib test` reported 319 files changed.

Before and after fingerprints were captured with the same temporary lexical scanner. It removes whitespace/comments, preserves each string literal as an exact token, and ignores commas immediately before closing delimiters to allow formatter-only trailing-comma changes. Evidence:

```text
before: 397 files, 554,998 normalized tokens, 26,808 string tokens
after:  397 files, 554,998 normalized tokens, 26,808 string tokens
semantic token mismatches: 0
```

```text
dart format --output=none --set-exit-if-changed lib test
  exit 0; Formatted 397 files (0 changed)
git diff --check
  clean
```

## TASK 8 no-Self-Check invitation compactness

The D9 follow-up kept the change bounded to `_BodyState.build` in
`lib/features/wr/presentation/wr_sca_deep_dive_screen.dart`. The no-Self-Check
explanation is now concise, one physical line with ellipsis, while the
`wr_deep_no_self_check_yet` invitation key, actionable Self-Check button, route,
and Premium semantics remain intact. Removing the unused question-bank import
was required after removing the count interpolation; it has no runtime effect.

Impact was checked before the edit on the owning `_BodyState` symbol:

```text
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests _BodyState
  LOW; 25 impacted; 4 direct upstream callers; no indexed processes/modules
  direct: wr_sca_deep_dive_screen_test.dart, app_router.dart,
          wr_self_check_screen.dart, wr_discover_screen.dart
HIGH/CRITICAL: none
```

Required focused verification was run serially:

```text
flutter test test/qa/deep_layout_qa_test.dart
  1 test passed; pending footer remains one physical line at phone width
flutter test test/qa/deep_no_self_check_qa_test.dart
  1 test passed; invitation is compact and the action remains available
flutter test test/features/wr_sca_deep_dive_screen_test.dart
  8 tests passed
dart format lib/features/wr/presentation/wr_sca_deep_dive_screen.dart
  Formatted 1 file (0 changed)
dart format --output=none --set-exit-if-changed \
  lib/features/wr/presentation/wr_sca_deep_dive_screen.dart
  exit 0
flutter analyze
  No issues found
git diff --name-only -- test/qa/deep_layout_qa_test.dart \
  test/qa/deep_no_self_check_qa_test.dart
  no output; QA tests untouched
git diff --check
  clean
```

The no-Self-Check QA reproduction now satisfies its `<=24px` invitation-height
assertion at 375px. No unrelated production file or QA test was changed.

The formatter-only pass did not introduce a functional test run; the previously
recorded functional suites remain the relevant behavior evidence.

## TASK 7 D10 display punctuation cleanup (separate scope)

Removed the four display em dashes from the two assigned localized messages:

- `lib/features/wr/presentation/wr_growth_skills_screen.dart`, `_JdSection.build` (lines 557 and 559): replaced both separators with colons.
- `lib/features/wr/presentation/wr_journey_narrative_screen.dart`, `_emptyLine` (lines 145 and 148): replaced both separators with commas.

The refreshed GitNexus graph was ready before editing. Impact evidence:

```text
_JdSection: LOW; 4 direct upstream dependents; 1 affected build process and 1 Presentation module; 12 impacted nodes
_emptyLine: LOW; 0 indexed callers; no affected processes/modules
HIGH/CRITICAL findings: none
```

Verification:

```text
flutter analyze
  No issues found (ran in 5.7s)
dart format --output=none --set-exit-if-changed \
  lib/features/wr/presentation/wr_growth_skills_screen.dart \
  lib/features/wr/presentation/wr_journey_narrative_screen.dart
  Formatted 2 files (0 changed)
flutter test test/features/wr_habit_seniority_test.dart \
  test/features/wr_detail_screens_test.dart \
  test/features/wr_i18n_journey_and_checkin_test.dart
  50 tests passed
sed -E 's://.*$::' <target files> | rg -n '—' || true
  no output; remaining target-file matches are comments only
git diff --check
  clean
```

### Deep Reading pending-content compactness

The authorized follow-up changed only `_BodyState.build` in
`lib/features/wr/presentation/wr_sca_deep_dive_screen.dart`. With a scored
Self-Check, the pending footer is now constrained to one line with ellipsis;
without a scored Self-Check, it is omitted so the preserved actionable
Self-Check invitation and button are not duplicated. Premium gating is unchanged.

Impact evidence:

```text
_BodyState: LOW; 4 direct upstream dependents; 25 impacted nodes; no indexed processes/modules
HIGH/CRITICAL findings: none
```

Verification:

```text
flutter test test/features/wr_sca_deep_dive_screen_test.dart
  8 tests passed
flutter test test/qa/deep_layout_qa_test.dart
  1 test passed; 375px reproduction footer height <= 22px
flutter analyze
  No issues found (ran in 17.8s)
dart format --output=none --set-exit-if-changed \
  lib/features/wr/presentation/wr_sca_deep_dive_screen.dart
  Formatted 1 file (0 changed)
sed -E 's://.*$::' <wr_sca_deep_dive_screen.dart> | rg -n '—' || true
  no output
git diff --check
  clean
```

No production files outside the three assigned TASK 7 screens, behavior outside
the pending-content presentation, or localized message meaning changed.

## Remaining review issues

- Journey's core `buildJourneyEntries`/`eventTypeLabel` implementation remains untouched because its prior impact was HIGH and no D11 defect was demonstrated; TASK 7 only changed punctuation in the separate narrative screen.
- The refreshed GitNexus graph reports 9557 symbols, 23349 relationships, 115 flows, and 4561 embeddings. The exact TASK 7 impact commands and direct callers are recorded in `UI-IMPACT.md`.
- The shared core v2 catalog/picker changes are outside this narrow TASK 2 runtime scope; their explicit-classification fixture adaptations are in the owned flow test. No core production logic was modified by UI.

## TASK 5 strict-v2 fixture repair (separate scope)

The five integration-failing UI suites were repaired with fixture-only changes.
Current-catalog rows now carry explicit `pillarCode`, `subgroup`, `mood`, and
`valence`, and current story fixtures use the canonical paired IDs. Strict v2
picker/classifier predicates, denominator logic, and production fallback were
not weakened or changed.

- `wr_sca_deep_dive_screen_test.dart`: classified the S1 and C2 rows so loop/group rows resolve in the deep-reading surface.
- `wr_flow_walkthrough_test.dart`: classified the six mood-walk fixtures with canonical rows, including positive `P-01`/`P-06` valence and subgroup data.
- `wr_discover_two_tier_test.dart`: made all synthetic rows explicit through `_sitOf` and classified inline count fixtures; Snapshot, gap, and denominator assertions now exercise the strict catalog.
- `wr_checkin_to_growth_chain_test.dart`: migrated the current C2 fixture to `C2-01`, classified the six-row pool, and replaced the obsolete forced-anchor expectation with a first-ten nonrepeat assertion. The single-row exhausted-pool path still proves three repeats and the `3` count.
- `wr_end_to_end_test.dart`: migrated the current fixtures to canonical `C2-01`/`A3-01` rows with explicit axes, preserving the all-tabs reflection flow.

Legacy history IDs were not mass-replaced. The exact seven prohibited current-
catalog matches in the separately granted chat/screenshot files remain absent;
the only remaining `C2-sit-01` mention in the changed UI tests is a comment
explaining an internal legacy ID.

Focused commands were run serially after the repair:

```text
flutter test test/features/wr_sca_deep_dive_screen_test.dart
  8 tests passed
flutter test test/features/wr_flow_walkthrough_test.dart
  8 tests passed
flutter test test/features/wr_discover_two_tier_test.dart
  46 tests passed
flutter test test/features/wr_checkin_to_growth_chain_test.dart
  3 tests passed
flutter test test/features/wr_end_to_end_test.dart
  4 tests passed
```

Total focused TASK 5 evidence: 69 tests passed. No production/core Dart files
were edited for this task, and no unresolved logic issue was found in the five
named integration paths.

## TASK 6 feature lint cleanup (separate scope)

Added braces to the nine feature-level `curly_braces_in_flow_control_structures`
findings listed in `/tmp/wr-analyze-final.dCdNk1.log`:

```text
guide_screen.dart:89
wr_meaning_screen.dart:167
wr_context_doc_screen.dart:96
wr_journey_screen.dart:509,574
wr_mood_reader_screen.dart:276
wr_payment_screen.dart:418
wr_self_check_screen.dart:185
wr_work_info_screen.dart:64
```

GitNexus impact was checked on each containing owner symbol before editing.
`eventTypeLabel` returned HIGH risk (one direct caller, `buildJourneyEntries`,
three affected processes) and was explicitly reviewed; `_WrMeaningScreenState`
returned MEDIUM, and the other owners returned LOW. No CRITICAL risk was
returned. The edits only add braces; behavior and string literals are unchanged.

```text
dart format <the 8 changed feature files>
  Formatted 8 files (0 changed)
flutter analyze
  No issues found (ran in 5.2s)
flutter test test/features/guide_test.dart test/features/wr_premium_surfaces_test.dart \
  test/features/wr_reflection_flow_test.dart test/features/wr_flow_walkthrough_test.dart \
  test/features/wr_end_to_end_test.dart test/features/wr_checkin_to_growth_chain_test.dart \
  test/features/wr_detail_screens_test.dart test/features/wr_i18n_journey_and_checkin_test.dart \
  test/features/wr_mood_library_test.dart test/features/wr_payment_screen_test.dart \
  test/features/wr_payment_return_test.dart test/features/wr_self_check_questions_ui_test.dart \
  test/features/wr_self_check_premium_test.dart test/features/wr_growth_opportunity_ui_test.dart
  181 tests passed
dart format --output=none --set-exit-if-changed lib test
  Formatted 397 files (0 changed)
git diff --check
  clean
```

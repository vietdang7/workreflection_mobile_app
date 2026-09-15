# Core impact and architecture review

Date: 2026-09-14
Scope: impact review and final implementation evidence for the authorized core v2 worktree.

The current worktree also contains broad formatter-only changes owned by UI
TASK4. Those changes are not attributed to the functional core v2 inventory
below.

## Graph baseline

- `gitnexus status`: indexed 9463 nodes, 23101 edges, 4504 embeddings at commit `48ebd98`; current worktree edits are not indexed.
- MCP is unavailable; all impact checks used `gitnexus impact --repo appmobileworkreflection --include-tests --depth 2`.

## Changed-symbol inventory

- `lib/core/models/wr_content.dart`: `WrValence`, strict v2 axes/classification on `WrSituation` and `WrStory`, canonical-compatible parsing, and nullable legacy parsing on `CareerMemoryEvent`.
- `lib/core/models/wr_episode.dart`: nullable legacy enum parsing in `ReflectionEpisode.fromJson`; no v2 snapshot fields or snapshot insert/copy changes are present in the final diff.
- `lib/core/models/wr_intelligence.dart`: `WrInsight.fromJson` and `PatternCount.fromJson` tolerant legacy parsing; other current changes are formatter-only.
- `lib/core/logic/wr_career_health.dart`: `pillarOfSituation`, `PillarTally`, `pillarTally`, `situationCounts`, `pillarShares`, `scaTouchedCount`.
- `lib/core/logic/wr_situation_picker.dart`: `pickSituationChoices`, `_isPickerEligible`, `pickChoiceOptions`, `resolveStoryFor`.
- `lib/core/logic/wr_deep_interpretation.dart`: `DeepSituation`, `DeepFacts`, ranking/trends, `DeepCluster`, `deepCluster`, `deepRung`, and lead/trend text.
- `lib/core/data/wr_canonical_catalog.dart`: new canonical asset catalog and remote merge boundary; `wr_content_repository.dart` loads and applies it.
- Assets, importer, retirement audit, and `20260914000000_wr_situations_v2.sql` are also changed.

The earlier baseline inventory incorrectly described `ReflectionEpisode` as
having v2 snapshot field and write-path changes. Those changes were reverted
and are not part of this final core scope; the nullable parser hardening remains
for readable legacy rows.

## Refreshed impact evidence

| Symbol | Risk | Impacted | Direct | Processes | d=1 review |
|---|---:|---:|---:|---:|---|
| `WrSituation` | CRITICAL | 163 | 88 | 1 | content/episode repositories, providers, core logic, feature screens, broad tests |
| `WrStory` | CRITICAL | 160 | 85 | 1 | content repository, providers, story/deep screens, broad tests |
| `CareerMemoryEvent` | CRITICAL | 161 | 86 | 1 | content repository, episode flow, Journey/feature surfaces, broad tests |
| `ReflectionEpisode` | CRITICAL | 129 | 53 | 3 | episode repository/controller, providers, flow screens, broad tests |
| `WrInsight` | CRITICAL | 123 | 79 | 2 | intelligence repository, providers, home/Journey surfaces, broad tests |
| `PatternCount` | CRITICAL | 121 | 77 | 2 | intelligence repository, providers, premium/deep surfaces, broad tests |
| `pillarTally` | HIGH | 17 | 4 | 3 | SCA deep dive, Discover, `buildDeepFacts`, core tests |
| `resolveStoryFor` | MEDIUM | 80 | 1 | 0 | `wr_providers.dart` direct caller; broad story flow transitively |
| `pickSituationChoices` | LOW | 1 | 1 | 0 | picker test (UI calls through its provider path) |
| `buildDeepFacts` | LOW | 4 | 3 | 2 | Deep Reading screen, `buildDeepInterpretation`, core tests |

The CRITICAL/HIGH warnings were surfaced to lead before any further broad edits. Existing d=1 callers remain the compatibility gate.

## Historical baseline findings (before the authorized implementation)

1. **Legacy eligibility — resolved.** The original
   `wr_situation_picker.dart:149-157` accepted all-null legacy rows. Strict
   `hasV2Classification` now excludes those rows, and the catalog boundary
   also normalizes valid-looking noncanonical remote rows to history-only.

2. **Exact story pairing — resolved.** The hash fallback was removed; unknown,
   retired, and unmatched history codes resolve to no story.

3. **Canonical runtime data — resolved.** The repository now loads local assets
   first and lets canonical fields/content win for known codes, while retaining
   remote unknown/history labels as unclassified, retired compatibility rows.

4. History snapshot expansion is explicitly out of scope in the final diff. No v2 snapshot fields or episode insert/copy changes remain; `ReflectionEpisode.fromJson` only retains nullable enum parsing so old rows remain readable. Current v2 correctness therefore comes from the canonical catalog boundary, while persisted unknown/retired codes remain history-only.

5. **Deep Reading conflicts — resolved.** R2 now requires explicit subgroup and
   valence, and R4 accepts the zero-positive low-share case.

6. **Fixture state — resolved.** The canonical asset and focused coverage/story
   tests use 72 real rows plus `other`, the custom row is null-safe, and the
   owned deep-dive fixture now provides explicit axes. The final full-core scan
   passes.

The production edits address the legacy portions of findings 1–3 and finding
5. Finding 4 is intentionally not implemented, as documented above. The
noncanonical remote boundary and four fixture failures described during the
intermediate scan were resolved in TASK3 without relaxing production
strictness.

## Final disposition of the original compatible path

1. Strict v2 classification and the canonical catalog boundary are implemented;
   custom, unknown, and retired rows are excluded from offered/measurement
   paths.
2. Story resolution is exact-code only, with no hash fallback.
3. Picker, counting, and Deep Reading enforce the strict predicate, R2
   subgroup-plus-valence rule, and zero-inclusive R4 threshold; focused and
   full-core tests pass.
4. `CareerMemoryEvent` and `PatternCount` were left without new snapshot fields;
   only nullable legacy parsing was retained where required for readability.
5. Lead owns final repository-wide change detection and integration/QA gates;
   this worker made no commit or deployment.

## Post-reboot TASK 2 completion evidence

This bounded continuation changed core test/audit coverage, importer source
portability, and stale exact-pair documentation after the earlier production
review. No commit or database deployment was performed.

- Added `scripts/audit_retired_situation_ids.js` with the explicit retirement
  list outside `lib/`, `test/`, and `assets/`. It verifies 72 active real rows,
  one custom row, duplicate-free active codes, and no retired code in the active
  asset.
- `node scripts/audit_retired_situation_ids.js` →
  `[PASS] retired=11 active=72 custom=1 activeRetired=0`.
- Runtime-scope exact retirement scan over `lib/**`, `test/**`, and `assets/**`
  returned no matches. The explicit list is no longer embedded in a test.
- Reworked `test/data/wr_seed_situation_story_pairing_test.dart` to read the
  generated v2 assets, assert 72 real + `other`, 48/24 valence, six 12-item
  moods, six balanced challenge subgroups, exact situation/story ID equality,
  and byte-for-byte parity across all six editorial fields. It also proves the
  custom null compatibility dimension parses safely.
- Expanded `test/core/wr_situation_library_coverage_test.dart` to 12 named
  cases, including strict axes, unknown/legacy readability, and the script-backed
  retirement audit. Added a canonical unknown-history membership test.
- `scripts/import_situations_v2.js` now requires `--source` or
  `WR_SITUATIONS_SOURCE`; it has no developer-home default, reports missing
  source/file errors clearly, and exposes guarded read-only loaders for parity
  verification.
- `WrCanonicalCatalog.mergeSituations` now converts noncanonical remote rows
  into retired, unclassified compatibility rows. The focused catalog test uses
  a valid-looking unknown v2 row and proves it remains readable but picker-
  ineligible.
- `test/core/logic/wr_sca_deep_dive_test.dart` now uses explicit v2 axes in its
  shared fixtures, preserving the strict classifier contract.

Serial focused Flutter evidence after edits (one Flutter process at a time):

| Command | Result |
|---|---|
| `flutter test test/core/wr_situation_library_coverage_test.dart` | 12 passed |
| `flutter test test/data/wr_seed_situation_story_pairing_test.dart` | 9 passed |
| `flutter test test/core/wr_canonical_catalog_test.dart` | 4 passed |
| `flutter test test/core/wr_content_repository_test.dart` | 18 passed |
| `flutter test test/core/logic/wr_situation_picker_test.dart` | 34 passed |
| `flutter test test/core/logic/wr_career_health_test.dart` | 32 passed |
| `flutter test test/core/logic/wr_deep_v2_contract_test.dart` | 6 passed |
| `flutter test test/core/logic/wr_deep_interpretation_test.dart` | 49 passed |
| `flutter test test/core/models/wr_content_test.dart` | 21 passed |

Focused total: 185 passed, 0 failed. The earlier picker/deep failures in the
baseline findings above are historical review evidence; the serial reruns now
pass with the deliberate v2 fixtures and zero-inclusive R4/mixed R5 contracts.

## Pre-fix full-core scan after UI formatting

`flutter test test/core` ran as one serial Flutter process and exited 1:
1,318 passed and 4 failed. All four failures are the same owned pre-v2 fixture
contract in `test/core/logic/wr_sca_deep_dive_test.dart`: the shared
`_situations` rows contain only legacy `scaDimension` and null explicit
`pillar`/`subgroup`/`mood`/`valence`, so strict v2 classification correctly
excludes them. Failures are at assertions on lines 185, 199, 334, and 380
(expected 3/1/true/non-null; actual 0/0/false/null). Captured log:
`/tmp/wr-core-test.63QeP0.log`.

## Final full-core scan after TASK3

`flutter test test/core` was rerun as one serial Flutter process after the
boundary and fixture fixes and exited 0: 1,322 passed and 0 failed. Captured
log: `/tmp/wr-core-test-final.VcI6ZH.log`.

The full format gate also passes: `dart format --output=none
--set-exit-if-changed lib test` reports 397 files, 0 changed, and
`git diff --check` is clean. The pre-TASK4 analyzer run had 18 existing
`curly_braces_in_flow_control_structures` info issues; the nine core locations
were then cleaned up. The post-TASK4 analyzer run has only the nine remaining
UI-owned feature-file infos, recorded in the TASK4 section below.

## Final canonical boundary review

`WrCanonicalCatalog.mergeSituations` correctly lets canonical local rows win
for known codes and preserves unknown remote labels for history. Noncanonical
remote rows are now stripped of explicit axes and marked retired at the merge
boundary, so `_isPickerEligible`, counting, and deep ranking exclude them. The
focused test covers a valid-looking unknown row. GitNexus cannot index these
new worktree symbols yet: impact checks for `mergeSituations`,
`_isPickerEligible`, and `WrCanonicalCatalog` all returned `Target not found`.

## TASK4 lint cleanup evidence

The nine authorized core brace-style findings were fixed with braces only in
`lib/core/data/payment_repository.dart`, `lib/core/logic/wr_flow_error.dart`,
and `lib/core/logic/wr_payment.dart`. No string, expression, or behavior
change was introduced.

GitNexus impact before editing: `logFlowError` HIGH (25 impacted, 15 direct,
2 processes); `WrInvoiceForm`/`validationError` MEDIUM (9 impacted, 7 direct);
`validateVoucher` LOW (1 direct); `voucherIneligibleReason` LOW (1 direct,
1 process); and `SupabasePaymentRepository`/`applyVoucher` LOW (7 impacted,
4 direct). The bare `applyVoucher` query was ambiguous and selected a fake
test method first; the owning production class was then checked explicitly.

`flutter test test/core/wr_payment_test.dart` passed 43/43. The post-cleanup
`flutter analyze` exits 1 only for nine UI-owned feature-file brace infos;
none remains in the three cleaned core files. Log:
`/tmp/wr-analyze-task4.grCD0b.log`.

Targeted `dart analyze lib/core/data/payment_repository.dart
lib/core/logic/wr_flow_error.dart lib/core/logic/wr_payment.dart` reports
`No issues found!` (exit 0). Zero-context diff review confirms the TASK4 delta
is limited to block delimiters; prior formatter hunks are attributed to UI
TASK4.

## TASK5 R3 denominator correction

Graph refresh completed before this edit: `npx gitnexus analyze --force
--embeddings` exited 0 with 9,557 nodes, 23,349 edges, 667 clusters, and 115
flows. Upstream impact for the edited private symbol was run against that
refreshed graph before modification:

| Symbol | Risk | Impacted | Direct | Processes | Direct caller |
|---|---:|---:|---:|---:|---|
| `_deepGapBody` | LOW | 2 | 1 | 1 | `deepGapText` |

The one direct production caller is `deepGapText`; the affected test process is
`test/core/logic/wr_deep_interpretation_test.dart`. No HIGH or CRITICAL warning
was returned. The implementation change is intentionally one local binding:
R3 gap prose now uses `DeepFacts.challengeTotal` for its denominator. R1,
R2, R4, and R5 remain on their existing denominator/ladder semantics; notably
`_deepR1Text` and `_deepR4Text` continue to use `classifiedTotal`.

The new mixed-valence regression constructs 8 dominant-C challenge rows, 4
additional challenge rows, and 6 positive rows: numerator 8, challenge-only
denominator 12, classified denominator 18. It asserts the R3 text contains 12
and does not display 18. This is in the existing deep interpretation test; no
QA-owned test file was changed.

TASK5 verification: `flutter test
test/core/logic/wr_deep_interpretation_test.dart` → 50 passed, 0 failed;
`flutter test test/core/logic/wr_deep_v2_contract_test.dart` → 6 passed, 0
failed. Targeted `dart analyze` for the two changed files reports `No issues
found!` (exit 0), and the owned-file format check reports 2 files, 0 changed.
The repository-wide check reports 400 files, 1 externally unformatted file
(`test/qa/deep_layout_qa_test.dart`, untracked and QA-owned); because it was
run with `--output=none --set-exit-if-changed`, it made no write. The prior
lead/UI 397-file clean gate remains intact for the tracked/shared scope.

## TASK5 follow-up: persisted history, D10 punctuation, and deep wording

### Persisted profile history normalization

Before editing, GitNexus impact for `MobileProfile` returned HIGH risk: 85
impacted nodes, 19 direct callers, 0 indexed processes, and 1 Models module.
The exact `MobileProfile.fromJson` constructor target was not separately
indexed. Direct dependents reviewed included `SupabaseWrRepository.getMobileProfile`,
`wrRecentSituationIdsProvider`, profile/home/wr consumers, and model,
repository, and session tests. The parser now eagerly applies
`whereType<String>().toList(growable: false)` to `recent_situation_ids`: valid
strings keep their order and unknown codes remain history-readable, while
null/non-string persisted values are discarded before picker consumers see
them. The public `List<String>` API is unchanged.

`flutter test test/qa/persisted_history_qa_test.dart` passed 1/1 and
`flutter test test/core/models_test.dart` passed 25/25, including the malformed
history regression. The QA reproduction file was not edited.

### D10 display punctuation

The five authorized user-display em dashes were replaced with colons only;
meaning and parsing behavior are unchanged. Upstream impacts before editing:

| Owning symbol | Risk | Impacted | Direct | Processes |
|---|---:|---:|---:|---:|
| `WrRenewalNotice` | MEDIUM | 10 | 5 | 0 |
| `wrGuideSections` | LOW | 1 | 1 | 0 |
| `StoreKitIapRepository` | LOW | 12 | 4 | 0 |

No HIGH/CRITICAL warning was returned. The affected display strings are
`wr_iap_renewal.dart:103`, `wr_user_guide.dart:389,696,868`, and
`wr_iap_repository.dart:359`; remaining em dashes in those files are comments
or documentation.

### Deep wording review

Before editing, impacts were LOW for `_deepR2Text` (0 impacted), `deepGapText`
(1 impacted, 1 direct, 1 process), and `deepStandoutOf` (2 impacted, 1 direct,
1 process). R2 now uses deterministic `variantSeed % 2` sentence-order
rotations for both two- and three-member clusters, retaining every actual
member name and cluster total. R3 uses the existing concrete-name/count
sentence first, followed by the approved abstract wording. No new claims or
situations were introduced.

The expanded deep suite passed 52/52, including same-seed stability and
different-seed variation regressions for both R2 member counts and the
concrete-first R3 assertion. Targeted analysis of all seven changed Dart files
reported no issues; their format check reported 7 files, 0 changed. No commit
or deployment was performed.

The post-edit v2 contract rerun also passed 6/6 serially:
`flutter test test/core/logic/wr_deep_v2_contract_test.dart` (log:
`/tmp/wr-deep-v2-expanded-task5.log`).

The QA exact mixed-valence release reproduction passed 8/8 after the complete
TASK5 batch, including the former 8-in-18 R3 case:
`flutter test test/qa/v2_release_qa_test.dart` (log:
`/tmp/wr-v2-release-qa-task5.log`).

Final closeout check: `dart format --output=none --set-exit-if-changed lib test`
reported 401 files, 0 changed. The earlier 400-file/one-file result was a
transient check before the QA file was synchronized. The installed GitNexus
CLI has no `detect-changes` command; no commit was attempted, so the fallback
scope review used `gitnexus status`, targeted `git status`, and `git diff
--check`, all clean for the owned changes.

## TASK7 explicit R3 population and whole-field history guard

Fresh pre-edit impact for `_deepGapBody` was LOW: 2 impacted nodes, 1 direct
caller (`deepGapText`), 1 affected process, and 1 Logic module. Fresh impact for
the owning `MobileProfile` class was HIGH: 85 impacted nodes, 19 direct callers,
0 indexed processes, and 1 Models module; the exact `MobileProfile.fromJson`
constructor target is not separately indexed. Both risk results were surfaced
before editing, and the previously reviewed d1 repository/provider/profile
consumers remain compatible.

`MobileProfile.fromJson` now guards the whole `recent_situation_ids` value with
a raw `is List` check before eagerly filtering list members with
`whereType<String>()`. A null, scalar string, map, or number becomes empty
history; a mixed list keeps valid strings, order, and unknown IDs while safely
supporting `.toSet()` at picker boundaries.

All nine non-even R3 `_deepGapBody` variants now qualify the denominator as
challenge reflections (`lượt thách thức` / `challenge reflections`) while
retaining the 8/12 arithmetic and concrete-first sentence order. The mixed R3
regression asserts the explicit Vietnamese population label.

Serial verification: `flutter test test/core/models_test.dart` → 26 passed;
`flutter test test/qa/persisted_history_qa_test.dart` → 1 passed;
`flutter test test/qa/v2_release_qa_test.dart` → 8 passed; and
`flutter test test/core/logic/wr_deep_interpretation_test.dart` → 52 passed,
all with 0 failures. Targeted `dart analyze` on the four affected Dart files
reported no issues; owned-file format check reported 4 files, 0 changed.
Logs: `/tmp/wr-models-task7.log`, `/tmp/wr-persisted-history-task7.log`,
`/tmp/wr-v2-release-qa-task7.log`, `/tmp/wr-deep-task7.log`,
`/tmp/wr-task7-analyze.log`, and `/tmp/wr-task7-format.log`.

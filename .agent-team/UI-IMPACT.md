# UI architecture review and impact evidence

Date: 2026-09-14

GitNexus MCP was unavailable in this worker, so the installed CLI was used against repository `appmobileworkreflection`. The refreshed graph reports 9557 symbols, 23349 relationships, 115 execution flows, and 4561 embeddings. Commands below are upstream impact checks with tests included.

## Changed-symbol inventory

| Symbol | File | Risk | Direct upstream callers / dependents | Minimal path |
| --- | --- | --- | --- | --- |
| `_WrCommitScreenState` | `lib/features/wr/presentation/flow/wr_commit_screen.dart` | MEDIUM | 6: app router; `wr_reflection_flow_test.dart`; `wr_flow_walkthrough_test.dart`; `wr_end_to_end_test.dart`; `wr_checkin_to_growth_chain_test.dart`; `wr_v1_6_screens_test.dart` | route `/wr/flow/commit` constructs the state; state watches `episodeFlowProvider` and `wrChoicePoolProvider` |
| `_restoreSavedAction` | same commit screen | LOW | 1: `_WrCommitScreenState.build` | restoration now exits when the user edited during pool loading |
| `_resetForEpisode` / `_handleActionChanged` | same commit screen | not indexed (new private methods) | owner only | reset route-local choice/text state by episode identity; record user edits |
| `ProfileScreen` | `lib/features/profile/presentation/profile_screen.dart` | LOW | 3: app router; `profile_test.dart`; `avatar_upload_test.dart` | router `/profile` constructs the screen |
| `_IapOfferButton` | `lib/features/wr/presentation/wr_paywall_screen.dart` | MEDIUM | 8: `_IapOfferList.build`; app router; IAP/store/payment/screenshot/end-to-end tests | `_IapOfferList` creates one button per StoreKit offer |
| `WrPaywallScreen` | same paywall file | MEDIUM | 7: app router; paywall/store/payment/IAP/screenshot/end-to-end tests | router `/wr/paywall` resolves `PaywallTrigger` and builds the screen |
| `_Harness.seedOpenEpisode` | `test/features/wr_reflection_flow_test.dart` | LOW | 1: test `main` | helper only seeds the in-memory episode repository |
| `wrChatControllerProvider` | `lib/features/wr/chat_providers.dart` | not indexed | GitNexus target missing; provider construction is imported through `WrAskScreen` and chat wiring/flow tests | production provider now passes `null`; `WrChatController` constructor remains the test/compatibility injection seam |
| `WrChatController` | same chat file | LOW | 2 direct indexed importers; 11 total indexed upstream nodes | controller/repository optional override parameter is retained; only production provider propagation is disabled |

`PremiumOverrideNotifier` was not changed, but was audited because the Profile control was removed. Its upstream impact is CRITICAL with 79 direct dependents, including entitlement, chat, payment/IAP, session scoping, and many tests. The authorized narrow edit removes its use as an entitlement source and production chat source; the notifier, persisted keys, optional controller/repository injection seam, and public APIs remain intact.

## Commands and results

```text
gitnexus impact -r appmobileworkreflection -d upstream --include-tests _WrCommitScreenState
  risk MEDIUM; direct 6; no indexed process/module impact
gitnexus impact -r appmobileworkreflection -d upstream --include-tests _restoreSavedAction
  risk LOW; direct 1 (`_WrCommitScreenState.build`)
gitnexus impact -r appmobileworkreflection -d upstream --include-tests ProfileScreen
  risk LOW; direct 3; no indexed process/module impact
gitnexus impact -r appmobileworkreflection -d upstream --include-tests _IapOfferButton
  risk MEDIUM; direct 8; 1 module affected
gitnexus impact -r appmobileworkreflection -d upstream --include-tests WrPaywallScreen
  risk MEDIUM; direct 7; no indexed process/module impact
gitnexus impact -r appmobileworkreflection -d upstream --include-tests PremiumOverrideNotifier
  risk CRITICAL; direct 79; no indexed process impact, but broad feature/test dependents
gitnexus impact -r appmobileworkreflection -d upstream --include-tests seedOpenEpisode
  risk LOW; direct 1; 1 process and 1 module affected
npx gitnexus query -r appmobileworkreflection "commit saved action restoration entitlement paywall AI consent"
  definitions included `_WrCommitScreenState`, consent screens, IAP, and entitlement-adjacent files; no process group returned
npx gitnexus context -r appmobileworkreflection _WrCommitScreenState
  incoming: router plus 5 direct test files; outgoing: build, restore helper, save, choice-pool/state properties
npx gitnexus context -r appmobileworkreflection PremiumOverrideNotifier
  incoming: wr_providers.dart plus 79 direct import/dependent edges; outgoing: load, set, constructor
npx gitnexus context -r appmobileworkreflection WrPaywallScreen
  incoming: app router plus 6 direct test files; outgoing: createState and trigger
npx gitnexus impact -r appmobileworkreflection -d upstream --include-tests PremiumOverrideNotifier
  risk CRITICAL; direct 79; warning surfaced to lead before the authorized provider-boundary edit
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests wrChatControllerProvider
  target not found; top-level provider is not indexed in the stale worktree index
npx gitnexus context -r appmobileworkreflection wrChatControllerProvider
  symbol not found; provider indexing limitation recorded rather than inferred as zero impact
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests WrChatController
  risk LOW; direct 2 (`wr_ask_screen.dart`, `wr_chat_starters_wiring_test.dart`); 11 total; no indexed processes/modules
npx gitnexus context -r appmobileworkreflection WrChatController
  incoming: `chat_providers.dart`, `wr_ask_screen.dart`, and wiring test; outgoing: load/startNew/open/send/clear/dismissError and constructor
```

## Risk disposition

The CRITICAL override finding was reviewed with lead/core. The authorized edits are limited to the `wrEntitlementProvider` source boundary and the `wrChatControllerProvider` production construction boundary; real web/mobile entitlement and consent paths remain unchanged. The `WrChatController` optional override parameter and repository API remain available for explicit tests/compatibility, but production chat now passes `null`. No notifier deletion or broad dependency edit was made. Earlier Journey checks remain HIGH for `buildJourneyEntries` and `eventTypeLabel`; Journey was left untouched because the existing type/date/label behavior has no demonstrated D11 defect.

The shared core v2 picker now requires explicit classification. Owned flow fixtures were therefore given `pillarCode`, `subgroup`, `mood`, and `valence`; legacy `*-sit-*` IDs remain unchanged. Three exact story fixtures now key their test story to the seeded legacy situation ID so strict story resolution remains meaningful.

## TASK 5 fixture-only impact refresh

The five affected UI suites were repaired by making current-catalog fixtures
explicit v2 records. No production symbol, picker predicate, denominator, or
classifier was edited. The wide-library test expectation was intentionally
updated to the current first-ten nonrepeat contract; the separate single-row
test still verifies three recorded repeats and the resulting count.

```text
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests _sitOf
  risk LOW; direct 1 (`main` in `test/features/wr_discover_two_tier_test.dart`)
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests _walkToMeaning
  risk LOW; direct 1 (`main` in `test/features/wr_end_to_end_test.dart`)
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests _Stage
  target was ambiguous/not indexed for the intended test-local helper; no production caller was inferred
```

The test-local fixture constants and `main` blocks have no indexed production
callers. No HIGH or CRITICAL risk was returned for this fixture-only scope.
The exact prohibited current-catalog ID scan in the two granted files is clean:

```text
rg -n --fixed-strings -e 'C2-sit-01' -e 'A3-sit-01' -e 'C1-sit-01' \
  test/logic/wr_chat_starters_test.dart test/screenshots/wr_customer_case_test.dart
  no matches
```

The remaining `C2-sit-01` occurrence in the Discover test is a migration
comment documenting an internal legacy ID, not a current-catalog fixture.

## TASK 6 brace-only lint impact

Before adding the nine feature-level braces, upstream impact was checked on the
containing owner symbols:

| Owner symbol | Risk | Direct upstream | Additional evidence |
| --- | --- | ---: | --- |
| `_GuideScreenState` | LOW | 3 | guide screenshot/feature tests and app router |
| `_WrMeaningScreenState` | MEDIUM | 6 | reflection/flow/E2E tests and app router |
| `_WrContextDocScreenState` | LOW | 2 | premium surfaces test and app router |
| `eventTypeLabel` | HIGH | 1 | `buildJourneyEntries`; 3 affected processes, 2 modules |
| `_memoryBreakdown` | LOW | 0 | private helper; no indexed edge |
| `_AudioPlayerBlockState` | LOW | 4 | mood library/meeting tests and app router |
| `_WrPaymentScreenState` | LOW | 3 | payment screen/return tests and app router |
| `_WrSelfCheckScreenState` | LOW | 3 | self-check UI/premium tests and app router |
| `_WrWorkInfoScreenState` | LOW | 2 | growth-opportunity test and app router |

Commands used for each owner:

```text
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests <owner-symbol>
```

The HIGH Journey finding was warned to the lead before editing. The resulting
changes add only control-flow braces; no behavior or string tokens changed.

## TASK 7 D10 display punctuation impact

The refreshed graph was ready before these checks. The exact owning symbols and
upstream blast radius were:

| Owner symbol | File | Risk | Direct upstream | Processes/modules |
| --- | --- | --- | ---: | --- |
| `_JdSection` / `build` | `lib/features/wr/presentation/wr_growth_skills_screen.dart` | LOW | 4 | 1 process, 1 module |
| `_emptyLine` | `lib/features/wr/presentation/wr_journey_narrative_screen.dart` | LOW | 0 indexed callers | none |

```text
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests _JdSection
  risk LOW; impacted 12; direct 4; build process 1; Presentation module 1
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests _emptyLine
  risk LOW; impacted 0; direct 0; no indexed processes/modules
```

No HIGH or CRITICAL result was returned. Four display-string em dashes were
replaced without changing the message meaning: two localized skills messages
now use colons, and two localized narrative messages now use commas. The
remaining em dashes in these files are comments only.

## TASK 7 Deep Reading pending-content compactness

The authorized follow-up changed only `_BodyState.build` in
`lib/features/wr/presentation/wr_sca_deep_dive_screen.dart`.

```text
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests _BodyState
  risk LOW; impacted 25; direct 4; no indexed processes/modules
  direct: wr_sca_deep_dive_screen_test.dart, app_router.dart,
          wr_self_check_screen.dart, wr_discover_screen.dart
```

No HIGH or CRITICAL risk surfaced. When a scored Self-Check exists, the pending
footer is now one line with ellipsis. With no scored Self-Check, the footer is
omitted so it does not duplicate the preserved actionable Self-Check invitation
and button. Premium gating and the invitation route are unchanged.

## TASK 8 no-Self-Check invitation compactness

The bounded follow-up changed the no-Self-Check invitation in
`_BodyState.build` in `lib/features/wr/presentation/wr_sca_deep_dive_screen.dart`.
The invitation copy is concise and constrained with `maxLines: 1` and
`TextOverflow.ellipsis`; its `wr_deep_no_self_check_yet` key, Self-Check action
button, route, and Premium gating remain unchanged. The now-unused question-bank
import was removed as a mechanical consequence of no longer interpolating its
count; no logic or public symbol changed.

```text
npx gitnexus impact -r appmobileworkreflection -d upstream --depth 3 --include-tests _BodyState
  risk LOW; impacted 25; direct 4; no indexed processes/modules
  direct: wr_sca_deep_dive_screen_test.dart, app_router.dart,
          wr_self_check_screen.dart, wr_discover_screen.dart
```

No HIGH or CRITICAL risk surfaced. The authorized scope remained one production
screen; QA tests were not edited.

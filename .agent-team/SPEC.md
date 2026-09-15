# WorkReflection update 14/09/2026

## Mission

Update the Flutter WorkReflection mobile application from the supplied 14/09/2026 content and logic specifications. Integrate the supplied situation library v2, preserve existing user history safely, repair picker and counting semantics, implement the five-rung Deep Reading behavior and layout, remove release-blocking demo state, and run an independent QA review before declaring the software ready for release. Report every unresolved logic, data, build, or manual-release issue to the orchestrator. Do not publish or deploy anything externally in this mission.

## Authoritative inputs

Read all of these before implementation:

- \`/home/duythong/Desktop/FileTam/workreflection/14-09-26/WorkReflection_Changelog_Dot2.docx\`
- \`/home/duythong/Desktop/FileTam/workreflection/14-09-26/WorkReflection _Changelog/SITUATIONS_v2.js\`
- \`/home/duythong/Desktop/FileTam/workreflection/14-09-26/WorkReflection _Changelog/WorkReflection_ThuVien_v2.docx\`
- \`/home/duythong/Desktop/FileTam/workreflection/14-09-26/WorkReflection _Changelog/WorkReflection_DienGiaiSau_v2 (1).docx\`
- \`/home/duythong/Desktop/FileTam/workreflection/14-09-26/WorkReflection _Changelog/WorkReflection_AI_DocGhiChu.docx\`

The JS file is the source of truth for the 72 real situations and the \`other\` custom option. The Word files are the specification and editorial cross-checks. The AI note is future-phase architecture only; it must not cause an AI note-reading feature or an AI API call in this release.

## Fixed stack and constraints

- Flutter 3.x / Dart 3.11, Riverpod, GoRouter, Supabase patterns already present in the repository.
- Keep the existing package and architecture choices. Do not add a dependency without recording a decision and obtaining lead approval.
- Pure business rules stay in framework-free \`lib/core/logic/\` modules and receive unit tests.
- The six check-in moods are \`stress\`, \`tired\`, \`foggy\`, \`outofsync\`, \`ok\`, and \`happy\` as represented by the existing app model.
- New situation semantics are \`pillar\` (\`S\`, \`C\`, \`A\`), \`subgroup\`, \`mood\`, and \`valence\` (\`thach-thuc\` or \`tich-cuc\`). A legacy \`dim\` field/property must not drive runtime logic. Existing database compatibility may be retained only where it does not override the v2 semantics.
- Existing user history must not be destructively deleted. Retired/removed/unknown situation IDs must be filtered or safely classified when read so they cannot crash lookup, counting, or display.
- The team roster requested by the user is: lead/orchestrator Claude Fable alias at low effort; core and UI workers Codex \`gpt-5.6-luna\` at max effort; QA Codex \`gpt-6-astra\` at low effort. If the exact Fable 5.1 identifier is unavailable, the lead must record that the installed Claude \`fable\` alias was used.

## Functional and architecture requirements

1. Replace the offered situation library with the supplied v2 data without retyping its editorial content. There must be 72 real situations plus the custom self-description option. The 72 real records contain 48 \`thach-thuc\` and 24 \`tich-cuc\`; challenge subgroups are balanced at 8 each; all six moods have 12 records each. Every real record must retain its title/story/reflection/self-reflection/aha/practice content and classification fields.

2. Remove the eleven retired IDs from runtime source/data references: \`S1-06\`, \`S1-09\`, \`S2-04\`, \`S2-09\`, \`C1-08\`, \`C2-08\`, \`C2-09\`, \`A1-06\`, \`A1-08\`, \`A3-07\`, \`A3-10\`. Old persisted IDs must be normalized or ignored safely during reads. Do not erase remote history as a shortcut.

3. Update the situation model/repository/seed mapping so v2 \`pillar\`, \`subgroup\`, \`mood\`, \`valence\`, and editorial fields are available to picker, counting, Deep Reading, and display code. Keep the custom \`other\` route working without pretending it belongs to a pillar or valence.

4. Rewrite the check-in picker to take one mood string/enum and use soft priority: three records matching the selected mood plus two records of the same valence from other moods, with no duplicates. Keep the custom self-description choice in the UI. Respect the recent-history rule so a normal run does not repeat a situation within the first ten reflections; test fallback behavior when the available unseen pool is exhausted.

5. Rewrite counting around the new fields. \`pillar\` is used for measurement, \`mood\` is used for check-in filtering, and \`valence\` is kept separate. Career Snapshot appearance counts must include both valences and use the classified denominator. Dominant-pillar and gap calculations must use challenge records only. Unknown/custom/retired records must not inflate a pillar count or cause a crash.

6. Implement and test the Deep Reading priority ladder in this order, using the first matching rung and always providing R5 when there is usable reflection data:

   - R1: top situation count at least 3 and at least 2 ahead of the runner-up.
   - R2: two or three situations sharing subgroup and valence, total at least 5.
   - R3: challenge-only dominant pillar plus Self-Check data.
   - R4: positive share at least 60% or at most 20%.
   - R5: safe fallback naming the most repeated concrete situation, even when it appears only twice or data is evenly distributed.

   Use the supplied v2 Vietnamese variants, rotate variants deterministically, use concrete situation names before abstract pillar text, and never end with “nothing stands out” as the only result. All displayed denominators must match the data being described.

7. Update Deep Reading layout to one main lead block, concrete repeated-situation rows, trend content by situation, and optional collapsed group detail that contains new concrete information. Pending trend/self-check explanations must collapse to one line at the bottom. Do not repeat Career Snapshot rows as the main Premium content.

8. Preserve the reflection invariants in the changelog checklist: selecting “Không đồng ý” still creates/counts the reflection but does not save the draft meaning as an insight; selected practice survives reopening; the journey entry is created with correct type/date; empty Self-Check data is an invitation rather than a Premium blur/lock; partial JD input survives reopening; and no demo buttons or seeded demo state remain in a fresh profile.

9. Do not implement the future “AI đọc ghi chú người dùng” feature in this release. Ensure current data boundaries remain compatible with it later: one note per future call, user-written text remains the durable Career Memory source, generated AI interpretation is not mixed into Career Memory, and any future kill switch remains a design requirement. Existing AI features must keep their current consent and safety behavior.

10. Follow repository \`AGENTS.md\`: before modifying every existing function/class/method, run GitNexus upstream impact analysis and address all d=1 callers; warn the lead before proceeding on HIGH/CRITICAL risk. Before any commit, run GitNexus change detection. When the MCP server is unavailable, use the installed \`npx gitnexus query/context/impact\` CLI and record the limitation.

## Commands

Run these from the repository root, verbatim, after integration and again before completion:

\`\`\`bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
\`\`\`

Focused checks may be run during development, but they do not replace the four commands above. If a command cannot run because of the host environment, record the exact error and do not call the mission green.

## Definition of Done

| ID | Check | Expected result |
|---|---|---|
| D1 | \`flutter pub get\` | Exit 0; dependency graph resolves without an unapproved package change. |
| D2 | \`dart format --output=none --set-exit-if-changed lib test\` | Exit 0; no unformatted Dart files. |
| D3 | \`flutter analyze\` | Exit 0 with no new analyzer errors or warnings in touched code. |
| D4 | \`flutter test\` | Entire existing and new suite passes. |
| D5 | v2 library test | At least 12 named test cases cover 72 real + custom counts, 48/24 valence, six 12-item moods, subgroup balance, removed IDs, and malformed/unknown history. |
| D6 | picker tests | Three same-mood plus two same-valence records are selected without duplicates; custom option remains available; first-ten non-repeat and exhausted-pool fallback are covered. |
| D7 | counting tests | Appearance sums to classified reflections; positive/challenge counts are separate; challenge-only dominant/gap math excludes positive records and safely ignores custom/unknown IDs. |
| D8 | Deep Reading tests | Fixtures prove R1, R2, R3, R4 high/low, and R5 selection plus boundary cases; 15 evenly distributed reflections still produce concrete non-empty R5 content. |
| D9 | Deep Reading widget tests | Main block, concrete loops, trend footer, collapsed group details, and no duplicated Career Snapshot content match the v2 structure. |
| D10 | release-blocker scans | Runtime \`lib\`, \`test\`, and \`assets\` contain no \`s.dim\`/\`json['dim']\`, no retired IDs, no Trust in \`aha\` content, no em-dash display strings, no demo controls, and no demo seed values in initial state. Historical notes may describe retired behavior but must not be runtime data. |
| D11 | reflection flow tests | “Không đồng ý”, practice persistence, journey entry, Self-Check invitation, JD resume, and fresh-profile empty state satisfy the supplied B1-B3 checklist. |
| D12 | QA gate | QA writes \`.agent-team/QA-REPORT.md\`; zero open BLOCKER/MAJOR findings, all QA tests green, and every finding has file:line evidence. |
| D13 | final review | Lead independently reruns all Commands, checks the diff and GitNexus impact scope, and reports any manual device/store checks that were not executable. No external publish/deploy occurs without a separate user instruction. |


# Home Conversational Reveal + Discover Screen Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement conversational reveal flow in WrHomeScreen (mood → Q2 chip → confirmation card + story) and verify Discover screen fixes are complete.

**Architecture:** WrHomeScreen gains 3 new UI steps after mood selection; `WrStoryFlowScreen` gains an optional `initialDimension` query param so Home can deep-link to dimension-filtered stories; Discover screen logic was already fixed in a previous session (tests green, only needs a commit).

**Tech Stack:** Flutter 3.x, Riverpod (FutureProvider), GoRouter, AnimatedSize/AnimatedSwitcher, WrColors design system

---

## Context: What Already Exists vs. What's Missing

### Already DONE (no code changes needed):
- `WrDiscoverScreen` — `_dominantNeedLabel` already returns LOWEST pillar, tiebreak C > S > A, quotes correct, layout centered (no card wrapper), backgroundColor white — 25 tests GREEN.
- `WrHomeScreen` — 2×2 mood grid, auto-save, Q2 chip reveal (AnimatedSize), chips from `wrSituationsProvider`, priority from `wrPatternCountsProvider`, `_saveSituation`, pattern-count guard, "Khác →" nav, error SnackBar, chip error revert, prepopulate from today checkin.

### Missing per spec (must implement):

**A1 — Q2 title for `okay` mood**: spec = `"Có điều gì bạn muốn nhìn lại hôm nay không?"`, current = `"Điều gì giúp bạn giữ được nhịp ổn?"`. Tests in `wr_home_screen_test.dart` line 301–306 assert the OLD text → must update both code AND tests simultaneously.

**A2 — `okay` mood: extra chip "Không, hôm nay ổn"** at the front of chip list. Tapping it → shows "Tuyệt. Hẹn gặp bạn ngày mai." and stops flow (does NOT call `_saveSituation`).

**A3 — Confirmation card after chip save**: replace the current flat text with a `WrCardMinimal` showing:
- `"Nghe như điều bạn đang mong: \"{expectedOutcome}\""` — 15px italic navy
- `scaPerspective` — 13px dark alpha .8, height 1.5
- Memory line (count ≥ 2 vs. first time) — 12px muted

**A4 — Story suggestion with real data**: after chip is saved, load a `WrStory` matching `scaDimension` of the selected situation. Show story card with icon + title + CTA "Đọc câu chuyện này" → `context.push('/wr/story/flow?dimension=X')`. Need to add a `wrSuggestedStoryProvider` in `wr_providers.dart` that accepts `ScaDimension`.

**A5 — `WrStoryFlowScreen` dimension filter**: router needs to read `?dimension=X` query param and pass to `WrStoryFlowScreen`. Currently `WrStoryFlowScreen` has no constructor params and loads all stories. Add `final ScaDimension? initialDimension` constructor param, filter `fetchStories(dimension: initialDimension)` when set.

---

## Pre-Conditions

Before starting: run `flutter analyze lib/ && flutter test` to confirm baseline is 0 errors + all tests pass (excluding `test/widget_test.dart`).

```bash
flutter analyze lib/ 2>&1 | grep -E "error|warning" | wc -l
flutter test --exclude-tags skip 2>&1 | tail -5
```

---

## Task 1: Update Q2 Title for `okay` Mood + Fix Failing Test

**Files:**
- Modify: `lib/features/wr/presentation/wr_home_screen.dart:63-68` (`_MoodOption.q2Title`)
- Modify: `test/features/wr_home_screen_test.dart:301-306` (test asserting old Q2 text)

### Step 1: Update `q2Title` switch in `_MoodOption`

In `lib/features/wr/presentation/wr_home_screen.dart`, find the `q2Title` getter:

```dart
/// Q2 title for this mood
String get q2Title => switch (this) {
      _MoodOption.stressed => 'Điều gì đang khiến bạn căng thẳng?',
      _MoodOption.tired    => 'Bạn mệt vì điều gì?',
      _MoodOption.okay     => 'Điều gì giúp bạn giữ được nhịp ổn?',
      _MoodOption.happy    => 'Điều gì làm bạn vui hôm nay?',
    };
```

Change the `okay` case to:

```dart
_MoodOption.okay     => 'Có điều gì bạn muốn nhìn lại hôm nay không?',
```

### Step 2: Update the test that checks the old okay Q2 text

In `test/features/wr_home_screen_test.dart`, around line 301:

Old test:
```dart
testWidgets('okay → Q2 shows "Điều gì giúp bạn giữ được nhịp ổn?"', (tester) async {
  await _pumpLarge(tester, _wrap(const WrHomeScreen()));
  await tester.tap(find.textContaining('khá ổn'));
  await tester.pumpAndSettle();
  expect(find.text('Điều gì giúp bạn giữ được nhịp ổn?'), findsOneWidget);
});
```

Replace with:
```dart
testWidgets('okay → Q2 shows "Có điều gì bạn muốn nhìn lại hôm nay không?"', (tester) async {
  await _pumpLarge(tester, _wrap(const WrHomeScreen()));
  await tester.tap(find.textContaining('khá ổn'));
  await tester.pumpAndSettle();
  expect(find.text('Có điều gì bạn muốn nhìn lại hôm nay không?'), findsOneWidget);
});
```

Also update the prepopulate test (line ~416) that checks for "okay" mood Q2 text:
Old: `expect(find.text('Điều gì giúp bạn giữ được nhịp ổn?'), findsOneWidget);`
New: `expect(find.text('Có điều gì bạn muốn nhìn lại hôm nay không?'), findsOneWidget);`

### Step 3: Run tests to verify

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection
flutter test test/features/wr_home_screen_test.dart 2>&1 | tail -5
```

Expected: All pass.

### Step 4: Commit

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection
git add lib/features/wr/presentation/wr_home_screen.dart test/features/wr_home_screen_test.dart
git commit -m "fix(wr-ui): Q2 text cho okay mood → spec DataSpec v3"
```

---

## Task 2: Add "Không, hôm nay ổn" chip for `okay` mood

**Files:**
- Modify: `lib/features/wr/presentation/wr_home_screen.dart` (state + chips + render)
- Modify: `test/features/wr_home_screen_test.dart` (add new tests)

### Step 1: Write the failing tests first

Add these tests to `test/features/wr_home_screen_test.dart`, inside the `'WrHomeScreen — Q2 conversational reveal'` group, before the closing `});`:

```dart
testWidgets('okay mood → "Không, hôm nay ổn" chip shown as first chip', (tester) async {
  await _pumpLarge(tester, _wrap(const WrHomeScreen()));
  await tester.tap(find.textContaining('khá ổn'));
  await tester.pumpAndSettle();
  expect(find.text('Không, hôm nay ổn'), findsOneWidget);
});

testWidgets('tap "Không, hôm nay ổn" → shows closing message, no record call', (tester) async {
  final intel = FakeWrIntelligenceRepository();
  await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel));
  await tester.tap(find.textContaining('khá ổn'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Không, hôm nay ổn'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Tuyệt. Hẹn gặp bạn ngày mai.'), findsOneWidget);
  expect(intel.recordSituationOccurrenceCalls, isEmpty);
});

testWidgets('stressed mood → "Không, hôm nay ổn" chip NOT shown', (tester) async {
  await _pumpLarge(tester, _wrap(const WrHomeScreen()));
  await tester.tap(find.textContaining('căng thẳng'));
  await tester.pumpAndSettle();
  expect(find.text('Không, hôm nay ổn'), findsNothing);
});
```

### Step 2: Run tests to verify they fail

```bash
flutter test test/features/wr_home_screen_test.dart 2>&1 | grep -E "FAILED|PASS|error" | head -10
```

Expected: The 3 new tests FAIL.

### Step 3: Add `_okayDone` state and update render logic

In `_WrHomeScreenState`, add a new state variable after line 106 (`_savingSituation`):

```dart
bool _okayDone = false; // true = user tapped "Không, hôm nay ổn"
```

Update the chip list rendering in the `AnimatedSize` child. Currently the chips are built with:
```dart
children: [
  ...q2Chips.map(...),  // real chips
  GestureDetector(...)  // "Khác →"
]
```

Replace with logic that prepends the "Không, hôm nay ổn" chip when `_selected == _MoodOption.okay && !_okayDone`:

The full updated `Wrap` children should be:
```dart
children: [
  // "Không, hôm nay ổn" chip — only for okay mood, before normal chips
  if (_selected == _MoodOption.okay)
    GestureDetector(
      onTap: () => setState(() { _okayDone = true; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: WrColors.cream,
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'Không, hôm nay ổn',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: WrColors.navy),
        ),
      ),
    ),
  // Real situation chips (up to 5) — only when NOT okayDone
  if (!_okayDone)
    ...q2Chips.map((sit) => GestureDetector(
          onTap: () => _saveSituation(sit),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedSituationCode == sit.code
                  ? WrColors.coral
                  : WrColors.cream,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              sit.text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _selectedSituationCode == sit.code
                    ? WrColors.white
                    : WrColors.navy,
              ),
            ),
          ),
        )),
  // "Khác →" chip — only when NOT okayDone
  if (!_okayDone)
    GestureDetector(
      onTap: () => context.push('/wr/situation'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: WrColors.cream,
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'Khác →',
          style: TextStyle(fontSize: 13, color: WrColors.navy),
        ),
      ),
    ),
],
```

After the Wrap, add the okayDone message and update the existing `if (_situationSaved)` block:

Replace the existing:
```dart
if (_situationSaved) ...[
  const SizedBox(height: 8),
  Text(
    _situationCount >= 2
        ? 'Hệ thống đã ghi nhớ — đây là lần thứ $_situationCount bạn chia sẻ điều này.'
        : 'Cảm ơn bạn đã chia sẻ. Hệ thống sẽ ghi nhớ điều này.',
    style: const TextStyle(
      fontSize: 14,
      color: WrColors.muted,
      height: 1.5,
    ),
  ),
],
```

With:
```dart
// Okay + "Không, hôm nay ổn" → closing line
if (_okayDone) ...[
  const SizedBox(height: 12),
  const Text(
    'Tuyệt. Hẹn gặp bạn ngày mai.',
    style: TextStyle(
      fontSize: 14,
      color: WrColors.muted,
      height: 1.5,
    ),
  ),
],
```

(The confirmation card for real chip saves will be added in Task 3.)

Also reset `_okayDone` when mood changes — in `_save()`, add `_okayDone = false;` inside the `setState` at the top of `_save`:

```dart
setState(() {
  _selected = option;
  _saving = true;
  _pendingOption = null;
  _okayDone = false;        // ← add this
  _situationSaved = false;  // ← add this (reset chip state on mood change)
  _selectedSituationCode = null;
});
```

### Step 4: Run tests to verify they pass

```bash
flutter test test/features/wr_home_screen_test.dart 2>&1 | tail -5
```

Expected: All pass.

### Step 5: Commit

```bash
git add lib/features/wr/presentation/wr_home_screen.dart test/features/wr_home_screen_test.dart
git commit -m "feat(wr-ui): okay mood chip 'Không hôm nay ổn' → closing line, no record"
```

---

## Task 3: Confirmation Card (expectedOutcome + scaPerspective + memory line)

**Files:**
- Modify: `lib/features/wr/presentation/wr_home_screen.dart` (replace flat text with WrCardMinimal)
- Modify: `test/features/wr_home_screen_test.dart` (add card content tests)

### Step 1: Write failing tests

In `test/features/wr_home_screen_test.dart`, add to the Q2 conversational reveal group:

```dart
testWidgets('confirmation card shows expectedOutcome italic after chip save', (tester) async {
  final content = FakeWrContentRepository();
  content.seedSituations([
    WrSituation(
      code: 'sit-01',
      text: 'Áp lực deadline',
      scaDimension: ScaDimension.s1,
      wave: 2,
      expectedOutcome: 'Được hiểu và hỗ trợ kịp thời',
    ),
  ]);
  final intel = FakeWrIntelligenceRepository();
  await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
  await tester.tap(find.textContaining('mệt mỏi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Áp lực deadline'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Nghe như điều bạn đang mong'), findsOneWidget);
  expect(find.textContaining('Được hiểu và hỗ trợ kịp thời'), findsOneWidget);
});

testWidgets('confirmation card shows scaPerspective after chip save', (tester) async {
  final content = FakeWrContentRepository();
  content.seedSituations([
    WrSituation(
      code: 'sit-01',
      text: 'Áp lực deadline',
      scaDimension: ScaDimension.s1,
      wave: 2,
      scaPerspective: 'Bạn đang cần rõ ràng về kỳ vọng',
    ),
  ]);
  final intel = FakeWrIntelligenceRepository();
  await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
  await tester.tap(find.textContaining('mệt mỏi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Áp lực deadline'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Bạn đang cần rõ ràng về kỳ vọng'), findsOneWidget);
});

testWidgets('confirmation card memory line — first time (count < 2)', (tester) async {
  final content = FakeWrContentRepository();
  content.seedSituations([
    WrSituation(code: 'sit-01', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
  ]);
  final intel = FakeWrIntelligenceRepository();
  await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
  await tester.tap(find.textContaining('mệt mỏi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Áp lực deadline'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Hệ thống sẽ ghi nhớ điều này cho hành trình của bạn.'), findsOneWidget);
});

testWidgets('confirmation card memory line — repeat (count >= 2)', (tester) async {
  final content = FakeWrContentRepository();
  content.seedSituations([
    WrSituation(code: 'sit-01', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
  ]);
  final intel = FakeWrIntelligenceRepository();
  intel.seedPatternCounts([
    PatternCount(userId: 'u1', situationCode: 'sit-01', occurrenceCount: 1, lastSeenAt: DateTime(2026, 7, 20)),
  ]);
  await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
  await tester.tap(find.textContaining('mệt mỏi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Áp lực deadline'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Hệ thống đã ghi nhớ — đây là lần thứ 2 bạn gặp tình huống này.'), findsOneWidget);
});
```

**Important**: note the new memory line texts differ from old ones:
- Old first-time: `'Cảm ơn bạn đã chia sẻ. Hệ thống sẽ ghi nhớ điều này.'`
- New first-time: `'Hệ thống sẽ ghi nhớ điều này cho hành trình của bạn.'`
- Old repeat: `'Hệ thống đã ghi nhớ — đây là lần thứ $_situationCount bạn chia sẻ điều này.'`
- New repeat: `'Hệ thống đã ghi nhớ — đây là lần thứ {N} bạn gặp tình huống này.'`

Also update the 2 existing tests that check the old confirmation text (lines 364, 389):

Old line 364: `expect(find.textContaining('Cảm ơn bạn đã chia sẻ. Hệ thống sẽ ghi nhớ điều này.'), findsOneWidget);`
New: `expect(find.textContaining('Hệ thống sẽ ghi nhớ điều này cho hành trình của bạn.'), findsOneWidget);`

Old line 389: `expect(find.textContaining('Hệ thống đã ghi nhớ — đây là lần thứ 2 bạn chia sẻ điều này.'), findsOneWidget);`
New: `expect(find.textContaining('Hệ thống đã ghi nhớ — đây là lần thứ 2 bạn gặp tình huống này.'), findsOneWidget);`

### Step 2: Run tests to verify they fail

```bash
flutter test test/features/wr_home_screen_test.dart 2>&1 | grep -E "FAILED|error" | head -10
```

### Step 3: Add `_selectedSituation` state and implement confirmation card

In `_WrHomeScreenState`, add a new state field (after `_savingSituation`):
```dart
WrSituation? _selectedSituation;  // full WrSituation after chip save, for card
```

Update `_saveSituation` to store the full `WrSituation`:
```dart
// In the try block after saving, before the setState:
_selectedSituation = sit;  // store for confirmation card
```

And in the error catch, reset:
```dart
setState(() { _savingSituation = false; _selectedSituationCode = null; _selectedSituation = null; });
```

Now replace the `if (_okayDone) ... if (_situationSaved)` block with the full confirmation card:

```dart
// "Không, hôm nay ổn" closing line
if (_okayDone) ...[
  const SizedBox(height: 12),
  const Text(
    'Tuyệt. Hẹn gặp bạn ngày mai.',
    style: TextStyle(fontSize: 14, color: WrColors.muted, height: 1.5),
  ),
],

// Confirmation card after chip save
if (_situationSaved && _selectedSituation != null) ...[
  const SizedBox(height: 16),
  WrCardMinimal(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // expectedOutcome line
        if (_selectedSituation!.expectedOutcome != null)
          Text(
            'Nghe như điều bạn đang mong: "${_selectedSituation!.expectedOutcome}"',
            style: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: WrColors.navy,
              height: 1.5,
            ),
          ),
        if (_selectedSituation!.expectedOutcome != null && _selectedSituation!.scaPerspective != null)
          const SizedBox(height: 10),
        // scaPerspective line
        if (_selectedSituation!.scaPerspective != null)
          Text(
            _selectedSituation!.scaPerspective!,
            style: TextStyle(
              fontSize: 13,
              color: WrColors.dark.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        const SizedBox(height: 10),
        // Memory line
        Text(
          _situationCount >= 2
              ? 'Hệ thống đã ghi nhớ — đây là lần thứ $_situationCount bạn gặp tình huống này.'
              : 'Hệ thống sẽ ghi nhớ điều này cho hành trình của bạn.',
          style: const TextStyle(
            fontSize: 12,
            color: WrColors.muted,
          ),
        ),
      ],
    ),
  ),
],
```

Check that `WrColors.dark` is defined. If not, find the right color constant for dark text:

```bash
grep -n "dark" /home/duythong/Documents/DuyThong/appmobileworkreflection/lib/core/theme/wr_colors.dart
```

### Step 4: Run tests

```bash
flutter test test/features/wr_home_screen_test.dart 2>&1 | tail -5
```

Expected: All pass.

### Step 5: Commit

```bash
git add lib/features/wr/presentation/wr_home_screen.dart test/features/wr_home_screen_test.dart
git commit -m "feat(wr-ui): confirmation card — expectedOutcome + scaPerspective + memory line"
```

---

## Task 4: Story Suggestion Matching `scaDimension`

This task adds a provider `wrStoriesByDimensionProvider` and updates the home screen story section to show a real matched story after chip save.

**Files:**
- Modify: `lib/features/wr/wr_providers.dart` (add `wrStoriesByDimensionProvider`)
- Modify: `lib/features/wr/presentation/wr_home_screen.dart` (consume story + update card)
- Modify: `lib/core/router/app_router.dart` (add `?dimension=X` query param to `/wr/story/flow` route)
- Modify: `lib/features/wr/presentation/wr_story_flow_screen.dart` (read `initialDimension` from route)
- Modify: `test/features/wr_home_screen_test.dart` (story suggestion tests)

### Step 4.1: Run impact analysis on `WrStoryFlowScreen`

Before editing, run impact analysis. This can be done via the GitNexus MCP tool `mcp__gitnexus__impact` with target `"WrStoryFlowScreen"`, direction `"upstream"`. Report results. If risk is HIGH/CRITICAL, warn before proceeding.

### Step 4.2: Write failing tests for story suggestion

Add to `test/features/wr_home_screen_test.dart` a new group `'WrHomeScreen — story suggestion after chip save'`:

```dart
group('WrHomeScreen — story suggestion after chip save', () {
  testWidgets('story card shows title matching situation scaDimension', (tester) async {
    final content = FakeWrContentRepository();
    content.seedSituations([
      WrSituation(code: 'sit-s1', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
    ]);
    content.seedStories([
      WrStory(
        storyId: 'st-s1-01',
        title: 'Câu chuyện S1',
        scaDimension: ScaDimension.s1,
        storyContent: 'content',
        emotionTags: const [],
        behaviorTags: const [],
        careerStages: const [],
      ),
      WrStory(
        storyId: 'st-c1-01',
        title: 'Câu chuyện C1',
        scaDimension: ScaDimension.c1,
        storyContent: 'content',
        emotionTags: const [],
        behaviorTags: const [],
        careerStages: const [],
      ),
    ]);
    final intel = FakeWrIntelligenceRepository();
    await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
    await tester.tap(find.textContaining('mệt mỏi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp lực deadline'));
    await tester.pumpAndSettle();
    // Story matching S1 should appear
    expect(find.textContaining('Câu chuyện S1'), findsOneWidget);
    expect(find.textContaining('Câu chuyện C1'), findsNothing);
  });

  testWidgets('story CTA button "Đọc câu chuyện này" shown after chip save', (tester) async {
    final content = FakeWrContentRepository();
    content.seedSituations([
      WrSituation(code: 'sit-s1', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
    ]);
    content.seedStories([
      WrStory(
        storyId: 'st-s1-01',
        title: 'Câu chuyện S1',
        scaDimension: ScaDimension.s1,
        storyContent: 'content',
        emotionTags: const [],
        behaviorTags: const [],
        careerStages: const [],
      ),
    ]);
    final intel = FakeWrIntelligenceRepository();
    await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
    await tester.tap(find.textContaining('mệt mỏi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp lực deadline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đọc câu chuyện này'), findsOneWidget);
  });

  testWidgets('eyebrow GỢI Ý CHO BẠN shown after chip save', (tester) async {
    final content = FakeWrContentRepository();
    content.seedSituations([
      WrSituation(code: 'sit-s1', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
    ]);
    content.seedStories([
      WrStory(
        storyId: 'st-s1-01',
        title: 'Câu chuyện S1',
        scaDimension: ScaDimension.s1,
        storyContent: 'content',
        emotionTags: const [],
        behaviorTags: const [],
        careerStages: const [],
      ),
    ]);
    final intel = FakeWrIntelligenceRepository();
    await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
    await tester.tap(find.textContaining('mệt mỏi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp lực deadline'));
    await tester.pumpAndSettle();
    expect(find.text('GỢI Ý CHO BẠN'), findsOneWidget);
  });
});
```

Also add `/wr/story/flow` route to the router in `_makeRouter` helper in the test file:
```dart
GoRoute(
  path: '/wr/story/flow',
  builder: (_, __) => const Scaffold(body: Text('StoryFlowScreen')),
),
```

### Step 4.3: Add `wrStoriesByDimensionProvider` to `wr_providers.dart`

In `lib/features/wr/wr_providers.dart`, add at the bottom:

```dart
/// Fetch stories filtered by [ScaDimension]. Used by WrHomeScreen after chip save.
/// Returns empty list when dimension is null.
final wrStoriesByDimensionProvider = FutureProvider.family<List<WrStory>, ScaDimension?>((ref, dimension) async {
  if (dimension == null) return const [];
  final repo = ref.watch(wrContentRepositoryProvider);
  return repo.fetchStories(dimension: dimension);
});
```

### Step 4.4: Update `WrHomeScreen` to show real story after chip save

In `_WrHomeScreenState`:

1. Add state field: `WrStory? _suggestedStory;`

2. In `_saveSituation`, after setting `_selectedSituation = sit;`, fetch first matching story:
```dart
// Fetch story suggestion for this dimension
final storyRepo = ref.read(wrContentRepositoryProvider);
final stories = await storyRepo.fetchStories(dimension: sit.scaDimension);
_suggestedStory = stories.isNotEmpty ? stories.first : null;
```
Add inside the `if (mounted)` setState block: `_suggestedStory = suggestedStory;` (use a local variable pattern like existing code).

3. Replace the static story card section. Find the existing story section (around line 494–555):

```dart
// ── section gợi ý story ───────────────────────────────────────────
SliverToBoxAdapter(
  child: Padding(
    padding: EdgeInsets.fromLTRB(24, topPattern != null ? 0 : 28, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(storyEyebrow),
        const SizedBox(height: 10),
        WrCardMinimal(
          child: Row(
            // ... static content ...
          ),
        ),
        const SizedBox(height: 8),
        WrActionLink(
          label: 'Đọc câu chuyện đầu tiên',
          onTap: () => context.push('/wr/story'),
        ),
        const SizedBox(height: 28),
      ],
    ),
  ),
),
```

Replace with:
```dart
// ── section gợi ý story ───────────────────────────────────────────
SliverToBoxAdapter(
  child: Padding(
    padding: EdgeInsets.fromLTRB(24, topPattern != null ? 0 : 28, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(storyEyebrow),
        const SizedBox(height: 10),
        WrCardMinimal(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon ô 48×48
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: WrColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_outlined, color: WrColors.navy, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _suggestedStory != null
                          ? _suggestedStory!.title
                          : 'Bạn chưa đọc câu chuyện nào.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: WrColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _suggestedStory != null
                          ? (_suggestedStory!.situation ?? 'Câu chuyện giúp bạn nhận ra pattern nghề nghiệp.')
                          : 'Câu chuyện giúp bạn nhận ra pattern nghề nghiệp.',
                      style: const TextStyle(fontSize: 13, color: WrColors.muted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        WrActionLink(
          label: _suggestedStory != null ? 'Đọc câu chuyện này' : 'Đọc câu chuyện đầu tiên',
          onTap: () {
            if (_suggestedStory != null && _selectedSituation != null) {
              context.push('/wr/story/flow?dimension=${_selectedSituation!.scaDimension.dbValue}');
            } else {
              context.push('/wr/story');
            }
          },
        ),
        const SizedBox(height: 28),
      ],
    ),
  ),
),
```

### Step 4.5: Update `WrStoryFlowScreen` to accept `initialDimension`

In `lib/features/wr/presentation/wr_story_flow_screen.dart`:

1. Change constructor to accept optional `initialDimension`:
```dart
class WrStoryFlowScreen extends ConsumerStatefulWidget {
  const WrStoryFlowScreen({super.key, this.initialDimension});
  
  final ScaDimension? initialDimension;

  @override
  ConsumerState<WrStoryFlowScreen> createState() => _WrStoryFlowScreenState();
}
```

2. In `_loadStories()`, pass `initialDimension` to `fetchStories`:
```dart
final allStories = await contentRepo.fetchStories(dimension: widget.initialDimension);
```

### Step 4.6: Update router to pass `?dimension` to `WrStoryFlowScreen`

In `lib/core/router/app_router.dart`, find the `/wr/story/flow` route:

```dart
GoRoute(
  path: '/wr/story/flow',
  builder: (context, state) => const WrStoryFlowScreen(),
),
```

Change to:
```dart
GoRoute(
  path: '/wr/story/flow',
  builder: (context, state) {
    final dimStr = state.uri.queryParameters['dimension'];
    final dim = dimStr != null
        ? ScaDimension.fromDb(dimStr)
        : null;
    return WrStoryFlowScreen(initialDimension: dim);
  },
),
```

Add import for `wr_content.dart` if not already present in `app_router.dart`:
```dart
import '../../core/models/wr_content.dart';
```

### Step 4.7: Run tests

```bash
flutter analyze lib/ 2>&1 | grep "error" | wc -l  # must be 0
flutter test test/features/wr_home_screen_test.dart 2>&1 | tail -5
```

### Step 4.8: Commit

```bash
git add lib/features/wr/wr_providers.dart \
        lib/features/wr/presentation/wr_home_screen.dart \
        lib/features/wr/presentation/wr_story_flow_screen.dart \
        lib/core/router/app_router.dart \
        test/features/wr_home_screen_test.dart
git commit -m "feat(wr-ui): story gợi ý theo scaDimension + WrStoryFlowScreen dimension filter"
```

---

## Task 5: Final Gates + TASK A Commit

### Step 5.1: Run full test suite

```bash
flutter test 2>&1 | tail -10
```

Expected: All tests pass (excluding `test/widget_test.dart` which is untracked and broken by design).

If `test/widget_test.dart` causes issues:
```bash
flutter test --exclude-tags skip $(find test -name "*.dart" ! -path "test/widget_test.dart") 2>&1 | tail -10
```

### Step 5.2: Run analyze

```bash
flutter analyze lib/ 2>&1 | grep -E "^error"
```

Expected: 0 errors.

### Step 5.3: Run detect_changes (GitNexus)

Use `mcp__gitnexus__detect_changes` with scope `"staged"` to verify only expected files changed.

### Step 5.4: Create final TASK A commit

If all gates green:
```bash
git add lib/features/wr/presentation/wr_home_screen.dart \
        lib/features/wr/wr_providers.dart \
        lib/features/wr/presentation/wr_story_flow_screen.dart \
        lib/core/router/app_router.dart \
        test/features/wr_home_screen_test.dart
git commit -m "feat(wr-ui): Home hỏi tuần tự check-in → tình huống → xác nhận → story (DataSpec v3)"
```

---

## Task 6: TASK B — Verify + Commit Discover Screen Fixes

Task B was already implemented in a previous session. The `wr_discover_screen_restyle_test.dart` has 25 tests — all GREEN. No code changes needed.

### Step 6.1: Verify tests pass

```bash
flutter test test/features/wr_discover_screen_restyle_test.dart 2>&1 | tail -3
```

Expected: `+25: All tests passed!`

### Step 6.2: Run detect_changes for discover screen

Use `mcp__gitnexus__detect_changes` with scope `"all"` to see what changed on branch vs main.

### Step 6.3: Create TASK B commit

```bash
git add lib/features/wr/presentation/wr_discover_screen.dart \
        test/features/wr_discover_screen_restyle_test.dart
git commit -m "fix(wr-ui): Hiểu mình — nhu cầu = trụ thấp nhất, quote thật, layout mockup"
```

Note: If `wr_discover_screen.dart` has no uncommitted changes (already committed previously), check `git status` first and only add files with actual changes.

---

## Task 7: Final Full Test Run + Report

```bash
flutter test $(find test -name "*.dart" -not -name "widget_test.dart") 2>&1 | tail -5
flutter analyze lib/ 2>&1 | tail -3
git log --oneline -5
```

Report:
1. Number of tests that ran and passed
2. SHA of each commit
3. Any deviations from spec + reasoning

---

## Important Notes for Implementer

1. **`WrColors.dark`** — check if this constant exists in `lib/core/theme/wr_colors.dart`. If it doesn't, use `const Color(0xFF1A1A2E)` or find the correct dark color used elsewhere in the codebase (e.g., `_ScaItem` uses `WrColors.dark` in `wr_discover_screen.dart` line 524 — copy from there).

2. **`WrSituation` with nullable fields** — `expectedOutcome` and `scaPerspective` are `String?`. The confirmation card must handle nulls gracefully (use `if (field != null)` guards).

3. **`_suggestedStory` fetch in `_saveSituation`** — do NOT use `ref.watch` inside `_saveSituation` (it's a `Future` method, not `build`). Use `ref.read(wrContentRepositoryProvider)` and call `fetchStories(dimension: sit.scaDimension)` directly.

4. **Do NOT commit**: `linux/`, `macos/`, `web/`, `windows/`, `.metadata`, `test/widget_test.dart`.

5. **gitnexus impact**: Before modifying `WrStoryFlowScreen`, run impact upstream. The `WrStoryFlowScreen` constructor change is a breaking change for callers — check the router and any other pushes to `/wr/story/flow`.

6. **FakeWrIntelligenceRepository behavior**: When `recordSituationOccurrence` is called, the fake increments the seeded count. Check `test/support/fake_wr_intelligence_repository.dart` to confirm this behavior before writing count-related tests.

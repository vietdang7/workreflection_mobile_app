# Task 2A + 2B: Home & Understand Tab Restyle

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restyle `WrHomeScreen` (Home tab) và `UnderstandScreen` (Understand tab) để khớp 100% với HTML design system trong `complete-flow-fixed (4).html`.

**Architecture:**
- Task 2A: Thay toàn bộ `wr_home_screen.dart` — header đảo chiều (greeting nhỏ trên, date-title lớn dưới), checkin 2×2 grid với 4 Mood buttons, 3 sections mới (system-recognition card, suggestion card, insight quote). Dữ liệu system-recognition dùng `homeSystemNoticeQuote` ARB + `recurringSituationsProvider` (lấy top situation). Suggestion card dùng static placeholder (chưa có backend story provider). Insight dùng `latestInsightProvider` từ `home_providers.dart`.
- Task 2B: `UnderstandScreen` ĐÃ khớp HTML design gần như hoàn toàn — chỉ cần kiểm tra spacing, thêm `WrSectionDivider` giữa các block, và align style với design tokens. Không xóa logic hiện tại.

**Tech Stack:** Flutter 3.x, Riverpod, `WrTextStyles`, `WrColors`, `WrCardMinimal`, `WrCardDark`, `WrActionLink`, `WrEyebrow`, `WrProgressTrack`, `WrSectionDivider` (tất cả đã có sẵn trong `lib/core/widgets/` và `lib/core/theme/`)

---

## Context: Design Tokens (từ HTML)

```
Colors:
  navy:  #093774  (WrColors.navy — MATCH)
  coral: #FF6859  (WrColors.coral — MATCH)
  teal:  #15B5B0  (WrColors.teal — MATCH)
  cream: #FFF3E6  (WrColors.cream — MATCH)
  dark:  #2C335D  (WrColors.dark — MATCH)
  muted: #8A95A3  (WrColors.muted — MATCH)
  bg:    #FFF3E6  (= cream)

Text styles (tất cả đã có trong WrTextStyles):
  greeting:   fontSize:14, w400, color:muted
  dateTitle:  fontSize:32, w800, color:navy
  eyebrow:    fontSize:11, w700, letterSpacing:0.55, muted, uppercase
  hLarge:     fontSize:22, w700, color:navy
  hMedium:    fontSize:16, w600, color:dark
  body:       fontSize:14, color:dark×0.8, height:1.5
  insightQuote: fontSize:20, italic, color:navy, height:1.45

Layout:
  top-area padding: fromLTRB(24, 8, 24, 16)
  content-pad: horizontal:24, bottom:80, gap between blocks: 28
  checkin-grid: 2 columns, gap:12
  checkin-btn: cream bg, borderRadius:16, padding: vertical:16 horizontal:12
  checkin-btn.selected: coral bg, white text
  card-minimal: WrCardMinimal (cream, radius:20, padding:20) — ĐÃ CÓ
  card-system: WrCardDark (navy, radius:20, padding:20) — ĐÃ CÓ
  divider: WrSectionDivider — ĐÃ CÓ
  action-link: WrActionLink — ĐÃ CÓ
```

---

## Context: Providers Available

```dart
// lib/features/wr/wr_providers.dart
final todayCheckinProvider = FutureProvider<Checkin?>(...); // getTodayCheckin()
final wrEntitlementProvider = FutureProvider<WrEntitlement>(...);
final currentUserIdProvider = Provider<String?>(...);

// lib/features/home/home_providers.dart (IMPORT FILE NÀY)
final latestInsightProvider = FutureProvider<Insight?>(...); // getLatestInsight()
final recurringSituationsProvider = FutureProvider<List<RecurringSituation>>(...); // getRecurringSituations()

// lib/features/understand/understand_providers.dart
final understandLatestInsightProvider = FutureProvider<Insight?>(...);
final understandSituationsProvider = FutureProvider<List<RecurringSituation>>(...);
final understandScaReportProvider = FutureProvider<ScaReport?>(...);
final understandInsightCountProvider = FutureProvider<int>(...);

// lib/features/survey/survey_providers.dart
final latestReportProvider = FutureProvider<CcReportFull?>(...);
```

## Context: Checkin Model

```dart
// lib/core/models/checkin.dart
enum Mood { stressed, tired, okay, happy }
enum CheckinEnergy { good, ok, low }
enum CheckinDirection { forward, steady, backward }

class Checkin {
  final Mood mood;
  final CheckinEnergy? energy;
  final CheckinDirection? direction;
  // ...
}
```

## Context: ARB Keys Already Exist

```
// Home screen (lib/l10n/app_vi.arb)
homeGreeting: "Chào {name}"
homeCheckinQuestion: "Bạn đang trải qua điều gì?"
homeMoodStressed: "Tôi đang căng thẳng"
homeMoodTired: "Tôi mệt mỏi cần nghỉ ngơi"
homeMoodOkay: "Tôi khá ổn"
homeMoodHappy: "Tôi đang vui"
homeEyebrowSystem: "Hệ thống nhận ra"
homeEyebrowSuggestion: "Gợi ý khi mệt mỏi"
homeEyebrowInsight: "Insight gần nhất"
homeLinkLearnMore: "Tìm hiểu thêm"
homeSuggestionTitle: "Khi bạn muốn nói nhưng chọn im lặng"
homeSuggestionMeta: "VOICE · 5 phút đọc"
homeSuggestionProgress: "3/8 phút"
homeSuggestionStatus: "Đang đọc"
homeInsightSavedDate: "Lưu ngày {date}"
homeSystemNoticeQuote: "\"Đây là lần thứ {n} bạn gặp tình huống {label}.\""
homeInsightEmpty: "Chưa có insight nào. Hãy bắt đầu hành trình của bạn!"
homeErrorLoadData: "Không thể tải dữ liệu."
homeRetry: "Thử lại"

// Understand screen (đã đủ, không thay đổi)
understandGreeting: "Career Snapshot"
understandTitle: "Hiểu mình"
understandEyebrowNeed, understandEyebrowSituations, understandEyebrowSca, understandEyebrowHealth
understandScaRole, understandScaVoice, understandScaMeaning
understandStatusStable, understandStatusImproving, understandStatusUnrated, understandStatusNeedsAttention
```

## Context: Files To Modify

- **Task 2A** (rewrite): `lib/features/wr/presentation/wr_home_screen.dart`
- **Task 2A** (update tests): `test/features/wr_home_screen_test.dart`
- **Task 2B** (small edit): `lib/features/understand/presentation/understand_screen.dart`
- **Task 2B** (tests likely still pass): `test/features/understand_test.dart`

---

## Task 1: Rewrite WrHomeScreen — Header + Check-in Grid

**Goal:** Đổi header (greeting nhỏ → date lớn) và thay checkin 2-row chips bằng 2×2 Mood grid.

**Files:**
- Modify: `lib/features/wr/presentation/wr_home_screen.dart` (toàn bộ rewrite)
- Modify: `test/features/wr_home_screen_test.dart` (update existing tests, add mood grid tests)

**Step 1: Viết test thất bại cho header mới**

Trong `test/features/wr_home_screen_test.dart`, thêm vào group `WrHomeScreen — header`:

```dart
testWidgets('header: greeting text is small, above date', (tester) async {
  final wr = FakeWrRepository()..seedProfile(_profile(name: 'Yumi'));
  await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
  // Greeting small above
  expect(find.textContaining('Chào Yumi'), findsOneWidget);
  // Date large below — format: "Thứ Ba, 24 tháng 6" or similar
  expect(find.byKey(const Key('home_date_title')), findsOneWidget);
});
```

**Step 2: Chạy test để verify thất bại**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection
flutter test test/features/wr_home_screen_test.dart -v
```

Expected: FAIL `home_date_title` not found.

**Step 3: Viết test thất bại cho 2×2 mood grid**

Trong `test/features/wr_home_screen_test.dart`, thêm group mới:

```dart
group('WrHomeScreen — mood grid', () {
  testWidgets('renders 4 mood buttons', (tester) async {
    await _pumpLarge(tester, _wrap(const WrHomeScreen()));
    expect(find.text('Tôi đang căng thẳng'), findsOneWidget);
    expect(find.text('Tôi mệt mỏi cần nghỉ ngơi'), findsOneWidget);
    expect(find.text('Tôi khá ổn'), findsOneWidget);
    expect(find.text('Tôi đang vui'), findsOneWidget);
  });

  testWidgets('tapping mood saves check-in immediately', (tester) async {
    final wr = FakeWrRepository();
    await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
    await tester.tap(find.text('Tôi đang vui'));
    await tester.pumpAndSettle();
    expect(wr.upsertCheckinCalls, contains(Mood.happy));
  });

  testWidgets('selected mood button has coral background', (tester) async {
    await _pumpLarge(tester, _wrap(const WrHomeScreen()));
    await tester.tap(find.text('Tôi khá ổn'));
    await tester.pump();
    // find the key for the selected button
    expect(find.byKey(const Key('mood_btn_okay_selected')), findsOneWidget);
  });

  testWidgets('old energy/direction chips are GONE', (tester) async {
    await _pumpLarge(tester, _wrap(const WrHomeScreen()));
    expect(find.text('Có năng lượng'), findsNothing);
    expect(find.text('Tiến lên'), findsNothing);
    expect(find.text('Lưu check-in'), findsNothing); // no save button
  });

  testWidgets('shows saved check-in date when todayCheckin exists', (tester) async {
    final wr = FakeWrRepository();
    final now = DateTime.now();
    wr.seedTodayCheckin(Checkin(
      id: 'c1', userId: 'u1', mood: Mood.okay,
      checkinDate: DateTime(now.year, now.month, now.day),
      createdAt: now,
    ));
    await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
    // Mood.okay → button "Tôi khá ổn" should appear selected
    expect(find.byKey(const Key('mood_btn_okay_selected')), findsOneWidget);
  });
});
```

**Step 4: Chạy tests để verify thất bại**

```bash
flutter test test/features/wr_home_screen_test.dart -v
```

Expected: FAIL — old labels still found, mood_btn_okay_selected not found.

**Step 5: Xóa `_CheckinCard`, `_OptionChip`, `_SavedBadge`, `_ShareCard` — Viết lại `wr_home_screen.dart`**

Rewrite hoàn toàn file. Cấu trúc mới:

```dart
// lib/features/wr/presentation/wr_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/mobile_profile.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/home_providers.dart';
import '../wr_providers.dart';

class WrHomeScreen extends ConsumerStatefulWidget {
  const WrHomeScreen({super.key});
  @override
  ConsumerState<WrHomeScreen> createState() => _WrHomeScreenState();
}

class _WrHomeScreenState extends ConsumerState<WrHomeScreen> {
  Mood? _selectedMood;
  bool _saving = false;

  String _dateLabel() {
    final now = todayVn();
    final weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return '${weekdays[now.weekday - 1]}, ${now.day}/${now.month}';
  }

  Future<void> _selectMood(Mood mood) async {
    setState(() { _selectedMood = mood; _saving = true; });
    try {
      await ref.read(wrRepositoryProvider).upsertCheckin(mood);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final todayCheckinAsync = ref.watch(todayCheckinProvider);
    final profileAsync = ref.watch(_mobileProfileProvider);

    // Pre-populate selected mood from today's existing check-in
    todayCheckinAsync.whenData((checkin) {
      if (checkin != null && _selectedMood == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedMood = checkin.mood);
        });
      }
    });

    final displayName = profileAsync.valueOrNull?.displayName ?? '';

    return Scaffold(
      backgroundColor: WrColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isNotEmpty
                                ? l10n.homeGreeting(displayName)
                                : l10n.homeGreeting('bạn'),
                            style: WrTextStyles.greeting,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            key: const Key('home_date_title'),
                            _dateLabel(),
                            style: WrTextStyles.dateTitle,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/profile'),
                      child: Container(
                        width: 34, height: 34,
                        decoration: const BoxDecoration(
                          color: WrColors.dark, shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: WrColors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content blocks ──────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Block 1: Checkin 2×2 grid
                  _MoodGridBlock(
                    selectedMood: _selectedMood,
                    saving: _saving,
                    onMoodSelected: _selectMood,
                  ),
                  const SizedBox(height: 28),
                  const WrSectionDivider(),
                  const SizedBox(height: 28),
                  // Block 2: System recognition card
                  _SystemRecognitionBlock(),
                  const SizedBox(height: 28),
                  const WrSectionDivider(),
                  const SizedBox(height: 28),
                  // Block 3: Suggestion card with progress
                  _SuggestionBlock(),
                  const SizedBox(height: 28),
                  const WrSectionDivider(),
                  const SizedBox(height: 28),
                  // Block 4: Latest insight quote
                  _InsightQuoteBlock(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Local provider (profile) ─────────────────────────────────────────────────

final _mobileProfileProvider = FutureProvider<MobileProfile?>((ref) async {
  return ref.watch(wrRepositoryProvider).getMobileProfile();
});

// ── Block 1: Mood Grid ───────────────────────────────────────────────────────

class _MoodGridBlock extends StatelessWidget {
  const _MoodGridBlock({
    required this.selectedMood,
    required this.saving,
    required this.onMoodSelected,
  });

  final Mood? selectedMood;
  final bool saving;
  final ValueChanged<Mood> onMoodSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final moods = [
      (Mood.stressed, l10n.homeMoodStressed, const Key('mood_btn_stressed')),
      (Mood.tired,    l10n.homeMoodTired,    const Key('mood_btn_tired')),
      (Mood.okay,     l10n.homeMoodOkay,     const Key('mood_btn_okay')),
      (Mood.happy,    l10n.homeMoodHappy,    const Key('mood_btn_happy')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.homeCheckinQuestion, style: WrTextStyles.hLarge),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: moods.map((entry) {
            final (mood, label, baseKey) = entry;
            final isSelected = selectedMood == mood;
            final selectedKey = Key('${baseKey.value}_selected');
            return GestureDetector(
              onTap: saving ? null : () => onMoodSelected(mood),
              child: Container(
                key: isSelected ? selectedKey : baseKey,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? WrColors.coral : WrColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? null
                      : Border.all(color: WrColors.navy.withValues(alpha: 0.08)),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? WrColors.white : WrColors.navy,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Block 2: System recognition ──────────────────────────────────────────────

class _SystemRecognitionBlock extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final situationsAsync = ref.watch(recurringSituationsProvider);

    return situationsAsync.when(
      loading: () => const _LoadingPlaceholder(),
      error: (_, __) => const SizedBox.shrink(),
      data: (situations) {
        if (situations.isEmpty) return const SizedBox.shrink();
        final top = situations.first;
        final quote = l10n.homeSystemNoticeQuote(top.occurrenceCount, top.label);
        return WrCardDark(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WrEyebrow(
                key: const Key('home_system_eyebrow'),
                l10n.homeEyebrowSystem,
                // WrEyebrow renders white-on-dark — need color override
              ),
              const SizedBox(height: 12),
              Text(
                quote,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: WrColors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              WrActionLink(
                label: l10n.homeLinkLearnMore,
                onTap: () => context.push('/wr/situation'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Block 3: Suggestion card (static placeholder) ────────────────────────────

class _SuggestionBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.homeEyebrowSuggestion),
        const SizedBox(height: 12),
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.homeSuggestionTitle, style: WrTextStyles.hMedium),
              const SizedBox(height: 4),
              Text(l10n.homeSuggestionMeta,
                  style: WrTextStyles.body.copyWith(fontSize: 12)),
              const SizedBox(height: 12),
              WrProgressTrack(value: 0.375), // 3/8 static
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.homeSuggestionProgress,
                      style: WrTextStyles.body.copyWith(fontSize: 12)),
                  Text(l10n.homeSuggestionStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: WrColors.teal,
                      )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Block 4: Latest insight quote ────────────────────────────────────────────

class _InsightQuoteBlock extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final insightAsync = ref.watch(latestInsightProvider);

    return insightAsync.when(
      loading: () => const _LoadingPlaceholder(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insight) {
        if (insight == null) {
          return Text(l10n.homeInsightEmpty, style: WrTextStyles.body);
        }
        final savedDate = '${insight.savedAt.day}/${insight.savedAt.month}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WrEyebrow(l10n.homeEyebrowInsight),
            const SizedBox(height: 12),
            Text(
              '"${insight.content}"',
              style: WrTextStyles.insightQuote,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.homeInsightSavedDate(savedDate),
              style: WrTextStyles.body.copyWith(fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
```

**Step 6: Chạy tests**

```bash
flutter test test/features/wr_home_screen_test.dart -v
```

Expected: Các tests cũ về "energy options", "direction options", "save button" sẽ FAIL — cần update ở Step 7.

**Step 7: Update tests cũ không còn relevant**

Trong `test/features/wr_home_screen_test.dart`:

- **Xóa** group `WrHomeScreen — check-in card` (toàn bộ — không còn 3-option chips).
- **Giữ nguyên** group `WrHomeScreen — header` nhưng update assertion:

```dart
group('WrHomeScreen — header', () {
  testWidgets('shows displayName from profile', (tester) async {
    final wr = FakeWrRepository()..seedProfile(_profile(name: 'Linh'));
    await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
    expect(find.textContaining('Linh'), findsWidgets);
  });

  testWidgets('falls back gracefully when no profile', (tester) async {
    await _pumpLarge(tester, _wrap(const WrHomeScreen()));
    expect(find.byType(WrHomeScreen), findsOneWidget);
  });

  testWidgets('header: date_title key present', (tester) async {
    final wr = FakeWrRepository()..seedProfile(_profile(name: 'Yumi'));
    await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
    expect(find.textContaining('Yumi'), findsWidgets);
    expect(find.byKey(const Key('home_date_title')), findsOneWidget);
  });
});
```

**Step 8: Cần update import trong test (thêm fake implementations cho providers mới)**

Kiểm tra `test/support/fake_repository.dart` có `getLatestInsight()` và `getRecurringSituations()` chưa:

```bash
grep -n "getLatestInsight\|getRecurringSituations\|seedInsights\|seedSituations" test/support/fake_repository.dart | head -20
```

Nếu đã có (từ understand_test.dart), tiếp tục. Nếu chưa, cần add vào FakeWrRepository.

**Step 9: Chạy lại tất cả home tests**

```bash
flutter test test/features/wr_home_screen_test.dart -v
```

Expected: TẤT CẢ PASS.

**Step 10: Chạy full test suite để đảm bảo không break**

```bash
flutter test --reporter=compact
```

Expected: không có regression.

**Step 11: Commit**

```bash
git add lib/features/wr/presentation/wr_home_screen.dart test/features/wr_home_screen_test.dart
git commit -m "feat(wr-ui): Task 2A — restyle Home tab per HTML design system

- Header: greeting (small, muted) above date-title (32px navy w800)
- Check-in: replace 2-row chips with 2×2 Mood grid (4 buttons)
  - Single tap saves immediately via upsertCheckin, no separate save button
  - Selected state: coral bg + white text; matches .checkin-btn.selected CSS
- Add 3 new data sections:
  - System recognition: WrCardDark with top recurring situation
  - Suggestion: WrCardMinimal with static placeholder + progress bar
  - Latest insight: italic quote + saved date
- Use WrTextStyles, WrColors, WrCardMinimal, WrCardDark, WrSectionDivider
- bg color: WrColors.cream (matches HTML --bg: #FFF3E6)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Fix WrEyebrow Color on Dark Cards

**Problem:** `WrEyebrow` hardcodes `color: WrColors.muted` (gray). Khi đặt trong `WrCardDark` (navy bg), eyebrow sẽ không đọc được. Cần override màu.

**Files:**
- Modify: `lib/core/widgets/eyebrow.dart`
- Check: `test/core/widgets_test.dart` (nếu có test cho WrEyebrow)

**Step 1: Check existing widget test**

```bash
grep -n "WrEyebrow" test/core/widgets_test.dart 2>/dev/null || echo "not found"
```

**Step 2: Add optional color param to WrEyebrow**

Sửa `lib/core/widgets/eyebrow.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

class WrEyebrow extends StatelessWidget {
  const WrEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        color: color ?? WrColors.muted,
      ),
    );
  }
}
```

**Step 3: Update `_SystemRecognitionBlock` trong wr_home_screen.dart để pass color**

Tìm dòng:
```dart
WrEyebrow(
  key: const Key('home_system_eyebrow'),
  l10n.homeEyebrowSystem,
),
```

Sửa thành:
```dart
WrEyebrow(
  l10n.homeEyebrowSystem,
  key: const Key('home_system_eyebrow'),
  color: WrColors.white.withValues(alpha: 0.7),
),
```

Và link text màu coral trên dark — `WrActionLink` cũng cần kiểm tra visibility trên dark bg. `WrActionLink` hardcodes `color: WrColors.coral` — coral trên navy là readable (đủ contrast), không cần thay đổi.

**Step 4: Chạy tests**

```bash
flutter test --reporter=compact
```

Expected: PASS — WrEyebrow là non-breaking change (color là optional).

**Step 5: Commit**

```bash
git add lib/core/widgets/eyebrow.dart lib/features/wr/presentation/wr_home_screen.dart
git commit -m "fix(wr-ui): WrEyebrow accepts optional color for dark card contexts

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Verify + Polish UnderstandScreen (Task 2B)

**Context:** `understand_screen.dart` ĐÃ implement đúng HTML design. Cần verify spacing và thêm `WrSectionDivider` giữa các blocks để match HTML (`.divider` sau `_DominantNeedBlock` và sau `_SituationsList`).

**Files:**
- Modify: `lib/features/understand/presentation/understand_screen.dart` (small changes only)
- Test: `test/features/understand_test.dart` (should still pass — just structural spacing)

**Step 1: So sánh HTML structure vs current code**

HTML structure:
```
[dominant need] → divider → [situations] → divider → [SCA card] → [health check]
```

Current Flutter code (understand_screen.dart lines 33–41):
```dart
_DominantNeedBlock(),
SizedBox(height: 28),
_SituationsList(),
SizedBox(height: 28),
_ScaCard(),
SizedBox(height: 28),
_CareerHealthCheck(),
```

Missing: `WrSectionDivider` sau `_DominantNeedBlock` và sau `_SituationsList`.

**Step 2: Thêm dividers**

Edit `lib/features/understand/presentation/understand_screen.dart`, thay:

```dart
_DominantNeedBlock(),
const SizedBox(height: 28),
_SituationsList(),
const SizedBox(height: 28),
_ScaCard(),
const SizedBox(height: 28),
_CareerHealthCheck(),
```

Thành:

```dart
_DominantNeedBlock(),
const SizedBox(height: 28),
const WrSectionDivider(),
const SizedBox(height: 28),
_SituationsList(),
const SizedBox(height: 28),
const WrSectionDivider(),
const SizedBox(height: 28),
_ScaCard(),
const SizedBox(height: 28),
_CareerHealthCheck(),
```

Đảm bảo import `section_divider.dart` đã có. Nếu chưa:

```dart
import '../../../core/widgets/section_divider.dart';
```

**Step 3: Verify header padding match HTML `.top-area`**

HTML: `padding: 8px 24px 16px`
Current code (line 59-61):
```dart
padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
```

Update sang `fromLTRB(24, 8, 24, 16)` để khớp HTML.

**Step 4: Chạy understand tests**

```bash
flutter test test/features/understand_test.dart -v
```

Expected: TẤT CẢ PASS (dividers và padding không ảnh hưởng assertions).

**Step 5: Chạy full suite**

```bash
flutter test --reporter=compact
```

Expected: PASS all.

**Step 6: Commit**

```bash
git add lib/features/understand/presentation/understand_screen.dart
git commit -m "fix(wr-ui): Task 2B — UnderstandScreen dividers + header padding per HTML spec

- Add WrSectionDivider between DominantNeed/Situations/ScaCard blocks
- Match top-area padding: fromLTRB(24, 8, 24, 16)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Scaffold Background Color Alignment

**Context:** Hiện `WrHomeScreen` dùng `Color(0xFFFBFBF9)` (off-white), nhưng HTML design `--bg: #FFF3E6` = `WrColors.cream`. `UnderstandScreen` dùng `WrColors.white`. Cả 2 cần align với design.

**Files:**
- Modify: `lib/features/wr/presentation/wr_home_screen.dart` (already set to cream in Task 1)
- Modify: `lib/features/understand/presentation/understand_screen.dart`

**Step 1: Update understand_screen.dart scaffold bg**

Tìm:
```dart
backgroundColor: WrColors.white,
```

Sửa thành:
```dart
backgroundColor: WrColors.cream,
```

**Step 2: Chạy tests**

```bash
flutter test --reporter=compact
```

Expected: PASS (bg color không affect widget tests).

**Step 3: Commit**

```bash
git add lib/features/understand/presentation/understand_screen.dart
git commit -m "fix(wr-ui): align scaffold bg to cream (#FFF3E6) on Understand tab

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Integration Smoke Test + Final Gate

**Step 1: Chạy tất cả tests có liên quan**

```bash
flutter test test/features/wr_home_screen_test.dart test/features/wr_screens_test.dart test/features/understand_test.dart test/core/widgets_test.dart -v
```

Expected: TẤT CẢ PASS.

**Step 2: Chạy full test suite**

```bash
flutter test --reporter=compact
```

Expected: Số tests không giảm. Nếu có failures, debug trước khi tiếp tục.

**Step 3: Analyze**

```bash
flutter analyze --no-pub
```

Expected: No errors (warnings OK nếu pre-existing).

**Step 4: Verify gitnexus detect_changes**

Theo CLAUDE.md requirement — chạy detect_changes trước khi commit lần cuối:

```
mcp__gitnexus__detect_changes({scope: "staged"})
```

Verify chỉ có wr_home_screen.dart, understand_screen.dart, eyebrow.dart bị thay đổi.

**Step 5: Final commit nếu chưa committed**

```bash
git log --oneline -5
```

Verify 3–4 commits đã push từ các tasks trước.

---

## Checklist Hoàn Thành

- [ ] `wr_home_screen.dart`: header đúng (greeting → date-title)
- [ ] `wr_home_screen.dart`: 2×2 Mood grid thay 2-row chips
- [ ] `wr_home_screen.dart`: single tap saves immediately (không có save button riêng)
- [ ] `wr_home_screen.dart`: WrCardDark system-recognition block
- [ ] `wr_home_screen.dart`: WrCardMinimal suggestion block với progress
- [ ] `wr_home_screen.dart`: insight quote block
- [ ] `wr_home_screen.dart`: WrSectionDivider giữa các blocks
- [ ] `wr_home_screen.dart`: bg = WrColors.cream
- [ ] `eyebrow.dart`: optional color param
- [ ] `understand_screen.dart`: WrSectionDivider giữa blocks
- [ ] `understand_screen.dart`: header padding fromLTRB(24, 8, 24, 16)
- [ ] `understand_screen.dart`: bg = WrColors.cream
- [ ] Tests: wr_home_screen_test.dart updated (old chip tests removed, mood grid tests added)
- [ ] Tests: understand_test.dart still passes unchanged
- [ ] `flutter test --reporter=compact` → PASS
- [ ] `flutter analyze --no-pub` → no errors

# Back Navigation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> Design đã duyệt: `docs/plans/2026-07-24-back-navigation-design.md`. QUY TRÌNH DỰ ÁN (CLAUDE.md): chạy `mcp__gitnexus__impact` (repo `appmobileworkreflection`, direction upstream) trước khi sửa mỗi symbol; `mcp__gitnexus__detect_changes` trước mỗi commit.

**Goal:** Thêm nút lùi về trang trước — widget `WrTabBackLink` đọc `?from=` cho 4 tab WR, gắn `?from=` vào 6 link chéo, và nút back cho fullscreen `/wr/story`.

**Architecture:** Query-param-based (1 bước nhớ, không state toàn cục). `WrTabBackLink` là StatelessWidget đọc `GoRouterState.of(context)`; render rỗng khi `from` thiếu/rác/trùng tab hiện tại. Link chéo `context.go('<path>?from=<tabKey>')`; nút lùi `context.go(<path sạch>)` nên tự biến mất ở đích.

**Tech Stack:** Flutter, go_router (GoRouterState), flutter_test + GoRouter test harness (pattern có sẵn trong `test/features/wr_journey_discover_link_test.dart`).

**Baseline gates:** `flutter analyze` = 1 warning pre-existing (`_situation` unused, `test/features/wr_screens_test.dart:143`); `flutter test` full = 1268 pass.

---

### Task 1: Widget `WrTabBackLink`

**Files:**
- Create: `lib/core/widgets/tab_back_link.dart`
- Test: `test/core/widgets/tab_back_link_test.dart` (mới)

**Step 1: Viết test fail trước.** Harness: `MaterialApp.router` với `GoRouter(initialLocation: ..., routes: [GoRoute(path: '/wr/discover', builder: (_, __) => const Scaffold(body: WrTabBackLink(currentTab: WrTab.discover))), GoRoute(path: '/wr/journey', builder: (_, __) => const Scaffold(body: Text('JOURNEY_PAGE')))])`. Test cases:

```dart
// 1. initialLocation '/wr/discover?from=journey' → find.text('Quay lại') findsOneWidget
// 2. initialLocation '/wr/discover' (không query) → findsNothing
// 3. initialLocation '/wr/discover?from=abc' (rác) → findsNothing
// 4. initialLocation '/wr/discover?from=discover' (trùng tab) → findsNothing
// 5. từ case 1, tap 'Quay lại' + pumpAndSettle → find.text('JOURNEY_PAGE') findsOneWidget
```

**Step 2:** `flutter test test/core/widgets/tab_back_link_test.dart` → FAIL (WrTabBackLink chưa tồn tại).

**Step 3: Implement tối thiểu:**

```dart
// lib/core/widgets/tab_back_link.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/wr_colors.dart';

/// Tab identity for WrTabBackLink — which shell tab the host screen is.
enum WrTab {
  home('/home'),
  discover('/wr/discover'),
  growth('/wr/growth'),
  journey('/wr/journey');

  const WrTab(this.path);
  final String path;

  static WrTab? fromKey(String? key) => switch (key) {
        'home' => WrTab.home,
        'discover' => WrTab.discover,
        'growth' => WrTab.growth,
        'journey' => WrTab.journey,
        _ => null,
      };
}

/// "Quay lại" link shown on a shell tab when reached via a cross-tab
/// link carrying `?from=<tabKey>`. Renders nothing for direct tab entry,
/// unknown keys, or when `from` equals the current tab.
class WrTabBackLink extends StatelessWidget {
  const WrTabBackLink({super.key, required this.currentTab});
  final WrTab currentTab;

  @override
  Widget build(BuildContext context) {
    final fromKey = GoRouterState.of(context).uri.queryParameters['from'];
    final fromTab = WrTab.fromKey(fromKey);
    if (fromTab == null || fromTab == currentTab) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => context.go(fromTab.path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.arrow_back_ios_new, size: 14, color: WrColors.muted),
            SizedBox(width: 6),
            Text(
              'Quay lại',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: WrColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 4:** Chạy lại test file → 5/5 PASS.

**Step 5: Commit** `feat(wr-ui): widget WrTabBackLink — nút Quay lại theo ?from= cho tab chéo` (nhớ detect_changes trước).

---

### Task 2: Gắn WrTabBackLink vào 4 tab WR

**Files:**
- Modify: `lib/features/wr/presentation/wr_home_screen.dart` (đầu body, trên greeting)
- Modify: `lib/features/wr/presentation/wr_discover_screen.dart` (trong top-area Padding, trên `WrEyebrow('Career Snapshot')`)
- Modify: `lib/features/wr/presentation/wr_growth_screen.dart` (trong top-area, trên 'Development Map')
- Modify: `lib/features/wr/presentation/wr_journey_screen.dart` (trong top-area, trên 'Career Memory')
- Test: `test/features/wr_back_navigation_test.dart` (mới)

**Step 1: Test fail trước.** Pump từng screen thật trong GoRouter với `initialLocation: '<tab>?from=<khác>'` + override providers bằng fakes (copy harness từ `test/features/wr_journey_discover_link_test.dart` — fakes: `FakeWrContentRepository`, `FakeWrIntelligenceRepository`, override `currentUserIdProvider`). 8 tests: mỗi tab × (có from hợp lệ → thấy 'Quay lại'; không from → không thấy). LƯU Ý màn nào cần thêm route đích trong harness để tap không crash thì thêm stub route.

**Step 2:** Chạy → FAIL (chưa gắn widget).

**Step 3:** Gắn `const WrTabBackLink(currentTab: WrTab.<tab>)` vào đầu Column top-area của từng màn (import `../../../core/widgets/tab_back_link.dart`). Chú ý: top-area Discover/Journey hiện là `const` Column — phải bỏ `const` ở mức cần thiết, giữ const cho children còn lại.

**Step 4:** Test file mới PASS + chạy `flutter test test/features/` không vỡ test cũ (một số test cũ pump screen KHÔNG có GoRouterState? — KIỂM TRA: `GoRouterState.of` throw nếu ngoài GoRouter. Các test cũ pump qua MaterialApp+GoRouter đã có (journey/discover/growth link tests dùng GoRouter). Test nào pump màn trực tiếp bằng MaterialApp(home:) sẽ CRASH → xử lý: trong WrTabBackLink dùng `GoRouterState.of` bọc try-catch? KHÔNG — dùng `GoRouter.maybeOf(context)` check null trước, null → SizedBox.shrink(). Cập nhật implement Task 1 tương ứng ngay từ đầu: an toàn khi không có router.)

**Step 5: Commit** `feat(wr-ui): gắn nút Quay lại vào 4 tab WR`.

---

### Task 3: Gắn `?from=` vào 6 link chéo

**Files:**
- Modify: `lib/features/wr/presentation/wr_home_screen.dart:643` → `context.go('/wr/discover?from=home')`
- Modify: `lib/features/wr/presentation/wr_journey_screen.dart:229` → `'/wr/discover?from=journey'`; `:263` → `'/home?from=journey'`
- Modify: `lib/features/wr/presentation/wr_discover_screen.dart:298` → `'/wr/growth?from=discover'`; `:381` → `'/wr/journey?from=discover'`
- Modify: `lib/features/wr/presentation/wr_growth_screen.dart:447` → `'/wr/discover?from=growth'`
- Test: thêm vào `test/features/wr_back_navigation_test.dart`

**Step 1: Test fail:** round-trip Journey→Discover: pump router 2 route thật (journey + discover với fakes), initial `/wr/journey` có patterns → tap 'Xem trong Hiểu mình' → settle → thấy 'Quay lại' → tap → settle → về Journey (thấy text đặc trưng màn Journey), 'Quay lại' biến mất. Thêm 1 test tương tự Discover→Growth.

**Step 2:** FAIL (link chưa có query). **Step 3:** Sửa 6 link. **Step 4:** PASS + full `test/features/` xanh. **Step 5: Commit** `feat(wr-ui): 6 link chéo mang ?from= để trang đích hiện Quay lại`.

---

### Task 4: Nút lùi `/wr/story`

**Files:**
- Modify: `lib/features/wr/presentation/wr_story_screen.dart` — chèn sliver đầu tiên TRƯỚC sliver title hiện có (dòng 16):

```dart
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 22, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: WrColors.dark),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
    ),
  ),
),
```

- Test: thêm vào `test/features/wr_back_navigation_test.dart`: (a) pump `/wr/story` push từ `/home` → tap icon back → về home; (b) pump initial thẳng `/wr/story` (không stack) → tap → về `/home`.

**Steps:** test fail → implement → pass → **Commit** `feat(wr-ui): nút lùi cho /wr/story (pop, fallback /home)`.

---

### Task 5: Gates cuối + index

**Step 1:** `flutter analyze` → đúng 1 warning pre-existing. **Step 2:** `flutter test` FULL → 1268 + số test mới, 0 fail. **Step 3:** `mcp__gitnexus__detect_changes({scope:'all'})` → chỉ file mong đợi. **Step 4:** `gitnexus analyze` (binary global, KHÔNG npx — repo không có package.json) cập nhật index. **Step 5:** Báo cáo số thật.

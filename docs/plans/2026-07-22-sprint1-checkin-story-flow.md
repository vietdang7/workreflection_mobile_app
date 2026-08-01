# Sprint 1: Check-in + Story Reflection Flow — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Xây dựng core loop: check-in energy/direction hàng ngày → situation flow (khi mệt mỏi) → story reflection flow với 6 phase lưu vào career memory.

**Architecture:** WrHomeScreen (ConsumerStatefulWidget) quản lý state check-in qua Riverpod; WrSituationFlowScreen và WrStoryFlowScreen là màn độc lập route `/wr/situation` và `/wr/story/flow`; toàn bộ ghi dữ liệu qua WrContentRepository + WrIntelligenceRepository interfaces (fake-able trong test).

**Tech Stack:** Flutter + Riverpod + GoRouter + Supabase; test với flutter_test + flutter_riverpod ProviderScope overrides.

---

## Codebase snapshot (đọc trước khi implement)

| File | Ghi chú |
|------|---------|
| `lib/core/models/checkin.dart` | Mood enum + Checkin class — SẼ SỬA |
| `lib/core/data/wr_repository.dart` | `upsertCheckin(Mood)` + `getTodayCheckin()` — SẼ SỬA signature |
| `lib/features/wr/presentation/wr_home_screen.dart` | Placeholder P1 — SẼ THAY HOÀN TOÀN |
| `lib/features/wr/presentation/wr_story_screen.dart` | Placeholder P1 — SẼ THAY HOÀN TOÀN |
| `lib/features/wr/wr_providers.dart` | `currentUserIdProvider`, `wrEntitlementProvider` |
| `lib/core/models/wr_content.dart` | WrSituation, WrStory, CareerMemoryEvent, enums |
| `lib/core/models/wr_intelligence.dart` | WrInsight, ReflectionStep, PatternCount… |
| `lib/core/data/wr_content_repository.dart` | fetchSituations, fetchStories, insertMemoryEvent, fetchMemoryEvents |
| `lib/core/data/wr_intelligence_repository.dart` | recordSituationOccurrence, insertReflectionStep, insertInsight, fetchPatternCounts |
| `lib/core/logic/vn_date.dart` | `todayVn()`, `todayVnFrom(utc)` |
| `lib/core/router/app_router.dart` | Route `/home` (branch 0), `/wr/story` (branch 1) — thêm `/wr/situation` và `/wr/story/flow` |
| `test/support/fake_repository.dart` | FakeWrRepository — SẼ SỬA (thêm energy/direction) |
| `test/support/fake_wr_content_repository.dart` | FakeWrContentRepository — dùng nguyên |
| `test/support/fake_wr_intelligence_repository.dart` | FakeWrIntelligenceRepository — dùng nguyên |

## Impact warnings (chạy trước khi sửa)

Trước Task 2 (sửa Checkin model), phải chạy:
```
mcp__gitnexus__impact({target: "Checkin", direction: "upstream"})
mcp__gitnexus__impact({target: "upsertCheckin", direction: "upstream"})
mcp__gitnexus__impact({target: "Mood", direction: "upstream"})
```

Trước Task 3 (sửa WrRepository interface + SupabaseWrRepository):
```
mcp__gitnexus__impact({target: "WrRepository", direction: "upstream"})
```

---

## Task 1: Migration SQL

**Files:**
- Create: `supabase/migrations/20260722000001_wr_checkin_energy_direction.sql`

**Step 1: Tạo file migration**

```sql
-- DO NOT push without Fable approval
-- Adds energy + direction columns to wr_checkins for Phase 2 Sprint 1.
-- Both nullable to preserve backward compatibility with existing rows.

alter table public.wr_checkins
  add column if not exists energy text
    check (energy in ('good', 'ok', 'low'));

alter table public.wr_checkins
  add column if not exists direction text
    check (direction in ('forward', 'steady', 'backward'));
```

**Step 2: Verify file tồn tại**

```bash
ls -la /path/to/repo/supabase/migrations/20260722000001_wr_checkin_energy_direction.sql
```

Expected: file hiện ra, KHÔNG chạy migration thật (stub only).

---

## Task 2: Mở rộng Checkin model

**Files:**
- Modify: `lib/core/models/checkin.dart`
- Test: `test/core/models/checkin_extended_test.dart` (file mới)

**Step 1: Chạy impact analysis**

```
mcp__gitnexus__impact({target: "Checkin", direction: "upstream"})
mcp__gitnexus__impact({target: "Mood", direction: "upstream"})
mcp__gitnexus__impact({target: "upsertCheckin", direction: "upstream"})
```

Đọc kết quả, ghi nhận d=1 callers.

**Step 2: Viết failing tests (file mới)**

Tạo `test/core/models/checkin_extended_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';

void main() {
  group('CheckinEnergy', () {
    test('dbValue round-trip good', () {
      expect(CheckinEnergy.fromDb(CheckinEnergy.good.dbValue), CheckinEnergy.good);
    });
    test('dbValue round-trip ok', () {
      expect(CheckinEnergy.fromDb(CheckinEnergy.ok.dbValue), CheckinEnergy.ok);
    });
    test('dbValue round-trip low', () {
      expect(CheckinEnergy.fromDb(CheckinEnergy.low.dbValue), CheckinEnergy.low);
    });
    test('fromDb throws on unknown', () {
      expect(() => CheckinEnergy.fromDb('unknown'), throwsArgumentError);
    });
  });

  group('CheckinDirection', () {
    test('dbValue round-trip forward', () {
      expect(CheckinDirection.fromDb(CheckinDirection.forward.dbValue), CheckinDirection.forward);
    });
    test('dbValue round-trip steady', () {
      expect(CheckinDirection.fromDb(CheckinDirection.steady.dbValue), CheckinDirection.steady);
    });
    test('dbValue round-trip backward', () {
      expect(CheckinDirection.fromDb(CheckinDirection.backward.dbValue), CheckinDirection.backward);
    });
    test('fromDb throws on unknown', () {
      expect(() => CheckinDirection.fromDb('xyz'), throwsArgumentError);
    });
  });

  group('Checkin.fromJson backward compat', () {
    test('parses old row without energy/direction (null)', () {
      final c = Checkin.fromJson({
        'id': 'c1',
        'user_id': 'u1',
        'mood': 'happy',
        'checkin_date': '2026-07-22',
        'created_at': '2026-07-22T07:00:00Z',
      });
      expect(c.mood, Mood.happy);
      expect(c.energy, isNull);
      expect(c.direction, isNull);
    });

    test('parses new row with energy + direction', () {
      final c = Checkin.fromJson({
        'id': 'c2',
        'user_id': 'u1',
        'mood': 'happy',
        'checkin_date': '2026-07-22',
        'created_at': '2026-07-22T07:00:00Z',
        'energy': 'good',
        'direction': 'forward',
      });
      expect(c.energy, CheckinEnergy.good);
      expect(c.direction, CheckinDirection.forward);
    });
  });

  group('energyToMood mapping', () {
    test('good → happy', () => expect(CheckinEnergy.good.toMood(), Mood.happy));
    test('ok → okay', () => expect(CheckinEnergy.ok.toMood(), Mood.okay));
    test('low → tired', () => expect(CheckinEnergy.low.toMood(), Mood.tired));
  });
}
```

**Step 3: Chạy test — verify FAIL**

```bash
flutter test test/core/models/checkin_extended_test.dart
```

Expected: FAIL ("CheckinEnergy not defined", v.v.)

**Step 4: Implement — sửa `lib/core/models/checkin.dart`**

Thêm sau enum `Mood` (GIỮ NGUYÊN Mood, không sửa):

```dart
/// Energy level for the new check-in UI (Phase 2).
/// Maps to wr_checkins.energy check constraint.
enum CheckinEnergy {
  good,
  ok,
  low;

  String get dbValue => switch (this) {
        CheckinEnergy.good => 'good',
        CheckinEnergy.ok => 'ok',
        CheckinEnergy.low => 'low',
      };

  static CheckinEnergy fromDb(String value) => switch (value) {
        'good' => CheckinEnergy.good,
        'ok' => CheckinEnergy.ok,
        'low' => CheckinEnergy.low,
        _ => throw ArgumentError('Unknown CheckinEnergy db value: $value'),
      };

  /// Maps energy → legacy Mood for backward-compatible upsert.
  Mood toMood() => switch (this) {
        CheckinEnergy.good => Mood.happy,
        CheckinEnergy.ok => Mood.okay,
        CheckinEnergy.low => Mood.tired,
      };
}

/// Perceived direction — forward/steady/backward.
/// Maps to wr_checkins.direction check constraint.
enum CheckinDirection {
  forward,
  steady,
  backward;

  String get dbValue => switch (this) {
        CheckinDirection.forward => 'forward',
        CheckinDirection.steady => 'steady',
        CheckinDirection.backward => 'backward',
      };

  static CheckinDirection fromDb(String value) => switch (value) {
        'forward' => CheckinDirection.forward,
        'steady' => CheckinDirection.steady,
        'backward' => CheckinDirection.backward,
        _ => throw ArgumentError('Unknown CheckinDirection db value: $value'),
      };
}
```

Sửa class `Checkin`:
- Thêm 2 optional fields: `final CheckinEnergy? energy;` và `final CheckinDirection? direction;`
- Thêm vào constructor: `this.energy, this.direction`
- Sửa `fromJson` để parse: `energy: json['energy'] != null ? CheckinEnergy.fromDb(json['energy'] as String) : null` (tương tự direction)

**Step 5: Chạy test — verify PASS**

```bash
flutter test test/core/models/checkin_extended_test.dart
```

Expected: 11 tests PASS.

**Step 6: Đảm bảo tests cũ vẫn pass**

```bash
flutter test test/core/wr_repository_test.dart
```

Expected: PASS (Mood cũ không thay đổi).

---

## Task 3: Mở rộng WrRepository + FakeWrRepository

**Files:**
- Modify: `lib/core/data/wr_repository.dart` (abstract interface + SupabaseWrRepository)
- Modify: `test/support/fake_repository.dart`

**Step 1: Chạy impact**

```
mcp__gitnexus__impact({target: "WrRepository", direction: "upstream"})
mcp__gitnexus__impact({target: "upsertCheckin", direction: "upstream"})
```

**Step 2: Viết failing test cho signature mới**

Tạo `test/core/wr_checkin_energy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import '../../test/support/fake_repository.dart';

void main() {
  group('FakeWrRepository — energy/direction upsert', () {
    late FakeWrRepository repo;
    setUp(() => repo = FakeWrRepository());

    test('upsertCheckin with energy+direction stores energy on checkin', () async {
      await repo.upsertCheckin(
        Mood.happy,
        energy: CheckinEnergy.good,
        direction: CheckinDirection.forward,
      );
      final c = await repo.getTodayCheckin();
      expect(c!.energy, CheckinEnergy.good);
      expect(c.direction, CheckinDirection.forward);
    });

    test('upsertCheckin without energy preserves backward compat', () async {
      await repo.upsertCheckin(Mood.okay);
      final c = await repo.getTodayCheckin();
      expect(c!.mood, Mood.okay);
      expect(c.energy, isNull);
    });

    test('upsertCheckin records energy in call log', () async {
      await repo.upsertCheckin(Mood.tired, energy: CheckinEnergy.low);
      // upsertCheckinCalls still records Mood for backward compat
      expect(repo.upsertCheckinCalls, [Mood.tired]);
    });
  });
}
```

**Step 3: Chạy test — verify FAIL**

```bash
flutter test test/core/wr_checkin_energy_test.dart
```

Expected: FAIL (wrong number of arguments for upsertCheckin).

**Step 4: Sửa abstract interface trong `wr_repository.dart`**

Thay signature:
```dart
// TRƯỚC:
Future<void> upsertCheckin(Mood mood);

// SAU:
Future<void> upsertCheckin(
  Mood mood, {
  CheckinEnergy? energy,
  CheckinDirection? direction,
});
```

Import thêm `CheckinEnergy`, `CheckinDirection` nếu chưa có (đã import checkin.dart).

**Step 5: Sửa `SupabaseWrRepository.upsertCheckin`**

```dart
@override
Future<void> upsertCheckin(
  Mood mood, {
  CheckinEnergy? energy,
  CheckinDirection? direction,
}) async {
  await _client.from('wr_checkins').upsert(
    {
      'user_id': _uid,
      'checkin_date': _todayVn,
      'mood': mood.dbValue,
      if (energy != null) 'energy': energy.dbValue,
      if (direction != null) 'direction': direction.dbValue,
    },
    onConflict: 'user_id,checkin_date',
  );
}
```

**Step 6: Sửa `FakeWrRepository.upsertCheckin` trong `test/support/fake_repository.dart`**

```dart
@override
Future<void> upsertCheckin(
  Mood mood, {
  CheckinEnergy? energy,
  CheckinDirection? direction,
}) async {
  upsertCheckinCalls.add(mood);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  _todayCheckin = Checkin(
    id: 'fake-checkin',
    userId: 'fake-user',
    mood: mood,
    energy: energy,
    direction: direction,
    checkinDate: today,
    createdAt: now,
  );
  if (!_checkinDates.any(
    (d) => d.year == today.year && d.month == today.month && d.day == today.day,
  )) {
    _checkinDates.add(today);
  }
}
```

**Step 7: Kiểm tra callers khác của upsertCheckin — cập nhật nếu cần**

```bash
grep -rn "upsertCheckin" /path/to/repo/lib /path/to/repo/test
```

Các caller hiện tại chỉ truyền positional `Mood` — với named optional params, chúng vẫn compile OK không cần sửa.

**Step 8: Chạy toàn bộ test**

```bash
flutter test
```

Expected: tất cả pass (kể cả optimistic_update_test.dart).

---

## Task 4: WrHomeScreen thật (check-in card + luồng lõi)

**Files:**
- Modify: `lib/features/wr/presentation/wr_home_screen.dart`
- Modify: `lib/features/wr/wr_providers.dart` (thêm providers mới)
- Test: `test/features/wr_home_screen_test.dart` (file mới)

**Step 1: Viết failing tests**

Tạo `test/features/wr_home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// Minimal GoRouter for WrHomeScreen — handles /wr/situation navigation
GoRouter _makeRouter({required Widget home}) => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => home),
        GoRoute(
          path: '/wr/situation',
          builder: (_, __) => const Scaffold(body: Text('SituationScreen')),
        ),
      ],
    );

Widget _wrap(
  Widget home, {
  FakeWrRepository? wr,
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String? userId,
}) {
  final wrRepo = wr ?? FakeWrRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeRouter(home: home);
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(wrRepo),
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue(userId ?? 'u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

MobileProfile _profile({String name = 'Minh'}) => MobileProfile(
      userId: 'u1',
      displayName: name,
      reminderEnabled: true,
      language: 'vi',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 7, 22),
    );

void main() {
  group('WrHomeScreen — header', () {
    testWidgets('shows displayName from profile', (tester) async {
      final wr = FakeWrRepository()..seedProfile(_profile(name: 'Linh'));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      expect(find.textContaining('Linh'), findsWidgets);
    });

    testWidgets('falls back gracefully when no profile', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      // Should not crash; header renders without displayName
      expect(find.byType(WrHomeScreen), findsOneWidget);
    });
  });

  group('WrHomeScreen — check-in card', () {
    testWidgets('renders energy options', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Có năng lượng'), findsOneWidget);
      expect(find.text('Bình thường'), findsOneWidget);
      expect(find.text('Mệt mỏi'), findsOneWidget);
    });

    testWidgets('renders direction options', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Tiến lên'), findsOneWidget);
      expect(find.text('Đứng yên'), findsOneWidget);
      expect(find.text('Thụt lùi'), findsOneWidget);
    });

    testWidgets('save button disabled until both selected', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Lưu check-in'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('save button enabled after energy + direction selected', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.text('Có năng lượng'));
      await tester.pump();
      await tester.tap(find.text('Tiến lên'));
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Lưu check-in'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('tapping save calls upsertCheckin with correct energy', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Có năng lượng'));
      await tester.pump();
      await tester.tap(find.text('Tiến lên'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu check-in'));
      await tester.pumpAndSettle();
      expect(wr.upsertCheckinCalls, contains(Mood.happy));
    });

    testWidgets('shows saved confirmation after save', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Bình thường'));
      await tester.pump();
      await tester.tap(find.text('Đứng yên'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu check-in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã lưu'), findsOneWidget);
    });

    testWidgets('energy=low shows share card after save', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Mệt mỏi'));
      await tester.pump();
      await tester.tap(find.text('Thụt lùi'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu check-in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsOneWidget);
    });

    testWidgets('energy=good does NOT show share card', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Có năng lượng'));
      await tester.pump();
      await tester.tap(find.text('Tiến lên'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu check-in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
    });

    testWidgets('shows saved state when today checkin already exists', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c1',
        userId: 'u1',
        mood: Mood.okay,
        energy: CheckinEnergy.ok,
        direction: CheckinDirection.steady,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      expect(find.textContaining('Đã lưu'), findsOneWidget);
    });
  });
}
```

**Step 2: Chạy test — verify FAIL**

```bash
flutter test test/features/wr_home_screen_test.dart
```

Expected: FAIL (nhiều lỗi — WrHomeScreen chưa có direction, button, saved state; FakeWrRepository chưa có `seedTodayCheckin`).

**Step 3: Thêm `seedTodayCheckin` vào FakeWrRepository**

Trong `test/support/fake_repository.dart`, thêm method:

```dart
void seedTodayCheckin(Checkin checkin) {
  _todayCheckin = checkin;
}
```

**Step 4: Thêm providers vào `wr_providers.dart`**

```dart
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';

// Fetch today's check-in (nullable)
final todayCheckinProvider = FutureProvider<Checkin?>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getTodayCheckin();
});
```

**Step 5: Implement WrHomeScreen mới**

Thay toàn bộ nội dung `lib/features/wr/presentation/wr_home_screen.dart` với màn thật:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/mobile_profile.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';

class WrHomeScreen extends ConsumerStatefulWidget {
  const WrHomeScreen({super.key});

  @override
  ConsumerState<WrHomeScreen> createState() => _WrHomeScreenState();
}

class _WrHomeScreenState extends ConsumerState<WrHomeScreen> {
  CheckinEnergy? _energy;
  CheckinDirection? _direction;
  bool _saved = false;
  bool _saving = false;

  String _dateLabel() {
    final now = todayVn();
    final weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return '${weekdays[now.weekday - 1]}, ${now.day} tháng ${now.month}';
  }

  Future<void> _save() async {
    if (_energy == null || _direction == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(wrRepositoryProvider);
      await repo.upsertCheckin(
        _energy!.toMood(),
        energy: _energy,
        direction: _direction,
      );
      if (mounted) setState(() { _saved = true; _saving = false; });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayCheckinAsync = ref.watch(todayCheckinProvider);
    final profileAsync = ref.watch(_mobileProfileProvider);

    // Pre-populate saved state from today's existing check-in
    todayCheckinAsync.whenData((checkin) {
      if (checkin != null && !_saved) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _saved = true; });
        });
      }
    });

    final displayName = profileAsync.valueOrNull?.displayName ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dateLabel(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFA3A3A3),
                              letterSpacing: 0.02,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displayName.isNotEmpty ? 'Chào $displayName,' : 'Chào buổi sáng,',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: WrColors.dark,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
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

            // Check-in card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: _CheckinCard(
                  energy: _energy,
                  direction: _direction,
                  saved: _saved,
                  saving: _saving,
                  onEnergySelected: (e) => setState(() => _energy = e),
                  onDirectionSelected: (d) => setState(() => _direction = d),
                  onSave: _save,
                ),
              ),
            ),

            // Low-energy share card
            if (_saved && _energy == CheckinEnergy.low)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: _ShareCard(onShare: () => context.push('/wr/situation')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider: mobile profile (local, only for home screen)
// ---------------------------------------------------------------------------

final _mobileProfileProvider = FutureProvider<MobileProfile?>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getMobileProfile();
});

// ---------------------------------------------------------------------------
// _CheckinCard
// ---------------------------------------------------------------------------

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({
    required this.energy,
    required this.direction,
    required this.saved,
    required this.saving,
    required this.onEnergySelected,
    required this.onDirectionSelected,
    required this.onSave,
  });

  final CheckinEnergy? energy;
  final CheckinDirection? direction;
  final bool saved;
  final bool saving;
  final ValueChanged<CheckinEnergy> onEnergySelected;
  final ValueChanged<CheckinDirection> onDirectionSelected;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHECK-IN NHANH',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFA3A3A3), letterSpacing: 0.05),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ngày hôm nay của bạn như thế nào?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.dark, height: 1.5),
          ),
          const SizedBox(height: 14),
          // Energy row
          Row(
            children: [
              _OptionChip(label: 'Có năng lượng', selected: energy == CheckinEnergy.good, onTap: () => onEnergySelected(CheckinEnergy.good)),
              const SizedBox(width: 8),
              _OptionChip(label: 'Bình thường', selected: energy == CheckinEnergy.ok, onTap: () => onEnergySelected(CheckinEnergy.ok)),
              const SizedBox(width: 8),
              _OptionChip(label: 'Mệt mỏi', selected: energy == CheckinEnergy.low, onTap: () => onEnergySelected(CheckinEnergy.low)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Bạn cảm thấy mình đang:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.dark, height: 1.5),
          ),
          const SizedBox(height: 10),
          // Direction row
          Row(
            children: [
              _OptionChip(label: 'Tiến lên', selected: direction == CheckinDirection.forward, onTap: () => onDirectionSelected(CheckinDirection.forward)),
              const SizedBox(width: 8),
              _OptionChip(label: 'Đứng yên', selected: direction == CheckinDirection.steady, onTap: () => onDirectionSelected(CheckinDirection.steady)),
              const SizedBox(width: 8),
              _OptionChip(label: 'Thụt lùi', selected: direction == CheckinDirection.backward, onTap: () => onDirectionSelected(CheckinDirection.backward)),
            ],
          ),
          const SizedBox(height: 16),
          if (saved)
            const _SavedBadge()
          else
            ElevatedButton(
              onPressed: (energy != null && direction != null && !saving) ? onSave : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.navy,
                foregroundColor: WrColors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: WrColors.white))
                  : const Text('Lưu check-in', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0x14FF6859) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? WrColors.coral : const Color(0x1A2C335D),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? WrColors.navy : WrColors.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedBadge extends StatelessWidget {
  const _SavedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 16),
          SizedBox(width: 6),
          Text('Đã lưu · Check-in hôm nay', style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.onShare});
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFF6859)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bạn mệt vì điều gì?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.dark)),
          const SizedBox(height: 8),
          const Text(
            'Đôi khi hiểu được nguyên nhân giúp bạn nhẹ hơn một chút.',
            style: TextStyle(fontSize: 13, color: Color(0xFF737373), height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onShare,
            style: OutlinedButton.styleFrom(
              foregroundColor: WrColors.navy,
              side: const BorderSide(color: WrColors.navy),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Chia sẻ thêm', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
```

**Step 6: Chạy test**

```bash
flutter test test/features/wr_home_screen_test.dart
```

Expected: tất cả PASS.

**Step 7: Chạy toàn bộ**

```bash
flutter analyze && flutter test
```

Expected: 0 issues; tất cả pass.

---

## Task 5: WrSituationFlowScreen (3 bước)

**Files:**
- Create: `lib/features/wr/presentation/wr_situation_flow_screen.dart`
- Modify: `lib/core/router/app_router.dart` (thêm route `/wr/situation`)
- Test: `test/features/wr_situation_flow_screen_test.dart` (file mới)

**Step 1: Viết failing tests**

Tạo `test/features/wr_situation_flow_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_situation_flow_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

WrSituation _sit({
  String code = 'S1.1',
  String text = 'Tôi không biết nên làm gì tiếp theo',
  int wave = 1,
  ScaDimension dim = ScaDimension.s1,
  String? expectedOutcome = 'Bạn muốn có sự rõ ràng về hướng đi',
  String? scaPerspective = 'Đây là giai đoạn định hướng quan trọng',
  HumanNeed? need = HumanNeed.roRang,
}) => WrSituation(
  code: code, text: text, scaDimension: dim, wave: wave,
  expectedOutcome: expectedOutcome, scaPerspective: scaPerspective,
  humanNeed: need,
);

Widget _wrap(Widget screen, {
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String? userId,
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = GoRouter(
    initialLocation: '/wr/situation',
    routes: [
      GoRoute(path: '/wr/situation', builder: (_, __) => screen),
      GoRoute(path: '/wr/story', builder: (_, __) => const Scaffold(body: Text('StoryTab'))),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      wrRepositoryProvider.overrideWithValue(FakeWrRepository()),
      currentUserIdProvider.overrideWithValue(userId ?? 'u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  group('WrSituationFlowScreen — step 1: list', () {
    testWidgets('renders list of situations from fake repo', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sit(code: 'S1.1', text: 'Tôi không biết nên làm gì'),
        _sit(code: 'S1.2', text: 'Tôi cảm thấy lạc lõng'),
      ]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      expect(find.text('Tôi không biết nên làm gì'), findsOneWidget);
      expect(find.text('Tôi cảm thấy lạc lõng'), findsOneWidget);
    });

    testWidgets('tapping situation moves to step 2 and shows expectedOutcome', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit(expectedOutcome: 'Bạn muốn rõ ràng về hướng đi')]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn muốn rõ ràng về hướng đi'), findsOneWidget);
    });

    testWidgets('step 2 does NOT show raw SCA code', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit()]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      // SCA codes should not appear
      expect(find.textContaining('S1'), findsNothing);
      expect(find.textContaining('A1'), findsNothing);
      expect(find.textContaining('C2'), findsNothing);
    });

    testWidgets('step 2 shows scaPerspective', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit(scaPerspective: 'Đây là giai đoạn định hướng')]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đây là giai đoạn định hướng'), findsOneWidget);
    });
  });

  group('WrSituationFlowScreen — step 3: save', () {
    testWidgets('save button calls recordSituationOccurrence', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();
      content.seedSituations([_sit(code: 'S1.1', dim: ScaDimension.s1)]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content, intel: intel));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu vào hành trình'));
      await tester.pumpAndSettle();
      expect(intel.recordSituationOccurrenceCalls.length, 1);
      expect(intel.recordSituationOccurrenceCalls.first.situationCode, 'S1.1');
    });

    testWidgets('save creates career memory event', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();
      content.seedSituations([_sit(code: 'S1.1')]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content, intel: intel));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu vào hành trình'));
      await tester.pumpAndSettle();
      expect(content.insertMemoryEventCalls.length, 1);
      expect(content.insertMemoryEventCalls.first.situationCode, 'S1.1');
      expect(content.insertMemoryEventCalls.first.emotion, 'low');
    });

    testWidgets('shows Đã ghi nhận after save', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit()]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu vào hành trình'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã ghi nhận'), findsOneWidget);
    });

    testWidgets('pattern >= 3 shows "lần thứ N" message', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();
      // Pre-seed 2 existing occurrences (after save = 3)
      intel.seedPatternCounts([
        PatternCount(
          userId: 'u1', situationCode: 'S1.1', scaDimension: ScaDimension.s1,
          occurrenceCount: 2, lastSeenAt: DateTime.now(),
        ),
      ]);
      content.seedSituations([_sit(code: 'S1.1')]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content, intel: intel));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu vào hành trình'));
      await tester.pumpAndSettle();
      expect(find.textContaining('lần thứ'), findsOneWidget);
    });
  });
}
```

**Step 2: Chạy test — verify FAIL**

```bash
flutter test test/features/wr_situation_flow_screen_test.dart
```

Expected: FAIL (WrSituationFlowScreen not found).

**Step 3: Implement `lib/features/wr/presentation/wr_situation_flow_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';

class WrSituationFlowScreen extends ConsumerStatefulWidget {
  const WrSituationFlowScreen({super.key});

  @override
  ConsumerState<WrSituationFlowScreen> createState() => _WrSituationFlowScreenState();
}

class _WrSituationFlowScreenState extends ConsumerState<WrSituationFlowScreen> {
  int _step = 0; // 0=list, 1=confirm, 2=saved
  WrSituation? _selected;
  bool _saving = false;
  int _patternCountAfterSave = 0;

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);
    try {
      final userId = ref.read(currentUserIdProvider) ?? '';
      final contentRepo = ref.read(wrContentRepositoryProvider);
      final intelRepo = ref.read(wrIntelligenceRepositoryProvider);
      final sit = _selected!;

      // (a) record occurrence
      await intelRepo.recordSituationOccurrence(
        userId: userId,
        situationCode: sit.code,
        scaDimensionDb: sit.scaDimension.dbValue,
      );

      // (b) count pattern after
      final counts = await intelRepo.fetchPatternCounts(userId);
      final thisCount = counts
          .where((p) => p.situationCode == sit.code)
          .fold<int>(0, (acc, p) => acc + p.occurrenceCount);

      // (c) insert memory event
      await contentRepo.insertMemoryEvent(CareerMemoryEvent(
        id: '',
        userId: userId,
        situationCode: sit.code,
        humanNeed: sit.humanNeed,
        scaDimension: sit.scaDimension,
        emotion: 'low',
      ));

      if (mounted) {
        setState(() {
          _step = 2;
          _saving = false;
          _patternCountAfterSave = thisCount;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  double get _progress => switch (_step) {
        0 => 0.33,
        1 => 0.66,
        _ => 1.0,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => setState(() => _step--),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => context.pop(),
                    ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: WrColors.navy,
                      minHeight: 3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_step) {
                0 => _StepList(onSelect: (s) => setState(() { _selected = s; _step = 1; })),
                1 => _StepConfirm(situation: _selected!, saving: _saving, onSave: _save),
                _ => _StepSaved(patternCount: _patternCountAfterSave),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: List
// ---------------------------------------------------------------------------

class _StepList extends ConsumerWidget {
  const _StepList({required this.onSelect});
  final ValueChanged<WrSituation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final situationsAsync = ref.watch(_situationsProvider);
    return situationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (situations) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        children: [
          const Text('Bạn đang gặp điều gì?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: WrColors.dark)),
          const SizedBox(height: 6),
          const Text('Chọn tình huống gần nhất với bạn lúc này.',
              style: TextStyle(fontSize: 13, color: Color(0xFF737373), height: 1.5)),
          const SizedBox(height: 20),
          ...situations.map((s) => _SituationTile(situation: s, onTap: () => onSelect(s))),
        ],
      ),
    );
  }
}

class _SituationTile extends StatelessWidget {
  const _SituationTile({required this.situation, required this.onTap});
  final WrSituation situation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A2C335D)),
        ),
        child: Text(situation.text,
            style: const TextStyle(fontSize: 14, color: WrColors.dark, height: 1.5)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Confirm
// ---------------------------------------------------------------------------

class _StepConfirm extends StatelessWidget {
  const _StepConfirm({required this.situation, required this.saving, required this.onSave});
  final WrSituation situation;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      children: [
        const Text('Điều bạn đang mong muốn:',
            style: TextStyle(fontSize: 12, color: Color(0xFFA3A3A3), fontWeight: FontWeight.w600, letterSpacing: 0.04)),
        const SizedBox(height: 8),
        if (situation.expectedOutcome != null)
          Text(situation.expectedOutcome!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.4)),
        if (situation.scaPerspective != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(situation.scaPerspective!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6)),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: saving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy,
            foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: WrColors.white))
              : const Text('Lưu vào hành trình', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Saved
// ---------------------------------------------------------------------------

class _StepSaved extends StatelessWidget {
  const _StepSaved({required this.patternCount});
  final int patternCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 36),
          const SizedBox(height: 16),
          const Text('Đã ghi nhận',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: WrColors.dark)),
          const SizedBox(height: 8),
          if (patternCount >= 3)
            Text('Đây là lần thứ $patternCount bạn gặp tình huống này.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go('/wr/story'),
            child: const Text('Đọc một câu chuyện tương tự →',
                style: TextStyle(fontSize: 14, color: WrColors.navy, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _situationsProvider = FutureProvider<List<WrSituation>>((ref) async {
  final repo = ref.watch(wrContentRepositoryProvider);
  final all = await repo.fetchSituations();
  // Sort by wave asc, then by code asc
  final sorted = List.of(all)
    ..sort((a, b) {
      final waveCmp = a.wave.compareTo(b.wave);
      if (waveCmp != 0) return waveCmp;
      return a.code.compareTo(b.code);
    });
  return sorted;
});
```

**Step 4: Thêm route `/wr/situation` vào `app_router.dart`**

Tìm dòng khai báo WrPaywallScreen route, thêm route mới trước:

```dart
GoRoute(
  path: '/wr/situation',
  builder: (context, state) => const WrSituationFlowScreen(),
),
```

Import: `import '../../features/wr/presentation/wr_situation_flow_screen.dart';`

**Step 5: Chạy tests**

```bash
flutter test test/features/wr_situation_flow_screen_test.dart
flutter analyze
```

Expected: tất cả PASS, 0 analyze issues.

---

## Task 6: WrStoryFlowScreen (6 phase)

**Files:**
- Create: `lib/features/wr/presentation/wr_story_flow_screen.dart`
- Modify: `lib/core/router/app_router.dart` (thêm route `/wr/story/flow`)
- Test: `test/features/wr_story_flow_screen_test.dart` (file mới)

**Lưu ý quan trọng về route:** `/wr/story` là StatefulShellBranch (tab), `/wr/story/flow` là fullscreen flow riêng.

**Step 1: Viết failing tests**

Tạo `test/features/wr_story_flow_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_story_flow_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

WrStory _story({
  String storyId = 'st1',
  ScaDimension dim = ScaDimension.c2,
  String content = 'Có một lần tôi...',
  String? aha = 'Điều tôi nhận ra là...',
  String? reflection = 'Điều này gợi lên điều gì?',
  String? practice = 'Hôm nay thử làm một việc nhỏ.',
  HumanNeed? need = HumanNeed.roRang,
}) => WrStory(
  storyId: storyId, title: 'Story $storyId', scaDimension: dim,
  storyContent: content, emotionTags: [], behaviorTags: [], careerStages: [],
  ahaMessage: aha, reflectionQuestion: reflection, practiceAction: practice,
  humanNeed: need,
);

Widget _wrap(Widget screen, {
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  FakeWrRepository? wr,
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final wrRepo = wr ?? FakeWrRepository();
  final router = GoRouter(
    initialLocation: '/wr/story/flow',
    routes: [
      GoRoute(path: '/wr/story/flow', builder: (_, __) => screen),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home'))),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      wrRepositoryProvider.overrideWithValue(wrRepo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  group('WrStoryFlowScreen — story phase', () {
    testWidgets('renders storyContent', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story(content: 'Có một lần tôi gặp khó khăn')]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      expect(find.textContaining('Có một lần tôi gặp khó khăn'), findsOneWidget);
    });

    testWidgets('shows label "Bạn có bao giờ?" for story phase', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story()]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      expect(find.textContaining('Bạn có bao giờ?'), findsOneWidget);
    });

    testWidgets('tapping "Tôi cũng từng như vậy" moves to aha phase', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story(aha: 'Điều WorkReflection nhận ra')]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Điều WorkReflection nhận ra'), findsOneWidget);
    });
  });

  group('WrStoryFlowScreen — aha phase', () {
    testWidgets('shows aha phase label', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story(aha: 'Aha message here')]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Điều WorkReflection nhận ra'), findsOneWidget);
    });

    testWidgets('Tiếp tục moves to confidence phase', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story()]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mức độ nhận ra'), findsOneWidget);
    });
  });

  group('WrStoryFlowScreen — confidence phase', () {
    Future<void> _toConfidence(WidgetTester tester, FakeWrContentRepository content) async {
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders 3 confidence options', (tester) async {
      final content = FakeWrContentRepository()..seedStories([_story()]);
      await _toConfidence(tester, content);
      expect(find.text('Rất liên quan'), findsOneWidget);
      expect(find.text('Hơi liên quan'), findsOneWidget);
      expect(find.text('Không liên quan'), findsOneWidget);
    });

    testWidgets('selecting confidence moves to reflection phase', (tester) async {
      final content = FakeWrContentRepository()..seedStories([_story(reflection: 'Gợi lên điều gì?')]);
      await _toConfidence(tester, content);
      await tester.tap(find.text('Rất liên quan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ghi lại suy nghĩ'), findsOneWidget);
    });
  });

  group('WrStoryFlowScreen — memory phase', () {
    Future<void> _toMemory(WidgetTester tester, FakeWrContentRepository content) async {
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy')); await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục')); await tester.pumpAndSettle();
      await tester.tap(find.text('Rất liên quan')); await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ qua')); await tester.pumpAndSettle(); // reflection skip
      await tester.tap(find.text('Lần này bỏ qua')); await tester.pumpAndSettle(); // practice skip
    }

    testWidgets('shows 4 memory type buttons', (tester) async {
      final content = FakeWrContentRepository()..seedStories([_story()]);
      await _toMemory(tester, content);
      expect(find.text('Nhận ra điều gì đó'), findsOneWidget);
      expect(find.text('Góc nhìn mới'), findsOneWidget);
      expect(find.text('Khám phá về mình'), findsOneWidget);
      expect(find.text('Quyết định đã rõ'), findsOneWidget);
    });

    testWidgets('selecting memory type saves 3 records (memory event + insight + 2 reflection steps)', (tester) async {
      final content = FakeWrContentRepository()..seedStories([_story()]);
      final intel = FakeWrIntelligenceRepository();
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content, intel: intel));
      await tester.tap(find.text('Tôi cũng từng như vậy')); await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục')); await tester.pumpAndSettle();
      await tester.tap(find.text('Rất liên quan')); await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ qua')); await tester.pumpAndSettle();
      await tester.tap(find.text('Lần này bỏ qua')); await tester.pumpAndSettle();
      await tester.tap(find.text('Nhận ra điều gì đó')); await tester.pumpAndSettle();
      // memory event
      expect(content.insertMemoryEventCalls.length, 1);
      // insight
      expect(intel.insertInsightCalls.length, 1);
      // reflection steps: insight + action
      expect(intel.insertReflectionStepCalls.length, 2);
    });

    testWidgets('"Câu chuyện này không quen" goes to next story', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([
        _story(storyId: 'st1', dim: ScaDimension.c2, content: 'Story 1'),
        _story(storyId: 'st2', dim: ScaDimension.a1, content: 'Story 2'),
      ]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.textContaining('không quen'));
      await tester.pumpAndSettle();
      expect(find.text('Story 2'), findsOneWidget);
    });
  });
}
```

**Step 2: Chạy test — verify FAIL**

```bash
flutter test test/features/wr_story_flow_screen_test.dart
```

Expected: FAIL.

**Step 3: Implement `lib/features/wr/presentation/wr_story_flow_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';

// Phase order cho story flow
enum _StoryPhase { story, aha, confidence, reflection, practice, memory }

// Wave priority: C2, A1, A3, C1, A4, A2, S1, C3, S2, S3
const _dimensionPriority = [
  ScaDimension.c2, ScaDimension.a1, ScaDimension.a3, ScaDimension.c1,
  ScaDimension.a4, ScaDimension.a2, ScaDimension.s1, ScaDimension.c3,
  ScaDimension.s2, ScaDimension.s3,
];

const _phaseLabels = {
  _StoryPhase.story: 'Bạn có bao giờ?',
  _StoryPhase.aha: 'Điều WorkReflection nhận ra',
  _StoryPhase.confidence: 'Mức độ nhận ra',
  _StoryPhase.reflection: 'Ghi lại suy nghĩ',
  _StoryPhase.practice: 'Thực hành nhỏ',
  _StoryPhase.memory: 'Phân loại trải nghiệm',
};

class WrStoryFlowScreen extends ConsumerStatefulWidget {
  const WrStoryFlowScreen({super.key});

  @override
  ConsumerState<WrStoryFlowScreen> createState() => _WrStoryFlowScreenState();
}

class _WrStoryFlowScreenState extends ConsumerState<WrStoryFlowScreen> {
  _StoryPhase _phase = _StoryPhase.story;
  WrStory? _story;
  int _storyIndex = 0; // index trong danh sách đã sắp priority
  List<WrStory> _stories = [];
  bool _loaded = false;

  int _intensity = 0; // 3=Rất, 2=Hơi, 1=Không
  String _reflectionText = '';
  bool _practiceAdded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final contentRepo = ref.read(wrContentRepositoryProvider);
    final allStories = await contentRepo.fetchStories();
    final events = await contentRepo.fetchMemoryEvents(limit: 200);
    final seenIds = events.map((e) => e.storyId).whereType<String>().toSet();

    // Sort by dimension priority
    final sorted = List.of(allStories);
    sorted.sort((a, b) {
      final ai = _dimensionPriority.indexOf(a.scaDimension);
      final bi = _dimensionPriority.indexOf(b.scaDimension);
      final aIdx = ai == -1 ? 999 : ai;
      final bIdx = bi == -1 ? 999 : bi;
      return aIdx.compareTo(bIdx);
    });

    // Remove seen, but keep fallback
    final unseen = sorted.where((s) => !seenIds.contains(s.storyId)).toList();
    final list = unseen.isNotEmpty ? unseen : sorted;

    if (mounted) {
      setState(() {
        _stories = list;
        _story = list.isNotEmpty ? list.first : null;
        _loaded = true;
      });
    }
  }

  void _nextStory() {
    final next = _storyIndex + 1;
    if (next < _stories.length) {
      setState(() {
        _storyIndex = next;
        _story = _stories[next];
        _phase = _StoryPhase.story;
        _intensity = 0;
        _reflectionText = '';
        _practiceAdded = false;
      });
    } else {
      // No more stories — go home
      if (mounted) context.go('/home');
    }
  }

  Future<void> _saveMemory(String memType) async {
    if (_story == null) return;
    setState(() => _saving = true);
    try {
      final userId = ref.read(currentUserIdProvider) ?? '';
      final contentRepo = ref.read(wrContentRepositoryProvider);
      final intelRepo = ref.read(wrIntelligenceRepositoryProvider);
      final story = _story!;

      // (a) insert CareerMemoryEvent
      await contentRepo.insertMemoryEvent(CareerMemoryEvent(
        id: '',
        userId: userId,
        storyId: story.storyId,
        scaDimension: story.scaDimension,
        humanNeed: story.humanNeed,
        intensity: _intensity,
        reflectionText: _reflectionText.isNotEmpty ? _reflectionText : null,
        behavior: memType,
      ));

      // (b) insert WrInsight
      if (story.ahaMessage != null) {
        await intelRepo.insertInsight(WrInsight(
          userId: userId,
          source: 'story',
          scaDimension: story.scaDimension,
          humanNeed: story.humanNeed,
          content: story.ahaMessage!,
        ));
      }

      // (c) insert ReflectionSteps: insight + action
      await intelRepo.insertReflectionStep(ReflectionStep(
        userId: userId,
        step: ReflectionStepType.insight,
        content: story.ahaMessage,
      ));
      if (_practiceAdded && story.practiceAction != null) {
        await intelRepo.insertReflectionStep(ReflectionStep(
          userId: userId,
          step: ReflectionStepType.action,
          content: story.practiceAction,
        ));
      } else {
        await intelRepo.insertReflectionStep(ReflectionStep(
          userId: userId,
          step: ReflectionStepType.action,
          content: null,
        ));
      }

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  double get _progress {
    const phases = _StoryPhase.values;
    final idx = phases.indexOf(_phase);
    return (idx + 1) / phases.length;
  }

  String get _phaseLabel => _phaseLabels[_phase] ?? '';

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_story == null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Không có câu chuyện nào.'),
            TextButton(onPressed: () => context.go('/home'), child: const Text('Về trang chủ')),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: Column(
          children: [
            // Header: back + progress + close
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: _phase == _StoryPhase.story ? null : () {
                      setState(() {
                        final idx = _StoryPhase.values.indexOf(_phase);
                        if (idx > 0) _phase = _StoryPhase.values[idx - 1];
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: WrColors.navy,
                          minHeight: 3,
                        ),
                        const SizedBox(height: 4),
                        Text(_phaseLabel,
                            style: const TextStyle(fontSize: 10, color: Color(0xFFA3A3A3), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildPhase()),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase() {
    final story = _story!;
    return switch (_phase) {
      _StoryPhase.story => _PhaseStory(
          story: story,
          onResonates: () => setState(() => _phase = _StoryPhase.aha),
          onNotResonates: _nextStory,
        ),
      _StoryPhase.aha => _PhaseAha(
          story: story,
          onContinue: () => setState(() => _phase = _StoryPhase.confidence),
        ),
      _StoryPhase.confidence => _PhaseConfidence(
          onSelect: (intensity) => setState(() {
            _intensity = intensity;
            _phase = _StoryPhase.reflection;
          }),
        ),
      _StoryPhase.reflection => _PhaseReflection(
          story: story,
          onSave: (text) => setState(() {
            _reflectionText = text;
            _phase = _StoryPhase.practice;
          }),
          onSkip: () => setState(() => _phase = _StoryPhase.practice),
        ),
      _StoryPhase.practice => _PhasePractice(
          story: story,
          onAdd: () => setState(() {
            _practiceAdded = true;
            _phase = _StoryPhase.memory;
          }),
          onSkip: () => setState(() => _phase = _StoryPhase.memory),
        ),
      _StoryPhase.memory => _PhaseMemory(saving: _saving, onSelect: _saveMemory),
    };
  }
}

// ---------------------------------------------------------------------------
// Phase widgets
// ---------------------------------------------------------------------------

class _PhaseStory extends StatelessWidget {
  const _PhaseStory({required this.story, required this.onResonates, required this.onNotResonates});
  final WrStory story;
  final VoidCallback onResonates;
  final VoidCallback onNotResonates;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        Text(
          '"${story.storyContent}"',
          style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: WrColors.dark, height: 1.7),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onResonates,
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy, foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Tôi cũng từng như vậy', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onNotResonates,
          child: const Text('Câu chuyện này không quen với tôi', style: TextStyle(color: Color(0xFF737373))),
        ),
      ],
    );
  }
}

class _PhaseAha extends StatelessWidget {
  const _PhaseAha({required this.story, required this.onContinue});
  final WrStory story;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        if (story.ahaMessage != null)
          Text(story.ahaMessage!,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.5)),
        if (story.selfReflection != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: WrColors.coral, width: 3)),
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(story.selfReflection!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6)),
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy, foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Tiếp tục', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _PhaseConfidence extends StatelessWidget {
  const _PhaseConfidence({required this.onSelect});
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        const Text('Điều này có liên quan đến bạn không?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.4)),
        const SizedBox(height: 24),
        _ConfidenceOption(label: 'Rất liên quan', onTap: () => onSelect(3)),
        const SizedBox(height: 10),
        _ConfidenceOption(label: 'Hơi liên quan', onTap: () => onSelect(2)),
        const SizedBox(height: 10),
        _ConfidenceOption(label: 'Không liên quan', onTap: () => onSelect(1)),
      ],
    );
  }
}

class _ConfidenceOption extends StatelessWidget {
  const _ConfidenceOption({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x1A2C335D)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: WrColors.dark)),
      ),
    );
  }
}

class _PhaseReflection extends StatefulWidget {
  const _PhaseReflection({required this.story, required this.onSave, required this.onSkip});
  final WrStory story;
  final ValueChanged<String> onSave;
  final VoidCallback onSkip;

  @override
  State<_PhaseReflection> createState() => _PhaseReflectionState();
}

class _PhaseReflectionState extends State<_PhaseReflection> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final question = widget.story.reflectionQuestion ?? 'Điều này gợi lên điều gì với bạn?';
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        Text(question, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.4)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Viết suy nghĩ của bạn...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: const Color(0x1A2C335D))),
            filled: true, fillColor: WrColors.white,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => widget.onSave(_ctrl.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy, foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Lưu và tiếp tục', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: widget.onSkip, child: const Text('Bỏ qua', style: TextStyle(color: Color(0xFF737373)))),
      ],
    );
  }
}

class _PhasePractice extends StatelessWidget {
  const _PhasePractice({required this.story, required this.onAdd, required this.onSkip});
  final WrStory story;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        if (story.practiceAction != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WrColors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1A2C335D)),
            ),
            child: Text(story.practiceAction!,
                style: const TextStyle(fontSize: 15, color: WrColors.dark, height: 1.5)),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy, foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Thêm vào lịch thực hành', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: onSkip, child: const Text('Lần này bỏ qua', style: TextStyle(color: Color(0xFF737373)))),
      ],
    );
  }
}

class _PhaseMemory extends StatelessWidget {
  const _PhaseMemory({required this.saving, required this.onSelect});
  final bool saving;
  final ValueChanged<String> onSelect;

  static const _options = [
    ('reflection', 'Nhận ra điều gì đó'),
    ('insight', 'Góc nhìn mới'),
    ('discovery', 'Khám phá về mình'),
    ('decision', 'Quyết định đã rõ'),
  ];

  @override
  Widget build(BuildContext context) {
    if (saving) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        const Text('Trải nghiệm này thuộc loại nào?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: WrColors.dark, height: 1.4)),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5,
          children: _options.map((opt) => _MemoryTypeBtn(
            label: opt.$2,
            onTap: () => onSelect(opt.$1),
          )).toList(),
        ),
      ],
    );
  }
}

class _MemoryTypeBtn extends StatelessWidget {
  const _MemoryTypeBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: WrColors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x1A2C335D)),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WrColors.dark)),
      ),
    );
  }
}
```

**Step 4: Thêm route `/wr/story/flow` vào `app_router.dart`**

Import thêm `wr_story_flow_screen.dart` và thêm route:

```dart
GoRoute(
  path: '/wr/story/flow',
  builder: (context, state) => const WrStoryFlowScreen(),
),
```

Lưu ý: đặt route này NGOÀI StatefulShellRoute (fullscreen), trước block `StatefulShellRoute.indexedStack`.

**Step 5: Chạy tests**

```bash
flutter test test/features/wr_story_flow_screen_test.dart
```

Expected: tất cả PASS.

---

## Task 7: Cập nhật WrStoryScreen (tab) để link vào flow

**Files:**
- Modify: `lib/features/wr/presentation/wr_story_screen.dart`

**Mục tiêu:** WrStoryScreen (tab `/wr/story`) hiện placeholder — thêm nút "Bắt đầu đọc" → push `/wr/story/flow`.

**Step 1: Sửa WrStoryScreen**

Thêm nút CTA vào placeholder:

```dart
// Thay SliverFillRemaining bằng:
SliverFillRemaining(
  hasScrollBody: false,
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Đọc câu chuyện phù hợp với bạn lúc này.', ...),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.push('/wr/story/flow'),
          child: const Text('Bắt đầu đọc'),
        ),
      ],
    ),
  ),
),
```

Import `go_router`.

**Step 2: Chạy toàn bộ**

```bash
flutter analyze && flutter test
```

Expected: 0 issues; tất cả pass.

---

## Task 8: Fix tests P1 bị vỡ + chạy gates cuối

**Files:**
- Check: tất cả test files hiện có

**Step 1: Chạy toàn bộ suite**

```bash
flutter test 2>&1 | tee /tmp/test_output.txt
```

**Step 2: Xử lý failures**

Các test P1 có thể bị vỡ do:
- `test/features/home_test.dart` — import `HomeScreen`, không liên quan WrHomeScreen → không bị ảnh hưởng
- `test/core/wr_repository_test.dart` — test `upsertCheckin(Mood.happy)` → vẫn pass vì named params optional
- `test/core/optimistic_update_test.dart` — tương tự, backward compat

Nếu có failure mới, fix ngay trong bước này.

**Step 3: Chạy flutter analyze**

```bash
flutter analyze
```

Expected: 0 issues.

**Step 4: Đếm số tests**

```bash
flutter test --reporter=compact 2>&1 | tail -5
```

Ghi lại số tests pass.

---

## Gates

| Gate | Command | Expected |
|------|---------|---------|
| Analyze | `flutter analyze` | 0 issues |
| Tests | `flutter test` | tất cả PASS |

## Điểm lệch spec (đã quyết bởi Fable)

1. **`/wr/story` vs `/wr/story/flow`**: Spec gốc nói thay WrStoryScreen — thay vào đó ta giữ WrStoryScreen (tab placeholder) và thêm route `/wr/story/flow` cho full flow, tránh break StatefulShellRoute.
2. **Khối "Hôm qua" và "Tiếp tục hôm nay"**: Không implement trong Sprint 1 — cần data CareerMemoryEvent thật từ user, sẽ làm Sprint 2.
3. **self phase bị lược bỏ**: Fable đã quyết — `aha_by_choice` không tồn tại trong wr_stories.
4. **practice enrollTheme**: Chỉ lưu `behavior='practice_added'` trong CareerMemoryEvent, không gọi `enrollTheme` thật (để dành P3 implementation đúng schema).
5. **goBranch điều hướng**: Situation flow sau save dùng `context.go('/wr/story')` thay vì `goBranch` vì không có access vào `navigationShell` trong màn con.

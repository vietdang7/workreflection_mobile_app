# Phase 5 Task 2 — SCA Radar Chart on ReportScreen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a triangular radar chart visualizing Structure/Culture/Activity scores above the per-layer cards on ReportScreen, matching the web's radar design (scale 0–5, CustomPainter approach).

**Architecture:** Extract score-to-chart-data mapping into a pure `lib/core/logic/sca_chart_data.dart` function (testable in isolation). Render the radar chart using a `CustomPainter` (no external chart package — 3-axis triangle is simple and avoids fl_chart's pubspec conflicts). The chart widget `ScaRadarChart` lives in `lib/features/survey/presentation/report_screen.dart` as a private widget class. New l10n key `reportScaChartTitle` is added to both ARBs.

**Tech Stack:** Flutter CustomPainter (dart:ui), no new pub dependencies, existing WrColors, existing `CcReportFull` model, existing `AppLocalizations`.

---

## Research Findings (pre-baked for implementer)

### Web radar chart (Premium.tsx lines 1007–1067)
- **3-axis triangle** with Structure at top, Culture bottom-right, Activity bottom-left.
- **Scale: 0 to 5.** Each score divided by 5 to get ratio (0.0–1.0).
- **5 grid levels** (concentric triangles at ratio 1/5, 2/5, 3/5, 4/5, 5/5).
- **Color:** stroke `#FF6859` (= `WrColors.coral`), fill `rgba(184, 84, 80, 0.15)` (coral at 15% opacity).
- **Data points:** circles r=5, filled with coral.
- **Axis labels:** label text + score value (e.g. "Structure 4.0").
- The SVG math: center `(cx, cy)`, maxR = size*0.35; angles: Structure = -π/2 (top), Culture = -π/2 + 2π/3, Activity = -π/2 + 4π/3.

### Score scale (verified from both SCAResults.tsx and Premium.tsx)
- `score_structure`, `score_culture`, `score_activity` from `cc_reports` are stored in range **0.0 – 5.0** (1-decimal precision, avg of Likert 1–5 answers).
- Max = 5.0. Grid at 1,2,3,4,5.

### Existing l10n keys — reuse, do NOT re-add
- `reportLayerStructure` (VI: "Cấu trúc tổ chức", EN: "Organisational Structure")
- `reportLayerCulture` (VI: "Văn hoá làm việc", EN: "Work Culture")
- `reportLayerActivity` (VI: "Hoạt động hàng ngày", EN: "Daily Activity")

### New l10n key needed
- `reportScaChartTitle` — section eyebrow/header for the chart (not in either ARB yet).

---

## Task 1: Add new l10n strings

**Files:**
- Modify: `lib/l10n/app_vi.arb`
- Modify: `lib/l10n/app_en.arb`

**Step 1: Add `reportScaChartTitle` to app_vi.arb**

Open `lib/l10n/app_vi.arb`. Find the block that starts with `"reportTitle"`. Add this key right after `"reportViewHistory": "Xem lịch sử khảo sát",`:

```json
  "reportScaChartTitle": "Bức tranh S-C-A",
```

**Step 2: Add `reportScaChartTitle` to app_en.arb**

Open `lib/l10n/app_en.arb`. Find the same `reportViewHistory` line. Add right after it:

```json
  "reportScaChartTitle": "S-C-A Overview",
```

**Step 3: Verify codegen runs**

Run:
```bash
flutter gen-l10n 2>&1
```
Expected: no errors, `lib/l10n/app_localizations.dart` regenerated (or `dart run build_runner build` if the project uses that).

Actually the project uses `generate: true` in pubspec.yaml (flutter gen-l10n auto-runs on `flutter pub get` or `flutter build`). Trigger it:
```bash
flutter pub get 2>&1 | tail -3
```

**Step 4: Confirm new key exists in generated file**

Run:
```bash
grep "reportScaChartTitle" lib/l10n/app_localizations.dart 2>/dev/null || grep "reportScaChartTitle" lib/l10n/app_localizations_vi.dart 2>/dev/null
```
Expected: at least one match.

---

## Task 2: Extract chart data logic into pure function

**Files:**
- Create: `lib/core/logic/sca_chart_data.dart`
- Create test: `test/core/sca_chart_data_test.dart`

### Step 1: Write the failing test first

Create `test/core/sca_chart_data_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/sca_chart_data.dart';

void main() {
  group('ScaChartData', () {
    test('ratios are scores divided by 5.0', () {
      final data = ScaChartData.fromScores(
        structure: 5.0,
        culture: 2.5,
        activity: 0.0,
      );
      expect(data.structureRatio, closeTo(1.0, 0.001));
      expect(data.cultureRatio, closeTo(0.5, 0.001));
      expect(data.activityRatio, closeTo(0.0, 0.001));
    });

    test('scores above max clamp to 1.0 ratio', () {
      // defensive: if a score somehow exceeds 5, ratio should not exceed 1.0
      final data = ScaChartData.fromScores(
        structure: 6.0,
        culture: 5.0,
        activity: 5.0,
      );
      expect(data.structureRatio, closeTo(1.0, 0.001));
    });

    test('scores below 0 clamp to 0.0 ratio', () {
      final data = ScaChartData.fromScores(
        structure: -1.0,
        culture: 0.0,
        activity: 0.0,
      );
      expect(data.structureRatio, closeTo(0.0, 0.001));
    });

    test('typical scores produce correct ratios', () {
      final data = ScaChartData.fromScores(
        structure: 3.5,
        culture: 4.2,
        activity: 3.8,
      );
      expect(data.structureRatio, closeTo(0.70, 0.001));
      expect(data.cultureRatio, closeTo(0.84, 0.001));
      expect(data.activityRatio, closeTo(0.76, 0.001));
    });

    test('hasData is false when all scores are zero', () {
      final data = ScaChartData.fromScores(
        structure: 0.0,
        culture: 0.0,
        activity: 0.0,
      );
      expect(data.hasData, isFalse);
    });

    test('hasData is true when any score is non-zero', () {
      final data = ScaChartData.fromScores(
        structure: 0.0,
        culture: 0.1,
        activity: 0.0,
      );
      expect(data.hasData, isTrue);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/core/sca_chart_data_test.dart 2>&1
```
Expected: FAIL — "Target file not found" or import error.

**Step 3: Implement `sca_chart_data.dart`**

Create `lib/core/logic/sca_chart_data.dart`:

```dart
// Pure data-mapping helper for the SCA radar chart.
// No Flutter/Supabase dependencies — fully unit-testable.

const _kMaxScore = 5.0;

/// Holds the normalized (0.0–1.0) ratios for each S-C-A axis,
/// computed from raw 0–5 scores.
class ScaChartData {
  const ScaChartData({
    required this.structureRatio,
    required this.cultureRatio,
    required this.activityRatio,
  });

  final double structureRatio;
  final double cultureRatio;
  final double activityRatio;

  /// Returns true when at least one score is non-zero (data worth rendering).
  bool get hasData =>
      structureRatio > 0 || cultureRatio > 0 || activityRatio > 0;

  factory ScaChartData.fromScores({
    required double structure,
    required double culture,
    required double activity,
  }) {
    double clamp(double v) => (v / _kMaxScore).clamp(0.0, 1.0);
    return ScaChartData(
      structureRatio: clamp(structure),
      cultureRatio: clamp(culture),
      activityRatio: clamp(activity),
    );
  }
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/core/sca_chart_data_test.dart 2>&1
```
Expected: All 6 tests PASS.

**Step 5: Commit this task**

```bash
git add lib/core/logic/sca_chart_data.dart test/core/sca_chart_data_test.dart lib/l10n/app_vi.arb lib/l10n/app_en.arb
git commit -m "$(cat <<'EOF'
feat(p5): extract ScaChartData pure logic + l10n key for radar chart (task 2 prep)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Implement the ScaRadarChart widget + ReportScreen integration

**Files:**
- Modify: `lib/features/survey/presentation/report_screen.dart`

### Step 1: Write the failing widget tests first

Open `test/features/report_test.dart`. Add these test cases inside the existing `group('ReportScreen', ...)` block, right after the last `testWidgets` call and before the closing `});` of the group:

```dart
    testWidgets('T2-R1: radar chart section renders when SCA scores are present', (tester) async {
      final report = _report(s: 4.0, c: 3.5, a: 4.5);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      // The chart section title should be visible
      expect(find.text('Bức tranh S-C-A'), findsOneWidget);
      // The chart CustomPaint should be present
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('T2-R2: radar chart is absent when all SCA scores are zero', (tester) async {
      final report = _report(s: 0.0, c: 0.0, a: 0.0);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Bức tranh S-C-A'), findsNothing);
    });
```

**Step 2: Run the new tests to verify they fail**

```bash
flutter test test/features/report_test.dart --name "T2-R" 2>&1
```
Expected: FAIL — 'Bức tranh S-C-A' not found (widget not yet built).

**Step 3: Add the radar chart painter + widget to report_screen.dart**

In `lib/features/survey/presentation/report_screen.dart`, add these imports at the top of the file (after the existing imports):

```dart
import 'dart:math' as math;
import '../../../core/logic/sca_chart_data.dart';
```

Then add these two new classes at the **end** of the file, after the `_PremiumUpsellCard` class:

```dart
// ---------------------------------------------------------------------------
// SCA Radar Chart
// ---------------------------------------------------------------------------

/// CustomPainter that draws a 3-axis triangular radar chart for S-C-A scores.
/// Matches the web Premium.tsx radar geometry: Structure=top, Culture=bottom-right,
/// Activity=bottom-left. Scale 0–5. Grid at levels 1–5.
class _ScaRadarPainter extends CustomPainter {
  const _ScaRadarPainter({required this.data});

  final ScaChartData data;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // maxR: 40% of the shorter dimension, leaving room for labels.
    final maxR = math.min(size.width, size.height) * 0.40;

    // Axis angles: Structure=top (-π/2), Culture=bottom-right, Activity=bottom-left
    const angles = [
      -math.pi / 2,
      -math.pi / 2 + 2 * math.pi / 3,
      -math.pi / 2 + 4 * math.pi / 3,
    ];

    Offset axisPoint(int axis, double ratio) => Offset(
          cx + math.cos(angles[axis]) * maxR * ratio,
          cy + math.sin(angles[axis]) * maxR * ratio,
        );

    // --- Grid triangles (5 levels) ---
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFE5E5E5);

    for (int level = 1; level <= 5; level++) {
      final r = level / 5.0;
      final p0 = axisPoint(0, r);
      final p1 = axisPoint(1, r);
      final p2 = axisPoint(2, r);
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      gridPaint.strokeWidth = level == 5 ? 1.5 : 0.8;
      canvas.drawPath(path, gridPaint);
    }

    // --- Axis lines ---
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFE5E5E5);

    for (int i = 0; i < 3; i++) {
      final tip = axisPoint(i, 1.0);
      canvas.drawLine(Offset(cx, cy), tip, axisPaint);
    }

    // --- Data polygon ---
    final sP = axisPoint(0, data.structureRatio);
    final cP = axisPoint(1, data.cultureRatio);
    final aP = axisPoint(2, data.activityRatio);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = WrColors.coral.withValues(alpha: 0.15);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..color = WrColors.coral;

    final dataPath = Path()
      ..moveTo(sP.dx, sP.dy)
      ..lineTo(cP.dx, cP.dy)
      ..lineTo(aP.dx, aP.dy)
      ..close();

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // --- Data point circles ---
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = WrColors.coral;

    for (final pt in [sP, cP, aP]) {
      canvas.drawCircle(pt, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ScaRadarPainter old) => old.data != data;
}

/// Radar chart section widget that renders the SCA pentagon + axis labels.
class ScaRadarChart extends StatelessWidget {
  const ScaRadarChart({
    super.key,
    required this.structure,
    required this.culture,
    required this.activity,
    required this.l10n,
  });

  final double structure;
  final double culture;
  final double activity;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final data = ScaChartData.fromScores(
      structure: structure,
      culture: culture,
      activity: activity,
    );

    if (!data.hasData) return const SizedBox.shrink();

    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(l10n.reportScaChartTitle),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: _ScaRadarPainter(data: data),
                  size: const Size(double.infinity, 260),
                  child: const SizedBox.expand(),
                ),
                // Axis labels — positioned relative to chart center
                // Structure: top center
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        l10n.reportLayerStructure,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.dark,
                        ),
                      ),
                      Text(
                        structure.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
                // Culture: bottom-right
                Positioned(
                  bottom: 4,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.reportLayerCulture,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.dark,
                        ),
                      ),
                      Text(
                        culture.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
                // Activity: bottom-left
                Positioned(
                  bottom: 4,
                  left: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reportLayerActivity,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.dark,
                        ),
                      ),
                      Text(
                        activity.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 4: Insert the radar chart section into `_ReportBody.build()`**

In the `_ReportBody` class's `build()` method, find the comment `// S / C / A layer cards` and the line `_LayerCard(label: l10n.reportLayerStructure, ...)` that immediately follows it.

Insert the chart **above** that block (after the `const SizedBox(height: 28)` that follows the total score header):

```dart
          // SCA Radar Chart (above per-layer cards)
          ScaRadarChart(
            structure: report.scoreStructure,
            culture: report.scoreCulture,
            activity: report.scoreActivity,
            l10n: l10n,
          ),
          const SizedBox(height: 16),
```

The insertion point in the build method (after line ~150 in the original file, after the `const SizedBox(height: 28),` that closes the total score section):

```dart
          const SizedBox(height: 28),

          // SCA Radar Chart  ← INSERT HERE
          ScaRadarChart(
            structure: report.scoreStructure,
            culture: report.scoreCulture,
            activity: report.scoreActivity,
            l10n: l10n,
          ),
          const SizedBox(height: 16),

          // S / C / A layer cards
          _LayerCard(
```

**Step 5: Run the failing widget tests**

```bash
flutter test test/features/report_test.dart --name "T2-R" 2>&1
```
Expected: PASS for both T2-R1 and T2-R2.

**Step 6: Run flutter analyze**

```bash
flutter analyze 2>&1 | tail -10
```
Expected: `No issues found!`

If analyze fails with issues in report_screen.dart:
- Missing import for `dart:math` → already added in Step 3.
- `WrEyebrow` not imported → it's already in the imports (`import '../../../core/widgets/eyebrow.dart'`).
- `withValues` API: `WrColors.coral.withValues(alpha: 0.15)` is the Flutter 3.x API. If the project uses an older API, use `.withOpacity(0.15)` instead.

**Step 7: Run ALL tests**

```bash
flutter test 2>&1 | tail -10
```
Expected: All tests pass (was 508, now should be 508 + 6 new unit tests + 2 new widget tests = 516).

**Step 8: Commit**

```bash
git add lib/features/survey/presentation/report_screen.dart test/features/report_test.dart
git commit -m "$(cat <<'EOF'
feat(p5): SCA radar chart on report (task 2)

CustomPainter 3-axis triangle chart above per-layer cards on ReportScreen,
matching web Premium.tsx geometry (Structure top, Culture bottom-right,
Activity bottom-left, scale 0-5, coral fill at 15% opacity, 5 grid levels).
Axis labels reuse existing reportLayerStructure/Culture/Activity l10n keys.
New reportScaChartTitle key added to VI+EN ARBs.
Extracted ScaChartData pure logic for unit testing.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Run gates and verify

**Step 1: flutter analyze**
```bash
flutter analyze 2>&1
```
Expected output ends with: `No issues found!`

**Step 2: flutter test**
```bash
flutter test 2>&1 | tail -5
```
Expected output ends with: `All tests passed!`

**Step 3: Paste the last 5-10 lines of both outputs** in your report to Fable.

---

## Checklist Before Reporting to Fable

- [ ] `reportScaChartTitle` key added to both ARBs
- [ ] `ScaChartData` pure logic in `lib/core/logic/sca_chart_data.dart` with 6 unit tests
- [ ] `ScaRadarChart` widget and `_ScaRadarPainter` added to `report_screen.dart`
- [ ] Chart appears above `_LayerCard` widgets (not in SurveyHistoryScreen or elsewhere)
- [ ] `dart:math` imported in report_screen.dart
- [ ] `sca_chart_data.dart` imported in report_screen.dart
- [ ] Zero-score guard: chart hidden when all scores are 0
- [ ] `flutter analyze` → 0 issues
- [ ] `flutter test` → all tests green (2 new widget + 6 new unit tests)
- [ ] Commit message: `feat(p5): SCA radar chart on report (task 2)`

## Deferred Items
- fl_chart was NOT added — CustomPainter is sufficient for 3-axis triangle and avoids pubspec risk.
- Score labels overlap prevention on very small screens: acceptable for now (labels use Positioned which may overlap on screens < 300px wide — out of scope for this task).
- The chart is not shown on SurveyHistoryScreen rows (per task scope).

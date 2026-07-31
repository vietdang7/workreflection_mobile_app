// WXS §3.12 Invariant 6 — Development Flow chỉ mở khi Pattern đủ mạnh.
// Run: flutter test test/core/logic/wr_dominant_need_dev_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_dominant_need.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

WrSituation _sit(String code, HumanNeed need) => WrSituation(
      code: code,
      text: code,
      scaDimension: ScaDimension.c1,
      wave: 1,
      humanNeed: need,
    );

/// [count] lần xuất hiện của [code] trong recentSituationIds.
List<String> _p(String code, int count) => List.filled(count, code);

void main() {
  final situations = [
    _sit('s1', HumanNeed.ketNoi),
    _sit('s2', HumanNeed.ketNoi),
    _sit('s3', HumanNeed.roRang),
  ];

  test('ngưỡng là hai lần lặp cùng chủ đề', () {
    expect(kDevelopmentFlowThreshold, 2);
  });

  test('một lần gặp chưa mở Development Flow', () {
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        recent: [..._p('s1', 1)],
        situations: situations,
      ),
      isFalse,
    );
  });

  test('hai lần cùng một tình huống thì mở', () {
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        recent: [..._p('s1', 2)],
        situations: situations,
      ),
      isTrue,
    );
  });

  test('cộng dồn các tình huống cùng nhu cầu', () {
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        recent: [..._p('s1', 1), ..._p('s2', 1)],
        situations: situations,
      ),
      isTrue,
    );
  });

  test('không cộng nhầm nhu cầu khác', () {
    expect(occurrencesForNeed(HumanNeed.ketNoi, [..._p('s3', 9)], situations), 0);
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        recent: [..._p('s3', 9)],
        situations: situations,
      ),
      isFalse,
    );
  });

  test('chưa có nhu cầu chủ đạo thì không mở', () {
    expect(
      developmentFlowUnlocked(
        need: null,
        recent: [..._p('s1', 9)],
        situations: situations,
      ),
      isFalse,
    );
  });

  // ── Hướng 2 — Self-Check mở khoá ngay (khách chốt 2026-07-31) ─────────────

  test('làm xong Self-Check thì mở ngay, không cần lặp lần nào', () {
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        recent: const [],
        situations: situations,
        hasSelfCheck: true,
      ),
      isTrue,
    );
  });

  test('Self-Check vẫn cần một nhu cầu chủ đạo để bám vào', () {
    expect(
      developmentFlowUnlocked(
        need: null,
        recent: const [],
        situations: situations,
        hasSelfCheck: true,
      ),
      isFalse,
    );
  });

  test('chưa Self-Check thì ngưỡng lặp giữ nguyên', () {
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        recent: [..._p('s1', 1)],
        situations: situations,
        hasSelfCheck: false,
      ),
      isFalse,
    );
  });
}

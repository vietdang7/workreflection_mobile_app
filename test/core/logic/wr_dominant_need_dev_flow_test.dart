// WXS §3.12 Invariant 6 — Development Flow chỉ mở khi Pattern đủ mạnh.
// Run: flutter test test/core/logic/wr_dominant_need_dev_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_dominant_need.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

WrSituation _sit(String code, HumanNeed need) => WrSituation(
      code: code,
      text: code,
      scaDimension: ScaDimension.c1,
      wave: 1,
      humanNeed: need,
    );

PatternCount _p(String code, int count) => PatternCount(
      userId: 'u1',
      situationCode: code,
      occurrenceCount: count,
      lastSeenAt: DateTime(2026, 7, 20),
    );

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
        patterns: [_p('s1', 1)],
        situations: situations,
      ),
      isFalse,
    );
  });

  test('hai lần cùng một tình huống thì mở', () {
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        patterns: [_p('s1', 2)],
        situations: situations,
      ),
      isTrue,
    );
  });

  test('cộng dồn các tình huống cùng nhu cầu', () {
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        patterns: [_p('s1', 1), _p('s2', 1)],
        situations: situations,
      ),
      isTrue,
    );
  });

  test('không cộng nhầm nhu cầu khác', () {
    expect(occurrencesForNeed(HumanNeed.ketNoi, [_p('s3', 9)], situations), 0);
    expect(
      developmentFlowUnlocked(
        need: HumanNeed.ketNoi,
        patterns: [_p('s3', 9)],
        situations: situations,
      ),
      isFalse,
    );
  });

  test('chưa có nhu cầu chủ đạo thì không mở', () {
    expect(
      developmentFlowUnlocked(
        need: null,
        patterns: [_p('s1', 9)],
        situations: situations,
      ),
      isFalse,
    );
  });
}

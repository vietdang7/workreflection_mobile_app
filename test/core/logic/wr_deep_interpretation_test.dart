// Thư viện nội dung "Diễn giải sâu & xu hướng".
// Nguồn: WorkReflection_DienGiaiSau_NoiDung.docx (khách gửi 10/09/2026).
// Run: flutter test test/core/logic/wr_deep_interpretation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_deep_interpretation.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

final _now = DateTime(2026, 9, 10);

const _situations = [
  WrSituation(code: 'S1-01', text: 'S', scaDimension: ScaDimension.s1, wave: 1),
  WrSituation(code: 'C2-01', text: 'C', scaDimension: ScaDimension.c2, wave: 1),
  WrSituation(code: 'A3-01', text: 'A', scaDimension: ScaDimension.a3, wave: 1),
  WrSituation(
    code: 'P-WIN',
    text: 'Vừa làm được điều hay',
    scaDimension: ScaDimension.pAchieve,
    wave: 1,
  ),
];

ScaSelfCheckResponse _check({
  required DateTime at,
  double s = 3.0,
  double c = 3.0,
  double a = 3.0,
}) =>
    ScaSelfCheckResponse(
      userId: 'u1',
      answers: const {},
      structureScore: s,
      cultureScore: c,
      activityScore: a,
      takenAt: at,
    );

ReflectionEpisode _ep(String code, DateTime at) => ReflectionEpisode(
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      situationCode: code,
      openedAt: at,
    );

/// [count] lượt mang mã [code], rải trong [withinDays] ngày gần nhất tính từ
/// [end]. Rải chứ không dồn một ngày: cửa sổ cắt theo ngày lịch.
List<ReflectionEpisode> _eps(
  String code,
  int count, {
  required DateTime end,
  int withinDays = 30,
}) =>
    [
      for (var i = 0; i < count; i++)
        _ep(code, end.subtract(Duration(days: i % withinDays))),
    ];

DeepFacts _facts({
  List<ScaSelfCheckResponse> history = const [],
  List<ReflectionEpisode> episodes = const [],
}) =>
    buildDeepFacts(
      history: history,
      episodes: episodes,
      situations: _situations,
      now: _now,
    );

void main() {
  group('Lớp 1 · dữ kiện', () {
    test('mẫu số là TỔNG số lần, không phải tổng ba trụ', () {
      // 10 lượt thuộc trụ C, 6 lượt là tình huống tích cực (không thuộc trụ
      // nào). Tổng ba trụ là 10, nhưng tổng số lần nhìn lại là 16.
      final f = _facts(episodes: [
        ..._eps('C2-01', 10, end: _now),
        ..._eps('P-WIN', 6, end: _now),
      ]);
      expect(f.pillarCount[SelfCheckPillar.c], 10);
      expect(f.totalReflection, 16);
    });

    test('tình huống tích cực KHÔNG bị dồn vào trụ A', () {
      // Lỗi có sẵn trước 10/09: `pillarOfDimension` bản cũ có `_ => pillar.a`,
      // nên mọi lượt "vừa làm được điều hay" phồng trụ A lên.
      final f = _facts(episodes: _eps('P-WIN', 20, end: _now));
      expect(f.pillarCount[SelfCheckPillar.a], 0);
      expect(f.dominant, isNull);
    });

    test('trụ nổi trội phải vượt 40% TỔNG SỐ LẦN', () {
      // 15 lượt C trên 100 lượt: nhiều nhất trong ba trụ, nhưng chỉ 15% bức
      // tranh người dùng đang nhìn.
      final f = _facts(episodes: [
        ..._eps('C2-01', 15, end: _now),
        ..._eps('P-WIN', 85, end: _now),
      ]);
      expect(f.dominant, isNull);
    });

    test('tier1 cần cả Self-Check lẫn 15 lần nhìn lại', () {
      expect(_facts(episodes: _eps('C2-01', 20, end: _now)).tier1Unlocked,
          isFalse);
      expect(_facts(history: [_check(at: _now)]).tier1Unlocked, isFalse);
      expect(
        _facts(
          history: [_check(at: _now)],
          episodes: _eps('C2-01', 15, end: _now),
        ).tier1Unlocked,
        isTrue,
      );
    });

    test('tier2 cần HAI cửa sổ liền kề, mỗi cửa sổ đủ 10 lần', () {
      // Chỉ cửa sổ hiện tại có dữ liệu.
      expect(_facts(episodes: _eps('C2-01', 20, end: _now)).tier2Unlocked,
          isFalse);

      final twoWindows = [
        ..._eps('C2-01', 12, end: _now),
        ..._eps('C2-01', 12, end: _now.subtract(const Duration(days: 30))),
      ];
      expect(_facts(episodes: twoWindows).tier2Unlocked, isTrue);
    });

    test('tier3 cần hai lần Self-Check cách nhau ít nhất 6 tuần', () {
      // §5 gọi đây là ràng buộc BẮT BUỘC: hai lần cách nhau vài ngày chỉ phản
      // ánh dao động tâm trạng, không phải thay đổi điều kiện làm việc.
      final tooClose = _facts(history: [
        _check(at: _now),
        _check(at: _now.subtract(const Duration(days: 20))),
      ]);
      expect(tooClose.tier3Unlocked, isFalse);

      final farEnough = _facts(history: [
        _check(at: _now),
        _check(at: _now.subtract(const Duration(days: 42))),
      ]);
      expect(farEnough.tier3Unlocked, isTrue);
    });
  });

  group('Tầng 1 · bốn nhánh khoảng lệch', () {
    DeepFacts withPillars({
      required double s,
      required double c,
      required double a,
      String dominantCode = 'C2-01',
      int count = 20,
    }) =>
        _facts(
          history: [_check(at: _now, s: s, c: c, a: a)],
          episodes: _eps(dominantCode, count, end: _now),
        );

    test('A · tự chấm ổn mà lại là trụ quay lại nhiều nhất', () {
      final f = withPillars(s: 3.0, c: 4.2, a: 3.0);
      expect(deepGapBranch(f), DeepGapBranch.outOfSync);
      expect(deepGapText(f), contains('20'));
    });

    test('B · hai nguồn xác nhận lẫn nhau', () {
      final f = withPillars(s: 3.0, c: 2.0, a: 3.0);
      expect(deepGapBranch(f), DeepGapBranch.aligned);
    });

    test('C · chưa trụ nào nổi trội rõ', () {
      final f = _facts(
        history: [_check(at: _now)],
        episodes: [
          ..._eps('S1-01', 7, end: _now),
          ..._eps('C2-01', 7, end: _now),
          ..._eps('A3-01', 6, end: _now),
        ],
      );
      expect(deepGapBranch(f), DeepGapBranch.even);
      expect(deepGapText(f), isNot(contains('nhiều nhất')));
    });

    // D nằm TRỌN trong điều kiện của B, nên nếu xét B trước thì D không bao giờ
    // chạy tới — mà §3.4 lại viết hẳn ba biến thể câu cho nó.
    test('D · trụ nổi trội không trùng trụ tự đánh giá thấp nhất', () {
      // C nổi trội ở mức giữa ("Ổn, còn dư địa"), còn A mới là chỗ người dùng thấy
      // khó nhất. 21 lượt → biến thể 0, biến thể gọi tên cả hai trụ.
      final f = withPillars(s: 4.2, c: 3.0, a: 1.8, count: 21);
      expect(deepGapBranch(f), DeepGapBranch.mismatch);
      final text = deepGapText(f);
      expect(text, contains('cách làm việc')); // trụ tự đánh giá thấp nhất
      expect(text, contains('mối quan hệ')); //  trụ quay lại nhiều nhất
    });

    test('ba biến thể xoay vòng, không lặp lại một câu', () {
      final texts = <String>{};
      for (final n in [15, 16, 17]) {
        texts.add(deepGapText(_facts(
          history: [_check(at: _now, c: 4.2)],
          episodes: _eps('C2-01', n, end: _now),
        )));
      }
      expect(texts.length, 3, reason: 'ba lần liên tiếp phải ra ba câu khác nhau');
    });

    test('mọi câu tầng 1 đều dựng từ đúng hai con số đang hiện', () {
      final f = withPillars(s: 3.0, c: 4.2, a: 3.0, count: 23);
      final text = deepGapText(f);
      expect(text, contains('23'));
    });
  });

  group('Tầng 2 · xu hướng Reflection', () {
    test('chưa đủ hai cửa sổ thì không có câu xu hướng', () {
      expect(
        deepReflectionTrendText(_facts(episodes: _eps('C2-01', 20, end: _now))),
        isNull,
      );
    });

    test('một nhóm dày lên thì nói ra', () {
      final f = _facts(episodes: [
        ..._eps('C2-01', 18, end: _now),
        ..._eps('S1-01', 2, end: _now),
        ..._eps('S1-01', 18, end: _now.subtract(const Duration(days: 30))),
        ..._eps('C2-01', 2, end: _now.subtract(const Duration(days: 30))),
      ]);
      final text = deepReflectionTrendText(f);
      expect(text, isNotNull);
      expect(text, contains('mối quan hệ'));
    });

    test('không nhóm nào đổi rõ thì nói là ổn định, không im lặng', () {
      final f = _facts(episodes: [
        ..._eps('C2-01', 12, end: _now),
        ..._eps('C2-01', 12, end: _now.subtract(const Duration(days: 30))),
      ]);
      expect(deepReflectionTrendText(f), contains('ổn định'));
    });
  });

  group('Tầng 3 · xu hướng Self-Check', () {
    test('chưa đủ 6 tuần thì im lặng', () {
      final f = _facts(history: [
        _check(at: _now),
        _check(at: _now.subtract(const Duration(days: 10))),
      ]);
      expect(deepSelfCheckTrendText(f), isNull);
    });

    test('đủ 6 tuần và một trụ đổi điểm thì nói ra kèm ngày lần trước', () {
      final f = _facts(
        history: [
          _check(at: _now, s: 4.5),
          _check(at: _now.subtract(const Duration(days: 60)), s: 2.0),
        ],
        episodes: _eps('C2-01', 20, end: _now),
      );
      final text = deepSelfCheckTrendText(f);
      expect(text, isNotNull);
      expect(text, contains('12/07/2026'));
    });

    // Ca khách báo 11/09/2026: hai lần Self-Check (05/09 và 14/08) cách nhau 22
    // ngày. Bản trước rơi về `kDeepOneSelfCheckOnly` — câu đó bảo "sau lần cập
    // nhật tiếp theo", nên người đã làm hai lần hiểu là làm thêm lần nữa sẽ mở
    // ra, làm ngay hôm sau và vẫn gặp đúng câu ấy. Thứ còn thiếu là KHOẢNG CÁCH.
    test('hai lần Self-Check quá sát nhau thì nói về khoảng cách, không mời '
        'làm thêm một lần', () {
      final content = buildDeepInterpretation(
        history: [
          _check(at: DateTime(2026, 9, 5)),
          _check(at: DateTime(2026, 8, 14)),
        ],
        episodes: _eps('C2-01', 29, end: _now),
        situations: _situations,
        now: _now,
      );
      expect(content.selfCheckTrendText, kDeepSelfChecksTooClose);
      expect(content.selfCheckTrendText, isNot(kDeepOneSelfCheckOnly));
    });

    test('mới đúng MỘT lần Self-Check thì vẫn là câu mời làm lần tiếp theo', () {
      final content = buildDeepInterpretation(
        history: [_check(at: DateTime(2026, 9, 5))],
        episodes: _eps('C2-01', 29, end: _now),
        situations: _situations,
        now: _now,
      );
      expect(content.selfCheckTrendText, kDeepOneSelfCheckOnly);
    });
  });

  group('Mục 6 · chưa đủ dữ liệu thì MỜI GỌI, không báo lỗi', () {
    // §6: "Tuyệt đối không dùng các câu kiểu 'Chưa đủ dữ liệu', 'Không thể tính
    // toán', 'Cần thêm X lần nữa mới hiển thị được'." Đây là phần dễ làm hỏng
    // trải nghiệm nhất vì người dùng đã trả tiền.
    const banned = [
      'Chưa đủ dữ liệu',
      'Không thể',
      'mới hiển thị được',
      'Lỗi',
      'không hợp lệ',
    ];

    test('mọi câu thay thế đều sạch từ cấm', () {
      final texts = [
        kDeepNoTrendYet,
        kDeepOneSelfCheckOnly,
        kDeepSelfChecksTooClose,
        kDeepNotEnoughReflection,
        deepStaleSelfCheckText(DateTime(2026, 5, 20)),
      ];
      for (final t in texts) {
        for (final b in banned) {
          expect(t, isNot(contains(b)), reason: '"$t" còn chứa "$b"');
        }
      }
    });

    test('câu mời cập nhật nói đúng ngày lần gần nhất', () {
      expect(
        deepStaleSelfCheckText(DateTime(2026, 5, 20)),
        contains('20/05/2026'),
      );
    });
  });

  group('Ghép cả màn', () {
    test('chưa đủ ngưỡng thì đoạn dẫn dắt là lời mời, không phải kết luận', () {
      final c = buildDeepInterpretation(
        history: [_check(at: _now)],
        episodes: _eps('C2-01', 3, end: _now),
        situations: _situations,
        now: _now,
      );
      expect(c.branch, isNull);
      expect(c.leadText, kDeepNotEnoughReflection);
      // Tầng 2 cũng chưa mở, nhưng vẫn phải có chữ — không để trống.
      expect(c.trendText, kDeepNoTrendYet);
    });

    test('chưa từng Self-Check thì không dựng câu tầng 3', () {
      final c = buildDeepInterpretation(
        history: const [],
        episodes: _eps('C2-01', 20, end: _now),
        situations: _situations,
        now: _now,
      );
      expect(c.selfCheckTrendText, isNull);
    });

    test('Self-Check quá 3 tháng thì kèm câu mời cập nhật', () {
      final c = buildDeepInterpretation(
        history: [_check(at: _now.subtract(const Duration(days: 200)))],
        episodes: _eps('C2-01', 20, end: _now),
        situations: _situations,
        now: _now,
      );
      expect(c.staleSelfCheckText, isNotNull);
      expect(c.staleSelfCheckText, contains('cập nhật lại'));
    });

    test('vừa làm Self-Check thì không mời cập nhật', () {
      final c = buildDeepInterpretation(
        history: [_check(at: _now.subtract(const Duration(days: 5)))],
        episodes: _eps('C2-01', 20, end: _now),
        situations: _situations,
        now: _now,
      );
      expect(c.staleSelfCheckText, isNull);
    });
  });
}

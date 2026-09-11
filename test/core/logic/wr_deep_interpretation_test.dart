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
  // §2.1 gán trụ cho cả tình huống tích cực, qua cột `pillar` chứ không qua
  // `sca_dimension` — nên bộ giả cũng phải có `pillarCode`, y như DB thật sau
  // migration `20260911100000_situation_pillar.sql`.
  WrSituation(
    code: 'P-WIN',
    text: 'Vừa làm được điều hay',
    scaDimension: ScaDimension.pAchieve,
    pillarCode: 'A',
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

/// Thư viện giả rộng, đủ chỗ để dựng những hình dạng phân bố của §9.
///
/// Mã theo quy ước `<TRỤ>-<gì cũng được>`: `S-a`, `C-03`, `A-11`, `P-09`. Mã
/// bắt đầu bằng P là tình huống TÍCH CỰC và trụ của nó xoay vòng S · C · A —
/// đúng như bảng §2.1 vốn cắt ngang hai nhóm P, nên bộ giả cũng không được để
/// trụ suy ra từ tiền tố.
///
/// Cần thư viện riêng thay vì dùng `_situations`: thang ưu tiên đọc ở LỚP TÌNH
/// HUỐNG, nên một bộ chỉ có bốn mã sẽ không dựng nổi cảnh "16 lượt rải đều trên
/// 16 tình huống khác nhau" mà §9 việc 4 yêu cầu.
List<WrSituation> _wideLibrary() {
  final out = <WrSituation>[];
  ScaDimension dimOf(String prefix) => switch (prefix) {
        'S' => ScaDimension.s1,
        'C' => ScaDimension.c2,
        _ => ScaDimension.a3,
      };

  for (final prefix in ['S', 'C', 'A']) {
    for (final suffix in [
      'a', 'b', 'c', 'd', 'e', 'f',
      for (var i = 0; i <= 40; i++) i.toString().padLeft(2, '0'),
      for (var i = 0; i <= 40; i++) i.toString(),
    ]) {
      out.add(WrSituation(
        code: '$prefix-$suffix',
        text: '$prefix-$suffix',
        scaDimension: dimOf(prefix),
        pillarCode: prefix,
        wave: 1,
      ));
    }
  }

  const rotate = ['S', 'C', 'A'];
  for (var i = 0; i <= 40; i++) {
    for (final suffix in [i.toString().padLeft(2, '0'), i.toString()]) {
      out.add(WrSituation(
        code: 'P-$suffix',
        text: 'P-$suffix',
        scaDimension:
            i.isEven ? ScaDimension.pAchieve : ScaDimension.pSteady,
        pillarCode: rotate[i % 3],
        wave: 1,
      ));
    }
  }
  return out;
}

final _wide = _wideLibrary();

DeepFacts _lib({
  List<ScaSelfCheckResponse> history = const [],
  List<ReflectionEpisode> episodes = const [],
}) =>
    buildDeepFacts(
      history: history,
      episodes: episodes,
      situations: _wide,
      now: _now,
    );

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
    test('ba mẫu số là ba con số khác nhau, và mỗi cái trả lời một câu', () {
      // 10 lượt trụ C thách thức, 6 lượt tích cực, 3 lượt tự viết không có mã.
      final f = _facts(episodes: [
        ..._eps('C2-01', 10, end: _now),
        ..._eps('P-WIN', 6, end: _now),
        ..._eps('khong-co-trong-thu-vien', 3, end: _now),
      ]);
      expect(f.pillarCount[SelfCheckPillar.c], 10);

      // Công sức người dùng bỏ ra — nuôi ngưỡng mở tầng.
      expect(f.totalReflection, 19);
      // Mẫu số hiển thị của mọi câu "{count} trong {total} lần" (§2.3).
      expect(f.classifiedTotal, 16);
      // Mẫu số của trụ nổi trội và khoảng lệch (§2.2).
      expect(f.challengeTotal, 10);
      expect(f.positiveTotal, 6);
    });

    test('tình huống tích cực có trụ riêng, không dồn vào bảng thách thức', () {
      // P-WIN nay có `pillarCode` là A (§2.1), nhưng nó là valence tích cực nên
      // KHÔNG được cộng vào bảng dùng để tìm trụ nổi trội — trộn vào là tuyên bố
      // "Cách làm việc đang là chỗ vướng" từ 20 lần người dùng ghi điều hay.
      final f = _facts(episodes: _eps('P-WIN', 20, end: _now));
      expect(f.pillarCount[SelfCheckPillar.a], 0);
      expect(f.positiveTotal, 20);
      expect(f.dominant, isNull);
    });

    test('trụ nổi trội chia cho số lượt THÁCH THỨC, không chia cho tổng', () {
      // ĐÂY LÀ LỖI KHÁCH BÁO 11/09/2026, thu nhỏ lại.
      //
      // 15 lượt C thách thức, 85 lượt tích cực. Luật cũ chia 15/100 = 15%,
      // không chạm ngưỡng 40%, nên màn hình kết luận "chưa nhóm nào nổi trội" —
      // trong khi C là trụ thách thức DUY NHẤT người này có.
      //
      // `DienGiaiSau v2` §2.2: "Mọi phép đếm để tìm trụ nổi trội và khoảng lệch
      // chỉ tính trên valence = thach-thuc. Nếu trộn chung, kết luận sẽ ngược
      // hoàn toàn."
      final f = _facts(episodes: [
        ..._eps('C2-01', 15, end: _now),
        ..._eps('P-WIN', 85, end: _now),
      ]);
      expect(f.challengeTotal, 15);
      expect(f.dominant, SelfCheckPillar.c);
    });

    test('phân bố đều giữa các trụ thách thức thì vẫn không có trụ nổi trội',
        () {
      // Ngưỡng 40% vẫn nguyên, chỉ mẫu số đổi. 10/10/10 thì mỗi trụ 33%.
      final f = _facts(episodes: [
        ..._eps('S1-01', 10, end: _now),
        ..._eps('C2-01', 10, end: _now),
        ..._eps('A3-01', 10, end: _now),
      ]);
      expect(f.challengeTotal, 30);
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

    test('gọi tên TÌNH HUỐNG dày lên, không gọi tên nhóm', () {
      // §6 điều chỉnh 1: "Thay vì 'nhóm Mối quan hệ đang tăng', nói 'tình huống
      // X đang xuất hiện dày hơn giai đoạn trước'."
      final f = _facts(episodes: [
        ..._eps('C2-01', 18, end: _now),
        ..._eps('S1-01', 2, end: _now),
        ..._eps('S1-01', 18, end: _now.subtract(const Duration(days: 30))),
        ..._eps('C2-01', 2, end: _now.subtract(const Duration(days: 30))),
      ]);
      final text = deepReflectionTrendText(f);
      expect(text, isNotNull);
      // Nhãn của C2-01 trong bộ giả là chữ "C".
      expect(text, contains('"C"'));
      expect(text, contains('18'));
      expect(text, contains('2'));
      // Và KHÔNG rơi về câu nói tên nhóm của bản cũ.
      expect(text, isNot(contains('mối quan hệ')));
    });

    test('không tình huống nào đổi đủ nhiều thì lùi về lớp trụ', () {
      // Mỗi tình huống chỉ lệch ĐÚNG MỘT lần, dưới `kDeepSituationShiftMin`,
      // nên lớp tình huống im. Tỉ trọng trụ thì đi từ 45% lên 55%, vượt
      // `kDeepTrendEpsilon`, nên lớp trụ lên tiếng thay. §8 nguyên tắc 1: không
      // tầng nào được kết thúc bằng sự im lặng.
      final f = _facts(episodes: [
        ..._eps('C2-01', 6, end: _now),
        ..._eps('A3-01', 5, end: _now),
        ..._eps('C2-01', 5, end: _now.subtract(const Duration(days: 30))),
        ..._eps('A3-01', 6, end: _now.subtract(const Duration(days: 30))),
      ]);
      expect(f.situationTrend, isEmpty);
      expect(deepReflectionTrendText(f), contains('ối quan hệ'));
    });

    test('không gì đổi rõ thì nói là ổn định, không im lặng', () {
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
        kDeepAllFreeform,
        deepStaleSelfCheckText(DateTime(2026, 5, 20)),
        // Dòng chờ gộp của §6 điều chỉnh 2 — ba dạng của nó.
        for (final c in [
          buildDeepInterpretation(
            history: [_check(at: _now)],
            episodes: _eps('C2-01', 16, end: _now),
            situations: _situations,
            now: _now,
          ),
          buildDeepInterpretation(
            history: [
              _check(at: _now),
              _check(at: _now.subtract(const Duration(days: 5))),
            ],
            episodes: [
              ..._eps('C2-01', 12, end: _now),
              ..._eps('C2-01', 12, end: _now.subtract(const Duration(days: 30))),
            ],
            situations: _situations,
            now: _now,
          ),
        ])
          if (c.waitingLine case final String line) line,
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

  // -------------------------------------------------------------------------
  // Thang ưu tiên năm bậc — nghiệm thu §9 việc 4
  // -------------------------------------------------------------------------
  //
  // "Kiểm tra bằng bốn bộ dữ liệu giả: một bộ có tình huống lặp 5 lần (phải ra
  // R1), một bộ phân bố đều 6/5/5 (phải ra R5), một bộ có trên 60 phần trăm
  // tích cực (phải ra R4), một bộ chỉ đúng 15 lần Reflection rải đều mỗi tình
  // huống 1 lần (vẫn phải ra R5 với nội dung hợp lệ, không được trả về rỗng)."

  group('Thang ưu tiên · §9 việc 4', () {
    test('R1 — một tình huống lặp 5 lần, bỏ xa phần còn lại', () {
      final f = _lib(episodes: [
        ..._eps('S-a', 5, end: _now),
        ..._eps('C-a', 2, end: _now),
        ..._eps('A-a', 2, end: _now),
        ..._eps('S-b', 2, end: _now),
        ..._eps('C-b', 2, end: _now),
        ..._eps('A-b', 2, end: _now),
      ]);
      expect(deepRung(f), DeepRung.standoutSituation);
      final text = deepLeadText(f);
      expect(text, contains('S-a'));
      expect(text, contains('5'));
    });

    test('R5 — phân bố 6/5/5 trên tình huống khác nhau', () {
      // Chính hình dạng khách báo lỗi ở §1.1. Sáu tình huống S khác nhau, năm
      // C, năm A, mỗi cái một lần: không tình huống nào nổi bật, không cụm nào
      // đạt 5, không trụ nào vượt 40%.
      final f = _lib(episodes: [
        for (var i = 0; i < 6; i++) ..._eps('S-$i', 1, end: _now),
        for (var i = 0; i < 5; i++) ..._eps('C-$i', 1, end: _now),
        for (var i = 0; i < 5; i++) ..._eps('A-$i', 1, end: _now),
      ], history: [
        _check(at: _now, s: 4.5),
      ]);
      expect(f.challengeTotal, 16);
      expect(deepRung(f), DeepRung.evenSpread);
      // §5.5 điều then chốt: vẫn gọi tên một tình huống kèm số lần, không dừng
      // ở câu "không có gì nổi bật". Hoà tuyệt đối 1-1-1 thì phá hoà theo mã,
      // nên tên được gọi là mã đứng đầu bảng chữ cái — cố định giữa hai lần mở
      // app, đó mới là điều cần khoá.
      expect(f.topSituation!.code, 'A-0');
      expect(deepLeadText(f), contains('"A-0"'));
      expect(deepLeadText(f), contains('1 lần'));
    });

    // Vế `positiveTotal > 0` của R4 — xem chú thích dài trong `deepRung`. Bảng
    // §4 và nghiệm thu §9 việc 4 mâu thuẫn nhau ở đúng chỗ này; test này khoá
    // lựa chọn đã chốt để nếu ai đảo lại thì thấy ngay.
    test('R4 KHÔNG chạy khi chưa từng ghi điều gì đang tốt', () {
      final f = _lib(episodes: [
        for (var i = 0; i < 16; i++) ..._eps('S-$i', 1, end: _now),
      ]);
      expect(f.positiveTotal, 0);
      expect(f.positiveShare, 0);
      expect(deepRung(f), DeepRung.evenSpread);
    });

    test('R4 chạy khi có tích cực nhưng rất ít', () {
      final f = _lib(episodes: [
        ..._eps('P-01', 1, end: _now),
        for (var i = 0; i < 15; i++) ..._eps('S-$i', 1, end: _now),
      ]);
      expect(f.positiveShare, closeTo(1 / 16, 1e-9));
      expect(deepRung(f), DeepRung.positiveBalance);
      expect(deepLeadText(f), contains('1 trong 16'));
    });

    test('R4 — trên 60 phần trăm là tình huống tích cực', () {
      final f = _lib(episodes: [
        for (var i = 0; i < 12; i++) ..._eps('P-$i', 1, end: _now),
        for (var i = 0; i < 3; i++) ..._eps('S-$i', 1, end: _now),
        for (var i = 0; i < 3; i++) ..._eps('C-$i', 1, end: _now),
      ]);
      expect(f.positiveShare, closeTo(12 / 18, 1e-9));
      expect(deepRung(f), DeepRung.positiveBalance);
      expect(deepLeadText(f), contains('12'));
    });

    test('R5 — đúng 15 lần, mỗi tình huống một lần, vẫn có chữ', () {
      final f = _lib(episodes: [
        for (var i = 0; i < 15; i++) ..._eps('S-$i', 1, end: _now),
      ]);
      expect(f.totalReflection, 15);
      expect(f.leadUnlocked, isTrue);
      expect(deepRung(f), DeepRung.evenSpread);

      final text = deepLeadText(f);
      expect(text, isNotEmpty);
      expect(text, contains('S-0'));
      expect(text, contains('1'));
    });

    test('R2 — một cụm cùng trụ, cùng valence, tổng đủ 5', () {
      final f = _lib(episodes: [
        ..._eps('S-a', 2, end: _now),
        ..._eps('S-b', 2, end: _now),
        ..._eps('S-c', 1, end: _now),
        for (var i = 0; i < 5; i++) ..._eps('C-$i', 1, end: _now),
        for (var i = 0; i < 5; i++) ..._eps('A-$i', 1, end: _now),
      ]);
      expect(deepRung(f), DeepRung.situationCluster);
      final c = deepCluster(f)!;
      expect(c.pillar, SelfCheckPillar.s);
      expect(c.total, 5);
      expect(deepLeadText(f), contains('S-a'));
    });

    test('R3 — có trụ nổi trội và có Self-Check, gọi kèm tên tình huống', () {
      final f = _lib(
        history: [_check(at: _now, c: 4.5)],
        episodes: [
          // Trụ C áp đảo nhưng rải đủ mỏng để R1 và R2 không chạm.
          for (var i = 0; i < 12; i++) ..._eps('C-$i', 1, end: _now),
          for (var i = 0; i < 3; i++) ..._eps('S-$i', 1, end: _now),
        ],
      );
      expect(f.dominant, SelfCheckPillar.c);
      expect(deepRung(f), DeepRung.awarenessGap);
      // §5.3: "nên gọi kèm tên tình huống cụ thể thay vì chỉ nói tên trụ".
      expect(deepLeadText(f), contains('C-0'));
    });

    test('KHÔNG BAO GIỜ RỖNG — §8 nguyên tắc bất biến thứ nhất', () {
      // Quét mọi số lần từ ngưỡng mở tới 40, với ba hình dạng dữ liệu khác
      // nhau. Không lần nào được trả về chuỗi rỗng.
      for (var n = kDeepTier1MinReflections; n <= 40; n++) {
        for (final shape in ['deu', 'dai', 'tron']) {
          final eps = switch (shape) {
            'deu' => [
                for (var i = 0; i < n; i++) ..._eps('S-$i', 1, end: _now),
              ],
            'dai' => _eps('S-a', n, end: _now),
            _ => [
                for (var i = 0; i < n; i++)
                  ..._eps(i.isEven ? 'P-${i ~/ 2}' : 'C-${i ~/ 2}', 1,
                      end: _now),
              ],
          };
          final f = _lib(episodes: eps);
          expect(
            deepLeadText(f).trim(),
            isNotEmpty,
            reason: 'n=$n shape=$shape trả về chuỗi rỗng',
          );
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  // Phép thử cuối trước khi bàn giao — §9.1
  // -------------------------------------------------------------------------

  group('Phép thử §9.1 · đúng tài khoản khách báo lỗi', () {
    // Chép nguyên phân bố 30 ngày của tài khoản
    // 3229092a-aeff-42ad-a513-b6bf80ca0b8f, đọc thẳng từ DB ngày 11/09/2026.
    //
    // 31 lượt: 17 thách thức (S 7 · C 5 · A 5), 10 tích cực, 4 lượt tự viết
    // không có mã. Đây là bộ dữ liệu đã làm màn hình kết luận "chưa có nhóm nào
    // nổi trội" và không gọi tên được điều gì.
    DeepFacts real() => _lib(
          history: [_check(at: _now, s: 4.2)],
          episodes: [
            ..._eps('C-03', 3, end: _now),
            ..._eps('S-06', 2, end: _now),
            ..._eps('S-09', 2, end: _now),
            ..._eps('S-02', 1, end: _now),
            ..._eps('S-04', 1, end: _now),
            ..._eps('S-10', 1, end: _now),
            ..._eps('C-04', 1, end: _now),
            ..._eps('C-09', 1, end: _now),
            ..._eps('A-08', 1, end: _now),
            ..._eps('A-03', 1, end: _now),
            ..._eps('A-04', 1, end: _now),
            ..._eps('A-07', 1, end: _now),
            ..._eps('A-11', 1, end: _now),
            ..._eps('P-09', 3, end: _now),
            ..._eps('P-08', 2, end: _now),
            ..._eps('P-01', 1, end: _now),
            ..._eps('P-02', 1, end: _now),
            ..._eps('P-03', 1, end: _now),
            ..._eps('P-04', 1, end: _now),
            ..._eps('P-07', 1, end: _now),
            ..._eps('tu-viet', 4, end: _now),
          ],
        );

    test('ba mẫu số khớp đúng dữ liệu thật', () {
      final f = real();
      expect(f.totalReflection, 31);
      expect(f.classifiedTotal, 27);
      expect(f.challengeTotal, 17);
      expect(f.positiveTotal, 10);
      expect(f.pillarCount[SelfCheckPillar.s], 7);
      expect(f.pillarCount[SelfCheckPillar.c], 5);
      expect(f.pillarCount[SelfCheckPillar.a], 5);
    });

    test('trụ nổi trội hiện ra sau khi sửa mẫu số', () {
      // 7/31 = 22% không chạm ngưỡng 40%; 7/17 = 41% thì chạm. Đúng một dòng
      // đổi, và nó là dòng làm màn hình đi từ im lặng sang có chuyện để nói.
      expect(real().dominant, SelfCheckPillar.s);
    });

    test('§9.1 — màn hình gọi tên tình huống cụ thể kèm số lần', () {
      final f = real();
      final text = deepLeadText(f);

      // Tiêu chí 1: có ít nhất một câu nêu tên một tình huống cụ thể kèm số lần.
      expect(text, contains('S-06'));
      expect(text, contains('5 lần'));

      // Tiêu chí 2: không còn câu nào nói "không có gì nổi bật" rồi dừng.
      expect(deepRung(f), isNot(DeepRung.awarenessGap));
      expect(text, isNot(contains('chưa nhóm nào nổi lên')));
      expect(text, isNot(contains('Chưa có nhóm nào chiếm ưu thế')));
    });

    test('§9.1 — mọi con số trên màn cộng lại khớp', () {
      final f = real();
      final appearance = [
        for (final p in SelfCheckPillar.values)
          (f.pillarCount[p] ?? 0) +
              f.situationsOf(p)
                  .where((s) => s.valence.isPositive)
                  .fold<int>(0, (x, s) => x + s.count),
      ];
      expect(appearance.fold<int>(0, (x, v) => x + v), f.classifiedTotal);
    });
  });
}

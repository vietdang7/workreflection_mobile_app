// Tests for wr_self_check_questions.dart — self-check question list and scoring.
// Run: flutter test test/core/wr_self_check_questions_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';

void main() {
  group('kSelfCheckQuestions', () {
    test('has exactly 15 questions', () {
      expect(kSelfCheckQuestions.length, 15);
    });

    test('has 5 S-pillar, 5 C-pillar, 5 A-pillar questions', () {
      final sByPillar = <SelfCheckPillar, int>{};
      for (final q in kSelfCheckQuestions) {
        sByPillar[q.pillar] = (sByPillar[q.pillar] ?? 0) + 1;
      }
      expect(sByPillar[SelfCheckPillar.s], 5);
      expect(sByPillar[SelfCheckPillar.c], 5);
      expect(sByPillar[SelfCheckPillar.a], 5);
    });

    test('all ids are unique and follow scq-01..scq-15 pattern', () {
      final ids = kSelfCheckQuestions.map((q) => q.id).toList();
      expect(ids.toSet().length, 15, reason: 'All IDs must be unique');
      for (var i = 0; i < 15; i++) {
        expect(ids[i], 'scq-${(i + 1).toString().padLeft(2, '0')}');
      }
    });

    test('no question text contains S1/S2/S3/Structure/Culture/Activity codes', () {
      for (final q in kSelfCheckQuestions) {
        expect(q.text, isNot(contains('Structure')),
            reason: 'id=${q.id} must not contain "Structure"');
        expect(q.text, isNot(contains('Culture')),
            reason: 'id=${q.id} must not contain "Culture"');
        expect(q.text, isNot(contains('Activity')),
            reason: 'id=${q.id} must not contain "Activity"');
      }
    });

    test('pillar displayNames are user-friendly Vietnamese (no S/C/A)', () {
      expect(SelfCheckPillar.s.displayName, 'Sự rõ ràng');
      expect(SelfCheckPillar.c.displayName, 'Mối quan hệ');
      expect(SelfCheckPillar.a.displayName, 'Cách làm việc');
    });
  });

  // Khoá nội dung theo tài liệu khách: SCA_QUESTIONS trong
  // FileTam/workreflection/WorkReflection_Sprint2_Mockup (2).html.
  // Test này đỏ nghĩa là có người sửa chữ lệch khỏi bản gốc của khách.
  group('nội dung khớp nguyên văn mockup của khách', () {
    const goldenFromMockup = <String, String>{
      'scq-01':
          'Trước khi bắt đầu một công việc mới, bạn thường được làm rõ về trách nhiệm của mình và người phối hợp cùng.',
      'scq-02':
          'Với các công việc quan trọng, bạn có quy trình và hướng dẫn cụ thể trước khi bắt đầu triển khai.',
      'scq-03':
          'Các nguyên tắc phối hợp trong đội ngũ của bạn được thống nhất rõ ràng và cập nhật đầy đủ đến mọi người liên quan.',
      'scq-04':
          'Bạn biết rõ thông tin nào cần chia sẻ qua kênh nào, không bị lạc trong quá nhiều nhóm chat hay email chồng chéo.',
      'scq-05':
          'Khi có thay đổi trong công việc, nhìn chung bạn không bị bất ngờ hay phải tự tìm hiểu thêm.',
      'scq-06':
          'Bạn nhận thấy cấp quản lý của mình nhất quán giữa những gì nói và những gì làm trong thực tế công việc.',
      'scq-07':
          'Những người bạn làm việc cùng thể hiện sự nhất quán giữa lời nói và hành động, bạn có thể tin vào cam kết của họ.',
      'scq-08':
          'Bạn cảm thấy thoải mái khi nêu ý kiến khác biệt với số đông, kể cả khi điều đó tạo ra tranh luận.',
      'scq-09':
          'Khi bạn nhận thấy rủi ro hoặc vấn đề tiềm ẩn, bạn sẵn sàng lên tiếng, kể cả khi chưa có giải pháp.',
      'scq-10':
          'Khi có bất đồng quan điểm, cuộc trao đổi của bạn tập trung vào tìm giải pháp thay vì tranh luận về ai đúng.',
      'scq-11':
          'Trong công việc hàng ngày, bạn hiểu rõ công việc của mình kết nối với mục tiêu chung của đội nhóm như thế nào.',
      'scq-12':
          'Khi mục tiêu thay đổi, bạn được thông báo kịp thời và rõ lý do, không phải tự đoán hay phát hiện muộn.',
      'scq-13':
          'Nhịp phối hợp của đội nhóm bạn rõ ràng và ổn định, có check-in đều đặn, không bị lạc nhịp.',
      'scq-14':
          'Sau mỗi giai đoạn hoặc dự án, nhóm của bạn có thời gian chính thức để nhìn lại và đánh giá những gì đã làm.',
      'scq-15':
          'Những điểm cần điều chỉnh sau khi nhìn lại được chuyển thành hành động cụ thể, có người theo dõi.',
    };

    test('cả 15 câu đúng từng ký tự so với SCA_QUESTIONS', () {
      for (final q in kSelfCheckQuestions) {
        expect(q.text, goldenFromMockup[q.id],
            reason: '${q.id} lệch khỏi bản gốc trong mockup của khách');
      }
    });

    test('không câu nào chứa dấu gạch ngang dài', () {
      for (final q in kSelfCheckQuestions) {
        expect(q.text, isNot(contains('\u2014')), reason: '${q.id} còn dấu —');
      }
    });
  });

  group('computePillarScore', () {
    test('returns average score for all answered S questions', () {
      // scq-01..05 are S pillar
      final answers = {
        'scq-01': 4,
        'scq-02': 3,
        'scq-03': 5,
        'scq-04': 2,
        'scq-05': 1,
      };
      final score = computePillarScore(SelfCheckPillar.s, answers);
      // average = (4+3+5+2+1)/5 = 3.0
      expect(score, closeTo(3.0, 0.001));
    });

    test('returns average for C pillar (scq-06..10)', () {
      final answers = {
        'scq-06': 5,
        'scq-07': 5,
        'scq-08': 5,
        'scq-09': 5,
        'scq-10': 5,
      };
      final score = computePillarScore(SelfCheckPillar.c, answers);
      expect(score, closeTo(5.0, 0.001));
    });

    test('returns average for A pillar (scq-11..15)', () {
      final answers = {
        'scq-11': 1,
        'scq-12': 1,
        'scq-13': 1,
        'scq-14': 1,
        'scq-15': 1,
      };
      final score = computePillarScore(SelfCheckPillar.a, answers);
      expect(score, closeTo(1.0, 0.001));
    });

    test('ignores answers for other pillars', () {
      final answers = {
        // S answers only
        'scq-01': 4,
        'scq-02': 4,
        'scq-03': 4,
        'scq-04': 4,
        'scq-05': 4,
        // C answers should not affect S score
        'scq-06': 1,
        'scq-07': 1,
      };
      final sScore = computePillarScore(SelfCheckPillar.s, answers);
      expect(sScore, closeTo(4.0, 0.001));
    });

    test('returns 0 when no answers provided for pillar', () {
      final score = computePillarScore(SelfCheckPillar.s, {});
      expect(score, 0.0);
    });

    test('handles partial answers — only uses answered questions', () {
      // Only 3 of 5 S questions answered
      final answers = {
        'scq-01': 2,
        'scq-02': 4,
        'scq-03': 3,
      };
      final score = computePillarScore(SelfCheckPillar.s, answers);
      // average of 2,4,3 = 3.0
      expect(score, closeTo(3.0, 0.001));
    });

    test('all 15 answered correctly computes all 3 pillar scores', () {
      final answers = <String, int>{};
      for (var i = 1; i <= 5; i++) {
        answers['scq-${i.toString().padLeft(2, '0')}'] = 3; // S → 3.0
      }
      for (var i = 6; i <= 10; i++) {
        answers['scq-${i.toString().padLeft(2, '0')}'] = 4; // C → 4.0
      }
      for (var i = 11; i <= 15; i++) {
        answers['scq-${i.toString().padLeft(2, '0')}'] = 5; // A → 5.0
      }

      expect(computePillarScore(SelfCheckPillar.s, answers), closeTo(3.0, 0.001));
      expect(computePillarScore(SelfCheckPillar.c, answers), closeTo(4.0, 0.001));
      expect(computePillarScore(SelfCheckPillar.a, answers), closeTo(5.0, 0.001));
    });
  });

  // ── Ràng buộc câu chữ ────────────────────────────────────────────────────
  //
  // Khách 2026-08-03: bỏ hẳn gạch ngang dài khỏi câu hỏi, thay bằng phẩy hoặc
  // hai chấm, vì gạch ngang làm câu đọc lên có cảm giác máy móc.
  //
  // Khoá bằng test chứ không chỉ sửa một lượt: câu hỏi là thứ được viết lại
  // nhiều lần, và một dấu gạch lọt vào lần biên tập sau sẽ không ai để ý cho
  // tới khi nó nằm trên màn hình người dùng.
  group('câu chữ của 15 câu hỏi', () {
    test('không câu nào còn gạch ngang dài', () {
      for (final q in kSelfCheckQuestions) {
        expect(
          q.text.contains('—'),
          isFalse,
          reason: '${q.id} còn gạch ngang dài: "${q.text}"',
        );
      }
    });

    test('không lọt cả gạch ngang trung bình (–) lẫn gạch nối dùng thay', () {
      // Sửa bằng tay dễ đổi một loại gạch này lấy một loại gạch khác. Chặn luôn
      // cả hai biến thể, và chặn cả " - " kiểu " chữ - chữ " vốn cũng là gạch
      // ngang chỉ khác ký tự.
      for (final q in kSelfCheckQuestions) {
        expect(q.text.contains('–'), isFalse, reason: '${q.id} có gạch (–)');
        expect(
          RegExp(r'\s-\s').hasMatch(q.text),
          isFalse,
          reason: '${q.id} có gạch nối đứng thay gạch ngang',
        );
      }
    });

    test('đủ 15 câu và câu nào cũng kết bằng dấu chấm', () {
      expect(kSelfCheckQuestions.length, 15);
      for (final q in kSelfCheckQuestions) {
        expect(q.text.trim().endsWith('.'), isTrue, reason: q.id);
      }
    });
  });

  group('scoreToPercent', () {
    test('score=1 → 0%', () => expect(scoreToPercent(1), closeTo(0, 0.001)));
    test('score=3 → 50%', () => expect(scoreToPercent(3), closeTo(50, 0.001)));
    test('score=5 → 100%', () => expect(scoreToPercent(5), closeTo(100, 0.001)));
  });
}

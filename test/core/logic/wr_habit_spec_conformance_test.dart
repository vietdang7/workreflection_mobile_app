// SINH TỰ ĐỘNG từ WorkReflection-Thoi-quen-va-Ma-tran-Cap-bac-v1.0.docx
// (script: tool/gen_habit_spec_conformance.py). ĐỪNG sửa tay — sửa tài
// liệu rồi chạy lại script.
//
// Mục đích: chứng minh mã nguồn khớp NGUYÊN VĂN hai bảng của tài liệu,
// chứ không chỉ khớp với những gì người viết mã nhớ về tài liệu.
//
// Run: flutter test test/core/logic/wr_habit_spec_conformance_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_seniority.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

void main() {
  group('B.2 — 30 ô của bảng mức độ liên quan', () {
    test('S1 × individual = Cần', () {
      expect(relevanceOf(ScaDimension.s1, SeniorityTier.individual),
          SkillRelevance.needed);
    });
    test('S1 × leadTeam = Cần', () {
      expect(relevanceOf(ScaDimension.s1, SeniorityTier.leadTeam),
          SkillRelevance.needed);
    });
    test('S1 × leadOrg = Cần', () {
      expect(relevanceOf(ScaDimension.s1, SeniorityTier.leadOrg),
          SkillRelevance.needed);
    });
    test('S2 × individual = Cần', () {
      expect(relevanceOf(ScaDimension.s2, SeniorityTier.individual),
          SkillRelevance.needed);
    });
    test('S2 × leadTeam = Cần', () {
      expect(relevanceOf(ScaDimension.s2, SeniorityTier.leadTeam),
          SkillRelevance.needed);
    });
    test('S2 × leadOrg = Cần', () {
      expect(relevanceOf(ScaDimension.s2, SeniorityTier.leadOrg),
          SkillRelevance.needed);
    });
    test('S3 × individual = Nên có', () {
      expect(relevanceOf(ScaDimension.s3, SeniorityTier.individual),
          SkillRelevance.nice);
    });
    test('S3 × leadTeam = Cần', () {
      expect(relevanceOf(ScaDimension.s3, SeniorityTier.leadTeam),
          SkillRelevance.needed);
    });
    test('S3 × leadOrg = Cần, ưu tiên cao', () {
      expect(relevanceOf(ScaDimension.s3, SeniorityTier.leadOrg),
          SkillRelevance.critical);
    });
    test('C1 × individual = Nên có', () {
      expect(relevanceOf(ScaDimension.c1, SeniorityTier.individual),
          SkillRelevance.nice);
    });
    test('C1 × leadTeam = Cần, ưu tiên cao', () {
      expect(relevanceOf(ScaDimension.c1, SeniorityTier.leadTeam),
          SkillRelevance.critical);
    });
    test('C1 × leadOrg = Cần, ưu tiên cao', () {
      expect(relevanceOf(ScaDimension.c1, SeniorityTier.leadOrg),
          SkillRelevance.critical);
    });
    test('C2 × individual = Cần', () {
      expect(relevanceOf(ScaDimension.c2, SeniorityTier.individual),
          SkillRelevance.needed);
    });
    test('C2 × leadTeam = Cần, ưu tiên cao', () {
      expect(relevanceOf(ScaDimension.c2, SeniorityTier.leadTeam),
          SkillRelevance.critical);
    });
    test('C2 × leadOrg = Cần, ưu tiên cao', () {
      expect(relevanceOf(ScaDimension.c2, SeniorityTier.leadOrg),
          SkillRelevance.critical);
    });
    test('C3 × individual = Nên có', () {
      expect(relevanceOf(ScaDimension.c3, SeniorityTier.individual),
          SkillRelevance.nice);
    });
    test('C3 × leadTeam = Cần, ưu tiên cao', () {
      expect(relevanceOf(ScaDimension.c3, SeniorityTier.leadTeam),
          SkillRelevance.critical);
    });
    test('C3 × leadOrg = Cần, ưu tiên cao', () {
      expect(relevanceOf(ScaDimension.c3, SeniorityTier.leadOrg),
          SkillRelevance.critical);
    });
    test('A1 × individual = Cần', () {
      expect(relevanceOf(ScaDimension.a1, SeniorityTier.individual),
          SkillRelevance.needed);
    });
    test('A1 × leadTeam = Nên có', () {
      expect(relevanceOf(ScaDimension.a1, SeniorityTier.leadTeam),
          SkillRelevance.nice);
    });
    test('A1 × leadOrg = Cần', () {
      expect(relevanceOf(ScaDimension.a1, SeniorityTier.leadOrg),
          SkillRelevance.needed);
    });
    test('A2 × individual = Cần', () {
      expect(relevanceOf(ScaDimension.a2, SeniorityTier.individual),
          SkillRelevance.needed);
    });
    test('A2 × leadTeam = Cần', () {
      expect(relevanceOf(ScaDimension.a2, SeniorityTier.leadTeam),
          SkillRelevance.needed);
    });
    test('A2 × leadOrg = Cần', () {
      expect(relevanceOf(ScaDimension.a2, SeniorityTier.leadOrg),
          SkillRelevance.needed);
    });
    test('A3 × individual = Nên có', () {
      expect(relevanceOf(ScaDimension.a3, SeniorityTier.individual),
          SkillRelevance.nice);
    });
    test('A3 × leadTeam = Cần', () {
      expect(relevanceOf(ScaDimension.a3, SeniorityTier.leadTeam),
          SkillRelevance.needed);
    });
    test('A3 × leadOrg = Cần, ưu tiên cao', () {
      expect(relevanceOf(ScaDimension.a3, SeniorityTier.leadOrg),
          SkillRelevance.critical);
    });
    test('A4 × individual = Nên có', () {
      expect(relevanceOf(ScaDimension.a4, SeniorityTier.individual),
          SkillRelevance.nice);
    });
    test('A4 × leadTeam = Nên có', () {
      expect(relevanceOf(ScaDimension.a4, SeniorityTier.leadTeam),
          SkillRelevance.nice);
    });
    test('A4 × leadOrg = Cần', () {
      expect(relevanceOf(ScaDimension.a4, SeniorityTier.leadOrg),
          SkillRelevance.needed);
    });
  });

  group('B.3 — 30 ô nội dung bước Chuyển hoá', () {
    test('pt-s1 × individual', () {
      expect(transformContentFor('pt-s1', SeniorityTier.individual),
          'Với mọi việc mới, luôn làm rõ kết quả tốt trông như thế nào trước khi bắt đầu.');
    });
    test('pt-s1 × leadTeam', () {
      expect(transformContentFor('pt-s1', SeniorityTier.leadTeam),
          'Đặt rõ kỳ vọng cho từng người trong nhóm, không giả định họ tự hiểu như bạn.');
    });
    test('pt-s1 × leadOrg', () {
      expect(transformContentFor('pt-s1', SeniorityTier.leadOrg),
          'Giữ kỳ vọng nhất quán giữa các nhóm, để không ai nhận hai tiêu chuẩn khác nhau cho cùng một việc.');
    });
    test('pt-s2 × individual', () {
      expect(transformContentFor('pt-s2', SeniorityTier.individual),
          'Xây một cách phân loại việc theo mức độ bạn thực sự cần quyết định, dùng lại mỗi tuần.');
    });
    test('pt-s2 × leadTeam', () {
      expect(transformContentFor('pt-s2', SeniorityTier.leadTeam),
          'Giúp từng người trong nhóm tự phân biệt việc quan trọng và việc gấp, không quyết định thay họ mọi lúc.');
    });
    test('pt-s2 × leadOrg', () {
      expect(transformContentFor('pt-s2', SeniorityTier.leadOrg),
          'Phân bổ ưu tiên giữa nhiều nhóm dựa trên mục tiêu chung, không theo người nào lên tiếng to nhất.');
    });
    test('pt-s3 × individual', () {
      expect(transformContentFor('pt-s3', SeniorityTier.individual),
          'Xây thói quen xác nhận lại thông tin quan trọng trước khi hành động theo đó.');
    });
    test('pt-s3 × leadTeam', () {
      expect(transformContentFor('pt-s3', SeniorityTier.leadTeam),
          'Chủ động truyền đạt lý do đằng sau một thay đổi cho nhóm, trước khi họ phải tự đoán.');
    });
    test('pt-s3 × leadOrg', () {
      expect(transformContentFor('pt-s3', SeniorityTier.leadOrg),
          'Dẫn dắt nhiều nhóm qua một thay đổi lớn, giữ thông tin nhất quán ở mọi cấp truyền đạt.');
    });
    test('pt-c1 × individual', () {
      expect(transformContentFor('pt-c1', SeniorityTier.individual),
          'Giữ việc giao trọn vẹn, không kiểm soát chi tiết, như một thói quen chứ không phải ngoại lệ.');
    });
    test('pt-c1 × leadTeam', () {
      expect(transformContentFor('pt-c1', SeniorityTier.leadTeam),
          'Học cách giao việc và thật sự buông, thay vì giao rồi vẫn kiểm tra như chưa từng giao.');
    });
    test('pt-c1 × leadOrg', () {
      expect(transformContentFor('pt-c1', SeniorityTier.leadOrg),
          'Xây một văn hóa tin tưởng áp dụng nhất quán cho nhiều nhóm, không chỉ ở người bạn thân cận nhất.');
    });
    test('pt-c2 × individual', () {
      expect(transformContentFor('pt-c2', SeniorityTier.individual),
          'Chủ động chia sẻ một góc nhìn của riêng bạn, không chỉ trả lời khi được hỏi.');
    });
    test('pt-c2 × leadTeam', () {
      expect(transformContentFor('pt-c2', SeniorityTier.leadTeam),
          'Tạo một khoảng an toàn rõ ràng để từng người trong nhóm dám nói, không chỉ chờ họ tự dũng cảm.');
    });
    test('pt-c2 × leadOrg', () {
      expect(transformContentFor('pt-c2', SeniorityTier.leadOrg),
          'Đảm bảo tiếng nói từ các nhóm phía dưới thật sự đến được nơi ra quyết định, không bị lọc mất giữa đường.');
    });
    test('pt-c3 × individual', () {
      expect(transformContentFor('pt-c3', SeniorityTier.individual),
          'Đưa phản hồi trở thành nhịp thường xuyên trong đội, không chỉ khi có vấn đề.');
    });
    test('pt-c3 × leadTeam', () {
      expect(transformContentFor('pt-c3', SeniorityTier.leadTeam),
          'Đưa phản hồi đều đặn cho từng người, không dồn lại đến kỳ đánh giá mới nói.');
    });
    test('pt-c3 × leadOrg', () {
      expect(transformContentFor('pt-c3', SeniorityTier.leadOrg),
          'Xây một quy trình phản hồi hai chiều cho toàn bộ phạm vi phụ trách, không chỉ từ trên xuống.');
    });
    test('pt-a1 × individual', () {
      expect(transformContentFor('pt-a1', SeniorityTier.individual),
          'Đặt một nhịp định kỳ để tự hỏi lại mục tiêu, thay vì làm theo quán tính.');
    });
    test('pt-a1 × leadTeam', () {
      expect(transformContentFor('pt-a1', SeniorityTier.leadTeam),
          'Kết nối mục tiêu của từng người trong nhóm với mục tiêu chung, để không ai chỉ làm vì được giao.');
    });
    test('pt-a1 × leadOrg', () {
      expect(transformContentFor('pt-a1', SeniorityTier.leadOrg),
          'Giữ định hướng chiến lược rõ ràng và nhất quán, để nhiều nhóm không đi lệch nhau theo thời gian.');
    });
    test('pt-a2 × individual', () {
      expect(transformContentFor('pt-a2', SeniorityTier.individual),
          'Đặt một nhịp nghỉ cố định, không đợi đến khi kiệt sức mới nghỉ.');
    });
    test('pt-a2 × leadTeam', () {
      expect(transformContentFor('pt-a2', SeniorityTier.leadTeam),
          'Chủ động bảo vệ nhịp làm việc của nhóm, không để deadline gấp trở thành trạng thái bình thường.');
    });
    test('pt-a2 × leadOrg', () {
      expect(transformContentFor('pt-a2', SeniorityTier.leadOrg),
          'Xây văn hóa làm việc bền vững ở quy mô rộng, để kiệt sức không trở thành cái giá ngầm định của hiệu suất.');
    });
    test('pt-a3 × individual', () {
      expect(transformContentFor('pt-a3', SeniorityTier.individual),
          'Học cách nhận ra sớm dấu hiệu của phản ứng, trước khi đã lỡ nói ra.');
    });
    test('pt-a3 × leadTeam', () {
      expect(transformContentFor('pt-a3', SeniorityTier.leadTeam),
          'Giữ bình tĩnh khi cả nhóm đang căng thẳng, vì phản ứng của bạn lúc đó ảnh hưởng đến tất cả.');
    });
    test('pt-a3 × leadOrg', () {
      expect(transformContentFor('pt-a3', SeniorityTier.leadOrg),
          'Ra quyết định bình tĩnh ở những tình huống có phạm vi ảnh hưởng lớn, khi áp lực dồn về một người.');
    });
    test('pt-a4 × individual', () {
      expect(transformContentFor('pt-a4', SeniorityTier.individual),
          'Đặt một nhịp nhìn lại định kỳ (retro cá nhân), để việc học không chỉ là tình cờ.');
    });
    test('pt-a4 × leadTeam', () {
      expect(transformContentFor('pt-a4', SeniorityTier.leadTeam),
          'Xây một nhịp nhìn lại định kỳ cho cả nhóm, để bài học không chỉ nằm lại ở một người.');
    });
    test('pt-a4 × leadOrg', () {
      expect(transformContentFor('pt-a4', SeniorityTier.leadOrg),
          'Xây một hệ thống ghi nhận và chia sẻ bài học cho toàn bộ phạm vi phụ trách, để cùng một sai lầm không lặp lại ở nhóm khác.');
    });
  });
}

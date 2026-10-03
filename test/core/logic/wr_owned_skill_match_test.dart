// Gợi ý chủ đề cho một chứng chỉ / khoá học / kỹ năng người dùng tự khai
// (Task D2), và việc bỏ chủ đề đã có khỏi khoảng trống kỹ năng.
//
// Máy chỉ ĐỀ XUẤT; người dùng xác nhận bằng ô tích. Nên luật quan trọng nhất ở
// đây là KHÔNG ĐOÁN BỪA: tên không khớp gì thì trả rỗng.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_owned_skill_match.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_jd_match.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

import '../../support/practice_themes_fixture.dart';

void main() {
  group('suggestThemesForOwnedSkill', () {
    test(
      '"Chứng chỉ Quản lý dự án PMP" gợi ý chủ đề có từ khoá kế hoạch/ưu tiên',
      () {
        final ids = suggestThemesForOwnedSkill(
          'Chứng chỉ Quản lý dự án PMP',
          kTestThemes,
        );
        expect(ids, isNotEmpty);
        expect(ids.length, lessThanOrEqualTo(3));
        expect(ids.first, 'pt-s2');
      },
    );

    test('tên không khớp gì → rỗng (không đoán bừa)', () {
      expect(
        suggestThemesForOwnedSkill('Bằng lái xe B2', kTestThemes),
        isEmpty,
      );
    });

    test('tên rỗng hoặc toàn khoảng trắng → rỗng', () {
      expect(suggestThemesForOwnedSkill('', kTestThemes), isEmpty);
      expect(suggestThemesForOwnedSkill('   ', kTestThemes), isEmpty);
    });

    test('khớp đúng chiều đứng trước khớp cả trụ', () {
      // "phản hồi" là từ khoá riêng của C3, còn "giao tiếp" chỉ nói trụ C.
      final ids = suggestThemesForOwnedSkill(
        'Khoá kỹ năng giao tiếp và phản hồi',
        kTestThemes,
      );
      expect(ids.first, 'pt-c3');
      expect(ids.length, lessThanOrEqualTo(3));
    });

    test('không phân biệt hoa thường, đọc được tên tiếng Anh', () {
      expect(
        suggestThemesForOwnedSkill('PUBLIC SPEAKING Masterclass', kTestThemes),
        contains('pt-c2'),
      );
      expect(
        suggestThemesForOwnedSkill('Emotional Intelligence', kTestThemes),
        contains('pt-a3'),
      );
    });

    test('khớp theo nguyên từ, không khớp nửa chữ', () {
      // "eq" (chỉ số cảm xúc) không được khớp vào giữa "request".
      expect(
        suggestThemesForOwnedSkill('Change request form', kTestThemes),
        isNot(contains('pt-a3')),
      );
    });

    test('bỏ chủ đề đã ngưng đề xuất', () {
      final themes = [
        for (final t in kTestThemes)
          t.themeId == 'pt-s2'
              ? PracticeTheme(
                  themeId: t.themeId,
                  title: t.titleVi,
                  scaDimension: t.scaDimension,
                  description: t.descriptionVi,
                  retiredAt: DateTime(2026),
                )
              : t,
      ];
      expect(
        suggestThemesForOwnedSkill('Chứng chỉ Quản lý dự án PMP', themes),
        isNot(contains('pt-s2')),
      );
    });

    test('kết quả ổn định giữa hai lần gọi', () {
      final a = suggestThemesForOwnedSkill('Kỹ năng giao tiếp', kTestThemes);
      final b = suggestThemesForOwnedSkill('Kỹ năng giao tiếp', kTestThemes);
      expect(a, b);
      expect(a.length, lessThanOrEqualTo(3));
    });
  });

  group('matchSkillsToContext + ownedThemeIds', () {
    test('matchSkillsToContext bỏ chủ đề đã có khỏi gaps', () {
      final m = matchSkillsToContext(
        contextText: 'quản lý đội nhóm',
        formations: const [],
        allThemes: kTestThemes,
        ownedThemeIds: {'pt-c1'},
      );
      expect(m!.gapThemes.map((t) => t.themeId), isNot(contains('pt-c1')));
      // Các chủ đề cùng trụ chưa khai vẫn còn.
      expect(m.gapThemes.map((t) => t.themeId), contains('pt-c2'));
    });

    test('không truyền ownedThemeIds thì giữ nguyên hành vi cũ', () {
      final m = matchSkillsToContext(
        contextText: 'quản lý đội nhóm',
        formations: const [],
        allThemes: kTestThemes,
      );
      expect(m!.gapThemes.map((t) => t.themeId), contains('pt-c1'));
    });
  });
}

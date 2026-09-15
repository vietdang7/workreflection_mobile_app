// Câu Insight đóng băng ngôn ngữ lúc GHI — dựng lại lúc ĐỌC.
//
// Ảnh khách gửi 15/09/2026: thẻ INSIGHT có tiêu đề tiếng Việt "Điều hệ thống
// đọc ra" nhưng thân câu tiếng Anh, và bên trong câu tiếng Anh đó lại có một
// đoạn tiếng Việt do chính người dùng viết.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_career_memory_rules.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';

const _situations = [
  WrSituation(
    code: 'S2-02',
    text: 'Tôi lạc giữa quá nhiều nhóm chat',
    textEn: 'I am lost among too many group chats',
    scaDimension: ScaDimension.s2,
    humanNeed: HumanNeed.roRang,
    wave: 1,
  ),
  WrSituation(
    code: 'S1-04',
    text: 'Tôi không biết ai là người quyết định cuối cùng',
    textEn: 'I do not know who makes the final call',
    scaDimension: ScaDimension.s1,
    humanNeed: HumanNeed.roRang,
    wave: 1,
  ),
];

void main() {
  tearDown(() => wrEnglish = false);

  group('localizeFrozenInsightText', () {
    test('câu tiếng Anh đã lưu được kể lại bằng tiếng Việt', () {
      wrEnglish = false;

      const frozen =
          'The same thread of clarity runs across the past 14 days: starting '
          'at "I do not know who makes the final call", and most recently '
          '"I am lost among too many group chats".';

      final out = localizeFrozenInsightText(frozen, situations: _situations);

      expect(
        out,
        'Cùng một mạch sự rõ ràng chạy suốt 14 ngày qua: bắt đầu ở '
        '"Tôi không biết ai là người quyết định cuối cùng", và gần nhất là '
        '"Tôi lạc giữa quá nhiều nhóm chat".',
      );
      // Không sót mảnh tiếng Anh nào.
      expect(out, isNot(contains('thread')));
      expect(out, isNot(contains('group chats')));
    });

    test('chiều ngược lại: câu tiếng Việt đã lưu kể lại bằng tiếng Anh', () {
      wrEnglish = true;

      const frozen =
          'Cùng một mạch sự rõ ràng chạy suốt 14 ngày qua: bắt đầu ở '
          '"Tôi không biết ai là người quyết định cuối cùng", và gần nhất là '
          '"Tôi lạc giữa quá nhiều nhóm chat".';

      final out = localizeFrozenInsightText(frozen, situations: _situations);

      expect(out, startsWith('The same thread of clarity runs across'));
      expect(out, contains('"I do not know who makes the final call"'));
      expect(out, contains('"I am lost among too many group chats"'));
    });

    test('CHỮ NGƯỜI DÙNG TỰ VIẾT giữ nguyên, không bị dịch', () {
      wrEnglish = false;

      // Đúng ca trong ảnh khách: khung tiếng Anh, một ô là nhãn tình huống
      // tiếng Anh, ô kia là câu người dùng gõ bằng tiếng Việt.
      const userWords =
          'Dừng lại để gọi tên một trải nghiệm cụ thể đã là bước phá…';
      const frozen =
          'The same thread of clarity runs across the past 14 days: starting '
          'at "$userWords", and most recently '
          '"I am lost among too many group chats".';

      final out = localizeFrozenInsightText(frozen, situations: _situations);

      expect(out, startsWith('Cùng một mạch sự rõ ràng chạy suốt 14 ngày qua'));
      // Nhãn tình huống đổi sang tiếng Việt...
      expect(out, contains('"Tôi lạc giữa quá nhiều nhóm chat"'));
      // ...còn chữ của chính người dùng thì không ai được đụng vào.
      expect(out, contains('"$userWords"'));
    });

    test(
      'khung "khoảng lặng" và khung "chủ đề vừa nổi lên" cũng kể lại được',
      () {
        wrEnglish = false;

        const quietGap =
            'The clarity group used to come up often, but in the past 21 days '
            'you have not returned to any situation in it.';
        expect(
          localizeFrozenInsightText(quietGap, situations: _situations),
          'Nhóm sự rõ ràng từng xuất hiện thường xuyên, nhưng 21 ngày gần đây '
          'bạn không quay lại tình huống nào thuộc nhóm này.',
        );

        const emerging =
            'Your last 3 Reflections all circle around clarity. This may be '
            'worth a closer look.';
        expect(
          localizeFrozenInsightText(emerging, situations: _situations),
          '3 lần Reflection gần đây của bạn đều xoay quanh sự rõ ràng. Đây có '
          'thể là điều đáng để nhìn kỹ hơn.',
        );
      },
    );

    test('câu lạ trả về nguyên văn, không ghép bừa', () {
      wrEnglish = false;

      const stranger = 'Một câu không thuộc khung nào của §9.';
      expect(
        localizeFrozenInsightText(stranger, situations: _situations),
        stranger,
      );
    });

    test('mọi khung đều kể lại được ở cả hai chiều', () {
      // Quét cả bộ để một khung mới thêm vào mà quên cặp Việt/Anh sẽ đỏ ngay,
      // thay vì lặng lẽ hiện sai ngôn ngữ trên máy khách.
      for (final template in kFrozenInsightTemplates) {
        final filled = template.en
            .replaceAll('{days}', '14')
            .replaceAll('{n}', '3')
            .replaceAll('{need}', 'clarity')
            .replaceAll('{first}', '"I do not know who makes the final call"')
            .replaceAll('{last}', '"I am lost among too many group chats"');

        wrEnglish = false;
        final vi = localizeFrozenInsightText(filled, situations: _situations);
        expect(
          vi,
          isNot(equals(filled)),
          reason: 'khung này không được nhận ra: ${template.en}',
        );
        expect(
          vi,
          isNot(contains('clarity')),
          reason: 'còn sót nhãn tiếng Anh trong: $vi',
        );
      }
    });
  });

  // Lỗi gốc KHÔNG nằm ở chỗ thiếu cơ chế dịch lại — cơ chế đó đã có sẵn cho
  // mảnh ký ức thực hành từ trước. Nó nằm ở chỗ nhánh Insight không được nối
  // vào. Nên phải có một test đứng ở tầng dựng dòng thời gian, chứ test hàm
  // thuần ở trên xanh mà sản phẩm vẫn hỏng.
  group('buildJourneyEntries — nối dây', () {
    test('thẻ Insight được kể lại theo ngôn ngữ đang bật', () {
      wrEnglish = false;

      final entries = buildJourneyEntries(
        episodes: const [],
        events: [
          CareerMemoryEvent(
            id: '1',
            userId: 'u',
            behavior: kInsightBehavior,
            reflectionText:
                'The same thread of clarity runs across the past 14 days: '
                'starting at "I do not know who makes the final call", and '
                'most recently "I am lost among too many group chats".',
            createdAt: DateTime(2026, 9, 12),
          ),
        ],
        situationLabels: {for (final s in _situations) s.code: s.text},
        situations: _situations,
      );

      expect(entries, hasLength(1));
      expect(entries.single.title, 'Điều hệ thống đọc ra');
      expect(
        entries.single.subtitle,
        'Cùng một mạch sự rõ ràng chạy suốt 14 ngày qua: bắt đầu ở '
        '"Tôi không biết ai là người quyết định cuối cùng", và gần nhất là '
        '"Tôi lạc giữa quá nhiều nhóm chat".',
      );
    });

    test('thẻ Chủ đề cũng vậy', () {
      wrEnglish = false;

      final entries = buildJourneyEntries(
        episodes: const [],
        events: [
          CareerMemoryEvent(
            id: '1',
            userId: 'u',
            behavior: kThemeBehavior,
            humanNeed: HumanNeed.roRang,
            reflectionText:
                'Your last 3 Reflections all circle around clarity. This may '
                'be worth a closer look.',
            createdAt: DateTime(2026, 9, 12),
          ),
        ],
        situationLabels: const {},
        situations: _situations,
      );

      expect(
        entries.single.subtitle,
        '3 lần Reflection gần đây của bạn đều xoay quanh sự rõ ràng. Đây có '
        'thể là điều đáng để nhìn kỹ hơn.',
      );
    });
  });
}

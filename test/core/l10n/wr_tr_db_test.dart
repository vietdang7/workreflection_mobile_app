// Tầng chọn ngôn ngữ cho chữ lấy từ DATABASE.
//
// `wr_tr_test.dart` khoá `tr()` — hai câu lập trình viên viết, luôn có đủ cả
// hai. Ở đây là chuyện khác: bản dịch là một ô trong bảng mà đội nội dung điền
// dần, nên nửa bảng chưa dịch là trạng thái BÌNH THƯỜNG chứ không phải lỗi, và
// nó phải hiện ra tiếng Việt chứ không phải một chỗ trống.
//
// Run: flutter test test/core/l10n/wr_tr_db_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

void main() {
  // Quên trả về là hàng trăm bài chạy sau đó đỏ ở file khác hẳn file gây ra.
  tearDown(() => wrEnglish = false);

  group('trDb', () {
    test('tiếng Việt thì luôn ra bản gốc, kể cả khi đã có bản dịch', () {
      expect(trDb('Xin chào', 'Hello'), 'Xin chào');
    });

    test('tiếng Anh và có bản dịch thì ra bản dịch', () {
      wrSetLocale('en');
      expect(trDb('Xin chào', 'Hello'), 'Hello');
    });

    test('CHƯA DỊCH thì rơi về tiếng Việt, không ra chỗ trống', () {
      wrSetLocale('en');
      expect(trDb('Xin chào', null), 'Xin chào');
    });

    test('chuỗi trắng cũng coi là chưa dịch', () {
      // Migration thêm cột có thể để lại '' thay vì NULL tuỳ cách nhập liệu.
      // Người dùng nhìn thấy chip trắng chữ thì không phân biệt được đó là lỗi
      // hay là hết nội dung.
      wrSetLocale('en');
      expect(trDb('Xin chào', ''), 'Xin chào');
      expect(trDb('Xin chào', '   '), 'Xin chào');
      expect(trDb('Xin chào', '\n\t '), 'Xin chào');
    });

    test('bản dịch được cắt khoảng trắng hai đầu', () {
      wrSetLocale('en');
      expect(trDb('Xin chào', '  Hello  '), 'Hello');
    });
  });

  group('model đọc theo ngôn ngữ đang bật', () {
    WrSituation situation({String? textEn}) => WrSituation(
          code: 'S1-01',
          text: 'Tôi im lặng trong cuộc họp',
          textEn: textEn,
          scaDimension: ScaDimension.s1,
          wave: 1,
        );

    test('WrSituation.text đổi theo ngôn ngữ, textVi thì không', () {
      final s = situation(textEn: 'I stayed quiet in the meeting');
      expect(s.text, 'Tôi im lặng trong cuộc họp');
      wrSetLocale('en');
      expect(s.text, 'I stayed quiet in the meeting');
      // `textVi` là đường thoát cho chỗ cần CHÍNH bản gốc bất kể ngôn ngữ.
      expect(s.textVi, 'Tôi im lặng trong cuộc họp');
    });

    test('dòng chưa dịch vẫn ra tiếng Việt khi đang bật tiếng Anh', () {
      final s = situation();
      wrSetLocale('en');
      expect(s.text, 'Tôi im lặng trong cuộc họp');
    });

    test('fromJson đọc cả cột _en lẫn cột gốc', () {
      final s = WrSituation.fromJson({
        'code': 'S1-01',
        'text': 'Tôi im lặng trong cuộc họp',
        'text_en': 'I stayed quiet in the meeting',
        'sca_dimension': 'S1',
        'wave': 1,
      });
      wrSetLocale('en');
      expect(s.text, 'I stayed quiet in the meeting');
    });

    test('thiếu hẳn cột _en trong hàng trả về thì không nổ', () {
      // Bản app mới chạy trước khi migration kịp lên remote là ca có thật.
      final s = WrSituation.fromJson({
        'code': 'S1-01',
        'text': 'Tôi im lặng trong cuộc họp',
        'sca_dimension': 'S1',
        'wave': 1,
      });
      wrSetLocale('en');
      expect(s.textEn, isNull);
      expect(s.text, 'Tôi im lặng trong cuộc họp');
    });

    test('WrStory đổi cả sáu cột hiển thị', () {
      final story = WrStory(
        storyId: 'S1-story-01',
        title: 'Buổi họp im lặng',
        titleEn: 'The quiet meeting',
        scaDimension: ScaDimension.s1,
        storyContent: 'Nội dung tiếng Việt',
        storyContentEn: 'English content',
        reflectionQuestion: 'Câu hỏi',
        reflectionQuestionEn: 'A question',
        selfReflection: 'Tự soi',
        selfReflectionEn: 'Self reflection',
        ahaMessage: 'Điều nhận ra',
        ahaMessageEn: 'What you noticed',
        practiceAction: 'Hành động',
        practiceActionEn: 'An action',
        emotionTags: const [],
        behaviorTags: const [],
        careerStages: const [],
      );
      wrSetLocale('en');
      expect(story.title, 'The quiet meeting');
      expect(story.storyContent, 'English content');
      expect(story.reflectionQuestion, 'A question');
      expect(story.selfReflection, 'Self reflection');
      expect(story.ahaMessage, 'What you noticed');
      expect(story.practiceAction, 'An action');
    });

    test('cột vốn nullable mà VẮNG thì vẫn là null, không thành chuỗi rỗng', () {
      // Nơi dùng đang phân biệt "có câu" với "không có câu" để quyết định hiện
      // hay giấu cả khối. Ép về chuỗi rỗng là biến "không có" thành "có nhưng
      // trắng", tức hiện một khối trống.
      final story = WrStory(
        storyId: 'S1-story-02',
        title: 'Tiêu đề',
        scaDimension: ScaDimension.s1,
        storyContent: 'Nội dung',
        emotionTags: const [],
        behaviorTags: const [],
        careerStages: const [],
      );
      wrSetLocale('en');
      expect(story.ahaMessage, isNull);
      expect(story.practiceAction, isNull);
      expect(story.selfReflection, isNull);
    });

    test('PracticeTheme và PracticeStep', () {
      const theme = PracticeTheme(
        themeId: 'T1',
        title: 'Dám lên tiếng',
        titleEn: 'Speaking up',
        description: 'Mô tả',
        descriptionEn: 'A description',
        formedLine: 'Câu ăn mừng',
        formedLineEn: 'A line to celebrate',
      );
      const step = PracticeStep(
        stepId: 'T1-1',
        themeId: 'T1',
        stepOrder: 1,
        title: 'Nhận diện',
        titleEn: 'Notice',
        content: 'Nội dung bước',
        contentEn: 'Step content',
        isPremium: false,
      );
      wrSetLocale('en');
      expect(theme.title, 'Speaking up');
      expect(theme.description, 'A description');
      expect(theme.formedLine, 'A line to celebrate');
      expect(step.title, 'Notice');
      expect(step.content, 'Step content');
    });
  });

  group('mã ngôn ngữ gửi lên máy chủ', () {
    test('mặc định là vi', () {
      expect(wrLocaleCode, 'vi');
      expect(wrLocaleHeaders, {'x-wr-locale': 'vi'});
    });

    test('đổi theo ngôn ngữ đang bật', () {
      wrSetLocale('en');
      expect(wrLocaleCode, 'en');
      expect(wrLocaleHeaders, {'x-wr-locale': 'en'});
    });
  });
}

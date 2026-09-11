// Cổng chặn phát hành của Thư viện Nội dung Cảm xúc.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §XII.3.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';

import '../../support/fake_wr_mood_content_repository.dart';

void main() {
  group('MoodContent.releasable — §XII.3', () {
    final draft = fakeMoodContent(
      id: 'draft',
      mood: Mood.okay,
      sortOrder: 1,
      placeholder: true,
    );
    final edited = fakeMoodContent(
      id: 'edited',
      mood: Mood.okay,
      sortOrder: 2,
      placeholder: false,
    );

    test('bản release không phát hành nội dung còn nháp', () {
      final result = MoodContent.releasable([draft, edited], isRelease: true);

      expect(result.map((c) => c.id), ['edited']);
    });

    test('bản debug giữ nguyên nội dung nháp để còn thử được luồng', () {
      // Seed hiện tại toàn bộ là placeholder = true; lọc ở debug sẽ để lại
      // thư viện rỗng và không ai chạy thử được.
      final result = MoodContent.releasable([draft, edited], isRelease: false);

      expect(result.map((c) => c.id), ['draft', 'edited']);
    });

    test('release mà chưa có mục nào biên tập xong thì trả về rỗng, '
        'chứ không âm thầm phát hành nháp', () {
      final result = MoodContent.releasable([draft], isRelease: true);

      expect(result, isEmpty);
    });

    test('isPublishable là nghịch đảo của placeholder', () {
      expect(draft.isPublishable, isFalse);
      expect(edited.isPublishable, isTrue);
    });
  });

  group('MoodContent.releasable — mục audio chưa có bản thu', () {
    final reading = fakeMoodContent(
      id: 'reading',
      mood: Mood.okay,
      sortOrder: 1,
      placeholder: false,
    );
    final silentAudio = fakeMoodContent(
      id: 'silent',
      mood: Mood.okay,
      sortOrder: 6,
      type: MoodContentType.audio,
      placeholder: true,
    );
    final recordedAudio = fakeMoodContent(
      id: 'recorded',
      mood: Mood.okay,
      sortOrder: 7,
      type: MoodContentType.audio,
      placeholder: false,
      audioUrl: 'https://cdn.example/mot-khoang-lang.mp3',
    );

    test('bản debug cũng ẩn mục audio chưa có bản thu', () {
      // Khác với nội dung nháp: mục nháp còn chữ để đọc thử, còn mục audio
      // không có bản thu thì mở ra chỉ có một khối trình phát rỗng.
      final result = MoodContent.releasable(
        [reading, silentAudio],
        isRelease: false,
      );

      expect(result.map((c) => c.id), ['reading']);
    });

    test('bản release cũng vậy', () {
      final result = MoodContent.releasable(
        [reading, silentAudio],
        isRelease: true,
      );

      expect(result.map((c) => c.id), ['reading']);
    });

    test('có bản thu rồi thì mục audio hiện lại, không cần sửa code', () {
      final result = MoodContent.releasable(
        [reading, silentAudio, recordedAudio],
        isRelease: true,
      );

      expect(result.map((c) => c.id), ['reading', 'recorded']);
    });

    test('audio_url rỗng hoặc toàn khoảng trắng vẫn tính là chưa có bản thu',
        () {
      final blank = fakeMoodContent(
        id: 'blank',
        mood: Mood.okay,
        sortOrder: 8,
        type: MoodContentType.audio,
        placeholder: false,
        audioUrl: '   ',
      );

      expect(blank.isUsable, isFalse);
      expect(MoodContent.releasable([blank], isRelease: false), isEmpty);
    });

    test('bài đọc không bị ràng buộc bản thu', () {
      expect(reading.isUsable, isTrue);
      expect(draftReading.isUsable, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Bản tiếng Anh
  //
  // Thư viện là bảng người dùng NHÌN THẤY nhiều nhất — mục đầu tiên của nhóm
  // cảm xúc vừa check-in hiện thẳng trên màn Hôm nay. Nó bị bỏ sót khỏi đợt
  // dịch 10/09, nên bật tiếng Anh lên thì cả màn Hôm nay là tiếng Anh trừ đúng
  // thẻ này.
  // -------------------------------------------------------------------------

  group('MoodContent — ngôn ngữ', () {
    tearDown(() => wrEnglish = false);

    final item = fakeMoodContent(
      id: 'm1',
      mood: Mood.stressed,
      title: 'Khi mọi thứ đều gấp cùng một lúc',
      body: 'Đoạn một.\n\nĐoạn hai.',
      titleEn: 'When everything is urgent at once',
      bodyEn: 'Paragraph one.\n\nParagraph two.',
    );

    test('tiếng Việt đọc bản gốc dù đã có bản dịch', () {
      expect(item.title, 'Khi mọi thứ đều gấp cùng một lúc');
      expect(item.body, startsWith('Đoạn một.'));
    });

    test('tiếng Anh đọc bản dịch', () {
      wrSetLocale('en');
      expect(item.title, 'When everything is urgent at once');
      expect(item.body, startsWith('Paragraph one.'));
    });

    test('CHƯA DỊCH thì rơi về tiếng Việt, không ra thẻ trắng', () {
      wrSetLocale('en');
      final untranslated = fakeMoodContent(
        id: 'm2',
        mood: Mood.tired,
        title: 'Chưa dịch',
        body: 'Nội dung.',
      );
      expect(untranslated.title, 'Chưa dịch');
      expect(untranslated.body, 'Nội dung.');
    });

    test('số đoạn không đổi theo ngôn ngữ — bố cục màn đọc phải giống nhau',
        () {
      final vi = item.paragraphs.length;
      wrSetLocale('en');
      expect(item.paragraphs.length, vi);
    });

    test('nhãn loại và thời lượng dịch ở tầng app, không cần cột trong DB', () {
      // Cả bảng chỉ có một giá trị `kind` và ba giá trị `duration`. Thêm cột
      // `_en` cho chúng là bắt người biên tập gõ lại cùng một chữ ba mươi lần.
      expect(item.kindLabel, 'BÀI ĐỌC');
      expect(item.durationLabel, '3 phút đọc');

      wrSetLocale('en');
      expect(item.kindLabel, 'READING');
      expect(item.durationLabel, '3 min read');
    });

    test('giá trị lạ thì trả nguyên văn, không bịa nhãn', () {
      // Đội nội dung thêm một loại mới mà quên báo: người dùng tiếng Anh thấy
      // một nhãn tiếng Việt — dở, nhưng hơn hẳn một ô trống hay một nhãn bịa.
      wrSetLocale('en');
      final odd = fakeMoodContent(
        id: 'm3',
        mood: Mood.happy,
        kind: 'PODCAST',
        duration: 'nửa tiếng',
      );
      expect(odd.kindLabel, 'PODCAST');
      expect(odd.durationLabel, 'nửa tiếng');
    });
  });
}

/// Bài đọc còn nháp — vẫn có toàn văn nên vẫn dùng được.
final draftReading = fakeMoodContent(
  id: 'draft_reading',
  mood: Mood.stressed,
  sortOrder: 1,
  placeholder: true,
);

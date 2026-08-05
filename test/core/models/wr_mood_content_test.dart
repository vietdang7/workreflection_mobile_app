// Cổng chặn phát hành của Thư viện Nội dung Cảm xúc.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §XII.3.

import 'package:flutter_test/flutter_test.dart';
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
}

/// Bài đọc còn nháp — vẫn có toàn văn nên vẫn dùng được.
final draftReading = fakeMoodContent(
  id: 'draft_reading',
  mood: Mood.stressed,
  sortOrder: 1,
  placeholder: true,
);

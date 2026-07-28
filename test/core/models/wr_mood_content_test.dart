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
}

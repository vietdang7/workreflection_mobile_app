// "Viết JD cùng app" — luật khoá buổi và nội dung năm buổi.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §6 + mockup v16, `screenJdDay*`.
//
// Run: flutter test test/core/logic/wr_jd_builder_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_jd_builder.dart';

void main() {
  group('§6 · Nội dung năm buổi', () {
    test('đủ năm buổi, đánh số 1..5 liên tục', () {
      expect(kJdDays.length, kJdDayCount);
      expect(
        kJdDays.map((d) => d.number).toList(),
        List.generate(kJdDayCount, (i) => i + 1),
      );
    });

    test('mỗi buổi có ít nhất một ô, ô nào cũng có nhãn và gợi ý', () {
      for (final day in kJdDays) {
        expect(day.fields, isNotEmpty, reason: 'buổi ${day.number}');
        expect(day.title.trim(), isNotEmpty, reason: 'buổi ${day.number}');
        expect(day.eyebrow.trim(), isNotEmpty, reason: 'buổi ${day.number}');
        for (final f in day.fields) {
          expect(f.label.trim(), isNotEmpty, reason: f.column);
          expect(f.hint.trim(), isNotEmpty, reason: f.column);
        }
      }
    });

    // Tên cột đi thẳng vào câu UPSERT ở SupabaseWrJdRepository. Trùng tên là
    // hai ô ghi đè nhau mà không có lỗi nào báo ra — chỉ thấy chữ biến mất.
    test('không có hai ô nào dùng chung một cột', () {
      final columns = jdColumns();
      expect(columns.toSet().length, columns.length);
    });

    // Buổi 1 là phần làm quen (không nằm trong JD), bốn buổi sau là JD thật.
    test('jdColumns() xếp đúng thứ tự các buổi', () {
      final expected = [
        for (final day in kJdDays)
          for (final f in day.fields) f.column,
      ];
      expect(jdColumns(), expected);
    });

    test('câu kết nói rõ JD được lưu vào hồ sơ', () {
      expect(kJdCompletionNote, contains('hồ sơ'));
    });
  });

  group('§6 · Khoá buổi sau cho đến khi xong buổi trước', () {
    test('buổi 1 luôn mở, kể cả khi chưa làm gì', () {
      expect(canOpenJdDay(1, const []), isTrue);
    });

    test('chưa xong buổi 1 thì buổi 2 còn khoá', () {
      expect(canOpenJdDay(2, const []), isFalse);
    });

    test('xong buổi liền trước thì buổi sau mở', () {
      expect(canOpenJdDay(2, const [1]), isTrue);
      expect(canOpenJdDay(3, const [1, 2]), isTrue);
      expect(canOpenJdDay(5, const [1, 2, 3, 4]), isTrue);
    });

    test('không cho nhảy cóc hai buổi', () {
      expect(canOpenJdDay(3, const [1]), isFalse);
      expect(canOpenJdDay(5, const [1, 2]), isFalse);
    });

    test('buổi đã xong thì luôn quay lại sửa được', () {
      // Bản ghi lệch: có buổi 3 mà thiếu buổi 2.
      expect(canOpenJdDay(3, const [1, 3]), isTrue);
    });

    // Luật "buổi liền trước" thay vì "mọi buổi trước": bản ghi thiếu buổi 2 mà
    // đã có buổi 3, 4 thì luật kia khoá vĩnh viễn buổi 5.
    test('bản ghi lệch vẫn còn đường đi tiếp', () {
      expect(canOpenJdDay(5, const [1, 3, 4]), isTrue);
    });

    test('số buổi ngoài 1..5 luôn khoá', () {
      expect(canOpenJdDay(0, const [1, 2, 3, 4, 5]), isFalse);
      expect(canOpenJdDay(6, const [1, 2, 3, 4, 5]), isFalse);
      expect(canOpenJdDay(-1, const []), isFalse);
    });
  });

  group('§6 · Vào lại màn mở đúng buổi đang dở', () {
    test('lần đầu mở ở buổi 1', () {
      expect(resumeJdDay(1, const []), 1);
    });

    test('buổi đang dở còn mở được thì giữ nguyên', () {
      expect(resumeJdDay(3, const [1, 2]), 3);
    });

    test('buổi đang dở đã xong rồi thì đi tới buổi chưa xong', () {
      expect(resumeJdDay(2, const [1, 2]), 3);
    });

    // Không bao giờ mở màn ở một buổi bấm gì cũng không được.
    test('buổi đang dở bị khoá thì lùi về buổi mở được', () {
      expect(resumeJdDay(5, const []), 1);
      expect(resumeJdDay(4, const [1]), 2);
    });

    test('xong cả năm buổi thì mở lại buổi cuối để đọc và sửa', () {
      expect(resumeJdDay(5, const [1, 2, 3, 4, 5]), kJdDayCount);
    });

    test('mọi trạng thái đều trả về một buổi mở được', () {
      for (var current = 1; current <= kJdDayCount; current++) {
        for (final completed in const [
          <int>[],
          [1],
          [1, 2],
          [1, 2, 3],
          [1, 2, 3, 4],
          [1, 2, 3, 4, 5],
          [1, 3, 4],
        ]) {
          final day = resumeJdDay(current, completed);
          expect(
            canOpenJdDay(day, completed),
            isTrue,
            reason: 'current=$current completed=$completed → $day',
          );
        }
      }
    });
  });

  group('§6 · Đánh dấu buổi đã xong', () {
    test('thêm buổi mới, giữ thứ tự tăng dần', () {
      expect(markJdDayDone(2, const [1]), [1, 2]);
      expect(markJdDayDone(1, const [2, 3]), [1, 2, 3]);
    });

    test('bấm lại buổi đã xong không nhân đôi', () {
      expect(markJdDayDone(2, const [1, 2]), [1, 2]);
    });

    test('isJdComplete chỉ đúng khi đủ cả năm buổi', () {
      expect(isJdComplete(const []), isFalse);
      expect(isJdComplete(const [1, 2, 3, 4]), isFalse);
      expect(isJdComplete(const [1, 2, 3, 4, 5]), isTrue);
      // Thừa số lạ vẫn tính là xong, miễn đủ 1..5.
      expect(isJdComplete(const [1, 2, 3, 4, 5, 9]), isTrue);
    });

    test('đi tuần tự năm lần thì kết thúc ở trạng thái hoàn tất', () {
      var completed = <int>[];
      for (var d = 1; d <= kJdDayCount; d++) {
        expect(canOpenJdDay(d, completed), isTrue, reason: 'buổi $d');
        completed = markJdDayDone(d, completed);
      }
      expect(isJdComplete(completed), isTrue);
    });
  });
}

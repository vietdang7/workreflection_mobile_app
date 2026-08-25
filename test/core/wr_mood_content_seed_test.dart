// Coverage test — assets/seed/wr_mood_content.json phải khớp hai nguồn nội dung
// đang hợp lệ cùng lúc:
//
//   · 20 bài của bốn nhóm cũ  → WorkReflection_HealingLibrary_ToanVan_v2.md
//                               (Cloud & Coral, 28/07, biên tập xong 04/08)
//   · 10 bài của hai nhóm mới → WorkReflection_Sprint2_Mockup_v16.html
//                               `CONTENT_LIBRARY` (changelog 24/08 §3, §4)
//
// Bóc bằng tool/extract_wr_mood_readings.py và tool/extract_wr_mood_readings_v3.py,
// dịch sang SQL bằng tool/gen_wr_mood_content_sql.py.
//
// Vì sao cần test này: seed JSON là nguồn chuẩn, còn khối SQL trong migration
// chỉ là bản dịch. Sai ở JSON thì sai xuống tận cơ sở dữ liệu mà không màn hình
// nào phát hiện được — thư viện vẫn dựng bình thường, chỉ là thiếu bài hoặc
// hiện nhầm mục nháp lên Home.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sáu nhóm, đúng thứ tự lưới check-in ở Home (`kCheckinOptions`).
const _moods = ['stress', 'tired', 'foggy', 'outofsync', 'ok', 'happy'];

/// Hai nhóm thêm 25/08/2026. Nội dung lấy nguyên văn từ mockup và changelog §4
/// ghi rõ chúng CÒN LÀ NHÁP, chưa qua biên tập lần cuối.
const _draftMoods = ['foggy', 'outofsync'];

void main() {
  late List<Map<String, dynamic>> rows;

  List<Map<String, dynamic>> ofMood(String mood) =>
      rows.where((r) => r['mood'] == mood).toList();

  setUpAll(() {
    final file = File('assets/seed/wr_mood_content.json');
    rows = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
  });

  group('Thư viện Nội dung Cảm xúc — seed', () {
    test('đủ 30 bài đọc, 5 bài mỗi cảm xúc', () {
      // §4: "Hoàn thiện toàn văn cho cả 30 bài (5 bài × 6 mood, gồm cả 2 mood
      // mới ở mục 3)".
      final readings = rows.where((r) => r['type'] == 'reading').toList();
      expect(readings.length, 30);
      for (final mood in _moods) {
        expect(
          readings.where((r) => r['mood'] == mood).length,
          5,
          reason: 'nhóm $mood phải có đúng 5 bài đọc',
        );
      }
    });

    test('không còn mục HEALING AUDIO nào', () {
      // §4: "Chuyển toàn bộ mục trước đây là HEALING AUDIO sang BÀI ĐỌC — vì
      // giai đoạn hiện tại chỉ sản xuất được nội dung dạng bài đọc, chưa thu
      // âm." Ba mục âm thanh nền thuần tuý (mưa, nhạc tập trung, nhạc ăn mừng)
      // không chuyển được nên bị bỏ hẳn, đúng ghi chú cho dev trong §4.
      expect(rows.where((r) => r['type'] == 'audio'), isEmpty);
      expect(rows.where((r) => r['kind'] == 'HEALING AUDIO'), isEmpty);
    });

    test('bài đọc chiếm sort_order 1..5 của mỗi nhóm', () {
      // Home hiện đúng mục ĐẦU nhóm (§8.3). Slot 1 phải luôn là một bài đọc
      // thật, nếu không bản release lọc nó đi và Home mất hẳn thẻ gợi ý.
      for (final mood in _moods) {
        final orders = ofMood(mood)
            .where((r) => r['type'] == 'reading')
            .map((r) => r['sort_order'] as int)
            .toList()
          ..sort();
        expect(orders, [1, 2, 3, 4, 5], reason: 'nhóm $mood');
      }
    });

    test('sort_order liên tục từ 1 trong mỗi nhóm', () {
      for (final mood in _moods) {
        final orders = ofMood(mood).map((r) => r['sort_order'] as int).toList()
          ..sort();
        expect(
          orders,
          List.generate(orders.length, (i) => i + 1),
          reason: 'nhóm $mood',
        );
      }
    });

    test('cả 30 bài đều phát hành được, không còn cờ nháp', () {
      // §4, ghi chú cho dev: "Toàn bộ 30 bài vẫn giữ cờ placeholder:true...
      // Nếu chốt xong nội dung, cần đổi cờ này thành false trước khi lên bản
      // chính thức."
      //
      // Owner chốt 25/08: đổi thành false ngay. Lý do là một ràng buộc của
      // chính app chứ không phải sốt ruột — `MoodContent.releasable` LỌC BỎ mọi
      // mục còn nháp ở bản release (§XII.3). Giữ cờ nháp thì hai ô check-in mới
      // lên store thành hai ô bấm vào không có bài nào, tức §3 và §4 triệt tiêu
      // nhau. Nội dung 10 bài đã đủ toàn văn nên điều kiện "chốt xong nội dung"
      // đã thoả.
      for (final r in rows) {
        expect(
          r['placeholder'],
          false,
          reason: '${r['title']}: còn cờ nháp thì bản release sẽ lọc mất',
        );
      }
    });

    test('bài đọc là toàn văn, không phải đoạn giới thiệu', () {
      // Hai ngưỡng khác nhau vì hai nguồn viết theo hai độ dài khác nhau:
      //   · nhóm cũ  — tài liệu quy định 3 phút = 350–450 từ, 4 phút = 450–550
      //   · nhóm mới — mockup viết loại 2–3 phút, khoảng 170–200 từ
      // Ngưỡng ở đây chỉ để bắt body tụt về một đoạn tóm tắt hai câu như bản
      // seed đầu tiên, không phải để áp một độ dài tối thiểu lên nội dung.
      for (final r in rows) {
        final words = (r['body'] as String).split(RegExp(r'\s+')).length;
        final floor = _draftMoods.contains(r['mood']) ? 140 : 250;
        expect(
          words,
          greaterThan(floor),
          reason: '${r['title']}: chỉ $words từ, nghi là bản tóm tắt',
        );
      }
    });

    test('10 bài nhóm mới kết bằng câu hỏi mở', () {
      // §4: "kết bằng một câu hỏi mở thay vì câu mệnh lệnh (đúng nguyên tắc
      // brand: nội dung luôn kết bằng câu hỏi mở)".
      for (final r in rows.where((r) => _draftMoods.contains(r['mood']))) {
        expect(
          (r['body'] as String).trimRight().endsWith('?'),
          isTrue,
          reason: r['title'] as String,
        );
      }
    });

    test('bài mẫu gốc đã được chỉnh câu kết', () {
      // §4 nêu ĐÍCH DANH bài này: "Bài mẫu gốc 'Khi áp lực đến từ việc muốn
      // kiểm soát mọi thứ' cũng được chỉnh lại câu kết cho khớp nguyên tắc
      // này." Đối chiếu với mockup v16 thì sửa đổi gồm đúng hai chỗ: một dấu
      // hai chấm đổi thành dấu phẩy, và một câu hỏi mở nối vào cuối.
      final r = rows.firstWhere(
        (r) => r['title'] == 'Khi áp lực đến từ việc muốn kiểm soát mọi thứ',
      );
      final body = r['body'] as String;
      expect(
        body.trimRight(),
        endsWith(
          'Trong những điều đang khiến bạn lo lắng lúc này, đâu là phần bạn '
          'thực sự có thể tác động?',
        ),
      );
      expect(body, contains('Một ví dụ nhỏ và quen thuộc, khi giao'));
    });

    test('19 bài còn lại của bốn nhóm cũ vẫn kết bằng câu khẳng định', () {
      // ĐANG CHỜ ĐỘI NỘI DUNG QUYẾT, không phải một khẳng định rằng như vậy là
      // đúng.
      //
      // §4 phát biểu nguyên tắc brand ở dạng phổ quát ("nội dung luôn kết bằng
      // câu hỏi mở") nhưng chỉ ghi lại MỘT bài đã được chỉnh. 19 bài toàn văn
      // còn lại, bóc từ HealingLibrary_ToanVan_v2.md, đều kết bằng câu khẳng
      // định. Tự viết thêm 19 câu hỏi kết là viết nội dung mới rồi phát hành
      // dưới danh nghĩa bản đã duyệt — việc đó thuộc đội nội dung.
      //
      // Test này khoá con số 19 lại để khi nào đội nội dung chỉnh xong, người
      // sửa buộc phải đi qua đây và cập nhật, thay vì nguyên tắc brand cứ trôi
      // đi trong im lặng.
      final open = rows
          .where((r) => (r['body'] as String).trimRight().endsWith('?'))
          .length;
      expect(
        open,
        11,
        reason: '10 bài nhóm mới + 1 bài mẫu gốc đã chỉnh. Nếu con số này tăng '
            'nghĩa là đội nội dung đã chỉnh thêm — cập nhật lại test.',
      );
    });

    test('bài đọc không mang kịch bản lồng tiếng', () {
      // §8.1: cột script chỉ dành cho HEALING AUDIO. Không còn hàng audio nào
      // thì cũng không được còn script nào.
      for (final r in rows) {
        expect(r['script'], isNull, reason: r['title'] as String);
      }
    });

    test('nhãn kind khớp với type', () {
      for (final r in rows) {
        expect(r['kind'], 'BÀI ĐỌC', reason: r['title'] as String);
        expect(r['type'], 'reading', reason: r['title'] as String);
      }
    });

    test('tiêu đề không trùng nhau', () {
      final titles = rows.map((r) => r['title'] as String).toList();
      expect(titles.toSet().length, titles.length);
    });
  });
}

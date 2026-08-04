// Coverage test — assets/seed/wr_mood_content.json phải khớp bản toàn văn
// Thư viện Nội dung Cảm xúc v2 (Cloud & Coral, 28/07/2026), theo Mục VIII
// Kiến trúc Dữ liệu Hai Lớp.
//
// Nguồn spec: ~/Desktop/FileTam/workreflection/
//             WorkReflection_HealingLibrary_ToanVan_v2.md
// Bóc bằng tool/extract_wr_mood_readings.py, dịch sang SQL bằng
// tool/gen_wr_mood_content_sql.py.
//
// Vì sao cần test này: seed JSON là nguồn chuẩn, còn khối SQL trong migration
// chỉ là bản dịch. Sai ở JSON thì sai xuống tận cơ sở dữ liệu mà không màn hình
// nào phát hiện được — thư viện vẫn dựng bình thường, chỉ là thiếu bài hoặc
// hiện nhầm mục nháp lên Home.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _moods = ['stress', 'tired', 'ok', 'happy'];

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
    test('đủ 20 bài đọc, 5 bài mỗi cảm xúc', () {
      final readings = rows.where((r) => r['type'] == 'reading').toList();
      expect(readings.length, 20);
      for (final mood in _moods) {
        expect(
          readings.where((r) => r['mood'] == mood).length,
          5,
          reason: 'nhóm $mood phải có đúng 5 bài đọc',
        );
      }
    });

    test('bài đọc chiếm sort_order 1..5 của mỗi nhóm', () {
      // Home hiện đúng mục ĐẦU nhóm (§8.3). Nếu một mục audio còn nháp lọt lên
      // slot 1, bản release lọc nó đi (§XII.3) và Home mất hẳn thẻ gợi ý.
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

    test('mọi bài đọc đã biên tập xong, phát hành được', () {
      for (final r in rows.where((r) => r['type'] == 'reading')) {
        expect(
          r['placeholder'],
          false,
          reason: '${r['title']}: bài đọc toàn văn không còn là nháp',
        );
      }
    });

    test('bài đọc là toàn văn, không phải đoạn giới thiệu', () {
      // Tài liệu quy định 3 phút = 350–450 từ, 4 phút = 450–550 từ. Ngưỡng 250
      // đủ rộng để không vỡ vì biên tập lặt vặt, nhưng vẫn chặn được trường hợp
      // body tụt về một đoạn tóm tắt hai câu như bản seed cũ.
      for (final r in rows.where((r) => r['type'] == 'reading')) {
        final words = (r['body'] as String).split(RegExp(r'\s+')).length;
        expect(
          words,
          greaterThan(250),
          reason: '${r['title']}: chỉ $words từ, nghi là bản tóm tắt',
        );
      }
    });

    test('bài đọc không mang kịch bản lồng tiếng', () {
      // §8.1: cột script chỉ dành cho HEALING AUDIO. Ràng buộc này cũng có ở
      // tầng cơ sở dữ liệu, nhưng chặn từ seed thì không phải chờ tới lúc
      // migration đổ vỡ mới biết.
      for (final r in rows.where((r) => r['type'] == 'reading')) {
        expect(r['script'], isNull, reason: r['title'] as String);
      }
    });

    test('nhãn kind khớp với type', () {
      for (final r in rows) {
        expect(
          r['kind'],
          r['type'] == 'reading' ? 'BÀI ĐỌC' : 'HEALING AUDIO',
          reason: r['title'] as String,
        );
      }
    });

    test('mục audio còn nguyên, vẫn ở trạng thái chờ thu âm', () {
      // Khách chốt: audio cập nhật sau. Giữ 10 mục phụ lục để kịch bản lồng
      // tiếng đã viết không mất, và để luồng audio còn đường thử trên bản debug.
      final audios = rows.where((r) => r['type'] == 'audio').toList();
      expect(audios.length, 10);
      for (final r in audios) {
        expect(r['placeholder'], true, reason: r['title'] as String);
        expect(r['sort_order'] as int, greaterThan(5), reason: r['title'] as String);
      }
    });

    test('tiêu đề không trùng nhau', () {
      final titles = rows.map((r) => r['title'] as String).toList();
      expect(titles.toSet().length, titles.length);
    });
  });
}

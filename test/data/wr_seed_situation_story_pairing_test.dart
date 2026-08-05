// Canh chính DỮ LIỆU SEED, không canh code.
//
// Kiến trúc Dữ liệu v2.0 §2.2: Situation là MỘT thực thể có đủ chín trường —
// nhãn chip, Story, Reflection, Self Reflection, Aha, Practice. Trong app nó
// nằm ở hai bảng, nên "một thực thể" chỉ đúng khi hai bảng dùng CHUNG một mã.
//
// Lỗi từng xảy ra: chip mang mã `<DIM>-sit-NN` còn nội dung mang mã `<DIM>-NN`,
// hai tập rời nhau. `resolveStoryFor` phải lùi về phép băm theo chiều, nên câu
// chuyện người dùng đọc ở bước Meaning và câu Aha ở bước Insight thường không
// nói về tình huống họ vừa chạm — chạm "Không dám lên tiếng" có thể đọc phải
// "Bạn luôn là người cuối cùng phát biểu". Và 40 nội dung không bao giờ có
// đường tới người dùng.
//
// Test này đọc thẳng file migration, vì đó là nguồn duy nhất của dữ liệu seed.
// Thêm một tình huống mà quên thêm nội dung cùng mã là test đỏ ngay.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _migrations = Directory('supabase/migrations');

/// Mã trong một khối `insert into public.<table>`, cột đầu tiên của mỗi dòng.
Set<String> _seededCodes(String table) {
  final codes = <String>{};
  final retired = <String>{};

  final files = _migrations
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in files) {
    final sql = f.readAsStringSync();

    // Khối insert: từ `insert into public.<table>` tới dấu `;` kết thúc câu.
    final blocks = RegExp(
      "insert\\s+into\\s+public\\.$table\\b(.*?)(?:on conflict|;)",
      dotAll: true,
      caseSensitive: false,
    ).allMatches(sql);
    for (final b in blocks) {
      for (final m
          in RegExp(r"\(\s*'([A-Za-z0-9-]+)'\s*,").allMatches(b.group(1)!)) {
        codes.add(m.group(1)!);
      }
    }

    // Chip bị ngưng đề xuất — không còn được chào mời nên không cần story.
    if (table == 'wr_situations' &&
        RegExp(r"set\s+retired_at\s*=", caseSensitive: false).hasMatch(sql)) {
      for (final m in RegExp(
        r"where\s+code\s+like\s+'([^']+)'",
        caseSensitive: false,
      ).allMatches(sql)) {
        final pattern = m.group(1)!.replaceAll('%', '');
        retired.addAll(codes.where((c) => c.contains(pattern)));
      }
    }
  }
  return codes.difference(retired);
}

void main() {
  test('mọi tình huống còn được đề xuất đều có Story trùng mã', () {
    final situations = _seededCodes('wr_situations');
    final stories = _seededCodes('wr_stories');

    expect(situations, isNotEmpty, reason: 'không đọc được seed wr_situations');
    expect(stories, isNotEmpty, reason: 'không đọc được seed wr_stories');

    final orphans = situations.difference(stories).toList()..sort();
    expect(
      orphans,
      isEmpty,
      reason: 'Những tình huống này sẽ rơi vào nhánh ĐOÁN của resolveStoryFor '
          '(bốc một story cùng chiều), nên người dùng đọc phải câu chuyện của '
          'tình huống khác. Thêm story cùng mã, hoặc đánh dấu retired_at.',
    );
  });

  test('thư viện đủ rộng cho mọi cụm cảm xúc của §III', () {
    // §III: "nếu số tình huống thuộc cụm dims liên quan từ 5 trở lên, chỉ lấy
    // trong cụm đó". Dưới 5 là bộ lọc tự vô hiệu và người dùng nhận gợi ý
    // không dính gì tới cảm xúc vừa chọn.
    final situations = _seededCodes('wr_situations');
    final byDim = <String, int>{};
    for (final c in situations) {
      final dim = c.startsWith('P-') ? 'P' : c.split('-').first;
      byDim[dim] = (byDim[dim] ?? 0) + 1;
    }

    // stressed → A3+C2 · tired → A3+A1 · okay → P-STEADY · happy → P-ACHIEVE.
    // Hai nhóm tích cực nằm chung tiền tố P- nên gộp lại kiểm 10 (5 mỗi nhóm).
    for (final cluster in const [
      ['A3', 'C2'],
      ['A3', 'A1'],
    ]) {
      final n = cluster.fold<int>(0, (s, d) => s + (byDim[d] ?? 0));
      expect(n, greaterThanOrEqualTo(5),
          reason: 'cụm $cluster chỉ có $n tình huống — bộ lọc §III tự vô hiệu');
    }
    expect(byDim['P'] ?? 0, greaterThanOrEqualTo(10),
        reason: 'thiếu tình huống tích cực cho hai ô check-in "khá ổn"/"vui"');
  });

  test('nhãn tình huống viết ở ngôi thứ nhất (§9.2)', () {
    // §9.2: nội dung Situation là tiếng nói nội tâm của chính người dùng, nên
    // dùng "tôi". Ngoại lệ duy nhất của tài liệu là lời trích dẫn của người
    // khác — nhãn chip ngắn thì không có chỗ cho trích dẫn.
    final offending = <String>[];
    final files = _migrations
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'));
    for (final f in files) {
      final sql = f.readAsStringSync();
      for (final b in RegExp(
        r'insert\s+into\s+public\.wr_situations\b(.*?)(?:on conflict|;)',
        dotAll: true,
        caseSensitive: false,
      ).allMatches(sql)) {
        for (final m in RegExp(r"\(\s*'([A-Za-z0-9-]+)'\s*,\s*'([^']*)'")
            .allMatches(b.group(1)!)) {
          if (RegExp(r'\bbạn\b', caseSensitive: false).hasMatch(m.group(2)!)) {
            offending.add('${m.group(1)}: ${m.group(2)}');
          }
        }
      }
    }
    expect(offending, isEmpty,
        reason: 'nhãn chip phải ở ngôi "tôi", không phải "bạn" (§9.2)');
  });
}

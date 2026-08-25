// Không có dữ liệu demo nào chảy vào tài khoản thật.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §7, ghi chú cho dev: "Dữ liệu
// demo … hiện đang được seed sẵn để xem trước màn hình — cần loại bỏ seed này
// khi triển khai thật, để mỗi user bắt đầu từ trạng thái rỗng."
//
// Vì sao là test QUÉT MÃ NGUỒN chứ không phải test hành vi: chỗ gọi là một RPC
// tới Supabase thật, không có repository giả nào đứng chắn. Muốn bắt được việc
// dòng gọi đó quay lại thì chỉ còn cách đọc chính mã nguồn.
//
// Vì sao đáng canh: từ 24/08 màn Diễn giải sâu (§7) đối chiếu điểm Self-Check
// với tần suất Reflection, và Career Memory (§8) sinh Cột mốc · Chủ đề ·
// Insight từ lịch sử đó. Dữ liệu bịa không dừng ở một màn xem trước sai — nó
// chảy vào những kết luận app nói với người dùng về chính đời họ.
//
// Run: flutter test test/core/wr_no_demo_seed_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Những RPC/bảng chỉ tồn tại để dựng dữ liệu xem trước.
const _bannedSymbols = <String>[
  'seed_wr_sample_data',
];

void main() {
  test('không mã nào trong lib/ gọi hàm seed dữ liệu mẫu', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Bỏ qua dòng chú thích: file wr_repository.dart có một khối comment
        // giải thích VÌ SAO không gọi nữa, và khối đó phải được ở lại.
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        for (final banned in _bannedSymbols) {
          if (line.contains(banned)) {
            offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Dữ liệu demo lại chảy vào tài khoản thật:\n'
          '${offenders.join('\n')}',
    );
  });
}

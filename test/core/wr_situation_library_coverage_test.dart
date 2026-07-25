// Coverage test — assets/seed/wr_situations.json must match the
// Career Situation Library (Tầng 1): 10 SCA dimensions × 6 situations = 60.
//
// Spec source: /home/duythong/Desktop/FileTam/workreflection/Career Situation Library.docx
// Mapping fields (expected_outcome, sca_perspective) come from
// WorkReflection_DataSpec_v3.docx Tầng 3.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

void main() {
  late List<Map<String, dynamic>> raw;

  setUpAll(() {
    final file = File('assets/seed/wr_situations.json');
    raw = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
  });

  group('Career Situation Library coverage', () {
    test('holds exactly 60 situations', () {
      expect(raw.length, 60);
    });

    test('every SCA dimension has exactly 6 situations', () {
      final counts = <String, int>{};
      for (final s in raw) {
        counts.update(s['sca_dimension'] as String, (v) => v + 1,
            ifAbsent: () => 1);
      }
      expect(counts.length, 10);
      for (final dim in ScaDimension.values) {
        expect(
          counts[dim.dbValue],
          6,
          reason: '${dim.dbValue} must have 6 situations',
        );
      }
    });

    test('codes are unique and follow <DIM>-sit-<NN>', () {
      final codes = raw.map((s) => s['code'] as String).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate codes');
      final pattern = RegExp(r'^[SCA][1-4]-sit-\d{2}$');
      for (final c in codes) {
        expect(pattern.hasMatch(c), isTrue, reason: 'bad code: $c');
      }
    });

    test('no situation is missing narrative fields', () {
      for (final s in raw) {
        final code = s['code'];
        for (final field in const [
          'text',
          'human_need',
          'expected_outcome',
          'sca_perspective',
        ]) {
          final v = s[field];
          expect(v, isA<String>(), reason: '$code.$field must be a String');
          expect(
            (v as String).trim(),
            isNotEmpty,
            reason: '$code.$field must not be empty',
          );
        }
        expect(s['wave'], inInclusiveRange(1, 3), reason: '$code.wave');
      }
    });

    test('every record parses into WrSituation', () {
      for (final s in raw) {
        final sit = WrSituation.fromJson(s);
        expect(sit.code, s['code']);
        expect(sit.humanNeed, isNotNull);
      }
    });

    test('perspectives never leak internal SCA codes to the user', () {
      // DataSpec v3, ghi chú logic tích hợp #4: "Không dùng mã kỹ thuật như S1
      // hay C2 trực tiếp với người dùng."
      final leak = RegExp(r'\b[SCA][1-4]\b');
      for (final s in raw) {
        for (final field in const [
          'text',
          'expected_outcome',
          'sca_perspective',
        ]) {
          expect(
            leak.hasMatch(s[field] as String),
            isFalse,
            reason: '${s['code']}.$field leaks an internal code',
          );
        }
      }
    });

    test('all 60 Career Situation Library entries are present', () {
      // Tầng 1 của Career Situation Library, theo đúng thứ tự tài liệu.
      const library = <String, List<String>>{
        'S1': [
          'Không rõ mình được kỳ vọng điều gì',
          'Không rõ trách nhiệm thuộc về ai',
          'Vai trò chồng chéo với người khác',
          'Công việc thay đổi liên tục, không ổn định',
          'Không biết thế nào là làm tốt',
          'Không biết ưu tiên điều gì trước',
        ],
        'S2': [
          'Khó phối hợp với phòng ban khác',
          'Người khác làm chậm tiến độ của tôi',
          'Không biết tìm ai khi cần hỗ trợ',
          'Công việc phụ thuộc quá nhiều người',
          'Làm việc nhóm không hiệu quả',
          'Thường xuyên phải làm lại vì hiểu sai',
        ],
        'S3': [
          'Không biết tìm thông tin ở đâu',
          'Thông tin đến quá muộn',
          'Thông tin mâu thuẫn nhau',
          'Không được cập nhật khi có thay đổi',
          'Thiếu dữ liệu để ra quyết định',
          'Luôn cảm thấy mình bị động',
        ],
        'C1': [
          'Không tin đồng nghiệp sẽ hoàn thành việc',
          'Không được cấp trên tin tưởng',
          'Bị kiểm soát quá mức',
          'Khó giao việc cho người khác',
          'Thiếu sự hỗ trợ từ đội nhóm',
          'Cảm thấy phải tự làm mọi thứ',
        ],
        'C2': [
          'Không dám lên tiếng',
          'Không được lắng nghe',
          'Ý kiến bị bỏ qua',
          'Sợ phản hồi cấp trên',
          'Sợ mắc lỗi trước tập thể',
          'Tiếng nói của mình không có giá trị',
        ],
        'C3': [
          'Có mâu thuẫn nhưng không thể nói ra',
          'Tránh các cuộc trò chuyện khó',
          'Phản hồi dễ trở thành tranh cãi',
          'Không hiểu nhau dù đã trao đổi',
          'Không biết cách góp ý',
          'Bầu không khí căng thẳng kéo dài',
        ],
        'A1': [
          'Không hiểu mục tiêu chung của tổ chức',
          'Không biết công việc mình đóng góp điều gì',
          'Làm rất nhiều nhưng không thấy ý nghĩa',
          'Không chắc mình đang đi đúng hướng',
          'Mục tiêu thay đổi liên tục mà không giải thích',
          'Muốn chuyển việc vì không còn thấy phù hợp',
        ],
        'A2': [
          'Luôn bận nhưng không hiệu quả',
          'Công việc liên tục bị gián đoạn',
          'Không hoàn thành được việc quan trọng',
          'Quá tải công việc',
          'Luôn trong trạng thái chạy theo deadline',
          'Cảm thấy mất kiểm soát với công việc',
        ],
        'A3': [
          'Không biết mình đang tiến bộ hay thụt lùi',
          'Liên tục lặp lại cùng một vấn đề',
          'Không hiểu nguyên nhân của sự thất vọng',
          'Đưa ra quyết định theo cảm xúc',
          'Không có thời gian nhìn lại',
          'Cảm thấy bị mắc kẹt',
        ],
        'A4': [
          'Mắc lại cùng một sai lầm',
          'Học nhiều nhưng khó áp dụng',
          'Không biến trải nghiệm thành bài học',
          'Không biết bước tiếp theo để phát triển',
          'Muốn thăng tiến nhưng thiếu định hướng',
          'Muốn chuyển nghề nhưng chưa rõ con đường',
        ],
      };

      final present = <String, Set<String>>{};
      for (final s in raw) {
        present
            .putIfAbsent(s['sca_dimension'] as String, () => <String>{})
            .add(s['text'] as String);
      }

      library.forEach((dim, texts) {
        for (final t in texts) {
          expect(
            present[dim],
            contains(t),
            reason: 'missing situation $dim: "$t"',
          );
        }
      });
    });
  });
}

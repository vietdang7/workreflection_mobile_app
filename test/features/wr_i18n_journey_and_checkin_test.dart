// Hai lỗi khách gửi ảnh 11/09/2026, cả hai chỉ lộ khi bật TIẾNG ANH.
//
// 1. Ô check-in ở Home cắt mất chữ: "I am / feeling goo". `WrParagraph` nối hai
//    tiếng cuối bằng U+00A0 để dòng chót không rớt một tiếng cụt — hay ở đoạn
//    văn, nhưng ở nhãn ngắn trong ô thì "feeling good" thành một khối không
//    ngắt được, rộng hơn lòng ô, và bị cắt ngang giữa từ.
//
// 2. Màn Hành trình nửa Anh nửa Việt: nhãn loại (STORY / PRACTICE) dịch được vì
//    đi qua `tr()`, còn tên chủ đề và tên bước thì nằm trong
//    `wr_career_memory.reflection_text` — chuỗi ghép sẵn lúc bấm xong bước và
//    đóng băng từ đó.
//
// Cả hai đều KHÔNG bị bộ test cũ bắt: bài 1 vì `flutter_test_config.dart` tắt
// `wrParagraphKeepsTail`, bài 2 vì chưa ai dựng dòng thời gian ở tiếng Anh.
//
// Run: flutter test test/features/wr_i18n_journey_and_checkin_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';

/// Thân của một lớp trong mã nguồn, để soi xem nó dựng chữ bằng widget nào.
///
/// Quét mã nguồn nghe vụng, nhưng thứ cần khoá ở đây đúng là một lựa chọn TRONG
/// MÃ chứ không phải một hành vi quan sát được: `WrParagraph` và `Text` cho ra
/// pixel khác nhau chỉ khi chuỗi đủ dài để xuống dòng, mà chuỗi ấy lại phụ
/// thuộc bề ngang thật của thiết bị. Bộ test dựng ở 800×600 nên gần như không
/// bao giờ chạm tới. Khoá ngay ở chỗ chọn thì không lệ thuộc kích thước nào.
/// Trả về phần MÃ của thân lớp — chú thích bị bỏ đi.
///
/// Bỏ chú thích là bắt buộc, không phải cho gọn: chỗ sửa nào cũng kèm một dòng
/// giải thích vì sao KHÔNG dùng `WrParagraph`, và nếu để nguyên thì chính lời
/// giải thích ấy làm bài này đỏ.
String _classBody(String path, String className) {
  final src = File(path).readAsStringSync();
  final start = src.indexOf('class $className');
  expect(start, isNot(-1), reason: 'không tìm thấy $className trong $path');
  final next = src.indexOf('\nclass ', start + 1);
  final body = src.substring(start, next == -1 ? src.length : next);
  return body
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  tearDown(() {
    wrEnglish = false;
    wrParagraphKeepsTail = false;
  });

  group('nhãn ô check-in không bị nối cứng', () {
    test(
      'phép nối đuôi câu BIẾN "feeling good" thành khối không ngắt được',
      () {
        // Ghi lại đúng cơ chế gây lỗi, để ai đó đưa `WrParagraph` trở lại ô
        // check-in sẽ thấy ngay vì sao không được.
        final joined = wrKeepSentenceTailTogether('I am\nfeeling good');
        expect(joined.contains(nbsp), isTrue);
        expect(joined.contains('feeling good'), isFalse);
      },
    );

    test('nhãn sáu ô không chứa khoảng trắng cứng ở bản tiếng Anh', () {
      wrSetLocale('en');
      for (final o in kCheckinOptions) {
        expect(o.label.contains(nbsp), isFalse, reason: o.id);
      }
    });

    test('ô check-in dựng nhãn bằng Text, không phải WrParagraph', () {
      expect(
        _classBody(
          'lib/features/wr/presentation/wr_home_screen.dart',
          '_CheckinTile',
        ).contains('WrParagraph'),
        isFalse,
      );
    });
  });

  group('ô Career Snapshot không căn đều', () {
    // "Fine, room to grow" trong cột hẹp: căn đều giãn khoảng trắng ra tới mép
    // phải, thành "Fine,⎵⎵⎵⎵⎵room / to grow" (ảnh khách 11/09).
    test('_SnapshotCell dựng giá trị bằng Text, không phải WrParagraph', () {
      expect(
        _classBody(
          'lib/features/wr/presentation/wr_discover_screen.dart',
          '_SnapshotCell',
        ).contains('WrParagraph'),
        isFalse,
      );
    });

    test('WrParagraph vẫn mặc định căn đều — lý do không dùng nó ở ô hẹp', () {
      expect(const WrParagraph('x').textAlign, TextAlign.justify);
    });
  });

  group('đổi ngôn ngữ thì cache Riverpod cũng tính lại', () {
    // Widget luôn dựng lại khi đổi ngôn ngữ (`wr_locale_rebuild_test.dart` khoá
    // điều đó). Cache của Riverpod thì KHÔNG: một provider đã dựng sẵn câu chữ
    // bằng `tr()` sẽ chở nguyên tiếng cũ sang. Đó là thẻ "A VIEW ON GROWTH" vẫn
    // nói tiếng Việt trong ảnh khách 11/09.
    final baked = Provider<String>((ref) {
      wrWatchLocale(ref);
      return tr('tiếng Việt', 'English');
    });

    final bakedWithoutWatch = Provider<String>((ref) {
      return tr('tiếng Việt', 'English');
    });

    test('provider gọi wrWatchLocale thì đổi theo', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      wrSetLocale('vi');
      expect(c.read(baked), 'tiếng Việt');

      wrSetLocale('en');
      c.read(appLocaleProvider.notifier).state = 'en';
      expect(c.read(baked), 'English');
    });

    test(
      'provider KHÔNG gọi thì kẹt lại tiếng cũ — đúng hình dạng của lỗi',
      () {
        final c = ProviderContainer();
        addTearDown(c.dispose);

        wrSetLocale('vi');
        expect(c.read(bakedWithoutWatch), 'tiếng Việt');

        wrSetLocale('en');
        c.read(appLocaleProvider.notifier).state = 'en';
        expect(c.read(bakedWithoutWatch), 'tiếng Việt');
      },
    );
  });

  group('dòng thời gian đọc lại tên chủ đề / tên bước theo ngôn ngữ đang bật', () {
    const labels = {
      'Vững vàng khi mọi thứ thay đổi': 'Steady when things change',
      'Steady when things change': 'Steady when things change',
      'Thử nghiệm: Chủ động hỏi lý do thay đổi':
          'Try: ask why the change happened',
      'Nhận diện — Ghi lại một thay đổi gây hụt hẫng':
          'Notice — write down a change that let you down',
    };

    test('dạng "chủ đề · bước"', () {
      expect(
        localizeFrozenPracticeText(
          'Vững vàng khi mọi thứ thay đổi · Thử nghiệm: Chủ động hỏi lý do thay đổi',
          labels,
        ),
        'Steady when things change · Try: ask why the change happened',
      );
    });

    test('dạng "bước: lời người dùng" giữ nguyên lời người dùng', () {
      // Tên bước có sẵn dấu hai chấm, nên cắt ở dấu hai chấm ĐẦU TIÊN là sai.
      expect(
        localizeFrozenPracticeText(
          'Nhận diện — Ghi lại một thay đổi gây hụt hẫng: uadafas',
          labels,
        ),
        'Notice — write down a change that let you down: uadafas',
      );
      expect(
        localizeFrozenPracticeText(
          'Thử nghiệm: Chủ động hỏi lý do thay đổi: ghi chú của tôi',
          labels,
        ),
        'Try: ask why the change happened: ghi chú của tôi',
      );
    });

    test('chữ lạ giữ nguyên, không bịa ra bản dịch', () {
      expect(
        localizeFrozenPracticeText('Một chủ đề không có trong bảng', labels),
        'Một chủ đề không có trong bảng',
      );
      expect(localizeFrozenPracticeText('bất kỳ', const {}), 'bất kỳ');
    });

    test('buildJourneyEntries dịch mảnh ký ức thực hành', () {
      wrSetLocale('en');
      final entries = buildJourneyEntries(
        episodes: const [],
        events: [
          CareerMemoryEvent(
            id: '1',
            userId: 'u',
            behavior: 'practice_step_done',
            reflectionText:
                'Vững vàng khi mọi thứ thay đổi · Thử nghiệm: Chủ động hỏi lý do thay đổi',
            createdAt: DateTime(2026, 8, 5),
          ),
          CareerMemoryEvent(
            id: '2',
            userId: 'u',
            behavior: kPracticeStepNoteBehavior,
            reflectionText:
                'Nhận diện — Ghi lại một thay đổi gây hụt hẫng: uadafas',
            createdAt: DateTime(2026, 8, 5),
          ),
        ],
        situationLabels: const {},
        practiceLabels: labels,
      );

      expect(entries, hasLength(2));
      // Mockup v47: một bước thực hành xong là "Practice: ‹việc›", việc là
      // phần sau nhãn giai đoạn của tên bước ĐÃ DỊCH — nên vẫn kiểm được rằng
      // tên bước được tra lại theo ngôn ngữ đang bật.
      expect(entries.map((e) => e.title), [
        'Practice: ask why the change happened',
        'Notice — write down a change that let you down: uadafas',
      ]);
      expect(entries.first.subtitle, 'You tried: ask why the change happened.');
      expect(entries.map((e) => e.label), ['PRACTICE', 'WHAT I WROTE DOWN']);
    });

    test('không có bảng tra thì giữ nguyên văn, không rơi mất mảnh ký ức', () {
      final entries = buildJourneyEntries(
        episodes: const [],
        events: [
          CareerMemoryEvent(
            id: '1',
            userId: 'u',
            behavior: 'practice_theme_done',
            reflectionText: 'Vững vàng khi mọi thứ thay đổi',
            createdAt: DateTime(2026, 8, 5),
          ),
        ],
        situationLabels: const {},
      );
      expect(entries.single.title, 'Vững vàng khi mọi thứ thay đổi');
    });

    // Máy thật 16/10, bật tiếng Anh: "Upkeep: Nhịp làm việc ổn định" và
    // "Bạn xác nhận một tâm thế đang hình thành" vẫn tiếng Việt.
    test('mảnh duy trì "Duy trì: ‹chủ đề›" dịch cả tên chủ đề', () {
      const withUpkeep = {
        ...labels,
        'Nhịp làm việc ổn định': 'A steady working rhythm',
        'Duy trì': 'Upkeep',
      };
      expect(
        localizeFrozenPracticeText(
          'Duy trì: Nhịp làm việc ổn định',
          withUpkeep,
        ),
        'Upkeep: A steady working rhythm',
      );
      // Dạng cũ "‹chủ đề› · Duy trì" vẫn chạy.
      expect(
        localizeFrozenPracticeText(
          'Nhịp làm việc ổn định · Duy trì',
          withUpkeep,
        ),
        'A steady working rhythm · Upkeep',
      );
    });

    test('dạng cũ "chủ đề — giai đoạn" (trước 05/08)', () {
      const old = {
        'Dám lên tiếng': 'Speaking up',
        'Nhận diện': 'Notice',
      };
      expect(
        localizeFrozenPracticeText('Dám lên tiếng — Nhận diện', old),
        'Speaking up — Notice',
      );
      // Một vế không có trong bảng: giữ nguyên, không dịch nửa vời.
      expect(
        localizeFrozenPracticeText('Dám lên tiếng — Điều gì đó', old),
        'Dám lên tiếng — Điều gì đó',
      );
    });

    test('Cột mốc do app viết đọc lại theo ngôn ngữ đang bật', () {
      wrSetLocale('en');
      const names = {'Nhịp làm việc ổn định': 'A steady working rhythm'};
      expect(
        localizeFrozenMilestoneText(
          'Bạn xác nhận một tâm thế đang hình thành',
          names,
        ),
        'You confirmed a stance that is taking shape',
      );
      expect(
        localizeFrozenMilestoneText('Hết một vòng: Nhịp làm việc ổn định', names),
        'One full round: A steady working rhythm',
      );
      expect(
        localizeFrozenMilestoneText(
          'Chặng 2: bạn trả lời câu hỏi cuối chặng. Chuyện đó đã nhẹ đi thật.',
          names,
        ),
        'Chapter 2: you answered the end-of-chapter question. It really has eased.',
      );
      expect(
        localizeFrozenMilestoneText(
          'Đã hoàn thành 5 ngày thực hành: Gửi 1 lời cảm ơn cụ thể',
          names,
        ),
        'Completed 5-day practice: Gửi 1 lời cảm ơn cụ thể',
      );
      // Cột mốc người dùng tự viết: giữ nguyên văn.
      expect(
        localizeFrozenMilestoneText('Tôi đang học cách nói không', names),
        'Tôi đang học cách nói không',
      );
      // Ngược lại: ghi lúc tiếng Anh, đọc lúc tiếng Việt.
      wrSetLocale('vi');
      expect(
        localizeFrozenMilestoneText(
          'You confirmed a stance that is taking shape',
          names,
        ),
        'Bạn xác nhận một tâm thế đang hình thành',
      );
      wrSetLocale('en');
    });

    test('buildJourneyEntries dịch Cột mốc, kỹ năng và duy trì', () {
      wrSetLocale('en');
      const withUpkeep = {
        'Nhịp làm việc ổn định': 'A steady working rhythm',
        'Duy trì': 'Upkeep',
      };
      final entries = buildJourneyEntries(
        episodes: const [],
        events: [
          CareerMemoryEvent(
            id: '1',
            userId: 'u',
            behavior: 'career_milestone',
            reflectionText: 'Bạn xác nhận một tâm thế đang hình thành',
            createdAt: DateTime(2026, 10, 13, 3),
          ),
          CareerMemoryEvent(
            id: '2',
            userId: 'u',
            behavior: 'skill_certified',
            reflectionText: 'Nhịp làm việc ổn định',
            createdAt: DateTime(2026, 10, 13, 2),
          ),
          CareerMemoryEvent(
            id: '3',
            userId: 'u',
            behavior: kPracticeMaintainedBehavior,
            reflectionText: 'Duy trì: Nhịp làm việc ổn định',
            createdAt: DateTime(2026, 10, 13, 1),
          ),
        ],
        situationLabels: const {},
        practiceLabels: withUpkeep,
      );
      expect(entries.map((e) => e.title), [
        'You confirmed a stance that is taking shape',
        'A steady working rhythm',
        'Upkeep: A steady working rhythm',
      ]);
    });
  });
}

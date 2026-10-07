// Tab Hành trình: chữ thực hành đã đóng băng trong Career Memory phải theo
// ngôn ngữ đang bật, kể cả tên bước CŨ trước migration 4 bước (người dùng báo
// 06/10 thấy "Practice: Chủ động hỏi lý do thay đổi" khi bật tiếng Anh).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/wr/growth_providers.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';

CareerMemoryEvent _ev(String behavior, String text) => CareerMemoryEvent(
  id: behavior,
  userId: 'u1',
  behavior: behavior,
  reflectionText: text,
  createdAt: DateTime(2026, 10, 5),
);

void main() {
  tearDown(() => wrEnglish = false);

  ProviderContainer container() => ProviderContainer(
    overrides: [
      practiceThemesProvider.overrideWith(
        (ref) async => [
          PracticeTheme(
            themeId: 'pt-s3',
            title: 'Vững vàng khi mọi thứ thay đổi',
            titleEn: 'Steady when things change',
          ),
        ],
      ),
      allPracticeStepsProvider.overrideWith(
        (ref) async => [
          PracticeStep(
            stepId: 'pt-s3-1',
            themeId: 'pt-s3',
            stepOrder: 1,
            title: 'Nhận diện: Ghi lại một thay đổi gây hụt hẫng',
            titleEn: 'Notice: Record a change that caught you out',
            content: '',
            isPremium: false,
          ),
        ],
      ),
    ],
  );

  Future<Map<String, String>> labels(ProviderContainer c) async {
    await c.read(practiceThemesProvider.future);
    await c.read(allPracticeStepsProvider.future);
    return c.read(wrPracticeLabelMapProvider);
  }

  test('tên bước cũ (gạch dài và hai chấm) dịch sang tiếng Anh', () async {
    final c = container();
    addTearDown(c.dispose);
    wrEnglish = true;
    c.read(appLocaleProvider.notifier).state = 'en';
    final map = await labels(c);

    final entries = buildJourneyEntries(
      episodes: const [],
      situationLabels: const {},
      practiceLabels: map,
      events: [
        _ev(
          'practice_step_done',
          'Vững vàng khi mọi thứ thay đổi · Thử nghiệm: Chủ động hỏi lý do thay đổi',
        ),
        _ev(
          'practice_step_done',
          'Vững vàng khi mọi thứ thay đổi · Nhận diện — Ghi lại một thay đổi gây hụt hẫng',
        ),
        _ev(
          kPracticeMaintainedBehavior,
          'Vững vàng khi mọi thứ thay đổi · Duy trì',
        ),
      ],
    );
    final titles = [for (final e in entries) e.title];
    expect(titles, contains('Practice: Ask why the change happened'));
    expect(titles, contains('Practice: Record a change that caught you out'));
    expect(titles, contains('Steady when things change · Upkeep'));
    for (final t in titles) {
      expect(
        t,
        isNot(matches(RegExp('[ạảãầấậẩẫằắặẳẵềếệểễịỉĩọỏõồốộổỗờớợởỡụủũừứựửữđ]'))),
        reason: t,
      );
    }
  });

  test(
    'bật tiếng Việt: bản ghi tiếng Anh và gạch dài về đúng tên tiếng Việt',
    () async {
      final c = container();
      addTearDown(c.dispose);
      final map = await labels(c);
      final entries = buildJourneyEntries(
        episodes: const [],
        situationLabels: const {},
        practiceLabels: map,
        events: [
          _ev(
            'practice_step_done',
            'Steady when things change · Try: Ask why the change happened',
          ),
          _ev(
            kPracticeMaintainedBehavior,
            'Steady when things change · Upkeep',
          ),
        ],
      );
      final titles = [for (final e in entries) e.title];
      expect(titles, contains('Thực hành: Chủ động hỏi lý do thay đổi'));
      expect(titles, contains('Vững vàng khi mọi thứ thay đổi · Duy trì'));
    },
  );

  test('đổi ngôn ngữ thì bảng tra dựng lại theo ngôn ngữ mới', () async {
    final c = container();
    addTearDown(c.dispose);
    final vi = await labels(c);
    expect(vi['Steady when things change'], 'Vững vàng khi mọi thứ thay đổi');
    wrEnglish = true;
    c.read(appLocaleProvider.notifier).state = 'en';
    final en = c.read(wrPracticeLabelMapProvider);
    expect(en['Vững vàng khi mọi thứ thay đổi'], 'Steady when things change');
  });
}

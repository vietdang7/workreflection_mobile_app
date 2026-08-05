// Bối cảnh công việc chảy từ tài liệu đã đọc sang các tính năng khác.
//
// Run: flutter test test/features/wr_job_context_test.dart
//
// Vì sao đáng test riêng: đây là chỗ nối. `wr-doc-analyze` đọc JD xong thì nội
// dung phải đi tiếp tới đối chiếu kỹ năng và gợi ý chủ đề — nếu đứt ở đây thì
// mọi thứ vẫn "chạy", chỉ là tài liệu người dùng tải lên lại nằm im như trước,
// và không có test nào kêu.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/growth_providers.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

const _jdTheme = PracticeTheme(
  themeId: 'pt-voice',
  title: 'Dám lên tiếng',
  scaDimension: ScaDimension.c2,
);
const _otherTheme = PracticeTheme(
  themeId: 'pt-rhythm',
  title: 'Nhịp làm việc ổn định',
  scaDimension: ScaDimension.a2,
);

WrContextDocument _readyJd() => WrContextDocument(
      id: 'doc-1',
      userId: 'u1',
      docType: 'jd',
      filePath: 'u1/jd-1.pdf',
      uploadedAt: DateTime(2026, 8, 1),
      analysisStatus: DocAnalysisStatus.ready,
      analyzedAt: DateTime(2026, 8, 2),
      extractedText: 'Phối hợp với các phòng ban, chăm sóc khách hàng.',
      analysis: const WrDocAnalysis(
        title: 'Chuyên viên chăm sóc khách hàng',
        summary: 'Giao tiếp với khách hàng và phối hợp đội nhóm.',
        responsibilities: ['Giao tiếp với khách hàng'],
        skills: ['Đàm phán'],
        pillars: {'S': 1, 'C': 4, 'A': 1},
      ),
    );

ProviderContainer _container({
  required FakeWrIntelligenceRepository intel,
  FakeWrRepository? wr,
  FakeWrContentRepository? content,
}) {
  final c = ProviderContainer(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrRepositoryProvider.overrideWithValue(wr ?? FakeWrRepository()),
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('wrJobContextTextProvider', () {
    test('đọc nội dung tài liệu đã phân tích', () async {
      final intel = FakeWrIntelligenceRepository()
        ..seedContextDocuments([_readyJd()]);

      final text = await _container(intel: intel)
          .read(wrJobContextTextProvider.future);

      expect(text, isNotNull);
      expect(text, contains('Chuyên viên chăm sóc khách hàng'));
      expect(text, contains('Giao tiếp với khách hàng'));
      expect(text, contains('Phối hợp với các phòng ban'));
    });

    test('tài liệu CHƯA đọc xong thì không lấy gì từ nó', () async {
      // Trạng thái pending nghĩa là chưa ai đọc file. Lấy đại tên file hay loại
      // tài liệu ra dùng là dựng bối cảnh từ hư không.
      final intel = FakeWrIntelligenceRepository()
        ..seedContextDocuments([
          WrContextDocument(
            id: 'doc-1',
            userId: 'u1',
            docType: 'jd',
            filePath: 'u1/jd-1.pdf',
            uploadedAt: DateTime(2026, 8, 1),
          ),
        ]);

      final text = await _container(intel: intel)
          .read(wrJobContextTextProvider.future);

      expect(text, isNull);
    });

    test('không có tài liệu thì vẫn dùng mô tả vai trò tự viết', () async {
      final wr = FakeWrRepository()
        ..seedProfile(MobileProfile(
          userId: 'u1',
          reminderEnabled: false,
          language: 'vi',
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
          roleText: 'Tôi phụ trách chăm sóc khách hàng.',
        ));

      final text = await _container(
        intel: FakeWrIntelligenceRepository(),
        wr: wr,
      ).read(wrJobContextTextProvider.future);

      expect(text, 'Tôi phụ trách chăm sóc khách hàng.');
    });

    test('có cả hai thì gộp, tài liệu đứng trước', () async {
      final intel = FakeWrIntelligenceRepository()
        ..seedContextDocuments([_readyJd()]);
      final wr = FakeWrRepository()
        ..seedProfile(MobileProfile(
          userId: 'u1',
          reminderEnabled: false,
          language: 'vi',
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
          roleText: 'Mô tả tôi tự viết.',
        ));

      final text =
          await _container(intel: intel, wr: wr).read(wrJobContextTextProvider.future);

      expect(text, contains('Mô tả tôi tự viết.'));
      expect(
        text!.indexOf('Chuyên viên chăm sóc khách hàng'),
        lessThan(text.indexOf('Mô tả tôi tự viết.')),
      );
    });
  });

  group('đối chiếu kỹ năng đọc được JD đã phân tích', () {
    test('trụ của JD quyết định phần khớp và khoảng trống', () async {
      final intel = FakeWrIntelligenceRepository()
        ..seedContextDocuments([_readyJd()])
        ..seedPracticeThemes([_jdTheme, _otherTheme])
        ..seedEnrollments([
          const PracticeEnrollment(userId: 'u1', themeId: 'pt-voice'),
        ]);

      // Năm lần thực hành = chủ đề C2 đã thành kỹ năng.
      final content = FakeWrContentRepository()
        ..seedMemoryEvents([
          for (var i = 0; i < 5; i++)
            CareerMemoryEvent(
              id: 'e$i',
              userId: 'u1',
              behavior: 'practice_step_done',
              reflectionText: 'Dám lên tiếng · Bước $i',
            ),
        ]);

      final c = _container(intel: intel, content: content);
      // Nạp trước các nguồn đồng bộ mà provider đối chiếu đang đọc.
      await c.read(practiceThemesProvider.future);
      await c.read(practiceEnrollmentsProvider.future);
      await c.read(practiceMemoryEventsProvider.future);

      final match = await c.read(wrSkillJdMatchProvider.future);

      expect(match, isNotNull);
      expect(match!.matchedPillars.first, 'C');
      expect(match.matchedSkills.map((s) => s.themeId), ['pt-voice']);
      // Chủ đề trụ A không liên quan tới JD này nên không phải khoảng trống.
      expect(match.gapThemes.map((t) => t.themeId), isNot(contains('pt-rhythm')));
    });
  });
}

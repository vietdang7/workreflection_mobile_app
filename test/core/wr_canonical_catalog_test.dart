import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_canonical_catalog.dart';
import 'package:workreflection_mobile/core/logic/wr_situation_picker.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';

void main() {
  late WrCanonicalCatalog catalog;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    catalog = await loadWrCanonicalCatalog();
  });

  test('loads the 72 real situations, custom option, and 72 stories', () {
    expect(catalog.realSituations, hasLength(72));
    expect(catalog.situations, hasLength(73));
    expect(catalog.stories, hasLength(72));
    expect(catalog.situationFor('other')!.isCustom, isTrue);
  });

  test('canonical situation wins over stale remote text and axes', () {
    final canonical = catalog.situationFor('A1-01')!;
    final stale = WrSituation(
      code: 'A1-01',
      text: 'STALE REMOTE TEXT',
      scaDimension: ScaDimension.a1,
      pillarCode: 'A',
      subgroup: 'A1',
      mood: 'foggy',
      valence: WrValence.thachThuc,
      wave: 1,
    );
    final legacy = const WrSituation(
      code: 'legacy-old',
      text: 'Old history label',
      scaDimension: ScaDimension.c2,
      wave: 1,
    );

    final merged = catalog.mergeSituations([stale, legacy]);
    expect(merged.where((s) => s.code == 'A1-01'), hasLength(1));
    expect(
      merged.firstWhere((s) => s.code == 'A1-01').textVi,
      canonical.textVi,
    );
    expect(
      merged.firstWhere((s) => s.code == 'legacy-old').textVi,
      'Old history label',
    );
  });

  test('canonical story wins over stale remote editorial content', () {
    final canonical = catalog.storyFor('A1-01')!;
    final stale = WrStory(
      storyId: 'A1-01',
      title: 'STALE TITLE',
      scaDimension: ScaDimension.a1,
      storyContent: 'STALE STORY',
      emotionTags: const [],
      behaviorTags: const [],
      careerStages: const [],
    );
    final merged = catalog.mergeStories([stale]);
    expect(merged.where((s) => s.storyId == 'A1-01'), hasLength(1));
    expect(
      merged.firstWhere((s) => s.storyId == 'A1-01').titleVi,
      canonical.titleVi,
    );
    expect(catalog.storyFor('unknown-history-code'), isNull);
  });

  test(
    'valid-looking unknown remote row stays history-only and picker-ineligible',
    () {
      final remoteV2 = const WrSituation(
        code: 'remote-v2-unknown',
        text: 'Old history label',
        scaDimension: ScaDimension.a1,
        pillarCode: 'A',
        subgroup: 'A1',
        mood: 'foggy',
        valence: WrValence.thachThuc,
        wave: 1,
      );

      final merged = catalog.mergeSituations([remoteV2]);
      final historyOnly = merged.firstWhere(
        (s) => s.code == 'remote-v2-unknown',
      );

      expect(catalog.situationFor('remote-v2-unknown'), isNull);
      expect(historyOnly.textVi, 'Old history label');
      expect(historyOnly.isRetired, isTrue);
      expect(historyOnly.pillarCode, isNull);
      expect(historyOnly.subgroup, isNull);
      expect(historyOnly.mood, isNull);
      expect(historyOnly.explicitValence, isNull);
      expect(historyOnly.hasV2Classification, isFalse);
      expect(
        pickSituationChoices(all: [historyOnly], mood: Mood.foggy, count: 1),
        isEmpty,
      );
    },
  );

  test('không nhãn phân loại nào lọt vào chữ đem hiện cho người dùng', () {
    // C1-10 trong file biên tập gốc có tiêu đề kết thúc bằng "valence: tích
    // cực". Đó là siêu dữ liệu, không phải câu để đọc, mà `title`/`text` lại
    // hiện nguyên văn trên chip bước Nhận biết, thẻ Home và trong đoạn Diễn
    // giải sâu. Bộ sinh `scripts/import_situations_v2.js` cắt phần đuôi này;
    // test khoá kết quả để một lần sinh lại từ nguồn chưa sửa không đưa nó trở
    // lại.
    final axisLabel = RegExp(
      r'(valence|pillar|subgroup|mood)\s*:',
      caseSensitive: false,
    );

    for (final situation in catalog.situations) {
      expect(
        axisLabel.hasMatch(situation.textVi),
        isFalse,
        reason: 'tình huống ${situation.code} còn nhãn phân loại trong tiêu đề',
      );
    }

    for (final story in catalog.stories) {
      for (final field in [
        story.titleVi,
        story.storyContentVi,
        story.reflectionQuestion,
        story.selfReflection,
        story.ahaMessage,
        story.practiceAction,
      ]) {
        if (field == null) continue;
        expect(
          axisLabel.hasMatch(field),
          isFalse,
          reason: 'story ${story.storyId} còn nhãn phân loại trong nội dung',
        );
      }
    }

    expect(
      catalog.situationFor('C1-10')!.textVi,
      'Tôi cảm thấy an tâm khi làm việc cùng họ',
    );
  });

  test('cả 72 tình huống và 72 story đều có bản tiếng Anh thật', () {
    // `trDb(vi, en)` rơi về tiếng Việt khi cột tiếng Anh rỗng, im lặng và
    // không báo lỗi. Bản v2 sinh từ SITUATIONS_v2.js vốn chỉ có tiếng Việt, nên
    // nếu không có `scripts/situations_v2_en.json` thì toàn bộ thư viện đọc ra
    // tiếng Việt trong chế độ tiếng Anh mà mọi test vẫn xanh. Test này là chỗ
    // duy nhất phát hiện được điều đó.
    for (final situation in catalog.realSituations) {
      final en = situation.textEn;
      expect(
        en != null && en.trim().isNotEmpty,
        isTrue,
        reason: 'tình huống ${situation.code} thiếu text_en',
      );
      expect(
        en,
        isNot(situation.textVi),
        reason:
            'tình huống ${situation.code} chép nguyên tiếng Việt sang cột EN',
      );
    }

    for (final story in catalog.stories) {
      final fields = <String, String?>{
        'title_en': story.titleEn,
        'story_content_en': story.storyContentEn,
        'reflection_question_en': story.reflectionQuestionEn,
        'self_reflection_en': story.selfReflectionEn,
        'aha_message_en': story.ahaMessageEn,
        'practice_action_en': story.practiceActionEn,
      };
      fields.forEach((name, value) {
        expect(
          value != null && value.trim().isNotEmpty,
          isTrue,
          reason: 'story ${story.storyId} thiếu $name',
        );
      });
    }
  });

  test('bật tiếng Anh thì thư viện đọc ra tiếng Anh', () {
    wrEnglish = true;
    addTearDown(() => wrEnglish = false);

    final situation = catalog.situationFor('S1-01')!;
    expect(situation.text, 'I was given new work without a clear scope');

    final story = catalog.storyFor('S1-01')!;
    expect(story.title, situation.text);
    expect(story.ahaMessage, story.ahaMessageEn);
    expect(story.practiceAction, story.practiceActionEn);
    // Lựa chọn tự mô tả không thuộc thư viện biên tập nên không có bản dịch DB;
    // chữ của nó đến từ tầng tr() chứ không phải cột _en, và đó là đúng.
    expect(catalog.situationFor('other')!.isCustom, isTrue);
  });
}

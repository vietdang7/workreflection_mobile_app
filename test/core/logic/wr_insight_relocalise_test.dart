// Câu Insight v47 đã lưu bằng một ngôn ngữ phải hiện theo ngôn ngữ đang bật
// (người dùng báo 06/10: bật tiếng Việt vẫn thấy Insight tiếng Anh và ngược
// lại). Chữ người dùng tự viết thì giữ nguyên.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_v47.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

const _situations = [
  WrSituation(
    code: 'X1-01',
    text: 'Tôi bị giao việc không rõ',
    textEn: 'I was given unclear work',
    scaDimension: ScaDimension.s1,
    wave: 1,
  ),
];

const _stories = [
  WrStory(
    storyId: 'X1-01',
    title: 't',
    scaDimension: ScaDimension.s1,
    humanNeed: HumanNeed.ketNoi,
    storyContent: 'c',
    emotionTags: [],
    behaviorTags: [],
    careerStages: [],
    ahaMessage: 'Có thể bạn đang phải tự đoán kỳ vọng.',
    ahaMessageEn: 'Maybe you are having to guess the expectation.',
  ),
];

ReflectionEpisode _episode(String saved) => ReflectionEpisode(
  id: 'e1',
  userId: 'u1',
  humanMoment: HumanMoment.confusion,
  state: ExperienceState.integrated,
  situationCode: 'X1-01',
  notes: const {'explore': 'Sếp giao việc mà không nói cần gì'},
  draftMeaning: saved,
);

String _buildIn(bool english) {
  final was = wrEnglish;
  wrEnglish = english;
  try {
    return reflectionAhaFor(
      code: 'X1-01',
      title: _situations.first.text,
      detail: 'Sếp giao việc mà không nói cần gì',
      situationAha: _stories.first.ahaMessage,
    );
  } finally {
    wrEnglish = was;
  }
}

void main() {
  tearDown(() => wrEnglish = false);

  test('lưu tiếng Anh, đang bật tiếng Việt → câu tiếng Việt', () {
    final savedEn = _buildIn(true);
    final savedVi = _buildIn(false);
    expect(savedEn, contains('What may be worth a closer look'));
    final out = relocaliseEpisodeInsight(
      savedEn,
      episode: _episode(savedEn),
      situations: _situations,
      stories: _stories,
    );
    expect(out, savedVi);
  });

  test('lưu tiếng Việt, đang bật tiếng Anh → câu tiếng Anh', () {
    final savedVi = _buildIn(false);
    wrEnglish = true;
    final out = relocaliseEpisodeInsight(
      savedVi,
      episode: _episode(savedVi),
      situations: _situations,
      stories: _stories,
    );
    expect(out, _buildIn(true));
    expect(wrEnglish, isTrue, reason: 'không được để lật cờ ngôn ngữ');
  });

  test('chữ người dùng tự viết thì giữ nguyên', () {
    const mine = 'Tôi nhận ra mình ngại hỏi lại.';
    expect(
      rebuildEpisodeInsight(
        mine,
        episode: _episode(mine),
        situations: _situations,
        stories: _stories,
      ),
      isNull,
    );
    wrEnglish = true;
    expect(
      relocaliseEpisodeInsight(
        mine,
        episode: _episode(mine),
        situations: _situations,
        stories: _stories,
      ),
      mine,
    );
  });

  test('nhánh "Điều khác" (không mã tình huống) cũng dựng lại được', () {
    final savedVi = reflectionAhaFor();
    wrEnglish = true;
    final out = relocaliseEpisodeInsight(
      savedVi,
      episode: ReflectionEpisode(
        id: 'e2',
        userId: 'u1',
        humanMoment: HumanMoment.confusion,
        state: ExperienceState.integrated,
        draftMeaning: savedVi,
      ),
      situations: _situations,
      stories: _stories,
    );
    expect(out, reflectionAhaFor());
    expect(out, startsWith('You stopped'));
  });

  test('Insight ở Home tìm đúng lượt nhìn lại theo nguyên văn', () {
    final savedEn = _buildIn(true);
    final out = relocaliseInsightByEpisodes(
      savedEn,
      episodes: [_episode(savedEn)],
      situations: _situations,
      stories: _stories,
    );
    expect(out, _buildIn(false));
    expect(
      relocaliseInsightByEpisodes(
        'khác',
        episodes: [_episode(savedEn)],
        situations: _situations,
        stories: _stories,
      ),
      'khác',
    );
  });
}

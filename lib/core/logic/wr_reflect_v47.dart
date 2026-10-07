// Luồng nhìn lại 4 bước — mockup v47 (06/10/2026), `screenReflectFlow`.
//
//   1/4 Chọn chuyện          chọn MỘT tình huống rồi bấm Tiếp tục
//   2/4 Một khoảnh khắc      kể lại (bắt buộc) → "Tôi đã kể xong"
//   3/4 Nhìn lại cùng nhau   Insight hiện NGAY (`reflectionAhaFor`)
//                            · "Ừ, tôi cũng thấy vậy" → lưu Insight đó
//                            · "Chưa đúng, để tôi nói lại" → lưu câu người dùng
//   4/4 Mang theo            chọn một phép thử nhỏ (`reflectionNextOptions`)
//                            hoặc tự viết → Lưu
//
// Bản trước có năm bước và một lớp ô trống "Với tôi, điều này…" trước khi hiện
// aha (changelog 24/08). v47 bỏ lớp đó: khách 06/10 muốn "Tôi đã kể xong" là
// thấy Insight ngay.
//
// Insight ở đây theo LUẬT như mockup (aha của tình huống + biến thể theo từ
// khoá trong câu kể). Mockup ghi "sau này có thể thay bằng Insight/LLM layer";
// hàm này là chỗ thay.

import '../l10n/wr_tr.dart';
import '../models/checkin.dart';
import '../models/wr_content.dart';
import '../models/wr_episode.dart';
import 'wr_situation_picker.dart' show resolveStoryFor;

/// Số bước của luồng v47.
const int kReflectV47Steps = 4;

/// Nhãn bước: "Bước 2/4 · Một khoảnh khắc cụ thể".
String reflectStepEyebrow(int step) {
  final name = switch (step) {
    0 => tr('Chọn chuyện', 'Pick a story'),
    1 => tr('Một khoảnh khắc cụ thể', 'One specific moment'),
    2 => tr('Nhìn lại cùng nhau', 'Looking back together'),
    _ => tr('Mang theo', 'Take it with you'),
  };
  return tr(
    'Bước ${step + 1}/$kReflectV47Steps · $name',
    'Step ${step + 1}/$kReflectV47Steps · $name',
  );
}

/// Mã bảng màu (`RF_PAL`) của một cảm xúc check-in, trùng `id` của lưới Home.
String moodBandId(Mood? mood) => switch (mood) {
  Mood.stressed => 'stress',
  Mood.tired => 'tired',
  Mood.foggy => 'foggy',
  Mood.outofsync => 'outofsync',
  Mood.okay => 'ok',
  Mood.happy => 'happy',
  null => 'happy',
};

// ---------------------------------------------------------------------------
// Bước 1 · Chọn chuyện
// ---------------------------------------------------------------------------

String get kPickStoryTitle => tr(
  'Điều gì giống ngày hôm nay của bạn nhất?',
  'What is most like your day today?',
);

String get kPickStorySubtitle =>
    tr('Chọn điều gần đúng nhất với bạn', 'Pick the one closest to you');

// ---------------------------------------------------------------------------
// Bước 2 · Một khoảnh khắc cụ thể
// ---------------------------------------------------------------------------

String get kMomentTitle => tr(
  'Điều gì xuất hiện trong khoảnh khắc đó làm bạn suy nghĩ?',
  'What came up in that moment that made you think?',
);

String get kMomentSubtitle => tr(
  'Kể lại khoảnh khắc mà bạn vẫn còn nhớ rõ',
  'Describe the moment you still remember clearly',
);

String get kMomentHint => tr(
  'Ví dụ: Trong cuộc họp sáng nay, lúc tôi vừa nói đến..., thì...',
  'For example: In this morning’s meeting, just as I started on..., ...',
);

String get kMomentDone => tr('Tôi đã kể xong', 'I am done telling it');

// ---------------------------------------------------------------------------
// Bước 3 · Nhìn lại cùng nhau
// ---------------------------------------------------------------------------

String get kInsightTitle => tr(
  'Có một điều hiện lên trong câu chuyện của bạn',
  'Something shows up in your story',
);

String get kInsightNote => tr(
  'Bạn không cần đồng ý. Hãy xem điều này có đúng với bạn không.',
  'You do not have to agree. See whether this is true for you.',
);

String get kInsightAgree => tr('Ừ, tôi cũng thấy vậy', 'Yes, I see it too');

String get kInsightRetell =>
    tr('Chưa đúng, để tôi nói lại', 'Not quite, let me say it');

String get kCorrectionEyebrow => tr('Một góc nhìn khác', 'Another angle');

String get kCorrectionTitle =>
    tr('Vậy điều gì gần với bạn hơn?', 'Then what is closer to you?');

String get kCorrectionNote => tr(
  'Bạn không cần đồng ý. Phần bạn sửa lại mới là điều đáng giữ.',
  'You do not have to agree. What you rewrite is what is worth keeping.',
);

String get kCorrectionHint =>
    tr('Thật ra, điều chạm vào tôi là...', 'Actually, what touched me was...');

String get kCorrectionKeep =>
    tr('Giữ lại cách hiểu của tôi', 'Keep my understanding');

bool _has(String text, String pattern) => RegExp(pattern).hasMatch(text);

/// Câu Insight hiện ở bước 3 (`reflectionAhaFor` của mockup v47).
///
/// [code] là mã tình huống (`C2-04`…), [title] là câu tình huống người dùng
/// chọn, [detail] là câu họ vừa kể, [situationAha] là câu aha của tình huống
/// trong thư viện. Không bao giờ trả chuỗi rỗng.
String reflectionAhaFor({
  String? code,
  String? title,
  String? detail,
  String? situationAha,
}) {
  final t = (detail ?? '').toLowerCase();

  switch (code) {
    case 'C2-03':
      return _has(t, 'không muốn|sợ|ngại|phản đối|khác biệt|duy nhất')
          ? tr(
              'Có thể điều khiến bạn gật đầu không chỉ là bạn đồng ý. Bạn đang '
                  'cân nhắc sự an toàn của việc khác biệt trước khi cân nhắc '
                  'chất lượng của ý kiến.',
              'Maybe what made you nod was not only agreement. You are weighing '
                  'how safe it is to differ before weighing how good the idea '
                  'is.',
            )
          : tr(
              'Có thể điều khiến bạn gật đầu không chỉ là bạn đồng ý. Bạn đang '
                  'ưu tiên giữ sự đồng thuận trước khi biết mình có thực sự '
                  'đồng ý hay không.',
              'Maybe what made you nod was not only agreement. You are putting '
                  'consensus first, before knowing whether you really agree.',
            );
    case 'C2-04':
      return _has(t, 'im|dừng|không nói|chuyển sang|không quay lại')
          ? tr(
              'Có thể điều làm bạn dừng lại không chỉ là bị ngắt lời. Sau '
                  'khoảnh khắc đó, bạn đã tự kết luận rằng nói tiếp cũng không '
                  'còn ý nghĩa.',
              'Maybe what stopped you was not only being interrupted. After '
                  'that moment, you concluded that going on was no longer '
                  'worth it.',
            )
          : tr(
              'Có thể điều làm bạn dừng lại không chỉ là bị ngắt lời. Điểm đáng '
                  'chú ý là điều xảy ra với cách bạn tham gia sau khoảnh khắc '
                  'bị ngắt lời.',
              'Maybe what stopped you was not only being interrupted. What is '
                  'worth noticing is what happened to how you took part after '
                  'that moment.',
            );
    case 'C2-05':
      return _has(t, 'sợ|ngại|mất lòng|hiểu sai|quan hệ')
          ? tr(
              'Có thể việc bạn giữ lại góp ý không phải vì bạn không muốn giúp. '
                  'Bạn đang bảo vệ mối quan hệ trước khi thử tìm một cách góp '
                  'ý đủ an toàn.',
              'Maybe you held back your feedback not because you did not want '
                  'to help. You are protecting the relationship before looking '
                  'for a safe enough way to say it.',
            )
          : tr(
              'Có thể việc bạn giữ lại góp ý không phải vì bạn không muốn giúp. '
                  'Bạn đang cân bằng giữa mong muốn nói điều hữu ích và mong '
                  'muốn giữ sự dễ chịu trong mối quan hệ.',
              'Maybe you held back your feedback not because you did not want '
                  'to help. You are balancing saying something useful with '
                  'keeping the relationship comfortable.',
            );
    case 'S1-04':
      return _has(t, 'chờ|không biết|ai|sếp|quyết')
          ? tr(
              'Có thể điều làm bạn chậm lại không phải vì bạn thiếu quyết đoán. '
                  'Bạn đang thiếu một ranh giới đủ rõ để biết mình nên tự quyết '
                  'hay chờ người khác chốt.',
              'Maybe what slowed you down was not a lack of decisiveness. You '
                  'are missing a clear enough line to know whether to decide '
                  'yourself or wait for someone else.',
            )
          : tr(
              'Có thể điều làm bạn chậm lại không phải vì bạn thiếu quyết đoán. '
                  'Bạn đang phải tự đoán quyền quyết định của mình trước khi '
                  'hành động.',
              'Maybe what slowed you down was not a lack of decisiveness. You '
                  'are having to guess how much you may decide before you act.',
            );
    case 'S2-04':
      return _has(t, 'muộn|bất ngờ|xảy ra|chuẩn bị|góp ý')
          ? tr(
              'Có thể điều khó chịu nhất không chỉ là biết muộn. Bạn mất cơ hội '
                  'tham gia vào quá trình trước khi kết quả đã được quyết định.',
              'Maybe the hardest part was not only finding out late. You lost '
                  'the chance to take part before the outcome was decided.',
            )
          : tr(
              'Có thể điều khó chịu nhất không chỉ là biết muộn. Việc biết sau '
                  'cùng có thể khiến bạn cảm thấy mình đứng ngoài một quyết định '
                  'có liên quan đến mình.',
              'Maybe the hardest part was not only finding out late. Being the '
                  'last to know can make you feel left out of a decision that '
                  'concerns you.',
            );
    case 'A3-03':
      return _has(t, 'nhớ|lần trước|từng|quen|giống')
          ? tr(
              'Có thể điều đang được chạm tới không chỉ là email, lời góp ý hay '
                  'cuộc họp hôm nay. Một trải nghiệm cũ có thể đang làm ý nghĩa '
                  'của chuyện hiện tại lớn hơn chính sự việc.',
              'Maybe what is being touched is not only today’s email, feedback '
                  'or meeting. An old experience may be making this one feel '
                  'bigger than it is.',
            )
          : tr(
              'Có thể điều đang được chạm tới không chỉ là email, lời góp ý hay '
                  'cuộc họp hôm nay. Điều quan trọng có thể nằm ở ý nghĩa bạn '
                  'gắn cho sự việc, không chỉ ở sự việc.',
              'Maybe what is being touched is not only today’s email, feedback '
                  'or meeting. What matters may be the meaning you give it, not '
                  'only the event.',
            );
  }

  final aha = situationAha?.trim();
  final name = title?.trim().replaceFirst(RegExp(r'^Tôi\s+'), '');
  if (name == null || name.isEmpty || aha == null || aha.isEmpty) {
    // Nhánh "Điều khác": không có tình huống trong thư viện để dựa vào.
    return tr(
      'Bạn đã dừng lại để gọi tên một khoảnh khắc cụ thể. Có thể điều đáng '
          'nhìn thêm là vì sao chính khoảnh khắc này, chứ không phải một '
          'khoảnh khắc khác, còn ở lại với bạn.',
      'You stopped to name one specific moment. What may be worth a closer '
          'look is why this moment, and not another, stayed with you.',
    );
  }
  return tr(
    'Điều bạn vừa kể có thể không chỉ là “$name”.\n\n'
        'Có thể phần đáng nhìn thêm là: $aha',
    'What you just described may be about more than “$name”.\n\n'
        'What may be worth a closer look: $aha',
  );
}

/// Ý chính của một câu Insight đã giữ, để nhắc lại ở chỗ khác (Home, thẻ
/// "Điều bạn từng viết" ở Phát triển).
///
/// Câu mẫu của [reflectionAhaFor] có hai đoạn: "Điều bạn vừa kể có thể không
/// chỉ là “…”." rồi "Có thể phần đáng nhìn thêm là: ‹aha›". Chép nguyên hai đoạn
/// vào giữa một câu khác thì đọc lủng củng; phần đáng nhắc là ‹aha›. Câu người
/// dùng tự viết thì giữ nguyên, chỉ gộp xuống dòng thành dấu cách.
String insightGist(String text) {
  final t = text.trim();
  for (final marker in const [
    'Có thể phần đáng nhìn thêm là: ',
    'What may be worth a closer look: ',
  ]) {
    final i = t.indexOf(marker);
    if (i < 0) continue;
    final rest = t.substring(i + marker.length).trim();
    if (rest.isNotEmpty) return rest;
  }
  return t.replaceAll(RegExp(r'\s*\n+\s*'), ' ');
}

/// Câu Insight [saved] của lượt [episode], theo ngôn ngữ ĐANG bật.
///
/// Bấm "Ừ, tôi cũng thấy vậy" là lưu nguyên câu [reflectionAhaFor] dựng ra,
/// bằng ngôn ngữ lúc bấm, vào `draft_meaning` và `wr_reflection_insights`. Đổi
/// ngôn ngữ sau đó thì Home, Phát triển, Hành trình hiện một câu tiếng Anh giữa
/// giao diện tiếng Việt (và ngược lại).
///
/// Câu đó hoàn toàn do app dựng từ tình huống + câu kể, nên dựng lại được: tính
/// [reflectionAhaFor] cho cả hai ngôn ngữ từ đúng dữ liệu của lượt đó; [saved]
/// khớp NGUYÊN VĂN một trong hai thì trả bản đang bật. Không khớp (người dùng
/// bấm "Chưa đúng, để tôi nói lại" và tự viết) thì giữ nguyên chữ của họ.
String relocaliseEpisodeInsight(
  String saved, {
  required ReflectionEpisode episode,
  required List<WrSituation> situations,
  required List<WrStory> stories,
}) =>
    rebuildEpisodeInsight(
      saved,
      episode: episode,
      situations: situations,
      stories: stories,
    ) ??
    saved;

/// Như [relocaliseEpisodeInsight] nhưng trả null khi [saved] không phải câu
/// app dựng (tức là chữ người dùng tự viết).
String? rebuildEpisodeInsight(
  String saved, {
  required ReflectionEpisode episode,
  required List<WrSituation> situations,
  required List<WrStory> stories,
}) {
  final s = saved.trim();
  if (s.isEmpty) return null;
  final code = episode.situationCode;
  WrSituation? situation;
  if (code != null) {
    for (final x in situations) {
      if (x.code == code) situation = x;
    }
  }
  final story = situation == null ? null : resolveStoryFor(situation, stories);

  // Getter `text` / `ahaMessage` đọc `wrEnglish` lúc gọi, nên dựng trong hàm.
  String build() => reflectionAhaFor(
    code: code,
    title: situation?.text ?? episode.notes[ReflectionPattern.notice.dbValue],
    detail: episode.notes[ReflectionPattern.explore.dbValue],
    situationAha: story?.ahaMessage,
  );

  final current = build();
  if (s == current.trim()) return current;
  final was = wrEnglish;
  wrEnglish = !was;
  final String other;
  try {
    other = build();
  } finally {
    wrEnglish = was;
  }
  return s == other.trim() ? current : null;
}

/// Như [relocaliseEpisodeInsight] cho một câu Insight không mang theo lượt
/// nhìn lại của nó (`wr_reflection_insights` không có `episode_id`): tìm lượt
/// có `draft_meaning` trùng nguyên văn. Không tìm thấy thì giữ nguyên.
String relocaliseInsightByEpisodes(
  String saved, {
  required List<ReflectionEpisode> episodes,
  required List<WrSituation> situations,
  required List<WrStory> stories,
}) {
  final s = saved.trim();
  for (final e in episodes) {
    if (e.draftMeaning?.trim() != s) continue;
    return relocaliseEpisodeInsight(
      saved,
      episode: e,
      situations: situations,
      stories: stories,
    );
  }
  return saved;
}

// ---------------------------------------------------------------------------
// Bước 4 · Mang theo
// ---------------------------------------------------------------------------

String get kTakeAwayTitle => tr(
  'Nếu chỉ chọn một phép thử nhỏ cho lần sau, bạn sẽ chọn gì?',
  'If you picked just one small experiment for next time, what would it be?',
);

String get kTakeAwaySubtitle => tr(
  'Chọn điều bạn muốn thử. Không cần biến nó thành một mục tiêu lớn.',
  'Pick what you want to try. It does not need to become a big goal.',
);

String get kTakeAwaySeen => tr('Điều bạn vừa nhìn thấy', 'What you just saw');

String get kTakeAwayWriteOwn => tr('Tự viết', 'Write my own');

String get kTakeAwayHint =>
    tr('Lần tới, tôi sẽ thử…', 'Next time, I will try…');

String get kTakeAwaySave => tr('Lưu', 'Save');

/// Một phép thử nhỏ (`rf-mentor-card`).
typedef ReflectNextOption = ({String id, String title, String desc});

/// Ba phép thử cho bước 4 (`reflectionNextOptions` của mockup v47).
///
/// [practice] là bước thực hành của tình huống trong thư viện, dùng làm mô tả
/// cho lựa chọn "Thử một bước nhỏ".
List<ReflectNextOption> reflectionNextOptions({
  String? code,
  String? practice,
}) {
  final observe = (
    id: 'observe',
    title: tr('Quan sát thêm một lần', 'Observe one more time'),
    desc: tr(
      'Xem đây là một lần đơn lẻ hay đang trở thành một kiểu lặp lại.',
      'See whether this is a one-off or turning into a pattern.',
    ),
  );
  final p = practice?.trim();
  final common = <ReflectNextOption>[
    observe,
    (
      id: 'small',
      title: tr('Thử một bước nhỏ', 'Try one small step'),
      desc: (p != null && p.isNotEmpty)
          ? p
          : tr(
              'Thử một cách nhỏ khác trong tình huống tương tự lần tới.',
              'Try a small, different approach the next time this happens.',
            ),
    ),
    (
      id: 'voice',
      title: tr('Nói ra điều mình cần', 'Say what you need'),
      desc: tr(
        'Khi điều này quay lại, thử diễn đạt rõ phần bạn muốn người khác hiểu.',
        'When this comes back, try putting into words what you want others '
            'to understand.',
      ),
    ),
  ];
  return switch (code) {
    'C2-04' => [
      (
        id: 'return',
        title: tr('Nói tiếp một câu', 'Say one more sentence'),
        desc: tr(
          'Khi bị ngắt lời, quay lại ý của mình bằng một câu ngắn.',
          'When interrupted, return to your point with one short sentence.',
        ),
      ),
      (
        id: 'ask',
        title: tr('Đặt một câu hỏi', 'Ask a question'),
        desc: tr(
          'Dùng một câu hỏi để đưa cuộc trao đổi trở lại điều bạn muốn nói.',
          'Use a question to bring the conversation back to your point.',
        ),
      ),
      observe,
    ],
    'C2-03' => [
      (
        id: 'question',
        title: tr('Hỏi trước khi đồng ý', 'Ask before agreeing'),
        desc: tr(
          'Đặt một câu hỏi làm rõ thay vì gật đầu ngay.',
          'Ask a clarifying question instead of nodding right away.',
        ),
      ),
      (
        id: 'voice',
        title: tr('Nói một góc nhìn', 'Share one view'),
        desc: tr(
          'Thử nói phần mình còn băn khoăn bằng một câu ngắn.',
          'Try saying what still bothers you in one short sentence.',
        ),
      ),
      observe,
    ],
    'C2-05' => [
      (
        id: 'specific',
        title: tr(
          'Góp ý một điều cụ thể',
          'Give one specific piece of feedback',
        ),
        desc: tr(
          'Nói về một hành vi và tác động của nó, thay vì đánh giá con người.',
          'Talk about one behaviour and its effect, not about the person.',
        ),
      ),
      (
        id: 'ask',
        title: tr('Hỏi trước, góp ý sau', 'Ask first, then give feedback'),
        desc: tr(
          'Tìm hiểu thêm hoàn cảnh của người kia trước khi đưa nhận xét.',
          'Learn more about their situation before you comment.',
        ),
      ),
      observe,
    ],
    _ => common,
  };
}

// ---------------------------------------------------------------------------
// Hoàn tất
// ---------------------------------------------------------------------------

String get kDoneSavedTitle =>
    tr('Đã lưu vào Career Memory', 'Saved to your Career Memory');

String get kDoneSavedNote => tr(
  'Lần nhìn lại này vừa để lại thêm một mảnh cho hành trình của bạn.',
  'This look back just added one more piece to your journey.',
);

String get kDoneMilestoneTitle =>
    tr('Đã ghi nhận một cột mốc', 'A milestone was recorded');

String get kDoneMilestoneNote => tr(
  'Điều vừa diễn ra đã được lưu như một sự thật đã xảy ra, không phải một '
      'việc cần làm.',
  'What just happened is kept as something that happened, not a to-do.',
);

String get kDoneKept => tr('Điều được giữ lại', 'What was kept');

String get kDoneHome => tr('Về màn hình chính', 'Back to home');

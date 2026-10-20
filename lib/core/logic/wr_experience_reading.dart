// Phần đọc "Trải nghiệm của bạn" ở tab Hiểu mình.
//
// Nguồn: "Logic đọc hiểu mình.docx" (Cloud & Coral, 15/10/2026) và mockup v77
// (`condSplit`, `pillarLevelText`, `COND_PHRASE`, `COND_SHAPE`, `expOverview`).
//
// Hai nguồn đọc, hai chủ ngữ:
//   · Từ điều kiện quanh bạn — 15 câu khảo sát, đọc TỪNG CÂU chứ không gộp
//     thành một điểm bình quân. Chủ ngữ là môi trường làm việc.
//   · Tổng quan — đặt nhóm người dùng quay lại nhiều nhất (dom) cạnh nhóm có
//     nhiều điều kiện đang cản trở nhất (blocked).
//
// HAI CHỖ CỐ Ý LỆCH SO VỚI MOCKUP:
//
//   · Câu nối chuỗi cản trở (`COND_SHAPE`) của mockup là MỘT câu viết sẵn cho
//     mỗi nhóm, và câu đó gọi đích danh từng điều (nhóm A: câu 11, 12, 14).
//     Người bị cản trở ở câu 13 và 15 sẽ đọc một câu sai — trái luật "câu phải
//     kiểm chứng được" của chính tài liệu. Ở đây câu viết sẵn chỉ dùng khi tập
//     điều đang cản trở khớp đúng điều câu đó nói; còn lại ghép từ cụm "đang
//     cản trở" của đúng những câu người dùng chấm thấp.
//   · Mảnh "phần khó rút gọn" của nhóm dom trong câu nối Tổng quan: mockup
//     ghi cứng một câu cho mỗi nhóm ("cảm giác cạn sức vào những ngày không có
//     gì gấp"), câu đó sai với phần lớn người dùng. Ở đây lấy đúng mảnh AI sinh
//     cùng khối "bạn đang khó ở chỗ nào" (§2, mục 9 đã chốt "AI sinh"); chưa có
//     mảnh đó (chưa đủ ngưỡng, chưa cho phép AI, AI lỗi, khác ngôn ngữ) thì gọi
//     đúng thứ dữ liệu cho phép nói: "những chuyện bạn ghi lại ở ‹nhóm›".
//
// Nguồn 1 — "Bạn đang khó ở chỗ nào": ngưỡng viết câu theo §2 (từ hai chuyện
// quay lại, hoặc một chuyện từ ba lần), KHÔNG theo bảng §5 (một chuyện hai
// lần). §2 có lý do ("hai điểm là một đường thẳng… gần như luôn sai"), bảng §5
// là bản tóm tắt; và ngưỡng chặt không đụng tới con số 2 lần mà mục 9 đã chốt
// cho danh sách "đang quay lại".
//
// Thang điểm: app lưu năm mức Likert theo thang 1–5 (Không bao giờ = 1 … Gần
// như luôn luôn = 5). Mockup v77 lưu chỉ số 0–4 khi bấm nhưng chia mức như
// thang 1–5, nên "Đôi khi" bị xếp vào mức cản trở; tài liệu ghi rõ 1–5 và
// "Đôi khi" = 3 = còn thất thường, nên ở đây theo tài liệu.

import '../l10n/wr_tr.dart';
import '../models/wr_content.dart';
import '../models/wr_episode.dart';
import 'wr_career_health.dart' show pillarOfSituation, selfCheckDateLabel;
import 'wr_repeated_situations.dart' show kRepeatedSituationsMinCount;
import 'wr_self_check_questions.dart';

// ---------------------------------------------------------------------------
// Ba mức của một câu
// ---------------------------------------------------------------------------

/// Mức của một câu khảo sát: 4–5 đang nâng đỡ, 3 còn thất thường, 1–2 đang
/// cản trở. Mức 3 không dồn vào phía nào cho gọn: có lúc có, có lúc không.
enum CondLevel { up, mid, down }

CondLevel condLevelOf(int score) => score >= 4
    ? CondLevel.up
    : score == 3
    ? CondLevel.mid
    : CondLevel.down;

/// Điểm 1–5 của câu [questionId], null khi chưa trả lời hoặc giá trị lạ.
int? condScoreOf(Map<String, dynamic> answers, String questionId) {
  final raw = answers[questionId];
  final v = raw is num ? raw.round() : int.tryParse('$raw');
  if (v == null || v < 1 || v > 5) return null;
  return v;
}

/// Ba cách gọi tên một câu, mỗi mức một cách. Cột giữa gọi tên ĐIỀU đó chứ
/// không khẳng định, để tiêu đề "CÒN THẤT THƯỜNG" làm phần đánh giá.
class CondPhrase {
  const CondPhrase(this.up, this.mid, this.down);

  final String up;
  final String mid;
  final String down;

  String of(CondLevel level) => switch (level) {
    CondLevel.up => up,
    CondLevel.mid => mid,
    CondLevel.down => down,
  };
}

/// Bộ cụm từ của tài liệu §3, nguyên văn. Getter để đổi ngôn ngữ là đổi chữ.
Map<String, CondPhrase> get kCondPhrases => {
  'scq-01': CondPhrase(
    tr(
      'Trách nhiệm được làm rõ từ đầu',
      'Responsibilities made clear from the start',
    ),
    tr(
      'Việc làm rõ trách nhiệm từ đầu',
      'Making responsibilities clear from the start',
    ),
    tr(
      'Trách nhiệm chưa được làm rõ từ đầu',
      'Responsibilities not made clear from the start',
    ),
  ),
  'scq-02': CondPhrase(
    tr('Có quy trình để dựa vào', 'A process to rely on'),
    tr('Quy trình cho việc quan trọng', 'Process for work that matters'),
    tr('Phải tự đoán cách làm', 'Having to guess how to do it'),
  ),
  'scq-03': CondPhrase(
    tr('Nguyên tắc phối hợp đã thống nhất', 'Agreed ways of working together'),
    tr(
      'Nguyên tắc phối hợp trong nhóm',
      'How the team agrees to work together',
    ),
    tr(
      'Nguyên tắc phối hợp chưa thống nhất',
      'Ways of working together not agreed',
    ),
  ),
  'scq-04': CondPhrase(
    tr('Thông tin đi đúng kênh', 'Information goes through the right channel'),
    tr('Kênh thông tin', 'Information channels'),
    tr(
      'Thông tin nằm rải nhiều nơi',
      'Information scattered across many places',
    ),
  ),
  'scq-05': CondPhrase(
    tr('Thay đổi được báo trước', 'Changes announced ahead'),
    tr('Việc báo trước khi có thay đổi', 'Notice ahead of changes'),
    tr('Thay đổi thường đến bất ngờ', 'Changes tend to come as a surprise'),
  ),
  'scq-06': CondPhrase(
    tr('Cấp quản lý nhất quán nói và làm', 'Managers do what they say'),
    tr(
      'Sự nhất quán nói và làm của cấp trên',
      'Whether managers do what they say',
    ),
    tr('Lời nói và việc làm chưa khớp nhau', 'Words and actions do not match'),
  ),
  'scq-07': CondPhrase(
    tr('Cam kết của đồng nghiệp đáng tin', 'Colleagues keep their commitments'),
    tr(
      'Độ tin cậy trong cam kết của đồng nghiệp',
      'How reliable colleagues\' commitments are',
    ),
    tr(
      'Cam kết của đồng nghiệp khó dựa vào',
      'Colleagues\' commitments are hard to rely on',
    ),
  ),
  'scq-08': CondPhrase(
    tr(
      'Nói khác số đông không thành chuyện',
      'Disagreeing with the majority is fine',
    ),
    tr('Việc nói khác với số đông', 'Speaking against the majority'),
    tr('Nói khác số đông còn e dè', 'Hesitant to disagree with the majority'),
  ),
  'scq-09': CondPhrase(
    tr('Nêu rủi ro sớm được đón nhận', 'Raising risks early is welcome'),
    tr('Việc nêu rủi ro sớm', 'Raising risks early'),
    tr('Thấy rủi ro nhưng chưa lên tiếng', 'Seeing risks but not speaking up'),
  ),
  'scq-10': CondPhrase(
    tr('Bất đồng hướng về giải pháp', 'Disagreements move towards solutions'),
    tr('Cách nhóm xử lý bất đồng', 'How the team handles disagreement'),
    tr(
      'Bất đồng dễ thành chuyện ai đúng',
      'Disagreements turn into who is right',
    ),
  ),
  'scq-11': CondPhrase(
    tr(
      'Việc của bạn gắn với mục tiêu chung',
      'Your work tied to the shared goal',
    ),
    tr(
      // Tài liệu ghi "Mối nối giữa việc của bạn và mục tiêu chung" (10 chữ),
      // vượt trần chín chữ của chính nó. Bỏ "của", nghĩa không đổi (15/10).
      'Mối nối giữa việc bạn và mục tiêu chung',
      'The link between your work and the shared goal',
    ),
    tr(
      'Chưa thấy việc mình gắn với mục tiêu chung',
      'Not seeing how your work ties to the shared goal',
    ),
  ),
  'scq-12': CondPhrase(
    tr('Mục tiêu đổi được báo kịp thời', 'Goal changes announced in time'),
    tr('Việc báo khi mục tiêu đổi', 'Notice when goals change'),
    tr('Mục tiêu đổi mà biết muộn', 'Learning late that goals changed'),
  ),
  'scq-13': CondPhrase(
    tr('Nhịp phối hợp đều và rõ', 'A steady, clear working rhythm'),
    tr('Nhịp phối hợp của nhóm', 'The team\'s working rhythm'),
    tr('Nhịp phối hợp chưa đều', 'An uneven working rhythm'),
  ),
  'scq-14': CondPhrase(
    tr(
      'Có lúc nhìn lại sau mỗi giai đoạn',
      'Time to look back after each phase',
    ),
    tr('Lúc nhìn lại sau mỗi giai đoạn', 'Looking back after each phase'),
    tr('Thiếu lúc để nhìn lại', 'No time set aside to look back'),
  ),
  'scq-15': CondPhrase(
    tr('Điều chỉnh thành việc cụ thể', 'Adjustments become concrete actions'),
    tr(
      'Việc chuyển điều chỉnh thành hành động',
      'Turning adjustments into action',
    ),
    tr(
      'Điều chỉnh nói rồi để đó',
      'Adjustments get talked about, then dropped',
    ),
  ),
};

// ---------------------------------------------------------------------------
// Một nhóm: chia năm câu thành ba mức
// ---------------------------------------------------------------------------

/// Năm câu của một nhóm chia theo mức, giữ thứ tự câu trong bộ khảo sát.
/// Mỗi phần tử là mã câu (`scq-01` …).
class CondSplit {
  const CondSplit({required this.up, required this.mid, required this.down});

  final List<String> up;
  final List<String> mid;
  final List<String> down;

  int get answered => up.length + mid.length + down.length;

  List<String> phrasesOf(CondLevel level) => [
    for (final id in switch (level) {
      CondLevel.up => up,
      CondLevel.mid => mid,
      CondLevel.down => down,
    })
      if (kCondPhrases[id] != null) kCondPhrases[id]!.of(level),
  ];
}

CondSplit condSplit(Map<String, dynamic> answers, SelfCheckPillar pillar) {
  final up = <String>[], mid = <String>[], down = <String>[];
  for (final q in kSelfCheckQuestions.where((q) => q.pillar == pillar)) {
    final v = condScoreOf(answers, q.id);
    if (v == null) continue;
    switch (condLevelOf(v)) {
      case CondLevel.up:
        up.add(q.id);
      case CondLevel.mid:
        mid.add(q.id);
      case CondLevel.down:
        down.add(q.id);
    }
  }
  return CondSplit(up: up, mid: mid, down: down);
}

/// Ngưỡng trung bình của nhãn nhóm (tài liệu §3, thang 1–5).
const double kCondUpAvg = 3.8;
const double kCondMidAvg = 2.6;

/// Nhãn của một nhóm: nói được đang nâng đỡ hay đang cản trở, và ở bao nhiêu
/// điều. [tone] null = chưa đánh giá.
class PillarCondLabel {
  const PillarCondLabel(this.text, this.tone);

  final String text;
  final CondLevel? tone;

  bool get blocked => tone == CondLevel.down;
}

/// Xét theo thứ tự, dừng ở nhánh đầu tiên đúng. Nhánh "có câu cản trở" đứng
/// trước các nhánh điểm: bốn câu tốt và một câu điểm 1 vẫn có trung bình cao,
/// nhưng điều đang chặn người dùng là câu điểm 1.
PillarCondLabel pillarCondLabel(
  Map<String, dynamic> answers,
  SelfCheckPillar pillar,
) {
  final s = condSplit(answers, pillar);
  if (s.answered == 0) {
    return PillarCondLabel(tr('Chưa đánh giá', 'Not rated yet'), null);
  }
  if (s.down.isNotEmpty) {
    return PillarCondLabel(
      tr(
        '${s.down.length} điều đang cản trở',
        s.down.length == 1
            ? '1 thing holding you back'
            : '${s.down.length} things holding you back',
      ),
      CondLevel.down,
    );
  }
  var total = 0;
  for (final q in kSelfCheckQuestions.where((q) => q.pillar == pillar)) {
    total += condScoreOf(answers, q.id) ?? 0;
  }
  final avg = total / s.answered;
  if (avg >= kCondUpAvg) {
    return PillarCondLabel(
      tr('Đang nâng đỡ bạn', 'Supporting you'),
      CondLevel.up,
    );
  }
  if (avg >= kCondMidAvg) {
    return PillarCondLabel(
      tr('Nâng đỡ nhưng chưa đều', 'Supporting, but unevenly'),
      CondLevel.mid,
    );
  }
  return PillarCondLabel(
    tr('Phần lớn đang cản trở', 'Mostly holding you back'),
    CondLevel.down,
  );
}

/// Dòng phụ dưới nhãn: tối đa hai cụm cụ thể, phần còn lại đếm gộp.
String pillarCondSubline(CondSplit s) {
  String more(int n) => tr(' · và $n điều nữa', ' · and $n more');
  if (s.down.isNotEmpty) {
    final p = s.phrasesOf(CondLevel.down);
    return tr('Đang cản trở: ', 'Holding you back: ') +
        p.take(2).join(' · ') +
        (p.length > 2 ? more(p.length - 2) : '');
  }
  if (s.up.isNotEmpty) {
    final p = s.phrasesOf(CondLevel.up);
    return tr('Đang nâng đỡ: ', 'Supporting you: ') +
        p.take(2).join(' · ') +
        (p.length > 2 ? more(p.length - 2) : '') +
        (s.mid.isNotEmpty
            ? tr(
                ' · còn ${s.mid.length} điều chưa đều',
                ' · ${s.mid.length} still uneven',
              )
            : '');
  }
  return tr(
    'Cả ${s.mid.length} điều ở nhóm này đều còn thất thường',
    'All ${s.mid.length} here are still uneven',
  );
}

// ---------------------------------------------------------------------------
// Câu nối chuỗi cản trở
// ---------------------------------------------------------------------------

/// Câu viết sẵn của tài liệu cho từng nhóm, kèm điều kiện để câu đó ĐÚNG với
/// người đang đọc. Câu nói "đều nằm ở lúc bắt đầu một việc" thì mọi điều đang
/// cản trở phải thuộc lúc bắt đầu; câu A gọi đích danh ba điều thì phải đúng
/// ba điều đó.
class _ChainText {
  const _ChainText({
    required this.required,
    required this.allowed,
    required this.sentence,
    required this.fragment,
  });

  /// Những câu phải đang ở mức cản trở.
  final Set<String> required;

  /// Mọi câu đang cản trở phải nằm trong tập này.
  final Set<String> allowed;

  /// Câu mở màn bên trong một nhóm (`COND_SHAPE`).
  final String sentence;

  /// Mảnh "chuỗi cản trở" dùng trong câu nối của Tổng quan.
  final String fragment;
}

Map<SelfCheckPillar, _ChainText> get _kChainTexts => {
  SelfCheckPillar.s: _ChainText(
    required: const {'scq-01', 'scq-02'},
    allowed: const {'scq-01', 'scq-02', 'scq-03'},
    sentence: tr(
      'Phần đang cản trở ở nhóm này đều nằm ở lúc bắt đầu một việc: ranh giới '
          'và cách làm chưa được nói ra trước khi bạn bắt tay vào.',
      'What holds you back here all sits at the start of a piece of work: '
          'boundaries and how to do it are not said out loud before you begin.',
    ),
    fragment: tr(
      'ranh giới và cách làm chưa được nói ra trước khi bắt đầu',
      'boundaries and how to do it are not said before starting',
    ),
  ),
  SelfCheckPillar.c: _ChainText(
    required: const {'scq-08'},
    allowed: const {'scq-08', 'scq-09', 'scq-10'},
    sentence: tr(
      'Phần đang cản trở ở nhóm này đều nằm ở lúc cần nói ra một điều khác với '
          'số đông.',
      'What holds you back here all sits at the moment you need to say '
          'something different from the majority.',
    ),
    fragment: tr(
      'việc nói khác số đông chưa được đón nhận',
      'saying something different from the majority is not welcomed',
    ),
  ),
  SelfCheckPillar.a: _ChainText(
    required: const {'scq-11', 'scq-12', 'scq-14'},
    allowed: const {'scq-11', 'scq-12', 'scq-14'},
    sentence: tr(
      'Ba điều đang cản trở ở nhóm này nối thành một chuỗi: việc của bạn chưa '
          'được nối với mục tiêu chung, mục tiêu đổi thì bạn biết muộn, và sau '
          'đó không có lúc nào để nhìn lại.',
      'The three things holding you back here form a chain: your work is not '
          'tied to the shared goal, you learn late when the goal changes, and '
          'afterwards there is no time to look back.',
    ),
    fragment: tr(
      'việc chưa được nối với mục tiêu chung và không có lúc nào để nhìn lại',
      'work is not tied to the shared goal and there is no time to look back',
    ),
  ),
};

_ChainText? _matchingChain(SelfCheckPillar pillar, CondSplit s) {
  final c = _kChainTexts[pillar];
  if (c == null || s.down.length < 2) return null;
  final down = s.down.toSet();
  if (!down.containsAll(c.required) || !c.allowed.containsAll(down)) {
    return null;
  }
  return c;
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// "a, b và c" / "a, b and c".
String _joinAnd(List<String> parts) {
  if (parts.length <= 1) return parts.join();
  final and = tr(' và ', ' and ');
  return '${parts.sublist(0, parts.length - 1).join(', ')}$and${parts.last}';
}

/// Câu mở màn bên trong một nhóm điều kiện.
String pillarCondLead(SelfCheckPillar pillar, CondSplit s) {
  if (s.down.isEmpty) {
    return s.mid.isEmpty
        ? tr(
            'Năm điều kiện ở nhóm này chưa có điều nào đang cản trở bạn.',
            'None of the conditions in this group is holding you back.',
          )
        : tr(
            'Năm điều kiện ở nhóm này chưa có điều nào đang cản trở bạn. Phần '
                'chưa đều là chỗ còn tuỳ vào từng giai đoạn.',
            'None of the conditions in this group is holding you back. The '
                'uneven ones are what still depends on the period.',
          );
  }
  final chain = _matchingChain(pillar, s);
  if (chain != null) return chain.sentence;
  final p = s.phrasesOf(CondLevel.down).map(_lowerFirst).toList();
  return s.down.length == 1
      ? tr(
          'Một điều ở nhóm này đang cản trở bạn: ${p.single}.',
          'One thing in this group is holding you back: ${p.single}.',
        )
      : tr(
          '${s.down.length} điều ở nhóm này đang cản trở bạn: ${_joinAnd(p)}.',
          '${s.down.length} things in this group are holding you back: '
              '${_joinAnd(p)}.',
        );
}

/// Mảnh "chuỗi cản trở" của nhóm [pillar] trong câu nối Tổng quan.
///
/// Ghép từ cụm thì lấy tối đa [kBlockedChainMaxPhrases] cụm, như dòng phụ dưới
/// nhãn nhóm. Máy thật 15/10: năm điều cản trở ghép đủ cả năm làm câu liên hệ
/// dài gần 50 chữ, trong khi mảnh mẫu của tài liệu chỉ có hai ý.
String blockedChainFragment(SelfCheckPillar pillar, CondSplit s) {
  final chain = _matchingChain(pillar, s);
  if (chain != null) return chain.fragment;
  return _joinAnd(
    s
        .phrasesOf(CondLevel.down)
        .take(kBlockedChainMaxPhrases)
        .map(_lowerFirst)
        .toList(),
  );
}

const int kBlockedChainMaxPhrases = 2;

// ---------------------------------------------------------------------------
// Cả bộ khảo sát
// ---------------------------------------------------------------------------

/// Khảo sát quá ngần này tháng thì coi là cũ: chỉ thêm một dòng nhắc, không
/// xoá kết quả, không khoá phần đọc, không chấm đỏ, không thông báo đẩy.
const int kSurveyStaleMonths = 3;

bool surveyIsStale(DateTime takenAt, DateTime now) {
  final t = takenAt.toLocal();
  return now.isAfter(DateTime(t.year, t.month + kSurveyStaleMonths, t.day));
}

String get kSurveyStaleNote => tr(
  'Kết quả này từ hơn ba tháng trước. Nếu điều kiện làm việc của bạn đã thay '
      'đổi, cập nhật lại để phần đọc theo kịp.',
  'These results are more than three months old. If your working conditions '
      'have changed, update them so the reading keeps up.',
);

/// Câu mở màn "Từ điều kiện quanh bạn".
String surveyLead(Map<String, dynamic> answers) {
  final splits = {
    for (final p in SelfCheckPillar.values) p: condSplit(answers, p),
  };
  final nDown = splits.values.fold(0, (n, s) => n + s.down.length);
  final nUp = splits.values.fold(0, (n, s) => n + s.up.length);
  final nMid = splits.values.fold(0, (n, s) => n + s.mid.length);
  if (nDown == 0) {
    if (nMid == 0) {
      return tr(
        'Trong 15 điều kiện quanh bạn, cả 15 điều đang nâng đỡ bạn.',
        'Of the fifteen conditions around you, all fifteen are supporting you.',
      );
    }
    return tr(
      'Trong 15 điều kiện quanh bạn, chưa có điều nào đang cản trở rõ. '
          '$nUp điều đang nâng đỡ, phần còn lại còn thất thường.',
      'Of the fifteen conditions around you, none is clearly holding you '
          'back. $nUp are supporting you, the rest are still uneven.',
    );
  }
  final most = splits.values
      .map((s) => s.down.length)
      .reduce((a, b) => a > b ? a : b);
  final worst = [
    for (final e in splits.entries)
      if (e.value.down.length == most) e.key.displayName,
  ];
  return worst.length == 1
      ? tr(
          'Trong 15 điều kiện quanh bạn, $nDown điều đang cản trở và $nUp '
              'điều đang nâng đỡ. Phần đang cản trở tập trung ở ${worst.single}.',
          'Of the fifteen conditions around you, $nDown are holding you back '
              'and $nUp are supporting you. What holds you back sits mostly in '
              '${worst.single}.',
        )
      : tr(
          'Trong 15 điều kiện quanh bạn, $nDown điều đang cản trở và $nUp '
              'điều đang nâng đỡ. Phần đang cản trở nằm ở ${_joinAnd(worst)}.',
          'Of the fifteen conditions around you, $nDown are holding you back '
              'and $nUp are supporting you. What holds you back sits in '
              '${_joinAnd(worst)}.',
        );
}

// ---------------------------------------------------------------------------
// Tổng quan
// ---------------------------------------------------------------------------

/// Số lần nhìn lại tối thiểu để đọc phần "Từ những lần nhìn lại" (§5).
const int kExperienceMinReflections = 15;

/// Sau "Chưa đúng lắm", chờ thêm chừng này lần nhìn lại mới đọc lại (§9).
const int kRereadAfterReflections = 3;

enum OverviewCase { aligned, diverged, noBlock }

/// Đầu vào của một bản đọc Tổng quan. Lưu nguyên khối này cùng phản hồi của
/// người dùng, để trong lúc chờ đọc lại vẫn dựng lại đúng bản họ đã xem.
class OverviewInputs {
  const OverviewInputs({
    required this.dom,
    required this.domCount,
    required this.total,
    required this.answers,
    this.hardPart,
    this.hardPartLocale,
  });

  /// Nhóm người dùng quay lại nhiều nhất.
  final SelfCheckPillar dom;
  final int domCount;

  /// Tổng số lần nhìn lại.
  final int total;

  /// Câu trả lời khảo sát lúc đọc.
  final Map<String, dynamic> answers;

  /// Mảnh "phần khó rút gọn" của nhóm [dom] do AI sinh, null khi chưa có.
  ///
  /// Lưu CÙNG bản đọc: sau "Chưa đúng lắm" bản cũ phải giữ nguyên từng chữ,
  /// không được tự đổi theo một lượt AI viết lại.
  final String? hardPart;

  /// Ngôn ngữ của [hardPart] ('vi'/'en'). Chữ do model viết, không getter nào
  /// dịch hộ được, nên khác ngôn ngữ đang bật thì không dùng.
  final String? hardPartLocale;

  Map<String, dynamic> toJson() => {
    'dom': dom.name,
    'dom_count': domCount,
    'total': total,
    'answers': answers,
    if (hardPart != null) 'hard_part': hardPart,
    if (hardPart != null) 'hard_part_locale': hardPartLocale,
  };

  static OverviewInputs? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final dom = SelfCheckPillar.values
        .where((p) => p.name == json['dom'])
        .firstOrNull;
    final answers = json['answers'];
    if (dom == null || answers is! Map) return null;
    return OverviewInputs(
      dom: dom,
      domCount: (json['dom_count'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      answers: Map<String, dynamic>.from(answers),
      hardPart: json['hard_part'] as String?,
      hardPartLocale: json['hard_part_locale'] as String?,
    );
  }
}

class ExperienceOverview {
  const ExperienceOverview({
    required this.kind,
    required this.dom,
    required this.blocked,
    required this.blockedCount,
    required this.head,
    required this.body,
    required this.link,
    required this.startPillar,
    required this.startReason,
  });

  final OverviewCase kind;
  final SelfCheckPillar dom;

  /// Nhóm có nhiều điều đang cản trở nhất; null khi không nhóm nào có.
  final SelfCheckPillar? blocked;
  final int blockedCount;

  final String head;
  final String body;

  /// Câu liên hệ, chỉ có ở trường hợp lệch nhau.
  final String? link;

  /// Thẻ "Chỗ đáng bắt đầu trước": một nhóm duy nhất và một câu lý do.
  final SelfCheckPillar startPillar;
  final String startReason;

  /// Khoá nhận diện bản đọc, để biết người dùng đã phản hồi CHÍNH bản này.
  String get key => '${kind.name}:${dom.name}:${blocked?.name ?? '-'}';
}

ExperienceOverview buildOverview(OverviewInputs i) {
  final down = {
    for (final p in SelfCheckPillar.values) p: condSplit(i.answers, p),
  };
  final most = down.values
      .map((s) => s.down.length)
      .reduce((a, b) => a > b ? a : b);
  // Hoà nhau mà dom nằm trong số đó thì hai phía đang chỉ cùng một chỗ;
  // còn lại lấy nhóm đứng trước theo thứ tự S · C · A như mockup.
  final SelfCheckPillar? blocked = most == 0
      ? null
      : down[i.dom]!.down.length == most
      ? i.dom
      : SelfCheckPillar.values.firstWhere((p) => down[p]!.down.length == most);
  final domName = i.dom.displayName;

  if (blocked == null) {
    return ExperienceOverview(
      kind: OverviewCase.noBlock,
      dom: i.dom,
      blocked: null,
      blockedCount: 0,
      head: tr(
        'Những gì bạn ghi lại dồn về $domName, và điều kiện quanh bạn chưa có '
            'chỗ nào đang cản trở rõ.',
        'What you write down gathers around $domName, and nothing in the '
            'conditions around you is clearly holding you back.',
      ),
      body: tr(
        'Khi điều kiện không phải phần đang chặn, chỗ đáng nhìn kỹ hơn là cách '
            'bạn đang làm việc với nhóm trải nghiệm này.',
        'When the conditions are not what is blocking you, the place worth a '
            'closer look is how you are working with this group of experience.',
      ),
      link: null,
      startPillar: i.dom,
      startReason: tr(
        'Điều kiện quanh bạn chưa chặn ở đâu, nên phần đáng làm nằm ở cách bạn '
            'đang xoay xở với nhóm này, không ở việc nới điều kiện.',
        'Nothing around you is blocking you yet, so the work is in how you '
            'handle this group, not in loosening the conditions.',
      ),
    );
  }

  if (blocked == i.dom) {
    return ExperienceOverview(
      kind: OverviewCase.aligned,
      dom: i.dom,
      blocked: blocked,
      blockedCount: most,
      head: tr(
        'Hai phía cùng chỉ về một chỗ: $domName.',
        'Both sides point to the same place: $domName.',
      ),
      body: tr(
        'Những gì bạn ghi lại dồn về nhóm này, và điều kiện quanh bạn cũng đang '
            'cản trở ở đây. Khi hai phía trùng nhau, một việc nhỏ làm đúng chỗ '
            'có khả năng tạo ra khác biệt thật.',
        'What you write down gathers around this group, and the conditions '
            'around you are holding you back here too. When both sides meet, a '
            'small thing done in the right place can make a real difference.',
      ),
      link: null,
      startPillar: i.dom,
      startReason: tr(
        'Hai phía đều dừng ở đây, nên một việc nhỏ làm đúng chỗ sẽ thấy kết quả '
            'sớm.',
        'Both sides stop here, so a small thing done in the right place will '
            'show results early.',
      ),
    );
  }

  final blockedName = blocked.displayName;
  final majority = i.domCount * 2 > i.total;
  final hard = i.hardPart?.trim();
  final domHard =
      hard != null && hard.isNotEmpty && i.hardPartLocale == wrLocaleCode
      ? hard
      : null;
  return ExperienceOverview(
    kind: OverviewCase.diverged,
    dom: i.dom,
    blocked: blocked,
    blockedCount: most,
    head: tr(
      'Chỗ bạn để tâm nhiều nhất và chỗ điều kiện đang cản trở nhiều nhất '
          'không trùng nhau.',
      'Where your attention goes most and where the conditions hold you back '
          'most are not the same place.',
    ),
    body: majority
        ? tr(
            'Phần lớn những gì bạn ghi lại nằm ở $domName, ${i.domCount} trong '
                '${i.total} lần. Trong khi đó điều kiện đang cản trở rõ nhất '
                'lại ở $blockedName, với $most điều.',
            'Most of what you write down sits in $domName, ${i.domCount} of '
                '${i.total} times. Meanwhile the conditions holding you back '
                'most are in $blockedName, with $most.',
          )
        : tr(
            'Những gì bạn ghi lại nằm nhiều nhất ở $domName, ${i.domCount} '
                'trong ${i.total} lần. Trong khi đó điều kiện đang cản trở rõ '
                'nhất lại ở $blockedName, với $most điều.',
            'What you write down sits mostly in $domName, ${i.domCount} of '
                '${i.total} times. Meanwhile the conditions holding you back '
                'most are in $blockedName, with $most.',
          ),
    link: tr(
      'Hai chuyện này thường có liên hệ. Khi '
          '${blockedChainFragment(blocked, down[blocked]!)}, '
          '${domHard ?? 'những chuyện bạn ghi lại ở $domName'} cũng khó tự nhẹ '
          'đi. Chỗ đáng thử trước có thể không phải chỗ bạn đang để tâm.',
      'These two are often linked. When '
          '${blockedChainFragment(blocked, down[blocked]!)}, '
          '${domHard ?? 'what you write down about $domName'} is hard to ease '
          'on its own. The place worth trying first may not be where your '
          'attention is.',
    ),
    startPillar: blocked,
    startReason: tr(
      'Đây là nhóm có nhiều điều kiện đang cản trở nhất. Nới một trong số đó '
          'thường làm nhẹ luôn phần bạn đang để tâm.',
      'This is the group with the most conditions holding you back. Loosening '
          'one of them often eases what your attention is on too.',
    ),
  );
}

// ---------------------------------------------------------------------------
// Nguồn 1 — những chuyện đang quay lại và khối "Bạn đang khó ở chỗ nào"
// ---------------------------------------------------------------------------
//
// Tài liệu §2. Phạm vi là TOÀN BỘ lịch sử. Một chuyện vào danh sách "đang quay
// lại" khi được ghi từ [kRepeatedSituationsMinCount] lần trở lên (mục 9: "2
// lần, giữ nguyên"). Câu do AI viết thì cần ngưỡng chặt hơn, xem
// [difficultyReadable].
//
// Chỉ lấy tình huống THÁCH THỨC: khối này nói người dùng đang khó ở đâu, và
// mười lần vui với đồng nghiệp không phải một chỗ khó.

/// Một dòng người dùng tự viết ở một lần nhìn lại: nguyên văn, kèm ngày.
class WrittenLine {
  const WrittenLine({required this.text, required this.date});

  final String text;

  /// Ngày theo giờ Việt Nam, chỉ phần ngày.
  final DateTime date;

  String get dateLabel => selfCheckDateLabel(date);

  Map<String, dynamic> toJson() => {'text': text, 'date': dateLabel};
}

/// Một chuyện đang quay lại trong một nhóm.
class RecurringStory {
  const RecurringStory({
    required this.code,
    required this.title,
    required this.count,
    required this.lines,
  });

  final String code;
  final String title;

  /// Số lần ghi, kể cả những lần chỉ đánh dấu.
  final int count;

  /// Dòng người dùng tự viết, mới nhất trước.
  final List<WrittenLine> lines;

  /// Số lần chỉ đánh dấu mà không viết gì: được đếm, không được bịa thành câu.
  int get markOnly => count - lines.length;
}

/// Dòng tự viết của một lần nhìn lại: bước kể lại khoảnh khắc. Chip tình huống
/// ở bước 0 là chữ của app nên không lấy.
String? _ownWords(ReflectionEpisode e) {
  final t = e.notes[ReflectionPattern.explore.dbValue]?.trim();
  return t == null || t.isEmpty ? null : t;
}

DateTime _vnDay(DateTime at) {
  final vn = at.toUtc().add(const Duration(hours: 7));
  return DateTime(vn.year, vn.month, vn.day);
}

/// Những chuyện đang quay lại trong nhóm [pillar], nhiều lần nhất trước (bằng
/// nhau thì chuyện có lần ghi gần nhất đứng trước).
List<RecurringStory> recurringStories(
  List<ReflectionEpisode> episodes,
  List<WrSituation> situations,
  SelfCheckPillar pillar,
) {
  final byCode = {for (final s in situations) s.code: s};
  final groups = <String, List<ReflectionEpisode>>{};
  for (final e in episodes) {
    final s = byCode[e.situationCode];
    if (s == null || s.valence.isPositive) continue;
    if (pillarOfSituation(s) != pillar) continue;
    (groups[s.code] ??= []).add(e);
  }

  DateTime latest(List<ReflectionEpisode> es) => es
      .map((e) => e.openedAt ?? DateTime(0))
      .reduce((a, b) => a.isAfter(b) ? a : b);

  final out = <(RecurringStory, DateTime)>[];
  for (final entry in groups.entries) {
    if (entry.value.length < kRepeatedSituationsMinCount) continue;
    final dated = [...entry.value]
      ..sort(
        (a, b) =>
            (b.openedAt ?? DateTime(0)).compareTo(a.openedAt ?? DateTime(0)),
      );
    out.add((
      RecurringStory(
        code: entry.key,
        title: byCode[entry.key]!.text,
        count: entry.value.length,
        lines: [
          for (final e in dated)
            if (_ownWords(e) case final t? when e.openedAt != null)
              WrittenLine(text: t, date: _vnDay(e.openedAt!)),
        ],
      ),
      latest(entry.value),
    ));
  }
  out.sort((a, b) {
    final c = b.$1.count.compareTo(a.$1.count);
    return c != 0 ? c : b.$2.compareTo(a.$2);
  });
  return [for (final o in out) o.$1];
}

/// Đủ dữ liệu để viết câu hình dạng chưa (§2): từ hai chuyện quay lại trở lên,
/// hoặc một chuyện quay lại từ ba lần trở lên. Dưới mức đó chỉ hiện số đếm.
bool difficultyReadable(List<RecurringStory> stories) =>
    stories.length >= 2 || stories.any((s) => s.count >= 3);

/// Hai trích dẫn dưới khối "khó ở chỗ nào": dòng tự viết mới nhất trước, lấy
/// từ CÙNG tập chuyện đã sinh ra câu, nên câu thứ hai luôn đặt cạnh được
/// chính chứng cứ của nó.
List<WrittenLine> difficultyQuotes(
  List<RecurringStory> stories, {
  int max = 2,
}) {
  final all = [for (final s in stories) ...s.lines]
    ..sort((a, b) => b.date.compareTo(a.date));
  return all.take(max).toList();
}

/// Trần nguyên liệu gửi sang AI: đủ để thấy điểm chung, không gửi cả lịch sử.
const int kDifficultyMaxStories = 6;
const int kDifficultyMaxLinesPerStory = 6;
const int kDifficultyMaxLineChars = 400;

/// Thân yêu cầu gửi Edge Function `wr-experience-read`: chỉ những nhóm đủ
/// ngưỡng. Rỗng thì không gọi.
List<Map<String, dynamic>> difficultyRequest(
  Map<SelfCheckPillar, List<RecurringStory>> byPillar,
) {
  String clip(String t) => t.length <= kDifficultyMaxLineChars
      ? t
      : t.substring(0, kDifficultyMaxLineChars);
  return [
    for (final p in SelfCheckPillar.values)
      if (byPillar[p] case final stories? when difficultyReadable(stories))
        {
          'pillar': p.name,
          'name': p.displayName,
          'stories': [
            for (final s in stories.take(kDifficultyMaxStories))
              {
                'title': s.title,
                'count': s.count,
                'lines': [
                  for (final l in s.lines.take(kDifficultyMaxLinesPerStory))
                    {'text': clip(l.text), 'date': l.dateLabel},
                ],
              },
          ],
          'quotes': [
            for (final q in difficultyQuotes(stories))
              {'text': clip(q.text), 'date': q.dateLabel},
          ],
        },
  ];
}

/// Hai câu AI viết cho một nhóm, kèm mảnh "phần khó rút gọn" cho Tổng quan.
class DifficultyReading {
  const DifficultyReading({
    required this.shape,
    required this.detail,
    this.hardPart,
  });

  /// Câu hình dạng: điểm chung của những chuyện đang quay lại.
  final String shape;

  /// Câu phân biệt: chặn cách hiểu tự trách, gọi tên phần khó thật.
  final String detail;

  /// Nhịp 3 rút thành một cụm danh từ, viết thường chữ đầu.
  final String? hardPart;

  static DifficultyReading? fromJson(Object? json) {
    if (json is! Map) return null;
    final shape = (json['shape'] as String?)?.trim() ?? '';
    final detail = (json['detail'] as String?)?.trim() ?? '';
    if (shape.isEmpty || detail.isEmpty) return null;
    final hard = (json['hard_part'] as String?)?.trim();
    return DifficultyReading(
      shape: shape,
      detail: detail,
      hardPart: hard == null || hard.isEmpty ? null : hard,
    );
  }
}

/// Kết quả một lượt đọc: mỗi nhóm đủ ngưỡng một bản, cùng ngôn ngữ đã viết.
class ExperienceAiReading {
  const ExperienceAiReading({required this.pillars, required this.locale});

  const ExperienceAiReading.none() : pillars = const {}, locale = null;

  final Map<SelfCheckPillar, DifficultyReading> pillars;
  final String? locale;

  DifficultyReading? of(SelfCheckPillar p) =>
      locale == wrLocaleCode ? pillars[p] : null;

  static ExperienceAiReading fromJson(Map<String, dynamic> json) {
    final raw = json['pillars'];
    final out = <SelfCheckPillar, DifficultyReading>{};
    if (raw is Map) {
      for (final p in SelfCheckPillar.values) {
        final r = DifficultyReading.fromJson(raw[p.name]);
        if (r != null) out[p] = r;
      }
    }
    return ExperienceAiReading(pillars: out, locale: json['locale'] as String?);
  }
}

// Chặng — hệ thống tự khép một chặng rồi viết bản đọc cho nó.
//
// Nguồn: script Sprint 2 (`CHAPTER_MIN_ENTRIES`, `CHAPTER_MIN_WEEKS`,
// `screenChapterRead`, `screenChapterList`, `answerChapter`).
//
// Script chỉ có ba chặng DỮ LIỆU CỨNG (`CHAPTERS`, chặng 1 · 2 · 3). Trước đây
// app chép nguyên ba chặng đó ra và hiện cho mọi người dùng thật. File này thay
// chúng bằng chặng tính từ Episode thật.
//
// LUẬT KHÉP CHẶNG — đúng chú thích của script, cả hai điều kiện chứ không phải
// một:
//   · ít nhất [kChapterMinEntries] lần nhìn lại trong chặng
//   · cách lần khép trước ít nhất [kChapterMinWeeks] tuần
// Chặng đầu tiên tính tuần từ lần nhìn lại đầu tiên. Chặng khép đúng lúc điều
// kiện thứ hai trong hai điều kiện được thoả: nếu đủ 8 lần trước khi đủ 6 tuần
// thì khép ở mốc 6 tuần (mọi lần trước mốc đó thuộc chặng này); nếu đủ 6 tuần
// trước khi đủ 8 lần thì khép ngay ở lần thứ 8. Chặng đang đi dở không hiện.
//
// NỘI DUNG MỘT CHẶNG. Script chỉ có chữ cứng cho ba khối, nên quy tắc dưới đây
// được SUY RA từ ý nghĩa của từng khối, đếm theo tình huống (cùng đơn vị với
// "Những điều đang lặp lại"):
//   · MỚI NỔI LÊN    — tình huống tăng nhiều nhất so với chặng trước, chặng
//                       này ít nhất 2 lần và tăng ít nhất 2 lần. Chặng đầu tiên
//                       không có chặng trước: lấy tình huống nhiều lần nhất
//                       (ít nhất 2 lần), đúng như chặng 1 của script.
//   · ĐÃ THÔI LẶP LẠI — tình huống chặng trước đã lặp (ít nhất 2 lần) mà chặng
//                       này còn dưới 2 lần; lấy cái chặng trước nhiều nhất. Chỉ
//                       có từ chặng thứ hai (script: "chỉ có từ chặng thứ hai
//                       trở đi").
//   · VẪN VẬY         — tình huống lặp ở cả hai chặng (đều ít nhất 2 lần), số
//                       lần chênh không quá 1. Chặng đầu tiên không có khối
//                       này: chưa có gì để nói "không đổi".
// Câu hỏi cuối chặng chỉ có khi có khối ĐÃ THÔI LẶP LẠI — hai nút trả lời của
// script ("Nhẹ đi thật" / "Chỉ thôi để ý") chỉ khớp với đúng câu hỏi đó.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../l10n/wr_tr.dart';
import '../models/wr_episode.dart';
import 'wr_repeated_situations.dart' show kRepeatedSituationsMinCount;

/// Số lần nhìn lại tối thiểu trong một chặng (script `CHAPTER_MIN_ENTRIES`).
const int kChapterMinEntries = 8;

/// Số tuần tối thiểu kể từ lần khép trước (script `CHAPTER_MIN_WEEKS`).
const int kChapterMinWeeks = 6;

/// Một khối trong bản đọc chặng: một tình huống, số lần chặng này, số lần
/// chặng trước (null ở chặng đầu tiên).
class WrChapterItem {
  const WrChapterItem({
    required this.situationCode,
    required this.title,
    required this.count,
    this.previousCount,
  });

  final String situationCode;
  final String title;
  final int count;
  final int? previousCount;
}

class WrChapter {
  const WrChapter({
    required this.number,
    required this.start,
    required this.end,
    required this.episodes,
    required this.isLatest,
    this.rose,
    this.faded,
    this.steady,
  });

  /// Thứ tự từ 1, chặng cũ nhất là 1.
  final int number;

  /// Mốc mở chặng (lần khép trước, hoặc lần nhìn lại đầu tiên).
  final DateTime start;

  /// Mốc khép chặng.
  final DateTime end;

  final List<ReflectionEpisode> episodes;

  /// Chặng khép gần nhất.
  final bool isLatest;

  final WrChapterItem? rose;
  final WrChapterItem? faded;
  final WrChapterItem? steady;

  /// Mã ổn định của chặng, dùng trong đường dẫn `/wr/chapter/:id`.
  String get id => 'ch$number';

  int get entries => episodes.length;

  bool get isFirst => number == 1;

  String get label => tr('Chặng $number', 'Chapter $number');

  /// "Tháng 8 đến tháng 10" — đúng dạng của script.
  String get range => chapterRangeLabel(start, end);

  String get lead {
    if (isFirst) {
      return tr(
        'Chặng đầu tiên. Chưa có chặng nào trước để so, nên đây là nền.',
        'The first chapter. There is no earlier chapter to compare with, so '
            'this is the baseline.',
      );
    }
    if (rose != null || faded != null) {
      return tr(
        'Những gì bạn ghi lại ở chặng này đã đổi chỗ so với chặng trước.',
        'What you wrote down in this chapter has shifted compared with the '
            'one before.',
      );
    }
    return tr(
      'Những gì bạn ghi lại ở chặng này gần giống chặng trước.',
      'What you wrote down in this chapter looks much like the one before.',
    );
  }

  String get note {
    if (isFirst) {
      return tr(
        'Đây là chặng nền. Từ chặng sau, phần "đã thôi lặp lại" mới có nghĩa.',
        'This is the baseline chapter. From the next one on, the "no longer '
            'repeating" part starts to mean something.',
      );
    }
    final f = faded;
    if (f != null) {
      return tr(
        'Chuyện "${f.title}" gần như không còn xuất hiện ở chặng này, sau khi '
            'lặp lại ${f.previousCount} lần ở chặng trước. Nó có thể đã được '
            'giải quyết, cũng có thể chỉ là bạn đã quen với nó.',
        '"${f.title}" barely shows up in this chapter, after coming back '
            '${f.previousCount} times in the one before. It may have been '
            'resolved, or you may simply have got used to it.',
      );
    }
    final r = rose;
    if (r != null) {
      return tr(
        'Chuyện "${r.title}" quay lại nhiều hơn hẳn ở chặng này: ${r.count} '
            'lần, chặng trước ${r.previousCount} lần.',
        '"${r.title}" came back far more often in this chapter: ${r.count} '
            'times, against ${r.previousCount} in the one before.',
      );
    }
    return tr(
      'Không có chuyện nào nổi lên hay lắng xuống rõ rệt so với chặng trước.',
      'Nothing rose or faded clearly compared with the chapter before.',
    );
  }

  /// Câu hỏi cuối chặng. Null khi không có khối "đã thôi lặp lại".
  String? get ask => faded == null
      ? null
      : tr(
          'Chuyện đó đã nhẹ đi thật, hay bạn chỉ thôi để ý tới nó?',
          'Has it really eased, or have you just stopped noticing it?',
        );
}

/// Thời điểm của một lần nhìn lại — sát nhất với lúc người dùng bắt đầu.
DateTime? chapterEpisodeTime(ReflectionEpisode e) =>
    e.openedAt ?? e.closedAt ?? e.updatedAt;

/// Các chặng ĐÃ KHÉP, cũ nhất đứng đầu.
///
/// [labels] tra tên tình huống theo mã (đúng map của tab Hiểu mình); mã không
/// có trong map thì không được chọn làm khối nào — không bao giờ hiện mã nội
/// bộ ra màn hình.
List<WrChapter> buildChapters(
  List<ReflectionEpisode> episodes, {
  required Map<String, String> labels,
  required DateTime now,
}) {
  final timed = [
    for (final e in episodes)
      if (chapterEpisodeTime(e) != null) e,
  ]..sort((a, b) => chapterEpisodeTime(a)!.compareTo(chapterEpisodeTime(b)!));
  if (timed.length < kChapterMinEntries) return const [];

  final spans = <({DateTime start, DateTime end, List<ReflectionEpisode> eps})>[];
  var i = 0;
  var start = chapterEpisodeTime(timed.first)!;
  const minSpan = Duration(days: kChapterMinWeeks * 7);

  while (timed.length - i >= kChapterMinEntries) {
    final eighth = chapterEpisodeTime(timed[i + kChapterMinEntries - 1])!;
    final deadline = start.add(minSpan);
    int endIndex;
    DateTime close;
    if (!eighth.isBefore(deadline)) {
      // Đủ tuần trước, đủ lần sau: khép ngay ở lần thứ 8.
      endIndex = i + kChapterMinEntries;
      close = eighth;
    } else {
      // Đủ lần trước, đủ tuần sau: khép ở mốc 6 tuần, nếu mốc đó đã tới.
      if (now.isBefore(deadline)) break;
      endIndex = i;
      while (endIndex < timed.length &&
          chapterEpisodeTime(timed[endIndex])!.isBefore(deadline)) {
        endIndex++;
      }
      close = deadline;
    }
    spans.add((start: start, end: close, eps: timed.sublist(i, endIndex)));
    i = endIndex;
    start = close;
  }

  final chapters = <WrChapter>[];
  Map<String, int>? previous;
  for (var n = 0; n < spans.length; n++) {
    final s = spans[n];
    final counts = _situationCounts(s.eps, labels);
    chapters.add(
      WrChapter(
        number: n + 1,
        start: s.start,
        end: s.end,
        episodes: s.eps,
        isLatest: n == spans.length - 1,
        rose: _rose(counts, previous, labels),
        faded: previous == null ? null : _faded(counts, previous, labels),
        steady: previous == null ? null : _steady(counts, previous, labels),
      ),
    );
    previous = counts;
  }
  return chapters;
}

/// Số lần nhìn lại của chặng đang đi dở — dùng cho trạng thái chờ.
int openChapterEntries(
  List<ReflectionEpisode> episodes,
  List<WrChapter> chapters,
) {
  final timed = episodes.where((e) => chapterEpisodeTime(e) != null).length;
  final closed = chapters.fold<int>(0, (s, c) => s + c.entries);
  return timed - closed;
}

Map<String, int> _situationCounts(
  List<ReflectionEpisode> eps,
  Map<String, String> labels,
) {
  final counts = <String, int>{};
  for (final e in eps) {
    final code = e.situationCode;
    if (code == null || code.isEmpty || !labels.containsKey(code)) continue;
    counts[code] = (counts[code] ?? 0) + 1;
  }
  return counts;
}

/// Thứ tự ổn định: điểm cao trước, hoà thì theo mã.
int _byScoreThenCode(
  MapEntry<String, int> a,
  MapEntry<String, int> b,
) {
  final c = b.value.compareTo(a.value);
  return c != 0 ? c : a.key.compareTo(b.key);
}

WrChapterItem? _rose(
  Map<String, int> now,
  Map<String, int>? prev,
  Map<String, String> labels,
) {
  const min = kRepeatedSituationsMinCount;
  if (prev == null) {
    final top = now.entries.where((e) => e.value >= min).toList()
      ..sort(_byScoreThenCode);
    if (top.isEmpty) return null;
    final e = top.first;
    return WrChapterItem(
      situationCode: e.key,
      title: labels[e.key]!,
      count: e.value,
    );
  }
  final rises = [
    for (final e in now.entries)
      if (e.value >= min && e.value - (prev[e.key] ?? 0) >= min)
        MapEntry(e.key, e.value - (prev[e.key] ?? 0)),
  ]..sort(_byScoreThenCode);
  if (rises.isEmpty) return null;
  final code = rises.first.key;
  return WrChapterItem(
    situationCode: code,
    title: labels[code]!,
    count: now[code]!,
    previousCount: prev[code] ?? 0,
  );
}

WrChapterItem? _faded(
  Map<String, int> now,
  Map<String, int> prev,
  Map<String, String> labels,
) {
  const min = kRepeatedSituationsMinCount;
  final drops = [
    for (final e in prev.entries)
      if (e.value >= min && (now[e.key] ?? 0) < min) e,
  ]..sort(_byScoreThenCode);
  if (drops.isEmpty) return null;
  final code = drops.first.key;
  return WrChapterItem(
    situationCode: code,
    title: labels[code]!,
    count: now[code] ?? 0,
    previousCount: prev[code],
  );
}

WrChapterItem? _steady(
  Map<String, int> now,
  Map<String, int> prev,
  Map<String, String> labels,
) {
  const min = kRepeatedSituationsMinCount;
  final same = [
    for (final e in now.entries)
      if (e.value >= min &&
          (prev[e.key] ?? 0) >= min &&
          (e.value - prev[e.key]!).abs() <= 1)
        e,
  ]..sort(_byScoreThenCode);
  if (same.isEmpty) return null;
  final code = same.first.key;
  return WrChapterItem(
    situationCode: code,
    title: labels[code]!,
    count: now[code]!,
    previousCount: prev[code],
  );
}

/// "Tháng 8 đến tháng 10" / "Tháng 11/2025 đến tháng 1/2026" / "Tháng 8".
String chapterRangeLabel(DateTime start, DateTime end) {
  const en = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  final s = start.toLocal();
  final e = end.toLocal();
  final sameYear = s.year == e.year;
  if (sameYear && s.month == e.month) {
    return tr('Tháng ${s.month}', en[s.month - 1]);
  }
  if (sameYear) {
    return tr(
      'Tháng ${s.month} đến tháng ${e.month}',
      '${en[s.month - 1]} to ${en[e.month - 1]}',
    );
  }
  return tr(
    'Tháng ${s.month}/${s.year} đến tháng ${e.month}/${e.year}',
    '${en[s.month - 1]} ${s.year} to ${en[e.month - 1]} ${e.year}',
  );
}

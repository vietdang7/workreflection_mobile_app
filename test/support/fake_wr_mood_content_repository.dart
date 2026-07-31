import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';

/// Fake in-memory cho Thư viện Nội dung Cảm xúc (Hai Lớp v1.6 §VIII).
///
/// Nạp trước bằng seed*; đặt [nextError] để giả lập lỗi (ném một lần rồi xoá).
class FakeWrMoodContentRepository implements WrMoodContentRepository {
  final List<MoodContent> _items = [];
  final List<String> _choicePool = [];

  Object? nextError;

  void seedContent(List<MoodContent> items) {
    _items
      ..clear()
      ..addAll(items);
  }

  void seedChoicePool(List<String> pool) {
    _choicePool
      ..clear()
      ..addAll(pool);
  }

  void _maybeThrow() {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      // ignore: only_throw_errors
      throw err;
    }
  }

  @override
  Future<List<MoodContent>> fetchByMood(Mood mood) async {
    _maybeThrow();
    final mine = _items.where((c) => c.mood == mood).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(mine);
  }

  @override
  Future<Map<Mood, List<MoodContent>>> fetchAllGrouped() async {
    _maybeThrow();
    final grouped = <Mood, List<MoodContent>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.mood, () => <MoodContent>[]).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return grouped;
  }

  @override
  Future<List<String>> fetchChoicePool() async {
    _maybeThrow();
    return List.unmodifiable(_choicePool);
  }
}

/// Dựng nhanh một mục nội dung cho test.
MoodContent fakeMoodContent({
  required String id,
  required Mood mood,
  String title = 'Một bài đọc',
  int sortOrder = 1,
  MoodContentType type = MoodContentType.reading,
  String kind = 'BÀI ĐỌC',
  String duration = '3 phút đọc',
  String body = 'Đoạn một.\n\nĐoạn hai.',
  bool placeholder = false,
  String? audioUrl,
}) {
  return MoodContent(
    id: id,
    mood: mood,
    sortOrder: sortOrder,
    title: title,
    kind: kind,
    duration: duration,
    type: type,
    body: body,
    placeholder: placeholder,
    audioUrl: audioUrl,
  );
}

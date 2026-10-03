// "Việc bạn tự đặt" — việc người dùng tự gõ để thực hành mỗi ngày (họp khách
// 01/10/2026, Task D1). Bảng `wr_user_practice_actions` + log theo ngày
// `wr_user_practice_action_logs`.
//
// ⚠ KHÔNG phải chủ đề thư viện. Không có `themeId`, không đi qua
// `PracticeEnrollment`, không tính vào quota chủ đề của gói Free.

/// Số lần cần làm để coi là xong. Khớp `default 5` của cột `target_count`.
const int kUserActionDefaultTarget = 5;

/// Trần độ dài tiêu đề. Khớp CHECK `char_length(btrim(title)) between 1 and 120`.
const int kUserActionTitleMax = 120;

/// Bỏ phần giờ, giữ ngày theo lịch máy.
DateTime wrDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ngày dạng `yyyy-MM-dd` cho cột `date` của Postgres.
String wrDateKey(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

class WrUserAction {
  const WrUserAction({
    required this.id,
    required this.title,
    required this.createdAt,
    this.targetCount = kUserActionDefaultTarget,
    this.completedAt,
    this.doneDays = const [],
  });

  final String id;
  final String title;
  final int targetCount;
  final DateTime createdAt;

  /// Người dùng đã bấm "Đánh dấu xong". Null = còn đang làm.
  final DateTime? completedAt;

  /// Những ngày đã bấm "Hôm nay tôi đã làm". Mỗi ngày tối đa một lần (khoá
  /// chính của bảng log).
  final List<DateTime> doneDays;

  int get doneCount => doneDays.length;

  bool get doneToday => isDoneOn(DateTime.now());

  bool isDoneOn(DateTime day) {
    final d = wrDateOnly(day);
    return doneDays.any((x) => wrDateOnly(x) == d);
  }

  bool get reachedTarget => doneCount >= targetCount;

  bool get isCompleted => completedAt != null;

  WrUserAction copyWith({DateTime? completedAt, List<DateTime>? doneDays}) =>
      WrUserAction(
        id: id,
        title: title,
        createdAt: createdAt,
        targetCount: targetCount,
        completedAt: completedAt ?? this.completedAt,
        doneDays: doneDays ?? this.doneDays,
      );

  /// Đọc một dòng `wr_user_practice_actions` có nhúng
  /// `wr_user_practice_action_logs(done_on)`.
  factory WrUserAction.fromJson(Map<String, dynamic> json) {
    final logs = json['wr_user_practice_action_logs'];
    final days = <DateTime>[
      if (logs is List)
        for (final l in logs)
          if (l is Map)
            if (DateTime.tryParse('${l['done_on']}') case final d?)
              wrDateOnly(d),
    ]..sort();
    return WrUserAction(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      targetCount:
          (json['target_count'] as num?)?.toInt() ?? kUserActionDefaultTarget,
      createdAt:
          DateTime.tryParse('${json['created_at']}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: DateTime.tryParse('${json['completed_at']}')?.toLocal(),
      doneDays: days,
    );
  }
}

// Bản JD người dùng tự viết — ánh xạ bảng `public.wr_jd_drafts`.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §6.

import '../logic/wr_jd_builder.dart';

class WrJdDraft {
  const WrJdDraft({
    required this.values,
    required this.currentDay,
    required this.completedDays,
    this.completedAt,
  });

  /// Nội dung theo TÊN CỘT, đúng khoá mà [WrJdField.column] khai.
  ///
  /// Giữ dạng map thay vì mười một trường riêng: màn hình duyệt theo
  /// [kJdDays] nên nó đọc theo tên cột chứ không đọc theo tên thuộc tính, và
  /// thêm một ô ở buổi nào đó sau này chỉ phải sửa đúng một chỗ.
  final Map<String, String?> values;

  /// Buổi đang dở, 1–5.
  final int currentDay;

  /// Những buổi đã bấm "Lưu và tiếp tục", tăng dần.
  final List<int> completedDays;

  /// Thời điểm đi hết cả năm buổi. Null nghĩa là chưa xong.
  final DateTime? completedAt;

  String? operator [](String column) => values[column];

  bool get isComplete => completedAt != null || isJdComplete(completedDays);

  /// Đã viết được chữ nào chưa. Dùng cho thẻ dẫn ở màn Thông tin công việc:
  /// chưa có chữ nào thì mời "cùng viết", có rồi thì mời "viết tiếp".
  bool get hasAnyContent =>
      values.values.any((v) => v != null && v.trim().isNotEmpty);

  static WrJdDraft empty() => const WrJdDraft(
        values: {},
        currentDay: 1,
        completedDays: [],
      );

  factory WrJdDraft.fromJson(Map<String, dynamic> json) {
    return WrJdDraft(
      values: {
        for (final c in jdColumns()) c: json[c] as String?,
      },
      currentDay: (json['current_day'] as num?)?.toInt() ?? 1,
      completedDays: ((json['completed_days'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList()
        ..sort(),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );
  }

  WrJdDraft copyWith({
    Map<String, String?>? values,
    int? currentDay,
    List<int>? completedDays,
    DateTime? completedAt,
  }) {
    return WrJdDraft(
      values: values ?? this.values,
      currentDay: currentDay ?? this.currentDay,
      completedDays: completedDays ?? this.completedDays,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

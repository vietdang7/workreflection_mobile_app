/// Tiến độ Self-Check được gom dần từ các câu hỏi nhỏ theo ngữ cảnh hằng ngày.
///
/// Bảng nguồn: public.wr_sca_self_check_drafts.
class WrDailySelfCheckDraft {
  const WrDailySelfCheckDraft({
    required this.userId,
    this.answers = const {},
    this.lastPromptedAt,
    this.completedAt,
  });

  final String userId;
  final Map<String, int> answers;
  final DateTime? lastPromptedAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  factory WrDailySelfCheckDraft.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'];
    final answers = <String, int>{};
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final value = entry.value;
        if (value is num) answers[entry.key.toString()] = value.toInt();
      }
    }
    return WrDailySelfCheckDraft(
      userId: json['user_id'] as String,
      answers: answers,
      lastPromptedAt: json['last_prompted_at'] != null
          ? DateTime.parse(json['last_prompted_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  WrDailySelfCheckDraft copyWith({
    Map<String, int>? answers,
    DateTime? lastPromptedAt,
    DateTime? completedAt,
  }) {
    return WrDailySelfCheckDraft(
      userId: userId,
      answers: answers ?? this.answers,
      lastPromptedAt: lastPromptedAt ?? this.lastPromptedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

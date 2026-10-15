// Phản hồi "Khớp với tôi" / "Chưa đúng lắm" cho một bản đọc của hệ thống.
//
// Nguồn: "Logic đọc hiểu mình.docx" §7 (15/10/2026). Mỗi lần bấm ghi một
// hàng: bản đọc nào (khoá + nguyên đầu vào), phán quyết gì, lúc nào. Sau "Chưa
// đúng lắm" hệ thống giữ nguyên bản cũ cho tới khi có thêm
// [kRereadAfterReflections] lần nhìn lại, nên phải lưu đủ đầu vào để dựng lại
// đúng bản người dùng đã xem.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loại bản đọc. Hiện chỉ Tổng quan có hai nút (tài liệu §7: hai màn đọc
/// trước nó trình bày dữ liệu của chính người dùng, không có gì để xác nhận).
const String kReadingKindOverview = 'overview';

class ReadingFeedback {
  const ReadingFeedback({
    required this.match,
    required this.readingKey,
    required this.reading,
    required this.createdAt,
  });

  /// true = Khớp với tôi, false = Chưa đúng lắm.
  final bool match;
  final String readingKey;
  final Map<String, dynamic> reading;
  final DateTime createdAt;

  factory ReadingFeedback.fromJson(Map<String, dynamic> json) =>
      ReadingFeedback(
        match: json['verdict'] == 'match',
        readingKey: json['reading_key'] as String? ?? '',
        reading: Map<String, dynamic>.from(
          (json['reading'] as Map?) ?? const {},
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

abstract class WrReadingFeedbackRepository {
  /// Lần phản hồi gần nhất cho loại bản đọc [kind], null khi chưa có.
  Future<ReadingFeedback?> fetchLatest(String userId, String kind);

  Future<void> insert({
    required String userId,
    required String kind,
    required String readingKey,
    required Map<String, dynamic> reading,
    required bool match,
  });
}

class SupabaseWrReadingFeedbackRepository
    implements WrReadingFeedbackRepository {
  SupabaseWrReadingFeedbackRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ReadingFeedback?> fetchLatest(String userId, String kind) async {
    final rows = await _client
        .from('wr_reading_feedback')
        .select('verdict, reading_key, reading, created_at')
        .eq('user_id', userId)
        .eq('reading_kind', kind)
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : ReadingFeedback.fromJson(rows.first);
  }

  @override
  Future<void> insert({
    required String userId,
    required String kind,
    required String readingKey,
    required Map<String, dynamic> reading,
    required bool match,
  }) async {
    await _client.from('wr_reading_feedback').insert({
      'user_id': userId,
      'reading_kind': kind,
      'reading_key': readingKey,
      'reading': reading,
      'verdict': match ? 'match' : 'off',
    });
  }
}

final wrReadingFeedbackRepositoryProvider =
    Provider<WrReadingFeedbackRepository>(
      (ref) => SupabaseWrReadingFeedbackRepository(Supabase.instance.client),
    );

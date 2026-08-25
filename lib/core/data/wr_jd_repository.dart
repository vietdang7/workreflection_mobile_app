// Repository cho bản JD người dùng tự viết (`wr_jd_drafts`).
//
// Nguồn: WorkReflection_Changelog_20260824.docx §6.
//
// Một hàng cho mỗi người dùng. Mọi thao tác ghi đều là UPSERT theo `user_id`:
// người dùng có thể vào màn lần đầu ở buổi 3 (dữ liệu cũ), hoặc vào lại sau
// nhiều tuần — không có thời điểm nào chắc chắn là "lần tạo đầu tiên" để mà
// tách INSERT với UPDATE.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/wr_jd_builder.dart';
import '../models/wr_jd_draft.dart';

abstract class WrJdRepository {
  /// Bản JD đang có. Null nghĩa là chưa từng mở màn này lần nào.
  Future<WrJdDraft?> fetch();

  /// Ghi nội dung một buổi.
  ///
  /// §6, ghi chú cho dev: "Nút Dừng ở đây, làm tiếp sau hiện CHƯA lưu dữ liệu
  /// đã nhập (chỉ là demo) — cần thiết kế cơ chế lưu nháp thật theo từng trường
  /// hoặc từng buổi." Đây là cơ chế đó, ở mức từng buổi.
  ///
  /// [markDayDone] false = lưu nháp rồi rời màn (buổi vẫn còn dở); true = bấm
  /// "Lưu và tiếp tục" (buổi coi như xong, buổi sau mở khoá).
  ///
  /// Chỉ những khoá có mặt trong [fields] mới bị ghi đè — mỗi lần lưu chỉ gửi
  /// các ô của MỘT buổi, gửi cả mười một cột sẽ xoá trắng những buổi khác.
  Future<WrJdDraft> save({
    required int day,
    required Map<String, String?> fields,
    required bool markDayDone,
  });
}

final wrJdRepositoryProvider = Provider<WrJdRepository>((ref) {
  return SupabaseWrJdRepository(Supabase.instance.client);
});

class SupabaseWrJdRepository implements WrJdRepository {
  const SupabaseWrJdRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'wr_jd_drafts';

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  @override
  Future<WrJdDraft?> fetch() async {
    final row = await _client
        .from(_table)
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    return row == null ? null : WrJdDraft.fromJson(row);
  }

  @override
  Future<WrJdDraft> save({
    required int day,
    required Map<String, String?> fields,
    required bool markDayDone,
  }) async {
    final current = await fetch();
    final completed = markDayDone
        ? markJdDayDone(day, current?.completedDays ?? const [])
        : (current?.completedDays ?? const <int>[]);

    // Lưu nháp giữa chừng thì `current_day` vẫn là buổi đang dở. Bấm "Lưu và
    // tiếp tục" thì nhảy sang buổi sau — trừ buổi 5, vốn không có buổi sau.
    final nextDay = markDayDone
        ? (day < kJdDayCount ? day + 1 : kJdDayCount)
        : day;

    final allowed = jdColumns().toSet();
    final patch = <String, dynamic>{
      'user_id': _uid,
      for (final e in fields.entries)
        if (allowed.contains(e.key))
          // Chuỗi rỗng ghi thành null: "chưa điền" và "điền rồi xoá hết" là
          // cùng một trạng thái, không nên phân biệt ở tầng dữ liệu.
          e.key: (e.value == null || e.value!.trim().isEmpty)
              ? null
              : e.value!.trim(),
      'current_day': nextDay,
      'completed_days': completed,
      if (isJdComplete(completed) && current?.completedAt == null)
        'completed_at': DateTime.now().toIso8601String(),
    };

    final row = await _client
        .from(_table)
        .upsert(patch, onConflict: 'user_id')
        .select()
        .single();
    return WrJdDraft.fromJson(row);
  }
}

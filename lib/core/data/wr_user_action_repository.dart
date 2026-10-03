import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wr_user_action.dart';

/// "Việc bạn tự đặt" (Task D1). Bảng riêng, KHÔNG đụng
/// `wr_practice_enrollments`: xem đầu `wr_user_action.dart`.
abstract class WrUserActionRepository {
  /// Mọi việc của người đang đăng nhập, mới nhất trước, kèm các ngày đã làm.
  Future<List<WrUserAction>> list();

  Future<WrUserAction> add(String title);

  /// Ghi "hôm nay tôi đã làm". Đã ghi hôm nay rồi thì DB trả 23505 (khoá chính
  /// `action_id, done_on`); tầng giao diện coi lỗi đó là đã ghi.
  Future<void> logToday(String actionId);

  Future<void> complete(String actionId);

  Future<void> delete(String actionId);
}

final wrUserActionRepositoryProvider = Provider<WrUserActionRepository>((ref) {
  return SupabaseWrUserActionRepository(Supabase.instance.client);
});

/// Dòng gửi lên khi thêm việc. Không gửi `id` / `created_at` / `target_count`:
/// để DB tự điền mặc định.
Map<String, dynamic> userActionInsertRow({
  required String userId,
  required String title,
}) => {'user_id': userId, 'title': title.trim()};

/// Dòng log một ngày. Gửi ngày theo lịch MÁY người dùng, không để DB tự điền
/// theo giờ Việt Nam: nút "Đã ghi hôm nay" trên màn hình cũng tính theo lịch
/// máy, hai bên phải cùng một ngày.
Map<String, dynamic> userActionLogRow({
  required String userId,
  required String actionId,
  required DateTime day,
}) => {'action_id': actionId, 'user_id': userId, 'done_on': wrDateKey(day)};

class SupabaseWrUserActionRepository implements WrUserActionRepository {
  const SupabaseWrUserActionRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'wr_user_practice_actions';
  static const String _logTable = 'wr_user_practice_action_logs';

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  @override
  Future<List<WrUserAction>> list() async {
    final rows = await _client
        .from(_table)
        .select(
          'id, title, target_count, created_at, completed_at, '
          '$_logTable(done_on)',
        )
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return rows.map(WrUserAction.fromJson).toList();
  }

  @override
  Future<WrUserAction> add(String title) async {
    final row = await _client
        .from(_table)
        .insert(userActionInsertRow(userId: _uid, title: title))
        .select('id, title, target_count, created_at, completed_at')
        .single();
    return WrUserAction.fromJson(row);
  }

  @override
  Future<void> logToday(String actionId) async {
    await _client
        .from(_logTable)
        .insert(
          userActionLogRow(
            userId: _uid,
            actionId: actionId,
            day: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> complete(String actionId) async {
    await _client
        .from(_table)
        .update({'completed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', actionId)
        .eq('user_id', _uid);
  }

  @override
  Future<void> delete(String actionId) async {
    await _client.from(_table).delete().eq('id', actionId).eq('user_id', _uid);
  }
}

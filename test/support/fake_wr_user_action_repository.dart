// Repo giả cho "Việc bạn tự đặt" (Task D1).
//
// ⚠ Chép lại MỌI CHECK và khoá chính của hai bảng trong
// `supabase/migrations/20261001120000_wr_user_practice_actions.sql`. Đã hai lần
// dính lỗi 400 chỉ lộ khi chạy thật vì fake nhận mọi thứ còn DB thì không.
// `test/core/wr_user_action_db_contract_test.dart` so các chuỗi CHECK dưới đây
// với file migration, nên sửa một bên mà quên bên kia là test đỏ.

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:workreflection_mobile/core/data/wr_user_action_repository.dart';
import 'package:workreflection_mobile/core/models/wr_user_action.dart';

/// CHECK của `wr_user_practice_actions.title`, chép nguyên văn từ migration.
const fakeUserActionTitleCheck = 'char_length(btrim(title)) between 1 and 120';

/// CHECK của `wr_user_practice_actions.target_count`.
const fakeUserActionTargetCheck = 'target_count between 1 and 100';

/// Khoá chính của bảng log: một việc chỉ ghi được một lần mỗi ngày.
const fakeUserActionLogPrimaryKey = 'primary key (action_id, done_on)';

class FakeWrUserActionRepository implements WrUserActionRepository {
  FakeWrUserActionRepository({
    this.userId = 'u1',
    DateTime Function()? now,
    this.failList = false,
  }) : _now = now ?? DateTime.now;

  final String userId;
  final DateTime Function() _now;
  bool failList;

  final List<WrUserAction> _rows = [];
  int _seq = 0;

  final List<String> addCalls = [];
  final List<String> logTodayCalls = [];
  final List<String> completeCalls = [];
  final List<String> deleteCalls = [];

  List<WrUserAction> get rows => List.unmodifiable(_rows);

  void seed(List<WrUserAction> actions) {
    _rows
      ..clear()
      ..addAll(actions);
  }

  /// `btrim(text)` của Postgres chỉ cắt dấu cách, không cắt tab hay xuống dòng.
  static String _btrim(String s) => s.replaceAll(RegExp(r'^ +| +$'), '');

  static PostgrestException _check(String constraint) => PostgrestException(
    message:
        'new row for relation "wr_user_practice_actions" violates check '
        'constraint "$constraint"',
    code: '23514',
  );

  @override
  Future<List<WrUserAction>> list() async {
    if (failList) throw StateError('list failed');
    final sorted = [..._rows]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<WrUserAction> add(String title) async {
    addCalls.add(title);
    final len = _btrim(title).runes.length;
    if (len < 1 || len > 120) {
      throw _check('wr_user_practice_actions_title_check');
    }
    final action = WrUserAction(
      id: 'ua-${++_seq}',
      title: title,
      createdAt: _now().add(Duration(microseconds: _seq)),
    );
    _rows.add(action);
    return action;
  }

  @override
  Future<void> logToday(String actionId) async {
    logTodayCalls.add(actionId);
    final i = _rows.indexWhere((a) => a.id == actionId);
    if (i < 0) {
      throw PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );
    }
    final today = wrDateOnly(_now());
    final action = _rows[i];
    if (action.doneDays.any((d) => wrDateOnly(d) == today)) {
      throw PostgrestException(
        message:
            'duplicate key value violates unique constraint '
            '"wr_user_practice_action_logs_pkey"',
        code: '23505',
      );
    }
    _rows[i] = action.copyWith(doneDays: [...action.doneDays, today]);
  }

  @override
  Future<void> complete(String actionId) async {
    completeCalls.add(actionId);
    final i = _rows.indexWhere((a) => a.id == actionId);
    if (i < 0) return;
    _rows[i] = _rows[i].copyWith(completedAt: _now());
  }

  @override
  Future<void> delete(String actionId) async {
    deleteCalls.add(actionId);
    _rows.removeWhere((a) => a.id == actionId);
  }
}

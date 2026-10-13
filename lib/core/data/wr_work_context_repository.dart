// Lịch sử ba trường VAI TRÒ của màn "Bối cảnh công việc" (script Sprint 2
// `screenJobContext` + `ROLE_FIELDS`), bảng `wr_work_context_history`.
//
// Mỗi lần lưu là một dòng MỚI, không đè bản cũ. Giá trị hiện tại của một
// trường là dòng mới nhất của trường đó.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ba trường của khối VAI TRÒ. `dbValue` khớp check constraint của cột
/// `wr_work_context_history.field`.
enum WrWorkContextField {
  position('position'),
  knowledge('knowledge'),
  skill('skill');

  const WrWorkContextField(this.dbValue);

  final String dbValue;

  static WrWorkContextField? fromDb(String? v) {
    for (final f in values) {
      if (f.dbValue == v) return f;
    }
    return null;
  }
}

/// Một bản ghi trong lịch sử của một trường.
class WrWorkContextEntry {
  const WrWorkContextEntry({
    required this.field,
    required this.value,
    required this.createdAt,
    this.id,
  });

  final String? id;
  final WrWorkContextField field;
  final String value;
  final DateTime createdAt;

  /// Null khi `field` không thuộc ba trường đã biết — bỏ qua thay vì ném lỗi.
  static WrWorkContextEntry? fromJson(Map<String, dynamic> json) {
    final field = WrWorkContextField.fromDb(json['field'] as String?);
    final value = (json['value'] as String?)?.trim();
    final at = json['created_at'] as String?;
    if (field == null || value == null || value.isEmpty || at == null) {
      return null;
    }
    return WrWorkContextEntry(
      id: json['id'] as String?,
      field: field,
      value: value,
      createdAt: DateTime.parse(at),
    );
  }
}

/// Gom lịch sử theo trường, mới nhất trước trong từng trường.
Map<WrWorkContextField, List<WrWorkContextEntry>> groupWorkContextHistory(
  Iterable<WrWorkContextEntry> entries,
) {
  final out = <WrWorkContextField, List<WrWorkContextEntry>>{
    for (final f in WrWorkContextField.values) f: <WrWorkContextEntry>[],
  };
  for (final e in entries) {
    out[e.field]!.add(e);
  }
  for (final list in out.values) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return out;
}

abstract class WrWorkContextRepository {
  /// Toàn bộ lịch sử của người đang đăng nhập, mới nhất trước.
  Future<List<WrWorkContextEntry>> listHistory();

  /// Ghi thêm một bản mới cho [field]. Không bao giờ sửa bản cũ.
  Future<WrWorkContextEntry> addEntry(WrWorkContextField field, String value);
}

final wrWorkContextRepositoryProvider = Provider<WrWorkContextRepository>((
  ref,
) {
  return SupabaseWrWorkContextRepository(Supabase.instance.client);
});

class SupabaseWrWorkContextRepository implements WrWorkContextRepository {
  const SupabaseWrWorkContextRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'wr_work_context_history';
  static const String _columns = 'id, field, value, created_at';

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  @override
  Future<List<WrWorkContextEntry>> listHistory() async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        if (WrWorkContextEntry.fromJson(r) case final e?) e,
    ];
  }

  @override
  Future<WrWorkContextEntry> addEntry(
    WrWorkContextField field,
    String value,
  ) async {
    final row = await _client
        .from(_table)
        .insert({
          'user_id': _uid,
          'field': field.dbValue,
          'value': value.trim(),
        })
        .select(_columns)
        .single();
    final entry = WrWorkContextEntry.fromJson(row);
    if (entry == null) throw StateError('invalid work context row');
    return entry;
  }
}

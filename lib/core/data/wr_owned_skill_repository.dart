import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wr_owned_skill.dart';
import 'wr_repository.dart' show contextDocMimeType;

/// Chứng chỉ / khoá học / kỹ năng người dùng tự khai (Task D2).
abstract class WrOwnedSkillRepository {
  /// Mọi mục của người đang đăng nhập, mới nhất trước.
  Future<List<WrOwnedSkill>> list();

  /// Thêm một mục. `id` / `createdAt` của [skill] bị bỏ qua, DB tự điền.
  Future<WrOwnedSkill> add(WrOwnedSkill skill);

  Future<void> update(String id, WrOwnedSkill skill);

  /// Xoá mục và tệp đính kèm (nếu có).
  Future<void> delete(WrOwnedSkill skill);

  /// Tải tệp đính kèm lên bucket `context-docs` ở `{uid}/cert-{ms}.{ext}`, trả
  /// đường dẫn để lưu vào `file_path`.
  ///
  /// ⚠ KHÔNG chèn dòng `wr_context_documents`: tệp chứng chỉ không chiếm suất
  /// tài liệu JD/CV của gói Free, và AI chưa đọc tệp này (ngoài phạm vi D2).
  Future<String> uploadAttachment(List<int> bytes, String ext);
}

final wrOwnedSkillRepositoryProvider = Provider<WrOwnedSkillRepository>((ref) {
  return SupabaseWrOwnedSkillRepository(Supabase.instance.client);
});

class SupabaseWrOwnedSkillRepository implements WrOwnedSkillRepository {
  const SupabaseWrOwnedSkillRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'wr_owned_skills';
  static const String _bucket = 'context-docs';
  static const String _columns =
      'id, kind, title, issuer, completed_on, file_path, theme_ids, created_at';

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  @override
  Future<List<WrOwnedSkill>> list() async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return rows.map(WrOwnedSkill.fromJson).toList();
  }

  @override
  Future<WrOwnedSkill> add(WrOwnedSkill skill) async {
    final row = await _client
        .from(_table)
        .insert(ownedSkillWriteRow(userId: _uid, skill: skill))
        .select(_columns)
        .single();
    return WrOwnedSkill.fromJson(row);
  }

  @override
  Future<void> update(String id, WrOwnedSkill skill) async {
    await _client
        .from(_table)
        .update(ownedSkillWriteRow(userId: _uid, skill: skill))
        .eq('id', id)
        .eq('user_id', _uid);
  }

  @override
  Future<void> delete(WrOwnedSkill skill) async {
    await _client.from(_table).delete().eq('id', skill.id).eq('user_id', _uid);
    final path = skill.filePath;
    if (path != null && path.isNotEmpty) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {
        // Dòng đã xoá; tệp mồ côi chỉ tốn chỗ, không lộ gì vì bucket private.
      }
    }
  }

  @override
  Future<String> uploadAttachment(List<int> bytes, String ext) async {
    final path = ownedSkillFilePath(
      userId: _uid,
      ext: ext,
      stamp: DateTime.now().millisecondsSinceEpoch,
    );
    final safeExt = path.split('.').last;
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            upsert: true,
            contentType: contextDocMimeType(safeExt),
          ),
        );
    return path;
  }
}

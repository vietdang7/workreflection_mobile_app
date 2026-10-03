// Repo giả cho "Chứng chỉ, khoá học, kỹ năng đã có" (Task D2).
//
// ⚠ Chép lại MỌI CHECK của bảng `wr_owned_skills` trong
// `supabase/migrations/20261001130000_wr_owned_skills.sql`.
// `test/core/wr_owned_skill_db_contract_test.dart` so các chuỗi dưới đây với
// file migration, nên sửa một bên mà quên bên kia là test đỏ.

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:workreflection_mobile/core/data/wr_owned_skill_repository.dart';
import 'package:workreflection_mobile/core/models/wr_owned_skill.dart';

/// CHECK của cột `kind`.
const fakeOwnedSkillKindCheck = "kind in ('certificate','course','skill')";
const fakeOwnedSkillKinds = {'certificate', 'course', 'skill'};

/// CHECK của cột `title`.
const fakeOwnedSkillTitleCheck = 'char_length(btrim(title)) between 1 and 160';

/// CHECK của cột `issuer`.
const fakeOwnedSkillIssuerCheck =
    'issuer is null or char_length(issuer) <= 160';

class FakeWrOwnedSkillRepository implements WrOwnedSkillRepository {
  FakeWrOwnedSkillRepository({this.userId = 'u1', this.failList = false});

  final String userId;
  bool failList;

  final List<WrOwnedSkill> _rows = [];
  int _seq = 0;

  final List<WrOwnedSkill> addCalls = [];
  final List<(String, WrOwnedSkill)> updateCalls = [];
  final List<String> deleteCalls = [];

  /// Đường dẫn các tệp đã "tải lên" bucket `context-docs`.
  final List<String> uploadedPaths = [];

  /// Đường dẫn các tệp đã bị xoá khỏi bucket.
  final List<String> removedPaths = [];

  List<WrOwnedSkill> get rows => List.unmodifiable(_rows);

  void seed(List<WrOwnedSkill> skills) {
    _rows
      ..clear()
      ..addAll(skills);
  }

  static String _btrim(String s) => s.replaceAll(RegExp(r'^ +| +$'), '');

  static PostgrestException _check(String col) => PostgrestException(
    message:
        'new row for relation "wr_owned_skills" violates check constraint '
        '"wr_owned_skills_${col}_check"',
    code: '23514',
  );

  /// Đúng bộ luật của DB cho một dòng ghi xuống.
  static void enforceChecks(Map<String, dynamic> row) {
    if (!fakeOwnedSkillKinds.contains(row['kind'])) throw _check('kind');
    final title = row['title'] as String? ?? '';
    final len = _btrim(title).runes.length;
    if (len < 1 || len > 160) throw _check('title');
    final issuer = row['issuer'] as String?;
    if (issuer != null && issuer.runes.length > 160) throw _check('issuer');
  }

  @override
  Future<List<WrOwnedSkill>> list() async {
    if (failList) throw StateError('list failed');
    return [..._rows]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<WrOwnedSkill> add(WrOwnedSkill skill) async {
    addCalls.add(skill);
    enforceChecks(ownedSkillWriteRow(userId: userId, skill: skill));
    final saved = skill.copyWith(
      id: 'os-${++_seq}',
      createdAt: DateTime(2026, 10, 3).add(Duration(seconds: _seq)),
    );
    _rows.add(saved);
    return saved;
  }

  @override
  Future<void> update(String id, WrOwnedSkill skill) async {
    updateCalls.add((id, skill));
    enforceChecks(ownedSkillWriteRow(userId: userId, skill: skill));
    final i = _rows.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _rows[i] = skill.copyWith(id: id, createdAt: _rows[i].createdAt);
  }

  @override
  Future<void> delete(WrOwnedSkill skill) async {
    deleteCalls.add(skill.id);
    _rows.removeWhere((s) => s.id == skill.id);
    if (skill.filePath != null) removedPaths.add(skill.filePath!);
  }

  @override
  Future<String> uploadAttachment(List<int> bytes, String ext) async {
    final path = ownedSkillFilePath(
      userId: userId,
      ext: ext,
      stamp: 1000 + uploadedPaths.length,
    );
    uploadedPaths.add(path);
    return path;
  }
}

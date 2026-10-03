// Chứng chỉ / khoá học / kỹ năng người dùng tự khai đã có (họp khách
// 01/10/2026, Task D2). Bảng `wr_owned_skills`.
//
// `themeIds` là chủ đề thư viện mà mục này tương ứng. Máy chỉ đề xuất, người
// dùng xác nhận bằng ô tích. App dùng tập này để KHÔNG đề xuất lại: gợi ý chủ
// đề, đối chiếu kỹ năng với JD và trợ lý trò chuyện.

import '../l10n/wr_tr.dart';
import 'wr_user_action.dart' show wrDateKey, wrDateOnly;

/// Trần độ dài tên. Khớp CHECK `char_length(btrim(title)) between 1 and 160`.
const int kOwnedSkillTitleMax = 160;

/// Trần độ dài đơn vị cấp. Khớp CHECK `char_length(issuer) <= 160`.
const int kOwnedSkillIssuerMax = 160;

enum OwnedSkillKind {
  certificate,
  course,
  skill;

  /// Giá trị cột `kind`. Khớp CHECK `kind in ('certificate','course','skill')`.
  String get dbValue => name;

  String get label => switch (this) {
    OwnedSkillKind.certificate => tr('Chứng chỉ', 'Certificate'),
    OwnedSkillKind.course => tr('Khoá học', 'Course'),
    OwnedSkillKind.skill => tr('Kỹ năng', 'Skill'),
  };

  static OwnedSkillKind fromDb(String? v) => OwnedSkillKind.values.firstWhere(
    (k) => k.dbValue == v,
    orElse: () => OwnedSkillKind.skill,
  );
}

class WrOwnedSkill {
  const WrOwnedSkill({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.issuer,
    this.completedOn,
    this.filePath,
    this.themeIds = const [],
  });

  final String id;
  final OwnedSkillKind kind;
  final String title;
  final String? issuer;
  final DateTime? completedOn;

  /// Đường dẫn trong bucket `context-docs` (`{uid}/cert-{ms}.{ext}`). Không
  /// phải một dòng `wr_context_documents`, nên không chiếm suất tài liệu.
  final String? filePath;

  final List<String> themeIds;
  final DateTime createdAt;

  WrOwnedSkill copyWith({String? id, DateTime? createdAt}) => WrOwnedSkill(
    id: id ?? this.id,
    kind: kind,
    title: title,
    issuer: issuer,
    completedOn: completedOn,
    filePath: filePath,
    themeIds: themeIds,
    createdAt: createdAt ?? this.createdAt,
  );

  factory WrOwnedSkill.fromJson(Map<String, dynamic> json) {
    final ids = json['theme_ids'];
    final done = DateTime.tryParse('${json['completed_on']}');
    return WrOwnedSkill(
      id: json['id'] as String,
      kind: OwnedSkillKind.fromDb(json['kind'] as String?),
      title: (json['title'] as String?) ?? '',
      issuer: json['issuer'] as String?,
      completedOn: done == null ? null : wrDateOnly(done),
      filePath: json['file_path'] as String?,
      themeIds: ids is List ? ids.map((e) => '$e').toList() : const [],
      createdAt:
          DateTime.tryParse('${json['created_at']}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Dòng ghi xuống `wr_owned_skills` (thêm hoặc sửa). Không gửi `id` /
/// `created_at`. Cắt khoảng trắng; đơn vị cấp rỗng thì gửi null.
Map<String, dynamic> ownedSkillWriteRow({
  required String userId,
  required WrOwnedSkill skill,
}) {
  final issuer = skill.issuer?.trim();
  return {
    'user_id': userId,
    'kind': skill.kind.dbValue,
    'title': skill.title.trim(),
    'issuer': (issuer == null || issuer.isEmpty) ? null : issuer,
    'completed_on': skill.completedOn == null
        ? null
        : wrDateKey(skill.completedOn!),
    'file_path': skill.filePath,
    'theme_ids': skill.themeIds,
  };
}

/// Đường tệp đính kèm trong bucket `context-docs`. Thư mục đầu PHẢI là id
/// người dùng: policy của bucket kiểm đúng điều đó.
String ownedSkillFilePath({
  required String userId,
  required String ext,
  required int stamp,
}) {
  final safeExt = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return '$userId/cert-$stamp.$safeExt';
}

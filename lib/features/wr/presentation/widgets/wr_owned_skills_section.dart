// Khối "Chứng chỉ, khoá học đã có" trong thẻ Tài liệu của màn Bối cảnh công
// việc (họp khách 01/10/2026, Task D2; rút gọn theo họp khách 14/10).
//
// Người dùng đính kèm những gì họ ĐÃ có để app không đề xuất lại: gợi ý chủ
// đề, đối chiếu kỹ năng với JD và trợ lý trò chuyện đều bỏ qua các chủ đề gắn
// với mục đó. Khai tay mở cho mọi gói (mặc định Q5).
//
// 14/10: khách bỏ form nhiều ô (tên, loại, nơi cấp, ngày, tích chủ đề) — chỉ
// còn MỘT nút tải file. Tên mục lấy từ tên file, chủ đề do máy tự khớp theo
// tên đó ([suggestThemesForOwnedSkill]). Tệp vẫn nằm ở `{uid}/cert-*` và KHÔNG
// thành một dòng `wr_context_documents`, nên không chiếm suất tài liệu JD.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/wr_owned_skill_repository.dart';
import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/logic/wr_owned_skill_match.dart';
import '../../../../core/models/wr_intelligence.dart' show PracticeTheme;
import '../../../../core/models/wr_owned_skill.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../growth_providers.dart';
import '../../owned_skill_providers.dart';
import '../wr_owned_skill_sheet.dart' show ownedSkillFilePickerProvider;
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

/// Tên mục suy từ tên file: bỏ đuôi, gạch nối / gạch dưới thành dấu cách.
String ownedSkillTitleFromFileName(String fileName) {
  var name = fileName.trim();
  final dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  name = name
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.isEmpty) return tr('Chứng chỉ', 'Certificate');
  return name.length > kOwnedSkillTitleMax
      ? name.substring(0, kOwnedSkillTitleMax).trim()
      : name;
}

class WrOwnedSkillsSection extends ConsumerStatefulWidget {
  const WrOwnedSkillsSection({super.key});

  @override
  ConsumerState<WrOwnedSkillsSection> createState() =>
      _WrOwnedSkillsSectionState();
}

class _WrOwnedSkillsSectionState extends ConsumerState<WrOwnedSkillsSection> {
  bool _busy = false;
  String? _error;

  Future<void> _upload() async {
    setState(() => _error = null);
    try {
      final picked = await ref.read(ownedSkillFilePickerProvider)();
      if (picked == null || !mounted) return;
      setState(() => _busy = true);
      // Chờ nạp xong thư viện chủ đề: khối này không `watch` nó, đọc giá trị
      // tức thời thì lần đầu luôn rỗng và mục mới không khớp chủ đề nào.
      final themes = await ref
          .read(practiceThemesProvider.future)
          .catchError((_) => const <PracticeTheme>[]);
      final title = ownedSkillTitleFromFileName(picked.name);
      final repo = ref.read(wrOwnedSkillRepositoryProvider);
      final path = await repo.uploadAttachment(picked.bytes, picked.ext);
      await repo.add(
        WrOwnedSkill(
          id: '',
          kind: OwnedSkillKind.certificate,
          title: title,
          filePath: path,
          themeIds: suggestThemesForOwnedSkill(title, themes),
          createdAt: DateTime.now(),
        ),
      );
      ref.invalidate(wrOwnedSkillsProvider);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Chưa tải lên được. Bạn thử lại giúp nhé.',
            'Could not upload. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(WrOwnedSkill skill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(wrKeepCompounds(tr('Xoá mục này?', 'Delete this item?'))),
        content: Text(
          wrKeepCompounds(
            tr(
              'App sẽ có thể gợi ý lại các chủ đề gắn với mục này.',
              'The app may suggest the themes linked to it again.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(wrKeepCompounds(tr('Huỷ', 'Cancel'))),
          ),
          TextButton(
            key: const Key('wr_owned_skill_delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              wrKeepCompounds(tr('Xoá', 'Delete')),
              style: const TextStyle(color: WrColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(wrOwnedSkillRepositoryProvider).delete(skill);
      ref.invalidate(wrOwnedSkillsProvider);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Chưa xoá được. Bạn thử lại giúp nhé.',
            'Could not delete. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(wrOwnedSkillsProvider).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WrParagraph(
          tr(
            'Đính kèm chứng chỉ, khoá học bạn đã có để hệ thống hiểu năng lực '
                'hiện tại và không gợi ý lại những kỹ năng đó.',
            'Attach the certificates and courses you already have so the '
                'system knows your current skills and does not suggest them '
                'again.',
          ),
          style: const TextStyle(
            fontSize: 14,
            color: WrColors.text2,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 11),
        for (final s in skills)
          _OwnedSkillTile(
            key: Key('wr_work_info_owned_skill_${s.id}'),
            skill: s,
            onDelete: _busy ? null : () => _delete(s),
          ),
        OutlinedButton.icon(
          key: const Key('wr_work_info_owned_skill_add'),
          onPressed: _busy ? null : _upload,
          style: OutlinedButton.styleFrom(
            foregroundColor: WrColors.navy,
            padding: const EdgeInsets.symmetric(vertical: 11),
            side: const BorderSide(color: WrColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded, size: 18),
          label: Text(
            wrKeepCompounds(
              _busy
                  ? tr('Đang tải lên…', 'Uploading…')
                  : tr('Tải lên chứng chỉ', 'Upload a certificate'),
            ),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            wrKeepCompounds(_error!),
            key: const Key('wr_work_info_owned_skill_error'),
            style: const TextStyle(fontSize: 13.5, color: WrColors.coral),
          ),
        ],
      ],
    );
  }
}

/// Một mục đã đính kèm: biểu tượng + tên + nút xoá. Không mở form sửa nữa.
class _OwnedSkillTile extends StatelessWidget {
  const _OwnedSkillTile({super.key, required this.skill, this.onDelete});

  final WrOwnedSkill skill;
  final VoidCallback? onDelete;

  IconData get _icon => switch (skill.kind) {
    OwnedSkillKind.certificate => Icons.workspace_premium_outlined,
    OwnedSkillKind.course => Icons.school_outlined,
    OwnedSkillKind.skill => Icons.handyman_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: WrColors.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: WrColors.teal.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 18, color: WrColors.teal),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              wrKeepCompounds(skill.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            key: Key('wr_owned_skill_delete_${skill.id}'),
            tooltip: tr('Xoá', 'Delete'),
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 17, color: WrColors.muted),
          ),
        ],
      ),
    );
  }
}

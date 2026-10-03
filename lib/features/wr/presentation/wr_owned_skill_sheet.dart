// Sheet thêm / sửa một chứng chỉ, khoá học hoặc kỹ năng đã có (họp khách
// 01/10/2026, Task D2).
//
// Gõ tên xong là app ĐỀ XUẤT chủ đề tương ứng (tối đa 3, tích sẵn) để người
// dùng xác nhận. Bỏ tích thì không gắn; tên không khớp gì thì không gợi ý gì,
// người dùng tự chọn trong danh sách đầy đủ nếu muốn.
//
// Mặc định Q5 (khách chưa trả lời): khai tay mở cho mọi gói. Tệp đính kèm chỉ
// được lưu lại, app CHƯA đọc nội dung tệp (AI đọc chứng chỉ để sau, Premium).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wr_owned_skill_repository.dart';
import '../../../core/data/wr_repository.dart' show kContextDocExtensions;
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_owned_skill_match.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/models/wr_owned_skill.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_title_text.dart';
import '../growth_providers.dart';
import '../owned_skill_providers.dart';

/// Một tệp đã chọn.
typedef PickedOwnedSkillFile = ({String name, String ext, List<int> bytes});

/// Hàm chọn tệp. Bơm được trong test qua [ownedSkillFilePickerProvider].
typedef OwnedSkillFilePicker = Future<PickedOwnedSkillFile?> Function();

Future<PickedOwnedSkillFile?> _pickWithFilePicker() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: kContextDocExtensions,
    withData: true,
  );
  final file = result?.files.firstOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return (
    name: file.name,
    ext: (file.extension ?? file.name.split('.').last).toLowerCase(),
    bytes: bytes,
  );
}

final ownedSkillFilePickerProvider = Provider<OwnedSkillFilePicker>(
  (ref) => _pickWithFilePicker,
);

/// Mở sheet. [existing] khác null là sửa mục đó.
Future<void> showOwnedSkillSheet(
  BuildContext context, {
  WrOwnedSkill? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WrColors.pageBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => WrOwnedSkillSheet(existing: existing),
  );
}

class WrOwnedSkillSheet extends ConsumerStatefulWidget {
  const WrOwnedSkillSheet({super.key, this.existing});

  final WrOwnedSkill? existing;

  @override
  ConsumerState<WrOwnedSkillSheet> createState() => _WrOwnedSkillSheetState();
}

class _WrOwnedSkillSheetState extends ConsumerState<WrOwnedSkillSheet> {
  late final TextEditingController _title;
  late final TextEditingController _issuer;
  late OwnedSkillKind _kind;
  DateTime? _completedOn;

  /// Tệp vừa chọn, chưa tải lên. Tải lên lúc bấm Lưu.
  PickedOwnedSkillFile? _picked;

  /// Tệp đã lưu từ trước (khi sửa).
  String? _existingPath;

  /// Chủ đề đang tích.
  final Set<String> _selected = {};

  /// Chủ đề người dùng đã tự bấm vào. Gợi ý mới khi sửa tên KHÔNG được đè lên
  /// lựa chọn của họ.
  final Set<String> _touched = {};

  /// Gợi ý theo tên hiện tại.
  List<String> _suggested = const [];

  bool _showAllThemes = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _issuer = TextEditingController(text: e?.issuer ?? '');
    _kind = e?.kind ?? OwnedSkillKind.certificate;
    _completedOn = e?.completedOn;
    _existingPath = e?.filePath;
    if (e != null) {
      // Mở lại đúng những gì người dùng đã xác nhận, coi như đã tự chọn.
      _selected.addAll(e.themeIds);
      _touched.addAll(e.themeIds);
    }
    _title.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _title
      ..removeListener(_onTitleChanged)
      ..dispose();
    _issuer.dispose();
    super.dispose();
  }

  List<PracticeTheme> get _themes =>
      ref.read(practiceThemesProvider).valueOrNull ?? const [];

  void _onTitleChanged() {
    final next = suggestThemesForOwnedSkill(_title.text, _themes);
    setState(() {
      // Bỏ gợi ý cũ chưa ai đụng tới, thêm gợi ý mới (tích sẵn để xác nhận).
      for (final id in _suggested) {
        if (!_touched.contains(id)) _selected.remove(id);
      }
      for (final id in next) {
        if (!_touched.contains(id)) _selected.add(id);
      }
      _suggested = next;
    });
  }

  void _toggle(String themeId, bool on) {
    setState(() {
      _touched.add(themeId);
      on ? _selected.add(themeId) : _selected.remove(themeId);
    });
  }

  bool get _canSave => !_busy && _title.text.trim().isNotEmpty;

  Future<void> _pickFile() async {
    try {
      final f = await ref.read(ownedSkillFilePickerProvider)();
      if (f != null && mounted) setState(() => _picked = f);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Chưa mở được tệp. Bạn thử lại giúp nhé.',
            'Could not open the file. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _completedOn ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
    );
    if (d != null && mounted) setState(() => _completedOn = d);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(wrOwnedSkillRepositoryProvider);
      var path = _existingPath;
      final picked = _picked;
      if (picked != null) {
        path = await repo.uploadAttachment(picked.bytes, picked.ext);
      }
      // Giữ thứ tự thư viện cho ổn định.
      final ids = [
        for (final t in _themes)
          if (_selected.contains(t.themeId)) t.themeId,
        for (final id in _selected)
          if (!_themes.any((t) => t.themeId == id)) id,
      ];
      final skill = WrOwnedSkill(
        id: widget.existing?.id ?? '',
        kind: _kind,
        title: _title.text.trim(),
        issuer: _issuer.text.trim().isEmpty ? null : _issuer.text.trim(),
        completedOn: _completedOn,
        filePath: path,
        themeIds: ids,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      final existing = widget.existing;
      if (existing == null) {
        await repo.add(skill);
      } else {
        await repo.update(existing.id, skill);
      }
      ref.invalidate(wrOwnedSkillsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Chưa lưu được. Bạn thử lại giúp nhé.',
            'Could not save. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xoá mục này?', 'Delete this item?')),
        content: Text(
          tr(
            'App sẽ có thể gợi ý lại các chủ đề gắn với mục này.',
            'The app may suggest the themes linked to it again.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Huỷ', 'Cancel')),
          ),
          TextButton(
            key: const Key('wr_owned_skill_delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              tr('Xoá', 'Delete'),
              style: const TextStyle(color: WrColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(wrOwnedSkillRepositoryProvider).delete(existing);
      ref.invalidate(wrOwnedSkillsProvider);
      if (mounted) Navigator.of(context).pop();
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

  String _hintFor(OwnedSkillKind k) => switch (k) {
    OwnedSkillKind.certificate => tr(
      'Ví dụ: Chứng chỉ Quản lý dự án PMP',
      'For example: PMP project management certificate',
    ),
    OwnedSkillKind.course => tr(
      'Ví dụ: Khoá kỹ năng thuyết trình',
      'For example: Presentation skills course',
    ),
    OwnedSkillKind.skill => tr(
      'Ví dụ: Đàm phán với khách hàng',
      'For example: Negotiating with clients',
    ),
  };

  String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final byId = {for (final t in themes) t.themeId: t};
    final visibleIds = <String>[
      ..._suggested,
      for (final id in _selected)
        if (!_suggested.contains(id)) id,
      if (_showAllThemes)
        for (final t in themes)
          if (!t.isRetired &&
              !_suggested.contains(t.themeId) &&
              !_selected.contains(t.themeId))
            t.themeId,
    ];
    final hasTitle = _title.text.trim().isNotEmpty;
    final fileName = _picked?.name ?? _existingPath?.split('/').last;

    InputDecoration fieldDecoration(String hint) => InputDecoration(
      border: InputBorder.none,
      counterText: '',
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14.5, color: WrColors.muted),
    );

    BoxDecoration box() => BoxDecoration(
      color: WrColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: WrColors.line),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              WrTitleText(
                widget.existing == null
                    ? tr('Thêm thứ bạn đã có', 'Add something you have')
                    : tr('Sửa mục đã khai', 'Edit this item'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: WrColors.navy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in OwnedSkillKind.values)
                    ChoiceChip(
                      key: Key('wr_owned_skill_kind_${k.dbValue}'),
                      label: Text(k.label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                      selectedColor: WrColors.navy.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: _kind == k
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: WrColors.navy,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: box(),
                child: TextField(
                  key: const Key('wr_owned_skill_title'),
                  controller: _title,
                  maxLength: kOwnedSkillTitleMax,
                  style: const TextStyle(fontSize: 15.5, color: WrColors.navy),
                  decoration: fieldDecoration(_hintFor(_kind)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: box(),
                child: TextField(
                  key: const Key('wr_owned_skill_issuer'),
                  controller: _issuer,
                  maxLength: kOwnedSkillIssuerMax,
                  style: const TextStyle(fontSize: 15.5, color: WrColors.navy),
                  decoration: fieldDecoration(
                    tr('Đơn vị cấp (không bắt buộc)', 'Issued by (optional)'),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    key: const Key('wr_owned_skill_date'),
                    onPressed: _busy ? null : _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    style: TextButton.styleFrom(foregroundColor: WrColors.navy),
                    label: Text(
                      _completedOn == null
                          ? tr(
                              'Ngày hoàn thành (không bắt buộc)',
                              'Completion date (optional)',
                            )
                          : _dateLabel(_completedOn!),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('wr_owned_skill_attach'),
                    onPressed: _busy ? null : _pickFile,
                    icon: const Icon(Icons.attach_file, size: 18),
                    style: TextButton.styleFrom(foregroundColor: WrColors.navy),
                    label: Text(
                      fileName ??
                          tr(
                            'Đính kèm tệp (không bắt buộc)',
                            'Attach a file (optional)',
                          ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              Text(
                tr(
                  'Tệp chỉ được lưu lại cho bạn, app chưa đọc nội dung tệp.',
                  'The file is only kept for you; the app does not read it.',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: WrColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              WrEyebrow(tr('CHỦ ĐỀ TƯƠNG ỨNG', 'MATCHING THEMES')),
              const SizedBox(height: 6),
              Text(
                tr(
                  'App gợi ý từ tên bạn nhập và sẽ không đề xuất lại các chủ đề '
                      'đã tích. Bỏ tích nếu không đúng.',
                  'Suggested from the name you typed. Ticked themes will not '
                      'be suggested to you again. Untick any that do not fit.',
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  color: WrColors.muted,
                  height: 1.5,
                ),
              ),
              if (hasTitle && _suggested.isEmpty && _selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    tr(
                      'Chưa thấy chủ đề nào khớp với tên này.',
                      'No theme matches this name yet.',
                    ),
                    key: const Key('wr_owned_skill_no_suggestion'),
                    style: const TextStyle(fontSize: 14, color: WrColors.navy),
                  ),
                ),
              for (final id in visibleIds)
                if (byId[id] case final t?)
                  CheckboxListTile(
                    key: Key('wr_owned_skill_theme_$id'),
                    value: _selected.contains(id),
                    onChanged: _busy ? null : (v) => _toggle(id, v ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: WrColors.navy,
                    title: Text(
                      t.title,
                      style: const TextStyle(
                        fontSize: 15,
                        color: WrColors.navy,
                      ),
                    ),
                  ),
              TextButton(
                key: const Key('wr_owned_skill_more_themes'),
                onPressed: () =>
                    setState(() => _showAllThemes = !_showAllThemes),
                style: TextButton.styleFrom(
                  foregroundColor: WrColors.navy,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  _showAllThemes
                      ? tr('Thu gọn danh sách chủ đề', 'Show fewer themes')
                      : tr('Chọn chủ đề khác', 'Pick another theme'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 13.5, color: WrColors.coral),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('wr_owned_skill_save'),
                  onPressed: _canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.coral,
                    foregroundColor: WrColors.navy,
                    disabledBackgroundColor: WrColors.coral.withValues(
                      alpha: 0.3,
                    ),
                    disabledForegroundColor: WrColors.navy.withValues(
                      alpha: 0.45,
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _busy ? tr('Đang lưu…', 'Saving…') : tr('Lưu', 'Save'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    key: const Key('wr_owned_skill_delete'),
                    onPressed: _busy ? null : _delete,
                    child: Text(
                      tr('Xoá mục này', 'Delete this item'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: WrColors.destructive,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

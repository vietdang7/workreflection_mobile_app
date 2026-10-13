// Bối cảnh công việc — script Sprint 2 `screenJobContext` + `ROLE_FIELDS`.
//
// Hai khối:
//
//   1. VAI TRÒ — ba trường Vị trí công việc · Kiến thức chuyên môn · Kỹ năng
//      chuyên môn. Mỗi lần sửa là một bản ghi MỚI (`wr_work_context_history`),
//      không đè bản cũ; người dùng xem lại được đường đi của vai trò.
//   2. TÀI LIỆU — đính kèm JD/CV (màn Tài liệu bối cảnh, AI đọc tài liệu) và
//      lối vào "Phác thảo theo gợi ý" (JD builder).
//
// ĐỒNG BỘ `role_text`. Trợ lý trò chuyện, Cơ hội phát triển, gợi ý chủ đề, đối
// chiếu kỹ năng và `wr-doc-analyze` đều đọc `wr_mobile_profiles.role_text`. Mỗi
// lần lưu "Vị trí công việc", giá trị mới cũng được ghi về `role_text`, nên mọi
// nơi đọc cũ vẫn chạy mà không phải sửa.
//
// Bên dưới giữ khối "Chứng chỉ, khoá học, kỹ năng đã có" (họp khách 01/10,
// Task D2) — tính năng đã chốt, script không có nhưng không mâu thuẫn.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/data/wr_work_context_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';
import 'widgets/wr_owned_skills_section.dart';

/// Lịch sử ba trường VAI TRÒ, đã gom theo trường (mới nhất trước).
///
/// Đọc lỗi (mạng, hoặc bảng chưa có trên máy chủ) thì coi như chưa có gì — màn
/// vẫn mở được để người dùng điền.
final wrWorkContextHistoryProvider =
    FutureProvider<Map<WrWorkContextField, List<WrWorkContextEntry>>>((
      ref,
    ) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return groupWorkContextHistory(const []);
      try {
        final rows = await ref
            .watch(wrWorkContextRepositoryProvider)
            .listHistory();
        return groupWorkContextHistory(rows);
      } catch (_) {
        return groupWorkContextHistory(const []);
      }
    });

/// Nhãn, gợi ý và ví dụ của từng trường — `ROLE_FIELDS` của script.
///
/// Kiến thức = thứ mình BIẾT. Kỹ năng = thứ mình LÀM ĐƯỢC.
({String label, String hint, String placeholder}) workContextFieldCopy(
  WrWorkContextField f,
) => switch (f) {
  WrWorkContextField.position => (
    label: tr('Vị trí công việc', 'Job position'),
    hint: tr(
      'Chức danh, phạm vi phụ trách, báo cáo cho ai.',
      'Job title, scope of responsibility, who you report to.',
    ),
    placeholder: tr(
      'Ví dụ:\n– Trưởng nhóm CSKH, 5 nhân sự\n– Phụ trách hotline và Zalo OA\n'
          '– Báo cáo cho Giám đốc Vận hành',
      'For example:\n– Customer service lead, team of 5\n– In charge of the '
          'hotline and Zalo OA\n– Reports to the Operations Director',
    ),
  ),
  WrWorkContextField.knowledge => (
    label: tr('Kiến thức chuyên môn', 'Professional knowledge'),
    hint: tr(
      'Những thứ bạn phải nắm mới làm được việc. Mỗi dòng một ý.',
      'What you need to know to do the job. One idea per line.',
    ),
    placeholder: tr(
      'Ví dụ:\n– Quy trình xử lý khiếu nại, hoàn tiền\n– Chính sách bảo hành ba '
          'dòng sản phẩm\n– Cách tính chỉ số hài lòng (CSAT)',
      'For example:\n– Complaint and refund process\n– Warranty policy for '
          'three product lines\n– How satisfaction scores (CSAT) are worked out',
    ),
  ),
  WrWorkContextField.skill => (
    label: tr('Kỹ năng chuyên môn', 'Professional skills'),
    hint: tr(
      'Những việc bạn tự làm được, không cần ai hướng dẫn. Mỗi dòng một ý.',
      'What you can do on your own, without anyone guiding you. One idea per '
          'line.',
    ),
    placeholder: tr(
      'Ví dụ:\n– Dựng báo cáo tuần trên Excel bằng pivot\n– Kèm nhân viên mới '
          'hai tuần đầu\n– Thương lượng gia hạn hợp đồng',
      'For example:\n– Build the weekly report in Excel with pivots\n– Coach '
          'new staff through their first two weeks\n– Negotiate contract '
          'renewals',
    ),
  ),
};

/// "dd/mm/yyyy" theo giờ máy — `roleDateLabel()` của script.
String workContextDateLabel(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')}/${l.year}';
}

class WrWorkInfoScreen extends ConsumerStatefulWidget {
  const WrWorkInfoScreen({super.key});

  @override
  ConsumerState<WrWorkInfoScreen> createState() => _WrWorkInfoScreenState();
}

class _WrWorkInfoScreenState extends ConsumerState<WrWorkInfoScreen> {
  /// Trường đang mở ô sửa (`state.roleEditing` của script). Mỗi lúc một trường.
  WrWorkContextField? _editing;

  /// Trường đang xổ lịch sử (`state.roleHistoryOpen`).
  WrWorkContextField? _historyOpen;

  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing(WrWorkContextField f) {
    setState(() {
      _editing = f;
      _error = null;
      _controller.clear();
    });
  }

  /// Ghi thêm một bản cho trường đang sửa. Ô trống thì chỉ đóng ô, không ghi.
  ///
  /// Trả về true khi đã ghi (hoặc không có gì để ghi).
  Future<bool> _saveEditing() async {
    final field = _editing;
    if (field == null || _busy) return true;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _editing = null);
      return true;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (field == WrWorkContextField.position) {
        // `role_text` là nơi mọi tính năng cũ đọc vai trò — ghi trước, để dù
        // phần lịch sử có trục trặc thì vai trò mới vẫn tới được trợ lý và gợi
        // ý.
        await ref.read(wrRepositoryProvider).saveRoleText(text);
        ref.invalidate(wrRoleTextProvider);
        // Gợi ý đang hiện được dựng từ role_text cũ — bỏ để lần đọc sau tính lại.
        ref.invalidate(wrGrowthOpportunityProvider);
      }
      await ref.read(wrWorkContextRepositoryProvider).addEntry(field, text);
      ref.invalidate(wrWorkContextHistoryProvider);
      if (mounted) setState(() => _editing = null);
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Không lưu được. Thử lại.',
            'Could not save. Try again.',
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Nút "Lưu" cuối khối — script `saveRoleAll`: ghi nốt ô đang mở, báo số
  /// mục đã có, rồi quay về.
  Future<void> _saveAll() async {
    final ok = await _saveEditing();
    if (!ok || !mounted) return;
    final history = await ref.read(wrWorkContextHistoryProvider.future);
    final role = (await ref.read(wrRoleTextProvider.future))?.trim() ?? '';
    final filled = WrWorkContextField.values
        .where(
          (f) =>
              (history[f]?.isNotEmpty ?? false) ||
              (f == WrWorkContextField.position && role.isNotEmpty),
        )
        .length;
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const Key('wr_work_info_saved'),
        content: Text(
          wrKeepCompounds(filled == 0
              ? tr('Chưa có mục nào được điền.', 'Nothing filled in yet.')
              : tr(
                  'Đã lưu bối cảnh công việc ($filled mục). Gợi ý thực hành '
                      'sẽ bám sát hơn.',
                  'Work context saved ($filled items). Practice suggestions '
                      'will fit more closely.',
                )),
        ),
      ),
    );
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final history =
        ref.watch(wrWorkContextHistoryProvider).valueOrNull ??
        groupWorkContextHistory(const []);
    // Người viết vai trò trước khi có bảng lịch sử (hoặc khi bảng chưa đọc
    // được): `role_text` vẫn là vị trí hiện tại của họ.
    final legacyRole = ref.watch(wrRoleTextProvider).valueOrNull?.trim();
    final hasLegacyRole = legacyRole != null && legacyRole.isNotEmpty;

    return WrInnerBandBackdrop(
      art: WrHeroArt.act,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          foregroundColor: WrColors.navy,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 40),
            children: [
              Text(
                wrKeepCompounds(tr('GIÚP GỢI Ý CHÍNH XÁC HƠN', 'FOR MORE ACCURATE SUGGESTIONS')),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: WrColors.eyebrow,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                wrKeepCompounds(tr('Bối cảnh công việc', 'Work context')),
                key: const Key('wr_work_info_title'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WrColors.navy,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              WrParagraph(
                tr(
                  'Chia sẻ thêm vài dòng về vai trò hiện tại của bạn. Dựa vào '
                      'đây các bài thực hành sẽ được phác thảo gần hơn với '
                      'công việc của bạn.',
                  'Share a few lines about your current role. From this, the '
                      'practice exercises are shaped closer to your work.',
                ),
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.6,
                  color: WrColors.text2,
                ),
              ),
              const SizedBox(height: 18),

              // ── 1. VAI TRÒ ─────────────────────────────────────────────
              WrCard(
                key: const Key('wr_work_info_role_card'),
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      wrKeepCompounds(tr('VAI TRÒ', 'ROLE')),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: WrColors.navy,
                      ),
                    ),
                    for (final f in WrWorkContextField.values)
                      _RoleField(
                        field: f,
                        history: history[f] ?? const [],
                        legacy: f == WrWorkContextField.position && hasLegacyRole
                            ? legacyRole
                            : null,
                        isLast: f == WrWorkContextField.values.last,
                        editing: _editing == f,
                        historyOpen: _historyOpen == f,
                        controller: _controller,
                        busy: _busy,
                        onEdit: () => _startEditing(f),
                        onCancel: () => setState(() => _editing = null),
                        onSave: _saveEditing,
                        onToggleHistory: () => setState(
                          () => _historyOpen = _historyOpen == f ? null : f,
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        wrKeepCompounds(_error!),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton(
                      key: const Key('wr_work_info_save'),
                      onPressed: _busy ? null : _saveAll,
                      style: _primaryStyle,
                      child: Text(
                        wrKeepCompounds(_busy ? tr('Đang lưu…', 'Saving…') : tr('Lưu', 'Save')),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 2. TÀI LIỆU ────────────────────────────────────────────
              const _DocumentsCard(),

              const SizedBox(height: 28),
              const WrOwnedSkillsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

final ButtonStyle _primaryStyle = ElevatedButton.styleFrom(
  backgroundColor: WrColors.coral,
  foregroundColor: WrColors.navy,
  padding: const EdgeInsets.symmetric(vertical: 11),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  elevation: 0,
);

final ButtonStyle _ghostStyle = OutlinedButton.styleFrom(
  foregroundColor: WrColors.navy,
  padding: const EdgeInsets.symmetric(vertical: 11),
  side: const BorderSide(color: WrColors.line),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

const _tealAction = TextStyle(
  fontSize: 12.5,
  fontWeight: FontWeight.w700,
  color: WrColors.pillTealText,
);

const _tinyMuted = TextStyle(fontSize: 12.5, color: WrColors.text3, height: 1.5);

/// Một trường của khối VAI TRÒ — `field(key)` trong script.
class _RoleField extends StatelessWidget {
  const _RoleField({
    required this.field,
    required this.history,
    required this.legacy,
    required this.isLast,
    required this.editing,
    required this.historyOpen,
    required this.controller,
    required this.busy,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
    required this.onToggleHistory,
  });

  final WrWorkContextField field;

  /// Mới nhất trước.
  final List<WrWorkContextEntry> history;

  /// `role_text` khi trường Vị trí chưa có bản nào trong lịch sử.
  final String? legacy;

  final bool isLast;
  final bool editing;
  final bool historyOpen;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onToggleHistory;

  @override
  Widget build(BuildContext context) {
    final copy = workContextFieldCopy(field);
    final cur = history.isNotEmpty ? history.first : null;
    final curText = cur?.value ?? legacy;
    final older = history.length > 1 ? history.sublist(1) : const [];
    final key = field.dbValue;

    return Container(
      key: Key('wr_work_info_field_$key'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: WrColors.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  wrKeepCompounds(copy.label),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: WrColors.navy,
                  ),
                ),
              ),
              if (!editing)
                GestureDetector(
                  key: Key('wr_work_info_edit_$key'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      wrKeepCompounds(curText != null
                          ? tr('Điều chỉnh', 'Adjust')
                          : tr('Thêm', 'Add')),
                      style: _tealAction,
                    ),
                  ),
                ),
            ],
          ),
          if (editing) ...[
            const SizedBox(height: 3),
            Text(wrKeepCompounds(copy.hint), style: _tinyMuted),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: WrColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WrColors.line),
              ),
              child: TextField(
                key: Key('wr_work_info_input_$key'),
                controller: controller,
                autofocus: true,
                minLines: 5,
                maxLines: 10,
                style: const TextStyle(
                  fontSize: 15,
                  color: WrColors.navy,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: copy.placeholder,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: WrColors.text3,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            if (curText != null) ...[
              const SizedBox(height: 6),
              Text(
                wrKeepCompounds(tr(
                  'Nội dung cũ vẫn được giữ lại. Lần này được ghi thêm, không '
                      'đè lên.',
                  'Your earlier text is kept. This one is added, not written '
                      'over it.',
                )),
                style: _tinyMuted,
              ),
            ],
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: Key('wr_work_info_record_$key'),
                    onPressed: busy ? null : onSave,
                    style: _primaryStyle,
                    child: Text(
                      wrKeepCompounds(tr('Ghi lại', 'Record')),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: Key('wr_work_info_cancel_$key'),
                    onPressed: busy ? null : onCancel,
                    style: _ghostStyle,
                    child: Text(
                      wrKeepCompounds(tr('Bỏ qua', 'Skip')),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (curText != null) ...[
            const SizedBox(height: 6),
            WrParagraph(
              curText,
              key: Key('wr_work_info_current_$key'),
              style: const TextStyle(
                fontSize: 14.5,
                color: WrColors.navy,
                height: 1.55,
              ),
              textAlign: TextAlign.start,
            ),
            if (cur != null) ...[
              const SizedBox(height: 4),
              Text(
                wrKeepCompounds(tr(
                  'Cập nhật ${workContextDateLabel(cur.createdAt)}',
                  'Updated ${workContextDateLabel(cur.createdAt)}',
                )),
                style: _tinyMuted,
              ),
            ],
          ] else ...[
            const SizedBox(height: 5),
            Text(
              wrKeepCompounds(copy.hint),
              style: const TextStyle(
                fontSize: 14,
                color: WrColors.text2,
                height: 1.5,
              ),
            ),
          ],
          if (older.isNotEmpty && !editing) ...[
            if (historyOpen) ...[
              const SizedBox(height: 9),
              Container(
                key: Key('wr_work_info_history_$key'),
                padding: const EdgeInsets.only(left: 11),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: WrColors.lineSoft, width: 2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final h in older)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wrKeepCompounds(workContextDateLabel(h.createdAt)),
                              style: _tinyMuted,
                            ),
                            const SizedBox(height: 1),
                            WrParagraph(
                              h.value,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: WrColors.text2,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                key: Key('wr_work_info_history_toggle_$key'),
                behavior: HitTestBehavior.opaque,
                onTap: onToggleHistory,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(wrKeepCompounds(tr('Thu gọn', 'Collapse')), style: _tealAction),
                ),
              ),
            ] else
              GestureDetector(
                key: Key('wr_work_info_history_toggle_$key'),
                behavior: HitTestBehavior.opaque,
                onTap: onToggleHistory,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    wrKeepCompounds(tr(
                      '${older.length} lần cập nhật trước ›',
                      '${older.length} earlier updates ›',
                    )),
                    style: _tealAction,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Khối TÀI LIỆU — đính kèm JD (AI đọc ở màn Tài liệu bối cảnh) và lối vào
/// JD builder.
class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(wrContextDocumentsProvider).valueOrNull ?? const [];
    final latest = docs.isEmpty ? null : docs.first;
    final fileName = latest?.filePath.split('/').last;

    return WrCard(
      key: const Key('wr_work_info_documents_card'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            wrKeepCompounds(tr('TÀI LIỆU', 'DOCUMENTS')),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 7),
          WrParagraph(
            tr(
              'Tải lên file Mô tả công việc (JD) để hệ thống gợi ý giúp bám '
                  'sát công việc thật của bạn hơn.',
              'Upload a job description (JD) so the suggestions stay closer to '
                  'the work you really do.',
            ),
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.text2,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 11),
          if (fileName != null)
            InkWell(
              key: const Key('wr_work_info_context_docs_row'),
              borderRadius: BorderRadius.circular(11),
              onTap: () => context.push('/wr/context-docs'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: WrColors.teal.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: WrColors.teal.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: WrColors.teal,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wrKeepCompounds(fileName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: WrColors.navy,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            wrKeepCompounds(tr('Đã đính kèm', 'Attached')),
                            style: _tinyMuted,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: WrColors.text3,
                    ),
                  ],
                ),
              ),
            )
          else
            OutlinedButton(
              key: const Key('wr_work_info_context_docs_row'),
              onPressed: () => context.push('/wr/context-docs'),
              style: _ghostStyle,
              child: Text(
                wrKeepCompounds(tr('Đính kèm tài liệu', 'Attach a document')),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 15),
          Container(height: 1, color: WrColors.lineSoft),
          const SizedBox(height: 13),
          WrParagraph(
            tr(
              'Nếu bạn chưa có JD, hãy cùng phác thảo theo gợi ý.',
              'If you do not have a JD yet, sketch one with the prompts.',
            ),
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.text2,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('wr_work_info_jd_builder_card'),
            onPressed: () => context.push('/wr/jd-builder'),
            style: _ghostStyle,
            child: Text(
              wrKeepCompounds(tr('Phác thảo theo gợi ý', 'Sketch with prompts')),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

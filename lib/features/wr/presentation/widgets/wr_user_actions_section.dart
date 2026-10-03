// "Việc bạn tự đặt" trên tab Phát triển (họp khách 01/10/2026, Task D1).
//
// Người dùng tự gõ một việc nhỏ muốn tập ("Hỏi ý kiến 1 đồng nghiệp mỗi ngày"),
// mỗi ngày bấm "Hôm nay tôi đã làm" một lần, đủ 5 lần thì đánh dấu xong.
//
// ⚠ ĐÂY KHÔNG PHẢI LỜI MỜI THÊM CHỦ ĐỀ. Khách đã bác hai lần mọi khối mời
//   người dùng nhận thêm chủ đề thư viện ở tab này (xem `wr_growth_screen.dart`).
//   Khối này là việc CỦA NGƯỜI DÙNG: không dẫn sang thư viện, không gợi ý chủ
//   đề nào, không tính vào quota, không đổi `practiceEnrollmentsProvider`.
//   Mặc định Q6 (khách chưa trả lời): không giới hạn số việc, không tính vào
//   "Kỹ năng đã hình thành", không lên Hành trình.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/data/wr_user_action_repository.dart';
import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/models/wr_user_action.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/wr_card.dart';
import '../../../../core/widgets/wr_title_text.dart';
import '../../user_action_providers.dart';

class WrUserActionsSection extends ConsumerStatefulWidget {
  const WrUserActionsSection({super.key});

  @override
  ConsumerState<WrUserActionsSection> createState() =>
      _WrUserActionsSectionState();
}

class _WrUserActionsSectionState extends ConsumerState<WrUserActionsSection> {
  final _controller = TextEditingController();

  /// Đang gửi một thao tác: chặn bấm chồng.
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _canAdd => !_busy && _controller.text.trim().isNotEmpty;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(wrUserActionsProvider);
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

  Future<void> _add() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    await _run(() async {
      await ref.read(wrUserActionRepositoryProvider).add(title);
      _controller.clear();
    });
  }

  Future<void> _logToday(WrUserAction a) => _run(() async {
    try {
      await ref.read(wrUserActionRepositoryProvider).logToday(a.id);
    } on PostgrestException catch (e) {
      // Khoá chính (action_id, done_on): hôm nay đã ghi rồi, ví dụ bấm từ máy
      // khác. Kết quả người dùng muốn đã có sẵn, không phải lỗi.
      if (e.code != '23505') rethrow;
    }
  });

  Future<void> _complete(WrUserAction a) =>
      _run(() => ref.read(wrUserActionRepositoryProvider).complete(a.id));

  Future<void> _delete(WrUserAction a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Xoá việc này?', 'Delete this action?')),
        content: Text(
          tr(
            'Những ngày bạn đã ghi cho việc này cũng sẽ mất.',
            'The days you logged for it will be removed too.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Huỷ', 'Cancel')),
          ),
          TextButton(
            key: const Key('wr_growth_user_action_delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              tr('Xoá', 'Delete'),
              style: const TextStyle(color: WrColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(wrUserActionRepositoryProvider).delete(a.id));
  }

  @override
  Widget build(BuildContext context) {
    // Đọc hỏng thì vẫn để ô nhập: mất danh sách không có nghĩa là mất quyền
    // thêm việc mới.
    final actions = ref.watch(wrUserActionsProvider).valueOrNull ?? const [];
    // Đang làm trước, đã xong xuống dưới; trong mỗi nhóm giữ thứ tự mới nhất
    // trước của repo.
    final ordered = [
      ...actions.where((a) => !a.isCompleted),
      ...actions.where((a) => a.isCompleted),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(tr('VIỆC BẠN TỰ ĐẶT', 'YOUR OWN ACTIONS')),
        const SizedBox(height: 6),
        Text(
          tr(
            'Việc nhỏ bạn tự chọn để tập. Không tính vào số chủ đề.',
            'Small things you chose to practise. They do not count as themes.',
          ),
          style: const TextStyle(
            fontSize: 13.5,
            color: WrColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        for (final a in ordered)
          _UserActionCard(
            key: Key('wr_growth_user_action_${a.id}'),
            action: a,
            busy: _busy,
            onLogToday: () => _logToday(a),
            onComplete: () => _complete(a),
            onDelete: () => _delete(a),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          decoration: BoxDecoration(
            color: WrColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WrColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('wr_growth_user_action_input'),
                  controller: _controller,
                  maxLength: kUserActionTitleMax,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _canAdd ? _add() : null,
                  style: const TextStyle(
                    fontSize: 15.5,
                    color: WrColors.navy,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: tr(
                      'Thêm một việc bạn muốn tự thực hành',
                      'Add something you want to practise',
                    ),
                    hintStyle: const TextStyle(
                      fontSize: 14.5,
                      color: WrColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('wr_growth_user_action_add'),
                onPressed: _canAdd ? _add : null,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tr('Thêm', 'Add'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(fontSize: 13.5, color: WrColors.coral),
          ),
        ],
      ],
    );
  }
}

class _UserActionCard extends StatelessWidget {
  const _UserActionCard({
    super.key,
    required this.action,
    required this.busy,
    required this.onLogToday,
    required this.onComplete,
    required this.onDelete,
  });

  final WrUserAction action;
  final bool busy;
  final VoidCallback onLogToday;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final a = action;
    final shown = a.doneCount > a.targetCount ? a.targetCount : a.doneCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WrCardMinimal(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: WrTitleText(
                      a.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: WrColors.pageBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$shown/${a.targetCount}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('wr_growth_user_action_delete_${a.id}'),
                  tooltip: tr('Xoá', 'Delete'),
                  onPressed: busy ? null : onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: WrColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _footer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    final a = action;
    if (a.isCompleted) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle_outlined,
            size: 17,
            color: WrColors.teal,
          ),
          const SizedBox(width: 8),
          Text(
            tr('Đã xong', 'Done'),
            style: const TextStyle(fontSize: 14.5, color: WrColors.muted),
          ),
        ],
      );
    }

    if (a.reachedTarget) {
      return Row(
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 18,
            color: WrColors.teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('Hoàn thành', 'Target reached'),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: WrColors.pillTealText,
              ),
            ),
          ),
          OutlinedButton(
            key: Key('wr_growth_user_action_complete_${a.id}'),
            onPressed: busy ? null : onComplete,
            style: _outlined,
            child: Text(
              tr('Đánh dấu xong', 'Mark as done'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    final today = a.doneToday;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: Key('wr_growth_user_action_done_${a.id}'),
        onPressed: (busy || today) ? null : onLogToday,
        style: _outlined,
        child: Text(
          today
              ? tr('Đã ghi hôm nay', 'Logged today')
              : tr('Hôm nay tôi đã làm', 'Done today'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static final ButtonStyle _outlined = OutlinedButton.styleFrom(
    foregroundColor: WrColors.navy,
    disabledForegroundColor: WrColors.muted,
    side: BorderSide(color: WrColors.navy.withValues(alpha: 0.22)),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

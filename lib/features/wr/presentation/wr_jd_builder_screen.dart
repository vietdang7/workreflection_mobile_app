// "Viết JD cùng app" — 5 buổi ngắn.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §6, mockup v16 `screenJdBuilder`.
//
// Lối vào: thẻ "Công ty chưa có JD? Cùng viết trong 5 buổi ngắn" ở màn Thông
// tin công việc hiện tại (`wr_work_info_screen.dart`).
//
// ---------------------------------------------------------------------------
// Ba chỗ bản thật KHÁC mockup, đúng ba ghi chú cho dev ở §6
// ---------------------------------------------------------------------------
//
//   1. KHÔNG có dãy nút "Buổi 1–5" ở cuối màn. Đó là công cụ xem trước cho
//      demo. Ở đây thanh tiến trình trên đầu bấm được, nhưng chỉ những buổi
//      [canOpenJdDay] cho phép — không nhảy cóc.
//
//   2. "Dừng ở đây, làm tiếp sau" LƯU THẬT nội dung đang gõ, không đánh dấu
//      buổi là xong. Ở mockup nút này vứt hết chữ vừa viết.
//
//   3. Dữ liệu vào bảng `wr_jd_drafts`, không phải local state — để Career
//      Memory, gợi ý Reflection và Cơ hội phát triển đọc lại được.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_jd_repository.dart';
import '../../../core/logic/wr_jd_builder.dart';
import '../../../core/models/wr_jd_draft.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';

/// Bản JD đang có. Null = chưa từng mở màn này.
final wrJdDraftProvider = FutureProvider<WrJdDraft?>((ref) async {
  ref.watch(currentUserIdProvider);
  try {
    return await ref.watch(wrJdRepositoryProvider).fetch();
  } catch (_) {
    // Chưa chạy migration, hoặc mất mạng. Trả null để màn mở ở buổi 1 với ô
    // trống, thay vì chặn người dùng bằng một màn lỗi.
    return null;
  }
});

class WrJdBuilderScreen extends ConsumerStatefulWidget {
  const WrJdBuilderScreen({super.key});

  @override
  ConsumerState<WrJdBuilderScreen> createState() => _WrJdBuilderScreenState();
}

class _WrJdBuilderScreenState extends ConsumerState<WrJdBuilderScreen> {
  /// Một controller cho mỗi cột, dựng theo nhu cầu.
  final _controllers = <String, TextEditingController>{};

  int? _day;
  List<int> _completed = const [];
  bool _seeded = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String column, String? initial) {
    return _controllers.putIfAbsent(
      column,
      () => TextEditingController(text: initial ?? ''),
    );
  }

  WrJdDay get _current => kJdDays[(_day ?? 1) - 1];

  Map<String, String?> _fieldsOfCurrentDay() => {
        for (final f in _current.fields) f.column: _controllers[f.column]?.text,
      };

  Future<void> _save({required bool markDayDone}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(wrJdRepositoryProvider).save(
            day: _day ?? 1,
            fields: _fieldsOfCurrentDay(),
            markDayDone: markDayDone,
          );
      ref.invalidate(wrJdDraftProvider);
      if (!mounted) return;
      if (markDayDone && (_day ?? 1) >= kJdDayCount) {
        // Xong buổi cuối: về lại màn Thông tin công việc.
        context.pop();
        return;
      }
      setState(() {
        _completed = saved.completedDays;
        if (markDayDone) _day = (_day ?? 1) + 1;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Không lưu được. Thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Dừng ở đây, làm tiếp sau" — lưu nháp thật rồi mới rời màn (§6).
  Future<void> _pauseAndLeave() async {
    await _save(markDayDone: false);
    if (mounted && _error == null) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(wrJdDraftProvider);

    // Chốt một lần, và chỉ khi dữ liệu đã về: chốt lúc còn loading sẽ khoá màn
    // ở buổi 1 với ô trống, và người dùng tưởng mình chưa từng viết gì.
    if (!_seeded && !draft.isLoading) {
      final d = draft.valueOrNull ?? WrJdDraft.empty();
      _completed = d.completedDays;
      _day = resumeJdDay(d.currentDay, d.completedDays);
      for (final c in jdColumns()) {
        _controllerFor(c, d[c]);
      }
      _seeded = true;
    }

    if (!_seeded) {
      return const Scaffold(
        backgroundColor: WrColors.pageBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final day = _current;
    final isLast = day.number >= kJdDayCount;

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        foregroundColor: WrColors.navy,
        title: const Text(
          'Viết JD cùng app',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                children: [
                  WrEyebrow(day.eyebrow.toUpperCase()),
                  const SizedBox(height: 8),
                  Text(
                    day.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProgressBar(
                    current: day.number,
                    completed: _completed,
                    onTap: (n) => setState(() => _day = n),
                  ),
                  const SizedBox(height: 20),
                  if (day.intro != null) ...[
                    WrParagraph(
                      day.intro!,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.65,
                        color: WrColors.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  for (final f in day.fields) ...[
                    _Field(
                      field: f,
                      controller: _controllerFor(f.column, null),
                    ),
                    const SizedBox(height: 22),
                  ],
                  if (isLast) _CompletionBanner(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const Key('wr_jd_error'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: WrColors.coral,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('wr_jd_primary'),
                      onPressed: _busy ? null : () => _save(markDayDone: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WrColors.navy,
                        foregroundColor: WrColors.white,
                        disabledBackgroundColor: WrColors.line,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isLast ? 'Hoàn tất, lưu vào hồ sơ' : 'Lưu và tiếp tục',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('wr_jd_pause'),
                    onPressed: _busy ? null : _pauseAndLeave,
                    child: const Text(
                      'Dừng ở đây, làm tiếp sau',
                      style: TextStyle(
                        fontSize: 15.5,
                        color: WrColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Năm vạch tiến trình. Bấm được, nhưng chỉ vào buổi đã mở khoá.
///
/// Thay cho dãy nút "Buổi 1–5" của mockup — thứ §6 nói rõ là chỉ để demo. Ở đây
/// vạch vừa là chỉ báo vừa là lối đi, và buổi bị khoá thì không nhận chạm.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.current,
    required this.completed,
    required this.onTap,
  });

  final int current;
  final List<int> completed;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var n = 1; n <= kJdDayCount; n++) ...[
          if (n > 1) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: canOpenJdDay(n, completed)
                  ? 'Buổi $n'
                  : 'Buổi $n, chưa mở khoá',
              button: true,
              child: GestureDetector(
                key: Key('wr_jd_step_$n'),
                behavior: HitTestBehavior.opaque,
                onTap: canOpenJdDay(n, completed) ? () => onTap(n) : null,
                child: Padding(
                  // Vạch chỉ cao 4px — chạm đúng vào nó thì trượt nhiều hơn
                  // trúng. Đệm dọc để vùng chạm cao đủ ngón tay.
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: n <= current
                          ? WrColors.coral
                          : WrColors.navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.field, required this.controller});

  final WrJdField field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isLine = field.kind == WrJdFieldKind.line;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrParagraph(
          field.label,
          style: TextStyle(
            fontSize: isLine ? 13.5 : 17,
            fontWeight: isLine ? FontWeight.w700 : FontWeight.w600,
            color: WrColors.navy,
            height: 1.4,
          ),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 8),
        if (field.guide != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: WrColors.coral.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: WrParagraph(
              field.guide!,
              style: const TextStyle(
                fontSize: 13.5,
                color: WrColors.navy,
                height: 1.55,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (field.example != null) ...[
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: WrColors.line, width: 2),
              ),
            ),
            child: WrParagraph(
              'VD: ${field.example!}',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: WrColors.text3,
                height: 1.5,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: isLine ? 2 : 6,
          ),
          decoration: BoxDecoration(
            color: WrColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WrColors.line),
          ),
          child: TextField(
            key: Key('wr_jd_field_${field.column}'),
            controller: controller,
            minLines: switch (field.kind) {
              WrJdFieldKind.line => 1,
              WrJdFieldKind.paragraph => 3,
              WrJdFieldKind.list => 5,
            },
            maxLines: switch (field.kind) {
              WrJdFieldKind.line => 1,
              WrJdFieldKind.paragraph => 6,
              WrJdFieldKind.list => 10,
            },
            style: const TextStyle(
              fontSize: 16,
              color: WrColors.navy,
              height: 1.55,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: field.hint,
              hintStyle: const TextStyle(
                fontSize: 15,
                color: WrColors.muted,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Banner cuối buổi 5 — §6: "kết thúc bằng banner xác nhận hoàn tất, giải thích
/// dữ liệu sẽ được dùng để cá nhân hoá gợi ý sau này".
class _CompletionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_jd_completion_note'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: WrColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOÀN TẤT',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: WrColors.cream.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          const WrParagraph(
            kJdCompletionNote,
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: WrColors.cream,
              height: 1.6,
            ),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }
}

// Giai đoạn duy trì + khoảnh khắc kỹ năng hình thành.
//
// Spec: sau khi xong ba bước làm quen, chủ đề mở ra một hành động nhẹ "Tôi vừa
// thực hành điều này hôm nay", bấm lại được nhiều lần theo thời gian. Khi bộ
// đếm chạm ngưỡng, một dấu mốc thật được ghi vào Career Memory và người dùng
// được ăn mừng — "cần được thiết kế như một khoảnh khắc đáng nhớ, không phải
// một dòng chữ lặng lẽ đổi trạng thái".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_skill_formation.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

/// Chủ đề đang được ghi nhận — lượt ghi chưa xong.
final Set<String> _maintainInFlight = {};

/// Chủ đề đã ghi nhận trong phiên này, theo ngày (`themeId` → ngày).
///
/// Danh sách Career Memory được tải lại SAU khi ghi; trong khoảng đó nó chưa có
/// dòng vừa ghi (thậm chí tạm rỗng), nên chỉ dựa vào nó thì cú bấm thứ hai vẫn
/// lọt qua luật một ngày một lần. Máy thật 16/10: bấm lần đầu không thấy gì,
/// bấm thêm thì ghi hai dòng trong nửa giây và kỹ năng "hình thành" sớm.
final Map<String, DateTime> _maintainedThisSession = {};

/// Xoá trí nhớ của phiên — chỉ cho test (mỗi test là một "phiên" mới).
@visibleForTesting
void resetMaintainGuardsForTest() {
  _maintainInFlight.clear();
  _maintainedThisSession.clear();
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Chủ đề này đã được ghi nhận hôm nay trong phiên hiện tại chưa — để nút đổi
/// sang "đã ghi" ngay, không chờ danh sách tải lại.
bool maintainedThisSessionToday(String themeId, DateTime now) {
  final at = _maintainedThisSession[themeId];
  return at != null && _sameDay(at, now);
}

/// Ghi nhận một lần duy trì: "Tôi vừa thực hành điều này hôm nay".
///
/// Một mảnh ký ức trong Career Memory, không phải một ô đếm riêng — cùng nguồn
/// sự thật với hoàn thành bước (luật số 1, Nguyên tắc Logic Dữ liệu).
///
/// Trả true khi đã ghi (hoặc hôm nay đã ghi từ trước).
Future<bool> logPracticeMaintained({
  required BuildContext context,
  required WidgetRef ref,
  required PracticeTheme theme,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return false;
  final now = DateTime.now();
  // Mỗi chủ đề ghi nhận một lần một ngày (script `markKeep`): hai lần trong
  // cùng một ngày vẫn là một ngày có thực hành.
  if (maintainedThisSessionToday(theme.themeId, now)) return true;
  final known = ref.read(practiceMemoryEventsProvider).valueOrNull ?? const [];
  if (maintainedToday(theme, known, now)) return true;
  // Lượt trước của chính chủ đề này còn đang gửi: bỏ qua cú bấm này.
  if (!_maintainInFlight.add(theme.themeId)) return false;
  final contentRepo = ref.read(wrContentRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  try {
    await contentRepo.insertMemoryEvent(
      CareerMemoryEvent(
        id: '',
        userId: userId,
        behavior: kPracticeMaintainedBehavior,
        scaDimension: theme.scaDimension,
        // `themeId` là thứ bộ đếm đọc; `reflectionText` chỉ còn để hiện chữ ở
        // tab Hành trình (Phần C mục 1).
        themeId: theme.themeId,
        // Script `markKeep`: mục Career Memory "Duy trì: ‹chủ đề›". Tiền tố
        // "Duy trì" có trong `wrPracticeLabelMapProvider` nên Hành trình đổi
        // được theo ngôn ngữ đang bật.
        reflectionText: tr('Duy trì: ${theme.title}', 'Upkeep: ${theme.title}'),
      ),
    );
    _maintainedThisSession[theme.themeId] = now;
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          wrKeepCompounds(tr('Chưa ghi nhận được. Thử lại.', 'Could not record it. Try again.')),
        ),
      ),
    );
    return false;
  } finally {
    _maintainInFlight.remove(theme.themeId);
  }

  ref.invalidate(practiceMemoryEventsProvider);
  if (context.mounted) {
    await recordSkillMilestones(context: context, ref: ref, theme: theme);
  }
  return true;
}

/// Ghi dấu mốc cho những kỹ năng vừa hình thành và ăn mừng — đúng một lần.
///
/// Gọi sau MỌI lần bộ đếm tăng: hoàn thành một bước, hoặc ghi nhận duy trì.
/// Đọc lại Career Memory từ máy chủ thay vì tin vào cache: cache có thể còn
/// thiếu chính sự kiện vừa ghi, và ghi dấu mốc hai lần thì tab Hành trình sẽ
/// có hai dòng ăn mừng cho cùng một kỹ năng.
Future<void> recordSkillMilestones({
  required BuildContext context,
  required WidgetRef ref,
  required PracticeTheme theme,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;
  final contentRepo = ref.read(wrContentRepositoryProvider);
  final threshold = ref.read(wrSkillThresholdProvider);

  List<SkillFormation> justFormed;
  try {
    final events = await contentRepo.fetchMemoryEvents(limit: 200);
    final enrollments = await ref.read(practiceEnrollmentsProvider.future);
    justFormed = newlyFormed(
      formations: skillFormations(
        themes: [theme],
        enrollments: enrollments,
        events: events,
        threshold: threshold,
      ),
      events: events,
      themes: [theme],
    );

    for (final skill in justFormed) {
      await contentRepo.insertMemoryEvent(
        CareerMemoryEvent(
          id: '',
          userId: userId,
          behavior: kSkillFormedBehavior,
          scaDimension: skill.scaDimension,
          themeId: skill.themeId,
          reflectionText: skill.title,
        ),
      );
    }
  } catch (_) {
    // Best-effort: lần thực hành sau sẽ ghi lại dấu mốc còn thiếu. Không chặn
    // luồng của người dùng chỉ vì mạng hỏng.
    return;
  }

  if (justFormed.isEmpty) return;
  ref.invalidate(practiceMemoryEventsProvider);

  if (!context.mounted) return;
  for (final skill in justFormed) {
    await showSkillFormedCelebration(context, skill);
    if (!context.mounted) return;
  }
}

/// Khoảnh khắc ăn mừng khi một kỹ năng vừa hình thành.
///
/// Cố ý là một tấm che toàn màn: đây là lúc sản phẩm phản chiếu lại cho người
/// dùng thấy nỗ lực của họ đã thành quả thật. Một snackbar trôi qua trong ba
/// giây không làm được việc đó.
Future<void> showSkillFormedCelebration(
  BuildContext context,
  SkillFormation skill,
) {
  return showDialog<void>(
    context: context,
    barrierColor: WrColors.navy.withValues(alpha: 0.55),
    builder: (context) => Dialog(
      key: const Key('wr_skill_formed_celebration'),
      backgroundColor: WrColors.pageBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: WrColors.teal,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 32,
                  color: WrColors.white,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              wrKeepCompounds(tr('MỘT KỸ NĂNG CỦA BẠN', 'A SKILL OF YOURS')),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: WrColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              wrKeepCompounds(skill.title),
              key: const Key('wr_skill_formed_title'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.3,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            // Câu riêng của chủ đề (bảng A.2) thay cho câu chung chung. Chủ đề
            // chưa có câu riêng — ba chủ đề đời đầu, hoặc migration nội dung
            // chưa chạy — thì lùi về đúng câu chốt ở mục A.1.
            Text(
              wrKeepCompounds(skill.formedLine ??
                  tr(
                    '"${skill.title}" giờ là một kỹ năng của bạn.',
                    '"${skill.title}" is now a skill of yours.',
                  )),
              key: const Key('wr_skill_formed_line'),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 10),
            WrParagraph(
              tr(
                'Bạn đã thực hành điều này ${skill.practiceCount} lần. '
                    'Nó không còn là một việc bạn phải nhớ để làm nữa.',
                'You have practised this ${skill.practiceCount} times. '
                    'It is no longer something you have to remember to do.',
              ),
              style: const TextStyle(
                fontSize: 15.5,
                color: WrColors.muted,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              wrKeepCompounds(tr(
                'Dấu mốc này đã được ghi vào hành trình của bạn.',
                'This marker has been written into your journey.',
              )),
              style: TextStyle(
                fontSize: 14,
                color: WrColors.muted,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wr_skill_formed_close'),
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.navy,
                  foregroundColor: WrColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  wrKeepCompounds(tr('Ghi nhận điều này', 'Record this')),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Nút "Tôi vừa thực hành điều này hôm nay" của giai đoạn duy trì.
///
/// Hiện khi chủ đề đã đi hết ba bước làm quen. Đã bấm hôm nay thì chuyển thành
/// dòng xác nhận, không phải một nút bấm được nhưng không làm gì.
class WrMaintainPracticeAction extends ConsumerStatefulWidget {
  const WrMaintainPracticeAction({super.key, required this.theme, this.onDone});

  final PracticeTheme theme;
  final VoidCallback? onDone;

  @override
  ConsumerState<WrMaintainPracticeAction> createState() =>
      _WrMaintainPracticeActionState();
}

class _WrMaintainPracticeActionState
    extends ConsumerState<WrMaintainPracticeAction> {
  bool _busy = false;

  Future<void> _press() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await logPracticeMaintained(
        context: context,
        ref: ref,
        theme: widget.theme,
      );
      if (ok) widget.onDone?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final events =
        ref.watch(practiceMemoryEventsProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final doneToday =
        maintainedToday(theme, events, now) ||
        maintainedThisSessionToday(theme.themeId, now);

    if (doneToday) {
      return Row(
        key: Key('wr_practice_maintained_today_${theme.themeId}'),
        children: [
          Icon(Icons.check_circle_outlined, size: 17, color: WrColors.teal),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              wrKeepCompounds(tr(
                'Đã ghi nhận hôm nay. Hẹn bạn lần thực hành sau.',
                'Recorded for today. See you at the next practice.',
              )),
              style: TextStyle(
                fontSize: 14.5,
                color: WrColors.muted,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: Key('wr_practice_maintain_${theme.themeId}'),
        onPressed: _busy ? null : _press,
        style: OutlinedButton.styleFrom(
          foregroundColor: WrColors.navy,
          side: BorderSide(color: WrColors.navy.withValues(alpha: 0.22)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          wrKeepCompounds(tr('Tôi vừa thực hành điều này hôm nay', 'I practised this today')),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Nút "Ghi nhận" của một chủ đề đang duy trì (script `markKeep`).
///
/// Mỗi chủ đề một lần một ngày, không huỷ được: bấm rồi thì nút thành
/// [doneLabel] tới hết ngày, mở lại vào hôm sau. Ghi xuống Career Memory qua
/// [logPracticeMaintained], nên tab Phát triển và màn Tâm thế & duy trì đọc
/// cùng một nguồn.
class WrKeepMarkButton extends ConsumerStatefulWidget {
  const WrKeepMarkButton({
    super.key,
    required this.theme,
    required this.markedToday,
    required this.doneLabel,
  });

  final PracticeTheme theme;
  final bool markedToday;
  final String doneLabel;

  @override
  ConsumerState<WrKeepMarkButton> createState() => _WrKeepMarkButtonState();
}

class _WrKeepMarkButtonState extends ConsumerState<WrKeepMarkButton> {
  bool _busy = false;

  bool get _on =>
      widget.markedToday ||
      maintainedThisSessionToday(widget.theme.themeId, DateTime.now());

  Future<void> _mark() async {
    if (_busy || _on) return;
    setState(() => _busy = true);
    try {
      await logPracticeMaintained(
        context: context,
        ref: ref,
        theme: widget.theme,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // `.mark` / `.mark.on` của script: viền teal nhạt, đã ghi thì nền teal.
    // Ghi xong là đổi ngay theo [maintainedThisSessionToday], không chờ danh
    // sách Career Memory tải lại.
    final on = _on;
    return Semantics(
      button: true,
      enabled: !on,
      child: GestureDetector(
        key: Key('wr_keep_mark_${widget.theme.themeId}'),
        behavior: HitTestBehavior.opaque,
        onTap: on || _busy ? null : _mark,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: on ? WrColors.teal : WrColors.teal.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: on ? WrColors.teal : WrColors.teal.withValues(alpha: 0.5),
            ),
          ),
          // Đang gửi: thay chữ bằng vòng xoay cùng cỡ, để cú bấm đầu có phản
          // hồi ngay chứ không im lặng tới khi mạng trả về.
          child: _busy && !on
              ? SizedBox(
                  key: Key('wr_keep_mark_busy_${widget.theme.themeId}'),
                  width: 14,
                  height: 14,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: WrColors.pillTealText,
                  ),
                )
              : Text(
                  wrKeepCompounds(
                    on ? widget.doneLabel : tr('Ghi nhận', 'Record'),
                  ),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: on ? WrColors.white : WrColors.pillTealText,
                  ),
                ),
        ),
      ),
    );
  }
}

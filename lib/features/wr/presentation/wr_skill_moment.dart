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
import '../../../core/logic/wr_skill_formation.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';

/// Ghi nhận một lần duy trì: "Tôi vừa thực hành điều này hôm nay".
///
/// Một mảnh ký ức trong Career Memory, không phải một ô đếm riêng — cùng nguồn
/// sự thật với hoàn thành bước (luật số 1, Nguyên tắc Logic Dữ liệu).
Future<void> logPracticeMaintained({
  required BuildContext context,
  required WidgetRef ref,
  required PracticeTheme theme,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;
  final contentRepo = ref.read(wrContentRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  try {
    await contentRepo.insertMemoryEvent(
      CareerMemoryEvent(
        id: '',
        userId: userId,
        behavior: kPracticeMaintainedBehavior,
        scaDimension: theme.scaDimension,
        reflectionText: '${theme.title} · Duy trì',
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Chưa ghi nhận được. Thử lại.')),
    );
    return;
  }

  ref.invalidate(practiceMemoryEventsProvider);
  if (!context.mounted) return;
  await recordSkillMilestones(context: context, ref: ref, theme: theme);
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
    );

    for (final skill in justFormed) {
      await contentRepo.insertMemoryEvent(
        CareerMemoryEvent(
          id: '',
          userId: userId,
          behavior: kSkillFormedBehavior,
          scaDimension: skill.scaDimension,
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
            const Text(
              'MỘT KỸ NĂNG VỪA HÌNH THÀNH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: WrColors.teal,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              skill.title,
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
            Text(
              'Bạn đã thực hành điều này ${skill.practiceCount} lần. '
              'Nó không còn là một việc bạn phải nhớ để làm nữa.',
              style: const TextStyle(
                fontSize: 14,
                color: WrColors.muted,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Dấu mốc này đã được ghi vào hành trình của bạn.',
              style: TextStyle(
                fontSize: 12.5,
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
                child: const Text(
                  'Ghi nhận điều này',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
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
class WrMaintainPracticeAction extends ConsumerWidget {
  const WrMaintainPracticeAction({
    super.key,
    required this.theme,
    this.onDone,
  });

  final PracticeTheme theme;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(practiceMemoryEventsProvider).valueOrNull ?? const [];
    final doneToday = maintainedToday(theme, events, DateTime.now());

    if (doneToday) {
      return Row(
        key: Key('wr_practice_maintained_today_${theme.themeId}'),
        children: [
          const Icon(Icons.check_circle_outline, size: 17, color: WrColors.teal),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Đã ghi nhận hôm nay. Hẹn bạn lần thực hành sau.',
              style: TextStyle(fontSize: 13, color: WrColors.muted, height: 1.5),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: Key('wr_practice_maintain_${theme.themeId}'),
        onPressed: () async {
          await logPracticeMaintained(
            context: context,
            ref: ref,
            theme: theme,
          );
          onDone?.call();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: WrColors.navy,
          side: BorderSide(color: WrColors.navy.withValues(alpha: 0.22)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Tôi vừa thực hành điều này hôm nay',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

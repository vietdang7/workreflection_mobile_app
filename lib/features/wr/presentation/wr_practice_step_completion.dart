// Hoàn thành một bước thực hành — chuỗi ghi dùng chung.
//
// Trước đây khối này là một closure trong hàm build của WrGrowthScreen, đóng
// kín trên biến `activeTheme`. Từ khi danh sách chủ đề tách sang màn riêng
// (giao diện mẫu Sprint 2), cả tab Phát triển lẫn màn chủ đề đều cần đúng
// chuỗi này: hỏi ghi chú → tiến độ → mảnh ký ức → ghi chú → chứng nhận kỹ
// năng → khép chủ đề. Chép làm đôi thì sửa một bên, bên kia vẫn xanh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/models/wr_mood_content.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_note_sheet.dart';
import 'wr_skill_moment.dart';

/// Đánh dấu [stepId] của [theme] là xong, kèm mọi dấu vết đi theo nó.
///
/// §VII: hỏi ghi chú TRƯỚC khi ghi bất cứ thứ gì. Đóng tấm ghi chú là huỷ hẳn
/// — bước vẫn chưa xong, chứ không phải xong-mà-không-ghi-chú.
Future<void> completePracticeStep({
  required BuildContext context,
  required WidgetRef ref,
  required PracticeTheme theme,
  required PracticeEnrollment enrollment,
  required String stepId,
  required List<PracticeStep> allSteps,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;
  final repo = ref.read(wrIntelligenceRepositoryProvider);
  final contentRepo = ref.read(wrContentRepositoryProvider);
  final entitlement = ref.read(wrEntitlementProvider).valueOrNull ??
      WrEntitlement(plan: WrPlan.free);

  final stepTitle = allSteps
      .where((s) => s.stepId == stepId)
      .map((s) => s.title)
      .firstOrNull;

  final noteResult = await showPracticeNoteSheet(
    context,
    stepTitle: stepTitle ?? 'Bước thực hành',
  );
  if (noteResult == null) return;

  final currentCompleted = enrollment.completedSteps;
  final newCompleted = [...currentCompleted, stepId];
  await repo.updateEnrollmentSteps(
    userId: userId,
    themeId: theme.themeId,
    completedSteps: newCompleted,
  );

  await contentRepo.insertMemoryEvent(
    CareerMemoryEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      behavior: 'practice_step_done',
      // Bộ đếm thực hành đọc `themeId`, không đọc tên (Phần C mục 1).
      themeId: theme.themeId,
      reflectionText: '${theme.title} · ${stepTitle ?? stepId}',
    ),
  );

  // §VII: chỉ khi người dùng thực sự viết mới sinh thêm một mảnh ký ức mang
  // đúng lời của họ. "Bỏ qua" đi thẳng qua khối này.
  final note = noteResult.note?.trim();
  if (noteResult.action == PracticeNoteAction.saveWithNote &&
      note != null &&
      note.isNotEmpty) {
    try {
      await repo.upsertPracticeStepNote(
        PracticeStepNote(userId: userId, stepId: stepId, note: note),
      );
      await contentRepo.insertMemoryEvent(
        CareerMemoryEvent(
          id: '${DateTime.now().millisecondsSinceEpoch}n',
          userId: userId,
          behavior: kPracticeStepNoteBehavior,
          reflectionText: '${stepTitle ?? stepId}: $note',
        ),
      );
    } catch (_) {
      /* best-effort: bước vẫn được đánh dấu xong, không nuốt ngược tiến độ
         chỉ vì ghi chú lưu hỏng */
    }
  }

  // Xong giai đoạn làm quen = xong mọi bước NGƯỜI NÀY MỞ ĐƯỢC, không phải mọi
  // bước tồn tại.
  //
  // Cả 13 chủ đề đều khoá bước "Chuyển hóa". Nếu đòi đủ ba bước thì người dùng
  // miễn phí dừng ở bước 2 vĩnh viễn, mà nút "Tôi vừa thực hành điều này hôm
  // nay" lại chỉ mở sau khi khép giai đoạn làm quen — nghĩa là họ kẹt ở 2/5 và
  // KHÔNG BAO GIỜ hình thành được kỹ năng nào. Cái bị khoá ở đó là việc ghi
  // nhận, trong khi ranh giới của mình là "ghi nhận miễn phí, diễn giải mới
  // Premium". Bước "Chuyển hóa" vẫn khoá; chỉ có đường đi tiếp là mở.
  final reachable = allSteps
      .where((s) => entitlement.canAccessPracticeStep(isPremiumStep: s.isPremium))
      .map((s) => s.stepId)
      .toSet();
  final hasCompletedAll =
      reachable.isNotEmpty && reachable.every(newCompleted.contains);

  // `completedAt != null` là cái mốc khép giai đoạn làm quen. Đã khép rồi thì
  // thôi — nâng cấp lên Premium xong đi nốt bước "Chuyển hóa" không được phép
  // sinh thêm một dòng "đã hoàn thành chủ đề" thứ hai trong Hành trình.
  if (hasCompletedAll && enrollment.completedAt == null) {
    await repo.completeTheme(userId: userId, themeId: theme.themeId);
    await contentRepo.insertMemoryEvent(
      CareerMemoryEvent(
        id: '${DateTime.now().millisecondsSinceEpoch}t',
        userId: userId,
        behavior: 'practice_theme_done',
        themeId: theme.themeId,
        reflectionText: theme.title,
      ),
    );
  }

  ref.invalidate(practiceEnrollmentsProvider);
  ref.invalidate(practiceMemoryEventsProvider);

  // Xong ba bước KHÔNG còn nghĩa là đã thành kỹ năng — đó mới là giai đoạn làm
  // quen. Kỹ năng hình thành khi bộ đếm chạm ngưỡng, kể cả những lần duy trì
  // sau này. Ở đây chỉ kiểm tra xem lần thực hành vừa rồi có chạm ngưỡng không.
  if (!context.mounted) return;
  await recordSkillMilestones(context: context, ref: ref, theme: theme);
}

/// Nhãn giai đoạn theo thứ tự bước — giao diện mẫu Sprint 2.
///
/// Ba giai đoạn là ngôn ngữ của người dùng ("Nhận diện → Thử nghiệm → Chuyển
/// hoá"), không phải số thứ tự trần.
String? practiceStageTag(int stepOrder) => switch (stepOrder) {
      1 => 'NHẬN DIỆN',
      2 => 'THỬ NGHIỆM',
      3 => 'CHUYỂN HOÁ',
      _ => null,
    };

/// Cùng ba giai đoạn nhưng viết như trong câu, không phải nhãn in hoa.
///
/// Mockup dùng cả hai dạng: nhãn `.pill` in hoa trên từng bước ở tab Phát
/// triển, và dạng câu ở dòng "Tiếp tục hôm nay" của Home ("bước Thử nghiệm đang
/// chờ"). Giữ chung một nguồn để hai nơi không lệch tên giai đoạn.
String? practiceStageLabel(int stepOrder) => switch (stepOrder) {
      1 => 'Nhận diện',
      2 => 'Thử nghiệm',
      3 => 'Chuyển hoá',
      _ => null,
    };

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
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_career_memory_rules.dart' show kMilestoneBehavior;
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/models/wr_mood_content.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_note_sheet.dart';
import 'wr_skill_moment.dart';

/// Kết quả một lần đánh dấu bước — cho thẻ "Cột mốc mới / Đã ghi nhận" ở màn
/// chủ đề (mockup v47 `practiceCompletionNotice`).
typedef PracticeStepCompletion = ({String stepTitle, bool firstMilestone});

/// Đánh dấu [stepId] của [theme] là xong, kèm mọi dấu vết đi theo nó.
///
/// §VII: hỏi ghi chú TRƯỚC khi ghi bất cứ thứ gì. Đóng tấm ghi chú là huỷ hẳn
/// — bước vẫn chưa xong, chứ không phải xong-mà-không-ghi-chú.
///
/// Mockup v47 hỏi ghi chú NGAY TRONG thẻ bước ("Bạn đã thử như thế nào?" ·
/// Lưu lại · Chỉ đánh dấu · Để sau); màn chủ đề truyền câu trả lời vào
/// [presetNote] nên tấm ghi chú không mở nữa. [choice] là cách người dùng đã
/// chọn ở "Bạn muốn thử cách nào?", nếu có.
///
/// Trả null khi người dùng huỷ.
Future<PracticeStepCompletion?> completePracticeStep({
  required BuildContext context,
  required WidgetRef ref,
  required PracticeTheme theme,
  required PracticeEnrollment enrollment,
  required String stepId,
  required List<PracticeStep> allSteps,
  PracticeNoteResult? presetNote,
  String? choice,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return null;
  final repo = ref.read(wrIntelligenceRepositoryProvider);
  final contentRepo = ref.read(wrContentRepositoryProvider);
  final entitlement =
      ref.read(wrEntitlementProvider).valueOrNull ??
      WrEntitlement(plan: WrPlan.free);

  final stepTitle = allSteps
      .where((s) => s.stepId == stepId)
      .map((s) => s.title)
      .firstOrNull;

  final noteResult =
      presetNote ??
      await showPracticeNoteSheet(
        context,
        stepTitle: stepTitle ?? tr('Bước thực hành', 'Practice step'),
      );
  if (noteResult == null) return null;
  final firstMilestone = enrollment.completedSteps.isEmpty;

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
        PracticeStepNote(
          userId: userId,
          stepId: stepId,
          note: note,
          choice: choice,
        ),
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
      .where(
        (s) => entitlement.canAccessPracticeStep(isPremiumStep: s.isPremium),
      )
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

  // Mockup v47: lần ĐẦU thử một bước của chủ đề là một Cột mốc — sự thật đã
  // xảy ra, không phải kế hoạch.
  if (firstMilestone) {
    try {
      await contentRepo.insertMemoryEvent(
        CareerMemoryEvent(
          id: '${DateTime.now().millisecondsSinceEpoch}m',
          userId: userId,
          behavior: kMilestoneBehavior,
          themeId: theme.themeId,
          // CHỈ tên chủ đề: câu "Lần đầu thử một cách khác: …" dựng lúc hiển
          // thị, để đổi ngôn ngữ không kẹt lại bản đã ghép sẵn trong DB.
          reflectionText: theme.titleVi,
        ),
      );
    } catch (_) {
      /* best-effort: Cột mốc hỏng không được nuốt ngược tiến độ */
    }
  }

  // Cách đã "lưu để thử" xong nhiệm vụ của nó.
  if (enrollment.pendingChoice != null) {
    try {
      await repo.setPendingChoice(
        userId: userId,
        themeId: theme.themeId,
        choice: null,
      );
    } catch (_) {
      /* best-effort */
    }
  }

  ref.invalidate(practiceEnrollmentsProvider);
  ref.invalidate(practiceMemoryEventsProvider);
  ref.invalidate(practiceStepNotesProvider);

  // Xong ba bước KHÔNG còn nghĩa là đã thành kỹ năng — đó mới là giai đoạn làm
  // quen. Kỹ năng hình thành khi bộ đếm chạm ngưỡng, kể cả những lần duy trì
  // sau này. Ở đây chỉ kiểm tra xem lần thực hành vừa rồi có chạm ngưỡng không.
  final result = (
    stepTitle: stepTitle ?? stepId,
    firstMilestone: firstMilestone,
  );
  if (!context.mounted) return result;
  await recordSkillMilestones(context: context, ref: ref, theme: theme);
  return result;
}

/// Nhãn giai đoạn theo thứ tự bước — mockup v47: Nhận diện → Phần của tôi →
/// Chọn một cách → Mang về. Nhãn "Chuyển hoá" đã bỏ hẳn (migration
/// 20261006120000 chuyển cả thư viện sang 4 bước).
String? practiceStageTag(int stepOrder) => practiceStageLabel(stepOrder)
    ?.toUpperCase();

/// Cùng bốn giai đoạn nhưng viết như trong câu, không phải nhãn in hoa.
///
/// Dùng ở dòng "Tiếp tục hôm nay" của Home ("bước Phần của tôi đang chờ") và
/// trên từng bước ở màn chủ đề. Giữ chung một nguồn để hai nơi không lệch tên.
String? practiceStageLabel(int stepOrder) => switch (stepOrder) {
  1 => tr('Nhận diện', 'Notice'),
  2 => tr('Phần của tôi', 'Your part'),
  3 => tr('Chọn một cách', 'Pick one way'),
  4 => tr('Mang về', 'Take it with you'),
  _ => null,
};

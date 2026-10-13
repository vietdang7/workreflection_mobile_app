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
import '../../../core/logic/wr_career_memory_rules.dart'
    show kMilestoneBehavior;
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

  // Hết bốn bước KHÔNG tự khép chủ đề nữa (script Sprint 2 `moveToKeep`):
  // màn chủ đề hiện thẻ "Hết một vòng" và người dùng tự bấm "Đưa vào phần duy
  // trì" — xem [movePracticeThemeToKeep]. "Hết" vẫn là hết mọi bước NGƯỜI NÀY
  // MỞ ĐƯỢC (bước 4 khoá Premium), tính ở màn chủ đề bằng
  // [practiceReachableDone].

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

  // `pending_choice` giữ lại sau khi thử: đó là cách đã dùng ở bước 3, màn
  // chủ đề cần nó cho dòng "Thử: ‹cách›" (script `practiceDetail`).

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

/// Nhãn giai đoạn theo thứ tự bước — script Sprint 2: Nhận diện → Phần của
/// tôi → Chọn một cách → Câu hỏi cho lần sau. Nhãn "Chuyển hoá" đã bỏ hẳn (migration
/// 20261006120000 chuyển cả thư viện sang 4 bước).
String? practiceStageTag(int stepOrder) =>
    practiceStageLabel(stepOrder)?.toUpperCase();

/// Cùng bốn giai đoạn nhưng viết như trong câu, không phải nhãn in hoa.
///
/// Dùng ở dòng "Tiếp tục hôm nay" của Home ("bước Phần của tôi đang chờ") và
/// trên từng bước ở màn chủ đề. Giữ chung một nguồn để hai nơi không lệch tên.
String? practiceStageLabel(int stepOrder) => switch (stepOrder) {
  1 => tr('Nhận diện', 'Notice'),
  2 => tr('Phần của tôi', 'Your part'),
  3 => tr('Chọn một cách', 'Pick one way'),
  4 => tr('Câu hỏi cho lần sau', 'A question for next time'),
  _ => null,
};

/// Đã đi hết mọi bước người này MỞ ĐƯỢC của chủ đề chưa.
///
/// Bước 4 khoá Premium: người dùng miễn phí đi hết ba bước đầu là hết một vòng
/// của họ, nếu không thì họ kẹt vĩnh viễn và không bao giờ vào được phần duy
/// trì (ranh giới là "ghi nhận miễn phí, diễn giải mới Premium").
bool practiceReachableDone({
  required List<PracticeStep> steps,
  required List<String> completed,
  required WrEntitlement entitlement,
}) {
  final reachable = [
    for (final s in steps)
      if (entitlement.canAccessPracticeStep(isPremiumStep: s.isPremium))
        s.stepId,
  ];
  return reachable.isNotEmpty && reachable.every(completed.contains);
}

/// Đưa một chủ đề đã đi hết bốn bước vào phần duy trì (script `moveToKeep`).
///
/// `completed_at` là mốc khép giai đoạn làm quen: từ đây chủ đề nằm trong
/// "Đang duy trì", không chiếm suất chủ đề đang làm, và bộ đếm kỹ năng coi như
/// đã qua phần làm quen. Ghi kèm một Cột mốc "Hết một vòng: ‹chủ đề›" vào
/// Career Memory. Không gắn `theme_id` cho cột mốc này: Hành trình đọc cột mốc
/// có `theme_id` là "Lần đầu thử một cách khác", nên tiêu đề đi trong chữ.
///
/// Trả về false khi không ghi được, để màn gọi giữ nguyên nút cho người dùng
/// thử lại.
Future<bool> movePracticeThemeToKeep({
  required WidgetRef ref,
  required PracticeTheme theme,
  required PracticeEnrollment enrollment,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return false;
  if (enrollment.completedAt != null) return true;
  try {
    await ref
        .read(wrIntelligenceRepositoryProvider)
        .completeTheme(userId: userId, themeId: theme.themeId);
  } catch (_) {
    return false;
  }
  try {
    await ref
        .read(wrContentRepositoryProvider)
        .insertMemoryEvent(
          CareerMemoryEvent(
            id: '${DateTime.now().millisecondsSinceEpoch}k',
            userId: userId,
            behavior: kMilestoneBehavior,
            reflectionText: tr(
              'Hết một vòng: ${theme.title}',
              'One full round: ${theme.title}',
            ),
          ),
        );
  } catch (_) {
    // Chủ đề đã sang duy trì; thiếu một dòng ký ức không đáng chặn người dùng.
  }
  ref.invalidate(practiceEnrollmentsProvider);
  ref.invalidate(practiceMemoryEventsProvider);
  return true;
}

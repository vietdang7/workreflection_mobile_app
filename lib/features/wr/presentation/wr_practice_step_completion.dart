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
import '../../../core/logic/wr_skill_certification.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/models/wr_mood_content.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_note_sheet.dart';

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
      reflectionText: '${theme.title} — ${stepTitle ?? stepId}',
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

  // Chứng nhận kỹ năng: lặp lại đủ nhiều thì ghi một dấu mốc, đúng một lần.
  try {
    final events = await contentRepo.fetchMemoryEvents(limit: 200);
    final certified = certifiedSkills(
      themes: [theme],
      enrollments: [enrollment.copyWith(completedSteps: newCompleted)],
      events: events,
    );
    for (final skill in newlyCertified(certified: certified, events: events)) {
      await contentRepo.insertMemoryEvent(
        CareerMemoryEvent(
          id: '',
          userId: userId,
          behavior: kSkillCertifiedBehavior,
          reflectionText: skill.title,
        ),
      );
    }
  } catch (_) {
    /* best-effort: dấu mốc sẽ được ghi ở lần thực hành sau */
  }

  final allStepIds = allSteps.map((s) => s.stepId).toSet();
  final hasCompletedAll = allStepIds.every((id) => newCompleted.contains(id));

  if (hasCompletedAll) {
    await repo.completeTheme(userId: userId, themeId: theme.themeId);
    await contentRepo.insertMemoryEvent(
      CareerMemoryEvent(
        id: '${DateTime.now().millisecondsSinceEpoch}t',
        userId: userId,
        behavior: 'practice_theme_done',
        reflectionText: theme.title,
      ),
    );
  }

  ref.invalidate(practiceEnrollmentsProvider);
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

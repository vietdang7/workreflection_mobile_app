// Providers cho Khảo sát tổ chức (ESI + eNPS) — mockup Sprint 2, màn Hồ sơ.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_org_survey_repository.dart';
import '../../core/models/wr_org_survey.dart';

/// 12 câu hỏi. Danh sách rỗng nghĩa là chưa đọc được bảng câu hỏi — màn giới
/// thiệu phải nói thẳng điều đó thay vì mở một bài khảo sát không có câu nào.
final wrOrgSurveyQuestionsProvider =
    FutureProvider<List<OrgSurveyQuestion>>((ref) async {
  return ref.watch(wrOrgSurveyRepositoryProvider).fetchQuestions();
});

/// Lần làm gần nhất, null nếu chưa từng làm.
///
/// Nuốt lỗi và trả null: thẻ trên màn Hồ sơ chỉ dùng cái này để đổi chữ nút
/// ("Tìm hiểu & tham gia" hay "Xem lại kết quả"). Không đáng để một lần đọc
/// hỏng làm cả màn Hồ sơ đỏ lên.
final wrOrgSurveyLatestProvider =
    FutureProvider<OrgSurveyResponse?>((ref) async {
  try {
    return await ref.watch(wrOrgSurveyRepositoryProvider).fetchLatestResponse();
  } catch (_) {
    return null;
  }
});

/// Mặt bằng chung, khoá theo mảng. eNPS nằm ở khoá null.
///
/// Lỗi đọc trả về map rỗng, và màn kết quả hiểu map rỗng đúng như khi chưa đủ
/// mẫu: chỉ hiện điểm của chính người dùng, không vẽ vạch so sánh. Vẽ một vạch
/// so sánh dựng trên số không đọc được là điều tệ nhất màn này có thể làm.
final wrOrgSurveyBenchmarkProvider =
    FutureProvider<Map<OrgSurveyArea?, OrgSurveyBenchmark>>((ref) async {
  try {
    final rows = await ref.watch(wrOrgSurveyRepositoryProvider).fetchBenchmark();
    return {for (final r in rows) r.area: r};
  } catch (_) {
    return const {};
  }
});

// Providers cho Khảo sát tổ chức (ESI + eNPS) — mockup Sprint 2, màn Hồ sơ.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_org_survey_repository.dart';
import '../../core/models/wr_org_survey.dart';

/// 12 câu hỏi. Danh sách rỗng nghĩa là chưa đọc được bảng câu hỏi — màn giới
/// thiệu phải nói thẳng điều đó thay vì mở một bài khảo sát không có câu nào.
final wrOrgSurveyQuestionsProvider = FutureProvider<List<OrgSurveyQuestion>>((
  ref,
) async {
  return ref.watch(wrOrgSurveyRepositoryProvider).fetchQuestions();
});

/// Lần làm gần nhất, null nếu chưa từng làm.
///
/// Nuốt lỗi và trả null: thẻ trên màn Hồ sơ chỉ dùng cái này để đổi chữ nút
/// ("Tìm hiểu & tham gia" hay "Xem lại kết quả"). Không đáng để một lần đọc
/// hỏng làm cả màn Hồ sơ đỏ lên.
final wrOrgSurveyLatestProvider = FutureProvider<OrgSurveyResponse?>((
  ref,
) async {
  try {
    return await ref.watch(wrOrgSurveyRepositoryProvider).fetchLatestResponse();
  } catch (_) {
    return null;
  }
});

/// Mặt bằng chung theo hai phạm vi, mỗi phạm vi khoá theo mảng (eNPS ở khoá
/// null). `industry` rỗng khi không truyền lĩnh vực.
class OrgSurveyBenchmarks {
  const OrgSurveyBenchmarks({this.all = const {}, this.industry = const {}});

  final Map<OrgSurveyArea?, OrgSurveyBenchmark> all;
  final Map<OrgSurveyArea?, OrgSurveyBenchmark> industry;
}

/// Mặt bằng chung, khoá theo lĩnh vực (null = chỉ phạm vi "tất cả").
///
/// KHÔNG nuốt lỗi: "RPC hỏng" phải ra `AsyncError`, không được trông giống
/// "chưa đủ người". Nơi dùng tự quyết định hiện gì khi lỗi.
final wrOrgSurveyBenchmarkProvider =
    FutureProvider.family<OrgSurveyBenchmarks, String?>((ref, industry) async {
      final rows = await ref
          .watch(wrOrgSurveyRepositoryProvider)
          .fetchBenchmark(industry: industry);
      return OrgSurveyBenchmarks(
        all: {
          for (final r in rows)
            if (r.scope == BenchmarkScope.all) r.area: r,
        },
        industry: {
          for (final r in rows)
            if (r.scope == BenchmarkScope.industry) r.area: r,
        },
      );
    });

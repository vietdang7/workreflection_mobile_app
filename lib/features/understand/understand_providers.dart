import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/wr_repository.dart';
import '../../core/models/insight.dart';
import '../../core/models/recurring_situation.dart';
import '../../core/models/sca_report.dart';

final understandInsightsProvider = FutureProvider<List<Insight>>((ref) async {
  return ref.watch(wrRepositoryProvider).getInsights();
});

final understandLatestInsightProvider = FutureProvider<Insight?>((ref) async {
  return ref.watch(wrRepositoryProvider).getLatestInsight();
});

final understandSituationsProvider =
    FutureProvider<List<RecurringSituation>>((ref) async {
  return ref.watch(wrRepositoryProvider).getRecurringSituations();
});

final understandScaReportProvider = FutureProvider<ScaReport?>((ref) async {
  return ref.watch(wrRepositoryProvider).getLatestScaReport();
});

/// Combined reflection count: checkins + saved insights (plan Task 14).
final understandInsightCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  final results = await Future.wait([repo.countCheckins(), repo.countInsights()]);
  return results[0] + results[1];
});

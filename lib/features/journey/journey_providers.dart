import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/wr_repository.dart';
import '../../core/models/insight.dart';
import '../../core/models/timeline_event.dart';

final journeyLatestInsightProvider = FutureProvider<Insight?>((ref) async {
  return ref.watch(wrRepositoryProvider).getLatestInsight();
});

final journeyTimelineProvider =
    FutureProvider<List<TimelineEvent>>((ref) async {
  return ref.watch(wrRepositoryProvider).getTimelineEvents();
});

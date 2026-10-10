import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wr_learning_resource.dart';

/// Thư viện học tập — đọc `cc_workshop_resources` của web (xem
/// `wr_learning_resource.dart`).
abstract class WrLearningRepository {
  /// Mọi tài liệu đang mở, mới nhất lên đầu.
  Future<List<LearningResource>> fetchActive();
}

final wrLearningRepositoryProvider = Provider<WrLearningRepository>((ref) {
  return SupabaseWrLearningRepository(Supabase.instance.client);
});

final wrLearningResourcesProvider =
    FutureProvider.autoDispose<List<LearningResource>>((ref) {
      return ref.watch(wrLearningRepositoryProvider).fetchActive();
    });

/// Một tài liệu theo id — lấy từ danh sách, không gọi thêm mạng.
final wrLearningResourceProvider = FutureProvider.autoDispose
    .family<LearningResource?, String>((ref, id) async {
      final all = await ref.watch(wrLearningResourcesProvider.future);
      return all.where((r) => r.id == id).firstOrNull;
    });

class SupabaseWrLearningRepository implements WrLearningRepository {
  const SupabaseWrLearningRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<LearningResource>> fetchActive() async {
    final rows = await _client
        .from('cc_workshop_resources')
        .select(
          'id, title, description, category, resource_type, external_url, '
          'file_url, duration_minutes, created_at',
        )
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return rows
        .map(LearningResource.fromJson)
        .where((r) => r.title.isNotEmpty && r.url != null)
        .toList();
  }
}

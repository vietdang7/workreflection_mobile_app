import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_user_action_repository.dart';
import '../../core/models/wr_user_action.dart';
import 'wr_providers.dart';

/// "Việc bạn tự đặt" của người đang đăng nhập (Task D1).
///
/// ⚠ Không provider nào về chủ đề thực hành được đọc cái này:
/// `practiceEnrollmentsProvider`, quota, tự thêm chủ đề và trợ lý trò chuyện
/// đều không biết tới việc tự đặt. Đó là chủ đích (trọng tâm review số 4).
final wrUserActionsProvider = FutureProvider<List<WrUserAction>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(wrUserActionRepositoryProvider).list();
});

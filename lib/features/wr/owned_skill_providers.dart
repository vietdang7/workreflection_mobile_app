import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_owned_skill_repository.dart';
import '../../core/models/wr_owned_skill.dart';
import 'wr_providers.dart';

/// Chứng chỉ / khoá học / kỹ năng người dùng tự khai (Task D2).
final wrOwnedSkillsProvider = FutureProvider<List<WrOwnedSkill>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(wrOwnedSkillRepositoryProvider).list();
});

/// Mọi chủ đề thư viện người dùng đã xác nhận là mình có sẵn.
///
/// Đọc hỏng hoặc chưa đọc xong thì là tập rỗng: hành vi y như trước khi có
/// tính năng này. Riêng phần mềm tự thêm chủ đề phải CHỜ đọc xong (xem
/// `_maybeAutoEnroll`), vì đoán rỗng ở đó là thêm nhầm một chủ đề họ đã có.
final wrOwnedThemeIdsProvider = Provider<Set<String>>((ref) {
  final skills = ref.watch(wrOwnedSkillsProvider).valueOrNull ?? const [];
  return {for (final s in skills) ...s.themeIds};
});

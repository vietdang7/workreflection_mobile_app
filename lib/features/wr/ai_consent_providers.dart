// Trạng thái đồng ý gửi dữ liệu sang dịch vụ AI bên thứ ba.
//
// Guideline 5.1.1(i) / 5.1.2(i) — xem `lib/core/logic/wr_ai_disclosure.dart`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_ai_consent_repository.dart';
import 'wr_providers.dart';

/// Lựa chọn hiện tại của người dùng.
///
/// Không bao giờ ném: đọc hỏng thì trả [WrAiConsent.unknown], tức "chưa trả
/// lời". Nghiêng về phía CHƯA CHO PHÉP là hướng an toàn duy nhất ở đây — đoán
/// nhầm thành "đã cho phép" là gửi dữ liệu đi khi chưa được phép, đúng thứ
/// Apple từ chối bản trước.
final wrAiConsentProvider = FutureProvider<WrAiConsent>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return WrAiConsent.unknown;
  try {
    return await ref.watch(wrAiConsentRepositoryProvider).fetch();
  } catch (_) {
    return WrAiConsent.unknown;
  }
});

/// True khi được phép gọi các tính năng AI.
///
/// Trong lúc còn đang tải thì trả false. Người dùng thấy chậm một nhịp còn hơn
/// một lượt dữ liệu rời máy trước khi biết câu trả lời.
final wrAiConsentGrantedProvider = Provider<bool>((ref) {
  return ref.watch(wrAiConsentProvider).valueOrNull?.isGranted ?? false;
});

/// Ghi nhận lựa chọn của người dùng.
class WrAiConsentController {
  WrAiConsentController(this._ref);

  final Ref _ref;

  WrAiConsentRepository get _repo => _ref.read(wrAiConsentRepositoryProvider);

  /// Người dùng bấm đồng ý. Trả false khi ghi hỏng — KHÔNG được coi như đã
  /// đồng ý, vì lần mở app sau đọc lại vẫn là chưa.
  Future<bool> grant() async {
    try {
      await _repo.grant();
    } catch (_) {
      return false;
    }
    _invalidateAiSurfaces();
    return true;
  }

  /// Người dùng rút lại.
  Future<bool> revoke() async {
    try {
      await _repo.revoke();
    } catch (_) {
      return false;
    }
    _invalidateAiSurfaces();
    return true;
  }

  /// Bắt các phần phụ thuộc AI đọc lại.
  ///
  /// Không chỉ `wrAiConsentProvider`: mục Diễn biến chạy tự động và đã trả
  /// "không có gì" trong lúc chưa được phép. Không dựng lại nó thì người vừa
  /// bấm đồng ý phải thoát ra vào lại mới thấy.
  void _invalidateAiSurfaces() {
    _ref.invalidate(wrAiConsentProvider);
    _ref.invalidate(wrNarrativeRefreshProvider);
  }
}

final wrAiConsentControllerProvider = Provider<WrAiConsentController>((ref) {
  return WrAiConsentController(ref);
});

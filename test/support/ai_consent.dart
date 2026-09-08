// Đồng ý gửi dữ liệu sang AI, dựng sẵn cho test.
//
// Từ 07/09/2026 mọi luồng AI đều đi qua cổng chặn `ensureAiConsent` phía app và
// `hasAiConsent` phía máy chủ (Guideline 5.1.1(i) — xem
// `lib/core/logic/wr_ai_disclosure.dart`). Test nào dựng màn Trò chuyện, màn
// Diễn biến hay màn Tài liệu bối cảnh mà không có override này sẽ thấy cổng
// chặn thay vì tính năng — đúng như người dùng thật chưa trả lời.
//
// Đặt ở đây thay vì chép vào từng file test để chỉ có MỘT chỗ phải sửa khi
// [kWrAiDisclosureVersion] tăng.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workreflection_mobile/core/data/wr_ai_consent_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_ai_disclosure.dart';
import 'package:workreflection_mobile/features/wr/ai_consent_providers.dart';

/// Người dùng trong test đã đồng ý cho gửi dữ liệu sang AI.
///
/// Dùng khi bài test đang kiểm MỘT THỨ KHÁC và chỉ cần luồng AI chạy được.
/// Bản thân cổng chặn có bộ test riêng ở `test/features/wr_ai_consent_test.dart`
/// — đừng kiểm nó gián tiếp qua các màn khác.
Override grantedAiConsent() => wrAiConsentProvider.overrideWith(
      (ref) async => WrAiConsent(
        version: kWrAiDisclosureVersion,
        grantedAt: DateTime(2026, 1, 1),
      ),
    );

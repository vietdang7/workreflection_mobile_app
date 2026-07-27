import 'package:flutter/foundation.dart';

/// Ghi lại lỗi thật của một bước trong luồng phản tư.
///
/// Người dùng chỉ thấy một câu ngắn ("Không lưu được. Thử lại."), nhưng khi
/// một bước hỏng thì cần biết chính xác vì sao — nuốt trọn ngoại lệ làm mọi
/// sự cố tầng dữ liệu trông giống hệt nhau.
///
/// Chỉ in ở bản debug; bản release im lặng.
void logFlowError(String step, Object error, [StackTrace? stack]) {
  if (!kDebugMode) return;
  debugPrint('[wr-flow] $step thất bại: $error');
  if (stack != null) debugPrintStack(stackTrace: stack, label: '[wr-flow] $step');
}

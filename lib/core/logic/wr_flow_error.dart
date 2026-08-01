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

/// Câu báo lỗi hiện trên màn hình.
///
/// Bản release chỉ nói ngắn gọn. Bản debug ghép thêm nguyên văn lỗi để người
/// đang thử app chụp lại được ngay, khỏi phải mở console.
String flowErrorMessage(String friendly, Object error) {
  if (!kDebugMode) return friendly;
  return '$friendly\n\n$error';
}

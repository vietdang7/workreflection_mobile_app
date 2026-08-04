// Khi nào một người ĐƯỢC một chủ đề thực hành.
//
// Hai hướng khách chốt 2026-07-31, ngưỡng chốt lại 2026-08-04:
//
//   Hướng 1 — tích luỹ: cứ đủ 15 LẦN nhìn lại là được một chủ đề.
//   Hướng 2 — tự đánh giá: mỗi lần làm xong bộ 15 câu là được một chủ đề.
//
// Đơn vị là LẦN, không phải NGÀY (khách đổi 2026-07-31 vì màn Hiểu mình có hai
// đơn vị đứng cạnh nhau, không ai đoán ra). Chạy 15 lượt trong một tối là mở
// khoá ngay — đánh đổi có ý thức.
//
// Bản trước ngưỡng là 2 lần chạm CÙNG MỘT NHU CẦU (`kDevelopmentFlowThreshold`,
// viện WXS §3.12 Inv.6). Nhìn lại hai lần đã ra chủ đề, sớm hơn hẳn con số 15
// mà khách vẫn hiểu là ngưỡng — hai bên nói hai chuyện khác nhau suốt một tuần.
//
// Vì sao là số ĐƯỢC HƯỞNG chứ không phải một cái cổng đóng/mở: chủ đề giờ do
// phần mềm tự thêm. Một cái cổng chỉ trả lời "có được không", không trả lời
// được "đã thêm đủ chưa" — mà đó mới là câu hỏi cần thiết để tự thêm mà không
// thêm trùng. So `earnedPracticeThemes` với số chủ đề đã ghi danh là ra ngay,
// và phép so đó lặp lại bao nhiêu lần cũng cho cùng kết quả.
//
// Pure Dart, không phụ thuộc Flutter.

/// Số lần nhìn lại đổi được một chủ đề thực hành.
const int kReflectionsPerPracticeTheme = 15;

/// Tổng số chủ đề một người đã được hưởng tới thời điểm này.
///
/// [reflectionCount] là số Episode — cùng con số với câu "Bạn đã nhìn lại N
/// lần" ở tab Hiểu mình, để hai chỗ không thể nói hai con số khác nhau.
/// [selfCheckCount] là số lần đã hoàn tất bộ tự đánh giá.
int earnedPracticeThemes({
  required int reflectionCount,
  required int selfCheckCount,
}) =>
    reflectionCount ~/ kReflectionsPerPracticeTheme + selfCheckCount;

/// Còn bao nhiêu lần nhìn lại nữa thì được thêm một chủ đề theo hướng 1.
///
/// Dùng cho câu "Bạn đã nhìn lại N/15 lần" — nói đúng quãng đường còn lại thay
/// vì bảo người dùng chờ một điều không đo được.
int reflectionsToNextTheme(int reflectionCount) =>
    kReflectionsPerPracticeTheme - (reflectionCount % kReflectionsPerPracticeTheme);

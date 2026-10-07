// Tên bước thực hành TRƯỚC migration 4 bước (20261006120000), kèm bản tiếng
// Anh.
//
// Migration đó đổi tên bước "Thử nghiệm" và "Chuyển hoá" của mọi chủ đề thư
// viện ngay trên hàng cũ (giữ `step_id`). Nhưng `wr_career_memory.reflection_text`
// của những lần thực hành trước đó đã đóng băng tên CŨ ("‹chủ đề› · Thử nghiệm:
// Chủ động hỏi lý do thay đổi"), mà bảng tra `wrPracticeLabelMapProvider` chỉ
// biết tên MỚI trong DB. Thành ra bật tiếng Anh, tab Hành trình vẫn hiện tên
// bước tiếng Việt.
//
// Chép từ `20260731000000_wr_practice_themes_by_dimension.sql` (bản tiếng Việt,
// đã đổi dấu gạch dài thành hai chấm như `20260805130000`) và
// `20260910140000_content_en_translations.sql` (bản tiếng Anh). Bản ghi cũ còn
// mang dấu gạch dài thì `practiceLegacyTitleKeys` sinh thêm khoá đó.
//
// Pure Dart.

/// (tiếng Việt, tiếng Anh) của 20 tên bước cũ.
const List<(String, String)> kLegacyPracticeStepTitles = [
  (
    'Thử nghiệm: Kết nối việc đang làm với mục tiêu lớn hơn',
    'Try: Connect today\'s work to something larger',
  ),
  (
    'Chuyển hóa: Tự hỏi lại mục tiêu định kỳ',
    'Shift: Revisit the goal on a rhythm',
  ),
  (
    'Thử nghiệm: Bỏ hoặc dời một việc không cấp thiết',
    'Try: Drop or move one thing that isn\'t urgent',
  ),
  ('Chuyển hóa: Xây nhịp nghỉ cố định', 'Shift: Build a fixed rest rhythm'),
  (
    'Thử nghiệm: Dừng lại một nhịp trước khi phản hồi',
    'Try: Take a beat before responding',
  ),
  (
    'Chuyển hóa: Nhận ra sớm dấu hiệu phản ứng',
    'Shift: Catch the reaction early',
  ),
  (
    'Thử nghiệm: Ghi chú điều sẽ làm khác đi ngay sau sai lầm',
    'Try: Note what you\'ll do differently, right after',
  ),
  ('Chuyển hóa: Xây nhịp nhìn lại định kỳ', 'Shift: Build a regular look back'),
  (
    'Thử nghiệm: Giao trọn một việc, không kiểm tra giữa chừng',
    'Try: Hand something over fully, no mid-way checks',
  ),
  (
    'Chuyển hóa: Duy trì niềm tin đã trao',
    'Shift: Keep the trust you\'ve given',
  ),
  (
    'Thử nghiệm: Đặt một câu hỏi trong họp',
    'Try: Ask one question in a meeting',
  ),
  ('Chuyển hóa: Chia sẻ một quan điểm', 'Shift: Share a view of your own'),
  (
    'Thử nghiệm: Chia sẻ 1 phản hồi thẳng thắn',
    'Try: Give one honest piece of feedback',
  ),
  ('Chuyển hóa: Xây thói quen phản hồi', 'Shift: Build the feedback habit'),
  (
    'Thử nghiệm: Hỏi thẳng một câu làm rõ',
    'Try: Ask one direct question to make it clear',
  ),
  (
    'Chuyển hóa: Biến việc hỏi rõ thành thói quen',
    'Shift: Make asking a habit',
  ),
  (
    'Thử nghiệm: Từ chối hoặc chuyển giao một việc',
    'Try: Decline or hand over one task',
  ),
  (
    'Chuyển hóa: Giữ một cách ưu tiên rõ ràng',
    'Shift: Keep a clear way of prioritising',
  ),
  (
    'Thử nghiệm: Chủ động hỏi lý do thay đổi',
    'Try: Ask why the change happened',
  ),
  (
    'Chuyển hóa: Xác nhận thay vì giả định',
    'Shift: Confirm rather than assume',
  ),
];

/// Mọi cách một tên bước cũ có thể đã bị lưu: dạng hai chấm và dạng gạch dài
/// trước 05/08.
Iterable<String> practiceLegacyTitleKeys(String vi) sync* {
  yield vi;
  final i = vi.indexOf(': ');
  if (i > 0) yield '${vi.substring(0, i)} — ${vi.substring(i + 2)}';
}

// Công tắc Premium dành riêng cho vài tài khoản nội bộ — công cụ thử nghiệm, không
// phải tính năng sản phẩm.
//
// Mục đích: chủ sản phẩm cần xem qua lại hai bản (miễn phí / đầy đủ) trên cùng
// một máy để nghiệm thu, mà không phải tạo hai tài khoản hay chờ webhook thanh
// toán ghi vào `wr_entitlements`.
//
// ---------------------------------------------------------------------------
// Vì sao là công tắc CỤC BỘ, không phải ghi thẳng vào DB
// ---------------------------------------------------------------------------
//
// RLS của `wr_entitlements` (migration `20260722000000_wr_two_layer_v1_2.sql`)
// chỉ cho SELECT — "ghi bởi backend/webhook thanh toán". Mở một policy UPDATE,
// dù chỉ cho một user_id, là dựng ra một đường vòng qua thanh toán ngay trong
// production và để nó nằm đó mãi.
//
// Công tắc này không mở đường nào cả: nó chỉ đổi thứ MÁY NÀY tự tin về gói của
// mình. Mọi cổng Premium trong app vốn đã nằm ở tầng client
// (`WrEntitlement.canUseFeature`), nên nó không nới lỏng thêm bất cứ điều gì mà
// server đang canh. Cái giá phải trả: trạng thái nằm trên máy, không đồng bộ
// sang thiết bị khác, và cài lại app là mất. Đúng như một công cụ thử nghiệm
// nên hành xử.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

/// Những tài khoản thấy được công tắc này. Không ai khác.
///
/// Cố ý ghi thẳng vào code chứ không đọc từ cấu hình: một hằng số nằm trong
/// repo thì mọi thay đổi đều đi qua review, còn một biến môi trường thì không.
///
/// Viết thường sẵn — [canTogglePremium] so sánh sau khi hạ về chữ thường.
const Set<String> kPremiumTogglePermittedEmails = {
  'thedangs7@gmail.com',
  'ngduythong1412@gmail.com',
};

/// True khi [email] được phép bật/tắt gói ngay trong app.
///
/// So sánh sau khi chuẩn hoá hoa/thường và cắt khoảng trắng — Supabase trả về
/// email đúng như lúc đăng ký, và một chữ hoa lạc chỗ không nên làm mất công
/// tắc.
bool canTogglePremium(String? email) {
  if (email == null) return false;
  return kPremiumTogglePermittedEmails.contains(email.trim().toLowerCase());
}

/// Gói cuối cùng sau khi áp công tắc.
///
/// [actual]   gói thật, đọc từ `wr_entitlements` hoặc `cc_profiles`.
/// [override] null = chưa động vào công tắc; true/false = ép cứng.
/// [allowed]  kết quả của [canTogglePremium] cho người đang đăng nhập.
///
/// [allowed] KHÔNG được bỏ đi. Công tắc lưu trên máy, không theo tài khoản —
/// đăng xuất rồi người khác đăng nhập trên cùng máy đó mà vẫn còn hiệu lực thì
/// công cụ thử nghiệm thành lỗ hổng. Nên mỗi lần đọc đều phải hỏi lại "người
/// đang đăng nhập có phải chủ công tắc không".
bool resolvePremium({
  required bool actual,
  required bool? override,
  required bool allowed,
}) {
  if (!allowed || override == null) return actual;
  return override;
}

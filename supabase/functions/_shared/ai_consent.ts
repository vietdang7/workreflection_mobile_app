// Chốt chặn: chưa được người dùng cho phép thì không gửi gì sang dịch vụ AI.
//
// ---------------------------------------------------------------------------
// VÌ SAO CHẶN Ở MÁY CHỦ TRONG KHI APP ĐÃ CHẶN RỒI
//
// App Store từ chối bản 1.0 (6) ngày 06/09/2026 theo Guideline 5.1.1(i) và
// 5.1.2(i): gửi dữ liệu cá nhân sang dịch vụ AI bên thứ ba mà không xin phép.
// Cổng chặn trong app (`ensureAiConsent`) là chỗ NGƯỜI DÙNG nhìn thấy, còn đây
// là chỗ thật sự có quyền quyết định.
//
// Vì cổng chặn phía app hỏng theo ba cách mà không ai hay:
//
//   • Một màn hình mới quên gọi `ensureAiConsent`. Không có gì nhắc.
//   • Một bản build cũ còn nằm trên máy ai đó, chưa hề có cổng chặn nào.
//   • Bất cứ ai cầm token đăng nhập đều gọi thẳng Edge Function được, không cần
//     đi qua app.
//
// Chặn ở đây thì không đường nào vòng: đây là nơi duy nhất dữ liệu thật sự rời
// khỏi hạ tầng của mình để sang OpenRouter.
//
// ---------------------------------------------------------------------------
// ĐẶT Ở ĐÂU TRONG HÀM
//
// NGAY SAU bước xác thực, TRƯỚC mọi truy vấn nạp dữ liệu người dùng. Không phải
// vì tiết kiệm — mà vì nạp xong rồi mới kiểm là đã gom sẵn một đống dữ liệu
// riêng tư vào bộ nhớ cho một yêu cầu lẽ ra bị từ chối.

import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2';

/// Phiên bản bản công bố hiện hành.
///
/// PHẢI khớp `kWrAiDisclosureVersion` trong
/// `lib/core/logic/wr_ai_disclosure.dart`. Lệch số là lệch luôn ý nghĩa của
/// chữ "đã đồng ý": app nghĩ người dùng đã đọc bản mới, máy chủ nghĩ chưa.
/// Phải khớp `kWrAiDisclosureVersion` trong `lib/core/logic/wr_ai_disclosure.dart`.
///
/// Lên 2 ngày 09/09/2026: bản công bố thêm luồng Báo cáo khảo sát gửi hồ sơ
/// nghề nghiệp + điểm sang Gemini. Ai đồng ý bản 1 sẽ được hỏi lại — đó là ý
/// đồ, vì họ đồng ý cho một danh sách ngắn hơn.
export const AI_DISCLOSURE_VERSION = 2;

/// Câu báo cho người dùng khi chưa đồng ý.
///
/// Nói được phải làm gì tiếp, không chỉ nói là bị chặn.
export const AI_CONSENT_REQUIRED_MESSAGE =
  'Bạn chưa cho phép gửi dữ liệu sang dịch vụ AI. Vào Tài khoản → Xử lý dữ ' +
  'liệu bằng AI để xem app gửi những gì và bật lên.';

/// True khi [userId] đang cho phép gửi dữ liệu sang AI.
///
/// Ba điều kiện, giống hệt `WrAiConsent.isGranted` bên Dart:
///   • đã từng đồng ý;
///   • chưa rút lại sau lần đồng ý đó (so mốc, vì tắt rồi bật lại thì cả hai
///     mốc đều có giá trị);
///   • bản công bố đã đọc không cũ hơn bản hiện hành.
///
/// Đọc hỏng thì trả FALSE. Nghiêng về phía chưa-cho-phép là hướng an toàn duy
/// nhất: đoán nhầm thành đã-cho-phép là gửi dữ liệu đi khi chưa được phép, đúng
/// thứ Apple từ chối. Người dùng gặp một lần chặn oan vì mạng chập thì thử lại
/// được; dữ liệu đã gửi đi rồi thì không gọi về được.
export async function hasAiConsent(
  db: SupabaseClient,
  userId: string,
): Promise<boolean> {
  try {
    const { data, error } = await db
      .from('wr_ai_consent')
      .select('version, granted_at, revoked_at')
      .eq('user_id', userId)
      .maybeSingle();

    if (error) {
      console.error('Không đọc được wr_ai_consent:', error.message);
      return false;
    }
    if (!data) return false;

    const granted = data.granted_at ? Date.parse(data.granted_at) : NaN;
    if (Number.isNaN(granted)) return false;

    const version = Number(data.version ?? 0);
    if (version < AI_DISCLOSURE_VERSION) return false;

    const revoked = data.revoked_at ? Date.parse(data.revoked_at) : NaN;
    if (!Number.isNaN(revoked) && revoked >= granted) return false;

    return true;
  } catch (e) {
    console.error('Lỗi khi kiểm wr_ai_consent:', e);
    return false;
  }
}

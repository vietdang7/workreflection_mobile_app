// Ngôn ngữ của một lượt gọi Edge Function.
//
// ---------------------------------------------------------------------------
// VÌ SAO PHẢI GỬI LÊN, KHÔNG ĐOÁN ĐƯỢC Ở MÁY CHỦ
//
// Ngôn ngữ là một công tắc trong màn Tài khoản, lưu ở bộ nhớ máy, không có
// trong `auth.users` và cũng không có trong `cc_profiles`. Máy chủ không có
// đường nào biết được ngoài việc app nói cho biết.
//
// Header `Accept-Language` KHÔNG dùng được thay: nó phản ánh ngôn ngữ hệ điều
// hành, mà đúng nhóm người dùng ở đây là người Việt để máy tiếng Anh hoặc
// ngược lại. Chọn theo hệ điều hành là ghi đè lựa chọn người dùng vừa bấm.
//
// ---------------------------------------------------------------------------
// TIẾNG VIỆT LÀ MẶC ĐỊNH, KỂ CẢ KHI THIẾU
//
// Bản app cũ chưa gửi `locale` vẫn đang chạy trên máy người dùng, và cửa hàng
// không ép ai cập nhật. Thiếu trường này phải trả về đúng hành vi cũ.

export type WrLocale = 'vi' | 'en';

/// Tên header app gửi kèm mọi lượt gọi.
export const WR_LOCALE_HEADER = 'x-wr-locale';

/// Đọc ngôn ngữ từ thân yêu cầu. Thiếu, sai kiểu, hay lạ giá trị → 'vi'.
export function readLocale(body: unknown): WrLocale {
  const raw = (body as Record<string, unknown> | null | undefined)?.locale;
  return raw === 'en' ? 'en' : 'vi';
}

/// Đọc ngôn ngữ từ HEADER, dùng được ngay khi vừa nhận yêu cầu.
///
/// Vì sao cần cả header lẫn thân: một nửa số lỗi trả về cho người dùng xảy ra
/// TRƯỚC lúc đọc thân — sai method, thiếu Authorization, hết phiên đăng nhập,
/// tính năng đang tắt. Thân chỉ đọc được một lần và đọc sau những chốt chặn đó,
/// nên nếu chỉ dựa vào thân thì đúng những câu lỗi người dùng hay gặp nhất lại
/// là những câu không bao giờ dịch được.
///
/// `wr-narrative` còn không có thân yêu cầu nào để mà đọc — nó được gọi bằng
/// POST rỗng — nên với hàm đó header là đường duy nhất.
export function readLocaleHeader(req: Request): WrLocale {
  return req.headers.get(WR_LOCALE_HEADER) === 'en' ? 'en' : 'vi';
}

/// Chọn giữa hai câu theo [locale]. Bản tiếng Việt là bản gốc.
export function pick(locale: WrLocale, vi: string, en: string): string {
  return locale === 'en' ? en : vi;
}

/// Luật ngôn ngữ dán vào cuối prompt, cho các hàm sinh văn xuôi NGẮN.
///
/// Dùng cho `wr-polish`, `wr-doc-analyze`, `wr-narrative`. `wr-chat` có khối
/// riêng (`ENGLISH_MODE` trong `system_prompt.ts`) vì nó còn phải ghi đè luật
/// xưng hô "mình/bạn" mà ba hàm này không có.
///
/// Vì sao dán thêm một khối thay vì dịch cả prompt: prompt là phần đã được
/// duyệt nội dung, và phần lớn luật trong đó — độ dài, giọng, danh sách điều
/// không được khẳng định — không phụ thuộc ngôn ngữ. Dịch cả prompt là mở ra
/// một bản thứ hai phải duyệt lại từ đầu, và từ đó mỗi lần đổi một luật phải
/// sửa song song hai nơi.
///
/// Trả về chuỗi rỗng khi đang chạy tiếng Việt, để chỗ gọi cứ nối thẳng vào
/// prompt mà không cần rẽ nhánh.
export function languageRule(locale: WrLocale): string {
  if (locale !== 'en') return '';
  return `

---

LANGUAGE:

Write your entire output in English. The instructions above and the user's own
notes are in Vietnamese; that does not change what language you answer in.

Keep every other rule above unchanged, including the length limit, the tone, and
the list of things you must not claim.

When you quote the user, keep their words in the language they wrote them.
Translating someone's own sentence back at them reads as correcting them.`;
}

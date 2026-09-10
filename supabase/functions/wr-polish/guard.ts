// Ba rào chắn của §7.2 — bản Deno.
//
// Nguồn: `WorkReflection_DienGiaiSau_NoiDung.docx` §7.
//
// Bản Dart cùng luật ở `lib/core/logic/wr_polish_guard.dart`. Hai bản cùng
// tồn tại có chủ đích: câu GỐC được dựng trên máy, còn hàm này chỉ nhìn thấy
// chuỗi được gửi lên. Bên nào giữ được câu gốc thì bên đó phải kiểm — nếu chỉ
// kiểm ở một phía thì một bản app cũ, một lỗi mạng cắt ngang, hay một client
// gọi thẳng vào hàm đều đủ để câu AI chưa soi lọt lên màn hình.
//
// Tách khỏi `index.ts` để test được không cần mạng.

/// §7.1 quy tắc 6.
export const BANNED_WORDS = [
  'mindset',
  'thành công',
  'bứt phá',
  'đột phá',
  'burnout',
  'trầm cảm',
  'rối loạn',
];

/// §7.1 quy tắc 7 — "chênh lệch không quá 20 phần trăm".
export const LENGTH_TOLERANCE = 0.20;

export type Rejection =
  | 'empty'
  | 'numbers_changed'
  | 'banned_word'
  | 'length_drift';

/// Mọi con số theo đúng thứ tự xuất hiện, chuẩn hoá dấu thập phân về dấu chấm.
///
/// Đổi "3,8" thành "3.8" KHÔNG phải là đổi con số, mà model đổi qua lại giữa hai
/// kiểu viết rất thường xuyên. Không chuẩn hoá thì rào chắn 1 huỷ gần như mọi
/// câu có số thập phân, và lớp 3 thành ra không bao giờ chạy.
export function extractNumbers(text: string): string[] {
  return [...text.matchAll(/\d+(?:[.,]\d+)?/g)].map((m) =>
    m[0].replace(/,/g, '.')
  );
}

/// Mỗi con số ghép với ĐƠN VỊ đi ngay sau nó, đã sắp xếp.
///
/// Bản đầu so hai dãy số theo THỨ TỰ XUẤT HIỆN. Chặt, nhưng huỷ đúng cái việc
/// model được giao: "Bạn đã nhìn lại 21 lần trong 30 ngày qua…" viết lại thành
/// "Trong 30 ngày qua bạn nhìn lại 21 lần…" không đổi con số nào, chỉ đảo mệnh
/// đề — mà đảo mệnh đề chính là cách viết một câu cho tự nhiên hơn.
///
/// So TẬP HỢP trần thì lại cho qua ca nguy hiểm nhất: "3 lần trong 14 ngày"
/// thành "14 lần trong 3 ngày".
///
/// Ghép số với từ đứng ngay sau giữ được cả hai: đảo mệnh đề thì các cặp y
/// nguyên, tráo số giữa hai đơn vị thì cặp đổi và bị bắt.
export function numberUnitPairs(text: string): string[] {
  const pairs: string[] = [];
  for (const m of text.matchAll(/(\d+(?:[.,]\d+)?)\s*([^\s\d]*)/g)) {
    const number = m[1].replace(/,/g, '.');
    const unit = m[2].toLowerCase().replace(/[^\p{L}%]/gu, '');
    pairs.push(`${number}|${unit}`);
  }
  return pairs.sort();
}

/// Soi câu model trả về. Null = dùng được.
export function inspectPolished(
  original: string,
  polished: string,
): Rejection | null {
  const text = polished.trim();
  if (text.length === 0) return 'empty';

  // Rào chắn 1 — §7.2. So các cặp SỐ + ĐƠN VỊ, xem ghi chú ở [numberUnitPairs].
  const before = numberUnitPairs(original);
  const after = numberUnitPairs(text);
  if (before.length !== after.length) return 'numbers_changed';
  for (let i = 0; i < before.length; i++) {
    if (before[i] !== after[i]) return 'numbers_changed';
  }

  // Rào chắn 2 — §7.2. Không đòi ranh giới từ: tiếng Việt viết rời, "trầm cảm"
  // là hai âm tiết và `\b` không hiểu điều đó.
  const lower = text.toLowerCase();
  for (const w of BANNED_WORDS) {
    if (lower.includes(w.toLowerCase())) return 'banned_word';
  }

  // §7.1 quy tắc 7 — cùng một ý với hai rào trên: dài gấp rưỡi là model đã THÊM
  // nội dung, ngắn một nửa là nó đã BỎ BỚT.
  const base = original.trim().length;
  if (base > 0) {
    const drift = Math.abs(text.length - base) / base;
    if (drift > LENGTH_TOLERANCE) return 'length_drift';
  }

  return null;
}

/// Lời dặn cho model — §7.1, chép nguyên văn tám quy tắc.
///
/// Chép nguyên văn có chủ đích: đây là phần khách viết ra và sẽ sửa lại. Diễn
/// đạt lại theo ý mình thì lần khách đối chiếu tài liệu với hành vi thật sẽ
/// không khớp, và không ai biết chỗ lệch nằm ở đâu.
export const POLISH_SYSTEM_PROMPT =
  `Bạn là biên tập viên tiếng Việt cho một ứng dụng giúp người đi làm nhìn lại công việc của mình.
Nhiệm vụ: viết lại đoạn văn dưới đây cho tự nhiên và bớt khuôn mẫu hơn. Giữ nguyên hoàn toàn ý nghĩa và mọi con số.
Bắt buộc tuân thủ:
1. Không thay đổi, làm tròn, hay thêm bớt bất kỳ con số nào.
2. Không thêm nhận định, chẩn đoán, hay lời khuyên mới không có trong đoạn gốc.
3. Không phán xét người đọc. Không dùng từ ngữ mang tính chẩn đoán tâm lý.
4. Xưng hô: gọi người đọc là "bạn". Không tự xưng.
5. Không dùng dấu gạch ngang dài.
6. Không dùng các từ sau: mindset, thành công, bứt phá, đột phá, burnout, trầm cảm, rối loạn.
7. Giữ độ dài tương đương đoạn gốc, chênh lệch không quá 20 phần trăm.
8. Kết đoạn bằng câu hỏi mở hoặc lời mời, không kết bằng mệnh lệnh.

Chỉ trả về đoạn văn đã viết lại. Không thêm lời dẫn, không thêm giải thích.`;

/// Khoá bộ nhớ đệm cho một câu gốc — §7.3 "chỉ gọi một lần khi nội dung diễn
/// giải được tạo mới, rồi lưu lại kết quả".
///
/// Băm chính CÂU GỐC chứ không băm dữ liệu sinh ra nó: hai người dùng khác nhau
/// có thể ra cùng một câu, và cùng một người mở lại màn hình mà dữ liệu chưa đổi
/// thì câu gốc y hệt. Câu đổi thì khoá đổi, tức là bộ đệm tự hết hạn đúng lúc
/// cần hết hạn, không cần một cột thời gian nào.
export async function sourceHash(
  original: string,
  locale: 'vi' | 'en' = 'vi',
): Promise<string> {
  // Ngôn ngữ PHẢI nằm trong khoá đệm. Cùng một câu gốc cho ra hai bản trau
  // chuốt khác nhau tuỳ app đang chạy ngôn ngữ nào; khoá chỉ theo câu gốc thì
  // người đổi sang tiếng Anh sẽ nhận lại đúng bản tiếng Việt đã đệm trước đó,
  // và không có cách nào làm nó mới lại.
  //
  // Tiếng Việt CỐ Ý không thêm tiền tố: thêm là đổi băm của mọi dòng đã đệm,
  // tức vứt sạch bộ đệm hiện có và bắt trả tiền model lại từ đầu cho những câu
  // đã trau chuốt xong.
  const keyed = locale === 'en' ? `en ${original.trim()}` : original.trim();
  const data = new TextEncoder().encode(keyed);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

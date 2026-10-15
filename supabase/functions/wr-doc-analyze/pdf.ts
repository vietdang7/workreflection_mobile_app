// Bóc chữ khỏi PDF ngay trong Edge Function.
//
// Có từ 15/10/2026, khi chuyển hẳn sang DeepSeek: DeepSeek chỉ nhận CHỮ, không
// nhận file hay ảnh, nên PDF phải được đọc thành chữ trước khi gửi đi. Trước
// đó việc này do bộ đọc file của OpenRouter làm hộ.
//
// Chỉ đọc được PDF CÓ LỚP CHỮ (xuất từ Word, Google Docs, trang web…). PDF
// chụp/quét là ảnh, không có chữ để bóc — nơi gọi nhận chuỗi ngắn và báo
// người dùng tải bản có chữ.

import { extractText, getDocumentProxy } from 'npm:unpdf@0.12.1';

/// Chữ trong [bytes], null khi file hỏng hay không mở được.
export async function extractPdfText(bytes: Uint8Array): Promise<string | null> {
  try {
    const pdf = await getDocumentProxy(new Uint8Array(bytes));
    const { text } = await extractText(pdf, { mergePages: true });
    const joined = Array.isArray(text) ? text.join('\n') : String(text ?? '');
    return joined.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
  } catch (e) {
    console.error(`Không mở được PDF: ${e}`);
    return null;
  }
}

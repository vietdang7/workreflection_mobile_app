// Run: deno test --allow-read --allow-net --allow-env supabase/functions/wr-doc-analyze/

import { assert, assertEquals } from 'jsr:@std/assert@1';
import { extractPdfText } from './pdf.ts';
import { redactPiiDetailed } from '../_shared/pii_redact.ts';

const HERE = new URL('.', import.meta.url).pathname;

Deno.test('PDF có lớp chữ: bóc ra đúng chữ', async () => {
  const bytes = await Deno.readFile(`${HERE}testdata/jd_text.pdf`);
  const text = await extractPdfText(bytes);
  assert(text);
  assert(text.includes('Senior Product Designer'), text);
});

Deno.test('CV PDF: giữ dấu xuống dòng và khử đủ PII (lỗi thật 20/10/2026)', async () => {
  // CV mẫu, thông tin hoàn toàn bịa. Bản cũ dồn cả trang thành một dòng nên
  // hai địa chỉ lọt sang DeepSeek; log khi đó thiếu hẳn `address`.
  const text = await extractPdfText(await Deno.readFile(`${HERE}testdata/cv_mau_pii.pdf`));
  assert(text && text.split('\n').length > 20, 'mất dấu xuống dòng');
  const { text: safe, counts } = redactPiiDetailed(text, { isCv: true });
  assertEquals(counts.address, 2);
  for (const leak of ['Nguyễn Đình Chiểu', 'Trần Duy Hưng', 'Minh Anh', '0909', 'gmail', '079196012345']) {
    assert(!safe.includes(leak), `còn lọt: ${leak}`);
  }
  assert(safe.includes('Công ty TNHH Hàng Tiêu Dùng ABC Việt Nam, Quận 1, TP.HCM'));
});

Deno.test('không phải PDF: trả null, không ném', async () => {
  assertEquals(await extractPdfText(new TextEncoder().encode('khong phai pdf')), null);
});

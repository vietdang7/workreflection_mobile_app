// Run: deno test --allow-read --allow-net --allow-env supabase/functions/wr-doc-analyze/

import { assert, assertEquals } from 'jsr:@std/assert@1';
import { extractPdfText } from './pdf.ts';

const HERE = new URL('.', import.meta.url).pathname;

Deno.test('PDF có lớp chữ: bóc ra đúng chữ', async () => {
  const bytes = await Deno.readFile(`${HERE}testdata/jd_text.pdf`);
  const text = await extractPdfText(bytes);
  assert(text);
  assert(text.includes('Senior Product Designer'), text);
});

Deno.test('không phải PDF: trả null, không ném', async () => {
  assertEquals(await extractPdfText(new TextEncoder().encode('khong phai pdf')), null);
});

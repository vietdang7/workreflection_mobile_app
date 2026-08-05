// Test bộ đọc .docx.
//
//   deno test --allow-read supabase/functions/wr-doc-analyze/docx_test.ts
//
// `testdata/jd-mau.docx` là file Word THẬT (Word/LibreOffice mở được), không
// phải chuỗi XML dựng tay. Toàn bộ giá trị của những test này nằm ở chỗ đó:
// phần dễ sai nhất là đọc bảng mục lục ZIP và giải nén, mà một fixture dựng
// tay thì không chạm tới hai chỗ ấy.

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from 'jsr:@std/assert@1';
import { docXmlToText, extractDocxText } from './docx.ts';

const fixture = await Deno.readFile(
  new URL('./testdata/jd-mau.docx', import.meta.url),
);

Deno.test('đọc được chữ từ file Word thật', async () => {
  const text = await extractDocxText(fixture);
  assert(text !== null, 'phải mở được file docx');
  assertStringIncludes(text!, 'Chuyên viên Chăm sóc Khách hàng cấp cao');
  assertStringIncludes(text!, 'Công ty Cổ phần Dịch vụ Minh An');
});

Deno.test('giữ dấu tiếng Việt nguyên vẹn', async () => {
  const text = (await extractDocxText(fixture))!;
  assertStringIncludes(text, 'Đàm phán điều khoản gia hạn hợp đồng');
  assert(!text.includes('�'), 'không được vỡ mã ký tự');
});

Deno.test('nội dung trong bảng cũng lấy được', async () => {
  const text = (await extractDocxText(fixture))!;
  assertStringIncludes(text, 'Tối thiểu 3 năm');
  assertStringIncludes(text, 'Giao tiếp, thuyết trình, lắng nghe');
});

Deno.test('mỗi đoạn một dòng, không dính vào nhau', async () => {
  const text = (await extractDocxText(fixture))!;
  // Ba gạch đầu dòng phải là ba dòng riêng. Dính lại thì model đọc thành một
  // câu vô nghĩa.
  const lines = text.split('\n');
  assert(
    lines.some((l) => l.startsWith('Giao tiếp trực tiếp với khách hàng')),
    'gạch đầu dòng phải đứng riêng một dòng',
  );
  assert(
    lines.some((l) => l.startsWith('Phối hợp với đội ngũ kinh doanh')),
    'gạch đầu dòng phải đứng riêng một dòng',
  );
});

Deno.test('file không phải ZIP thì trả null, không ném lỗi', async () => {
  const notZip = new TextEncoder().encode('đây chỉ là chữ thường, không phải file');
  assertEquals(await extractDocxText(notZip), null);
});

Deno.test('ZIP hợp lệ nhưng không phải docx thì trả null', async () => {
  // Cắt cụt fixture: vẫn còn dấu vết ZIP ở đầu nhưng mất bảng mục lục.
  assertEquals(await extractDocxText(fixture.subarray(0, 200)), null);
});

Deno.test('bóc thẻ XML: ô bảng ngăn bằng tab, đoạn ngăn bằng xuống dòng', () => {
  const xml = '<w:p><w:r><w:t>Một</w:t></w:r></w:p>' +
    '<w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc>' +
    '<w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr>';
  assertEquals(docXmlToText(xml), 'Một\nA B');
});

Deno.test('giải mã thực thể XML đúng thứ tự', () => {
  // "&amp;lt;" phải ra "&lt;", KHÔNG phải "<". Giải `&amp;` trước là sai.
  assertEquals(docXmlToText('<w:t>a &amp;lt; b</w:t>'), 'a &lt; b');
  assertEquals(docXmlToText('<w:t>Lương &amp; thưởng</w:t>'), 'Lương & thưởng');
});

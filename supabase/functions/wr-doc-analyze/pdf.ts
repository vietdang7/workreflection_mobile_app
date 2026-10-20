import { getDocumentProxy } from 'npm:unpdf@0.12.1';

/// Bóc chữ PDF, GIỮ dấu xuống dòng.
///
/// Trước 20/10/2026 hàm dùng `extractText(pdf, { mergePages: true })` của
/// unpdf — hàm đó nối mọi mẩu chữ bằng dấu cách, cả trang thành MỘT dòng. Chạy
/// thật với CV mẫu: bộ khử PII bắt địa chỉ theo dòng ("Địa chỉ: … hết dòng",
/// dòng địa chỉ đầu CV) nên trượt cả hai địa chỉ, và chúng đi sang DeepSeek.
/// pdf.js vẫn đánh dấu cuối dòng bằng `hasEOL` trên từng mẩu chữ; đọc thẳng
/// `getTextContent()` để giữ nó.
export async function extractPdfText(bytes: Uint8Array): Promise<string | null> {
  try {
    const pdf = await getDocumentProxy(new Uint8Array(bytes));
    const pages: string[] = [];
    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const content = await page.getTextContent();
      let line = '';
      const lines: string[] = [];
      for (const item of content.items as { str?: string; hasEOL?: boolean }[]) {
        if (typeof item.str !== 'string') continue;
        line += item.str;
        if (item.hasEOL) {
          lines.push(line);
          line = '';
        }
      }
      if (line) lines.push(line);
      pages.push(lines.join('\n'));
    }
    return pages
      .join('\n\n')
      .replace(/[ \t]+/g, ' ')
      .replace(/ *\n */g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  } catch (e) {
    console.error(`Không mở được PDF: ${e}`);
    return null;
  }
}

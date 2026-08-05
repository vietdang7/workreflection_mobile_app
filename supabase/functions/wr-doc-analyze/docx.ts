// Đọc chữ ra khỏi file .docx — không cần model, không tốn tiền.
//
// VÌ SAO TỰ BÓC CHỮ Ở ĐÂY
//
// JD và CV người Việt gửi nhau phần lớn là file Word. Trước bản này mình chỉ
// nhận PDF và ảnh, nên người dùng phải tự xuất PDF trước — một bước thừa mà ai
// cũng có thể bỏ ngang.
//
// Không đẩy .docx sang model như PDF: bộ đọc file của OpenRouter chỉ nhận PDF,
// còn model đọc hình thì không mở được file nén. Mà thực ra không cần —
// .docx là một file ZIP chứa XML, chữ nằm sẵn trong đó. Bóc tại chỗ thì rẻ
// hơn, nhanh hơn, và không có chỗ nào để bịa thêm chữ không có trong tài liệu.
//
// Chỉ dựng đúng phần ZIP cần dùng: docx do Word/Google Docs/LibreOffice xuất ra
// đều là ZIP thường (deflate hoặc không nén), một file, không mã hoá.

/// Chữ ký các khối trong file ZIP.
const SIG_EOCD = 0x06054b50; // end of central directory
const SIG_CENTRAL = 0x02014b50; // central directory file header
const SIG_LOCAL = 0x04034b50; // local file header

/// Phần chứa nội dung bài viết chính. Header/footer/chú thích nằm ở file khác —
/// cố ý bỏ qua: JD hiếm khi để nội dung ở đó, mà gộp vào thì lẫn số trang.
const MAIN_PART = 'word/document.xml';

interface ZipEntry {
  name: string;
  method: number;
  compressedSize: number;
  localOffset: number;
}

/// Đọc bảng mục lục ZIP. Trả mảng rỗng nếu đây không phải file ZIP.
function readCentralDirectory(view: DataView): ZipEntry[] {
  // EOCD nằm cuối file, sau nó còn tối đa 65535 byte chú thích.
  let eocd = -1;
  const start = Math.max(0, view.byteLength - 22 - 0xffff);
  for (let i = view.byteLength - 22; i >= start; i--) {
    if (view.getUint32(i, true) === SIG_EOCD) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) return [];

  const count = view.getUint16(eocd + 10, true);
  let offset = view.getUint32(eocd + 16, true);

  const entries: ZipEntry[] = [];
  for (let i = 0; i < count; i++) {
    if (offset + 46 > view.byteLength) break;
    if (view.getUint32(offset, true) !== SIG_CENTRAL) break;
    const method = view.getUint16(offset + 10, true);
    const compressedSize = view.getUint32(offset + 20, true);
    const nameLen = view.getUint16(offset + 28, true);
    const extraLen = view.getUint16(offset + 30, true);
    const commentLen = view.getUint16(offset + 32, true);
    const localOffset = view.getUint32(offset + 42, true);
    const name = new TextDecoder().decode(
      new Uint8Array(view.buffer, view.byteOffset + offset + 46, nameLen),
    );
    entries.push({ name, method, compressedSize, localOffset });
    offset += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

/// Lấy nội dung thô của một file trong ZIP.
async function readEntry(
  bytes: Uint8Array,
  view: DataView,
  entry: ZipEntry,
): Promise<Uint8Array | null> {
  const lo = entry.localOffset;
  if (lo + 30 > bytes.byteLength) return null;
  if (view.getUint32(lo, true) !== SIG_LOCAL) return null;
  // Kích thước ở local header có thể bằng 0 (ghi sau, ở data descriptor), nên
  // độ dài lấy từ bảng mục lục; riêng hai độ dài tên/extra thì phải lấy ở đây
  // vì local header được phép khác central.
  const nameLen = view.getUint16(lo + 26, true);
  const extraLen = view.getUint16(lo + 28, true);
  const dataStart = lo + 30 + nameLen + extraLen;
  const data = bytes.subarray(dataStart, dataStart + entry.compressedSize);

  if (entry.method === 0) return data; // không nén
  if (entry.method !== 8) return null; // chỉ deflate — docx không dùng gì khác

  // Sao ra một Uint8Array mới thay vì đưa thẳng lát cắt: TypeScript không nhận
  // `Uint8Array<ArrayBufferLike>` làm BlobPart, và bản sao cũng cắt đứt tham
  // chiếu tới nguyên cả file trong bộ nhớ.
  const owned = new Uint8Array(data);
  const stream = new Blob([owned]).stream().pipeThrough(
    new DecompressionStream('deflate-raw'),
  );
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/// XML của Word → chữ thuần.
///
/// Giữ ranh giới đoạn và ô bảng: JD hay để trách nhiệm trong bảng, dán liền
/// không dấu ngắt thì "Giao tiếp với khách hàngPhối hợp với đội kỹ thuật" thành
/// một dòng vô nghĩa.
export function docXmlToText(xml: string): string {
  const withBreaks = xml
    .replace(/<w:tab[^>]*\/>/g, '\t')
    .replace(/<w:br[^>]*\/>/g, '\n')
    // Đoạn cuối cùng trong một ô bảng: cắt trước `</w:p>` để cả hàng nằm trên
    // một dòng. Không có dòng này thì mỗi ô rơi xuống một dòng riêng, và cặp
    // "Kinh nghiệm / Tối thiểu 3 năm" mất luôn quan hệ nhãn–giá trị.
    .replace(/<\/w:p>\s*<\/w:tc>/g, '\t')
    .replace(/<\/w:p>/g, '\n')
    .replace(/<\/w:tc>/g, '\t')
    .replace(/<\/w:tr>/g, '\n');

  const text = withBreaks
    .replace(/<[^>]+>/g, '')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(Number(d)))
    .replace(/&amp;/g, '&'); // sau cùng, để "&amp;lt;" không thành "<"

  return text
    .split('\n')
    .map((line) => line.replace(/[ \t]+/g, ' ').trim())
    .filter((line) => line.length > 0)
    .join('\n');
}

/// Bóc chữ từ một file .docx. Trả null khi file không phải docx đọc được.
export async function extractDocxText(bytes: Uint8Array): Promise<string | null> {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const entries = readCentralDirectory(view);
  if (entries.length === 0) return null;

  const main = entries.find((e) => e.name === MAIN_PART);
  if (!main) return null;

  try {
    const raw = await readEntry(bytes, view, main);
    if (!raw) return null;
    return docXmlToText(new TextDecoder().decode(raw));
  } catch (_) {
    return null;
  }
}

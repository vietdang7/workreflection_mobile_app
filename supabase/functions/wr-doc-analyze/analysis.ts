// Lời dặn cho model đọc tài liệu, và bộ chuẩn hoá kết quả nó trả về.
//
// Tách khỏi `index.ts` để test được không cần mạng: `analysis_test.ts` bơm thẳng
// JSON model từng trả để kiểm tra bộ chuẩn hoá.

/// Ba trụ SCA, dùng chung tên với Self-Check trong app.
///   S = Sự rõ ràng · C = Mối quan hệ · A = Cách làm việc
export type Pillar = 'S' | 'C' | 'A';

export interface DocAnalysis {
  doc_type: string;
  title: string | null;
  organization: string | null;
  summary: string;
  responsibilities: string[];
  requirements: string[];
  skills: string[];
  keywords: string[];
  pillars: Record<Pillar, number>;
  language: string | null;
}

/// Lời dặn đọc tài liệu.
///
/// Ba ràng buộc quan trọng nhất, và vì sao:
///   • CHỈ ghi điều CÓ TRONG tài liệu. Model đọc một JD thiếu phần yêu cầu sẽ
///     rất sẵn lòng "bổ sung" yêu cầu điển hình của ngành — và người dùng sẽ
///     tin đó là JD của họ.
///   • Giữ nguyên văn tiếng Việt của tài liệu, không dịch, không diễn giải lại.
///   • Trọng số ba trụ chấm theo thứ tài liệu NHẤN MẠNH, không theo cảm nhận về
///     nghề. Không thấy gì thì chấm 0, không chấm "trung bình cho an toàn".
export function buildExtractionPrompt(docType: string): string {
  const kind = docType === 'jd'
    ? 'một bản mô tả công việc (JD)'
    : docType === 'cv'
    ? 'một hồ sơ năng lực (CV)'
    : 'một tài liệu liên quan tới công việc';

  return `Bạn đang đọc ${kind} do người dùng tải lên. Hãy đọc toàn bộ chữ trong tài liệu và trả về DUY NHẤT một đối tượng JSON, không kèm lời dẫn, không bọc trong dấu \`\`\`.

Cấu trúc JSON:
{
  "doc_type": "jd" | "cv" | "other",
  "title": "chức danh hoặc tiêu đề tài liệu, null nếu không có",
  "organization": "tên công ty/tổ chức, null nếu không có",
  "summary": "2-3 câu tóm tắt tài liệu này nói gì",
  "responsibilities": ["từng đầu việc/trách nhiệm, mỗi mục một dòng"],
  "requirements": ["từng yêu cầu năng lực, bằng cấp, kinh nghiệm"],
  "skills": ["kỹ năng được nêu tên"],
  "keywords": ["8-15 từ khoá quan trọng nhất"],
  "pillars": { "S": 0-5, "C": 0-5, "A": 0-5 },
  "language": "vi" | "en" | ...,
  "raw_text": "TOÀN BỘ chữ bạn đọc được trong tài liệu, giữ nguyên thứ tự"
}

Quy tắc bắt buộc:
1. CHỈ ghi những gì thật sự có trong tài liệu. Không suy đoán, không thêm điều
   "thường thấy" của ngành nghề đó. Không có thì để mảng rỗng hoặc null.
2. Giữ nguyên ngôn ngữ và cách dùng từ của tài liệu. Không dịch sang tiếng khác.
3. "raw_text" phải là chữ đọc được từ tài liệu, không phải bản tóm tắt của bạn.
4. Trọng số "pillars" chấm theo mức tài liệu NHẤN MẠNH mỗi nhóm, thang 0-5:
   - S (Sự rõ ràng): mục tiêu, kỳ vọng, trách nhiệm, quy trình, kế hoạch, báo cáo, phân tích.
   - C (Mối quan hệ): giao tiếp, phối hợp, khách hàng, đội nhóm, đàm phán, dẫn dắt người khác.
   - A (Cách làm việc): chủ động, linh hoạt, đa nhiệm, chịu áp lực, tự sắp xếp, cải tiến.
   Không thấy dấu hiệu nào thì chấm 0. Đừng chấm đều cho an toàn.
5. Nếu ảnh mờ hoặc không đọc được chữ, trả "raw_text": "" và các mảng rỗng.`;
}

function asString(v: unknown): string | null {
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t.length > 0 ? t : null;
}

function asStringList(v: unknown, max = 30): string[] {
  if (!Array.isArray(v)) return [];
  const out: string[] = [];
  for (const item of v) {
    const s = asString(item);
    // Bỏ trùng: model hay lặp lại một yêu cầu ở cả `requirements` lẫn `skills`,
    // và danh sách hiển thị lên màn hình thì lặp trông như lỗi.
    if (s && !out.includes(s)) out.push(s);
    if (out.length >= max) break;
  }
  return out;
}

function asPillar(v: unknown): number {
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(5, Math.round(n)));
}

/// Chuẩn hoá thứ model trả về thành đúng hình dạng app mong đợi.
///
/// Model có thể thiếu trường, trả số dạng chuỗi, hoặc trả `null` giữa mảng.
/// Lưu thẳng vào database thì mỗi chỗ đọc lại phải tự phòng thân, và sẽ có chỗ
/// quên.
export function normalizeAnalysis(
  parsed: Record<string, unknown>,
): { analysis: DocAnalysis; extractedText: string } {
  const rawPillars = (parsed.pillars ?? {}) as Record<string, unknown>;

  const analysis: DocAnalysis = {
    doc_type: asString(parsed.doc_type) ?? 'other',
    title: asString(parsed.title),
    organization: asString(parsed.organization),
    summary: asString(parsed.summary) ?? '',
    responsibilities: asStringList(parsed.responsibilities),
    requirements: asStringList(parsed.requirements),
    skills: asStringList(parsed.skills),
    keywords: asStringList(parsed.keywords, 20),
    pillars: {
      S: asPillar(rawPillars.S ?? rawPillars.s),
      C: asPillar(rawPillars.C ?? rawPillars.c),
      A: asPillar(rawPillars.A ?? rawPillars.a),
    },
    language: asString(parsed.language),
  };

  // `raw_text` để riêng, KHÔNG nhét vào cột `analysis`: nó là phần dài nhất và
  // là thứ duy nhất mọi tính năng khác cần đọc nguyên văn. Để lẫn trong jsonb
  // thì mỗi lần đọc ngữ cảnh phải kéo cả bản phân tích theo.
  const extractedText = asString(parsed.raw_text) ?? '';

  return { analysis, extractedText };
}

/// Trụ nổi trội nhất, dùng để nói một câu ngắn về tài liệu.
/// Null khi không trụ nào nhỉnh hơn — hoà thì im, đừng chọn bừa.
export function dominantPillar(pillars: Record<Pillar, number>): Pillar | null {
  const entries = (['S', 'C', 'A'] as Pillar[])
    .map((p) => [p, pillars[p] ?? 0] as const)
    .sort((a, b) => b[1] - a[1]);
  if (entries[0][1] === 0) return null;
  if (entries[0][1] === entries[1][1]) return null;
  return entries[0][0];
}

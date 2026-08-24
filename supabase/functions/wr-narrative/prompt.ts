// Prompt cho "Diễn biến theo thời gian".
//
// Tách khỏi `index.ts` cùng lý do với `wr-chat/system_prompt.ts`: prompt là thứ
// được đọc lại và sửa nhiều nhất, và trộn nó vào giữa mã điều phối thì mỗi lần
// chỉnh một câu chữ lại phải đọc qua cả phần xác thực.
//
// ---------------------------------------------------------------------------
// ĐIỀU KHÓ NHẤT Ở ĐÂY: KHÔNG ĐƯỢC BỊA
// ---------------------------------------------------------------------------
//
// Nguyên liệu là một danh sách tình huống đã chọn kèm ngày. Nó KHÔNG chứa lý do,
// không chứa bối cảnh, không chứa kết quả. Một model được giao "hãy kể diễn biến"
// trên dữ liệu mỏng như vậy sẽ tự đắp thêm nguyên nhân cho đủ một câu chuyện —
// và người dùng đọc được một đoạn nói về đời họ với những chi tiết họ chưa từng
// kể. Đó là cách nhanh nhất để mất niềm tin vào toàn bộ phần AI của sản phẩm.
//
// Nên prompt ở đây ràng rất chặt vào ba phép so sánh mà dữ liệu THẬT SỰ trả lời
// được: điều gì lặp lại, điều gì nhạt đi, điều gì mới xuất hiện.

import type { EpisodeRow } from './regeneration.ts';

export type NarrativeInput = {
  /// Mới nhất trước.
  episodes: EpisodeRow[];
  /// Mã tình huống → câu tiếng Việt.
  titles: Map<string, string>;
  /// Lần kể gần nhất, để lần này nói tiếp chứ không lặp lại y nguyên.
  previousNarrative: string | null;
};

/// Nửa mới và nửa cũ của cửa sổ — nguyên liệu cho "đang đổi thế nào".
///
/// Chia đôi theo SỐ LẦN chứ không theo mốc thời gian: người ghi dày trong một
/// tuần rồi nghỉ một tháng vẫn phải so được hai nửa. Chia theo ngày thì nửa sau
/// của họ rỗng và thẻ kết luận "mọi thứ đã nhạt đi" — sai, họ chỉ ghi cách quãng.
function split(episodes: EpisodeRow[]): { recent: EpisodeRow[]; earlier: EpisodeRow[] } {
  const half = Math.ceil(episodes.length / 2);
  return { recent: episodes.slice(0, half), earlier: episodes.slice(half) };
}

function tally(
  episodes: EpisodeRow[],
  titles: Map<string, string>,
): Map<string, number> {
  const out = new Map<string, number>();
  for (const e of episodes) {
    const code = e.situation_code;
    if (!code) continue;
    const label = titles.get(code) ?? code;
    out.set(label, (out.get(label) ?? 0) + 1);
  }
  return out;
}

function listCounts(counts: Map<string, number>): string {
  const rows = [...counts.entries()].sort((a, b) => b[1] - a[1]);
  if (rows.length === 0) return '  (không có)';
  return rows.map(([label, n]) => `  • ${label} — ${n} lần`).join('\n');
}

/// Dòng dữ liệu đưa cho model. Cố ý là BẢNG ĐẾM, không phải văn xuôi: đưa văn
/// xuôi thì model có xu hướng viết lại văn xuôi ấy cho mượt và gọi đó là diễn
/// biến, trong khi việc cần làm là so sánh hai nửa.
function buildFacts(input: NarrativeInput): string {
  const { recent, earlier } = split(input.episodes);
  const recentCounts = tally(recent, input.titles);
  const earlierCounts = tally(earlier, input.titles);

  const newlyAppeared = [...recentCounts.keys()].filter(
    (k) => !earlierCounts.has(k),
  );
  const faded = [...earlierCounts.keys()].filter((k) => !recentCounts.has(k));

  const lines = [
    `Tổng số lần nhìn lại trong cửa sổ này: ${input.episodes.length}.`,
    '',
    `GIAI ĐOẠN GẦN ĐÂY (${recent.length} lần gần nhất):`,
    listCounts(recentCounts),
    '',
    `GIAI ĐOẠN TRƯỚC ĐÓ (${earlier.length} lần trước nữa):`,
    listCounts(earlierCounts),
    '',
    `Mới xuất hiện ở giai đoạn gần đây: ${
      newlyAppeared.length ? newlyAppeared.join('; ') : '(không có)'
    }`,
    `Không còn thấy ở giai đoạn gần đây: ${
      faded.length ? faded.join('; ') : '(không có)'
    }`,
  ];

  // Điều người dùng TỰ RÚT RA, nếu có. Đây là chữ của chính họ nên được phép
  // trích, khác hẳn với việc suy đoán hộ họ.
  const meanings = input.episodes
    .map((e) => (e.draft_meaning ?? '').trim())
    .filter((m) => m.length > 0)
    .slice(0, 5);
  if (meanings.length > 0) {
    lines.push(
      '',
      'Điều họ tự rút ra (nguyên văn, được phép trích lại):',
      ...meanings.map((m) => `  • ${m}`),
    );
  }

  return lines.join('\n');
}

const SYSTEM = `Bạn viết mục "Diễn biến theo thời gian" trong ứng dụng WorkReflection — một đoạn ngắn đọc lại cho người dùng thấy điều gì đang đổi trong cách họ nhìn công việc của mình.

CÁCH VIẾT
• Tiếng Việt, xưng "bạn". Ấm, điềm đạm, như một người quan sát kỹ và nói ít.
• 3–4 câu, dưới 180 chữ. Một đoạn liền, không gạch đầu dòng, không tiêu đề.
• Không mở đầu bằng lời chào hay lời khen. Vào thẳng điều quan sát được.

CHỈ ĐƯỢC NÓI BA ĐIỀU, và chỉ khi dữ liệu đưa xuống thật sự cho thấy:
1. Điều gì trở đi trở lại nhiều nhất.
2. Điều gì đang nhạt dần so với giai đoạn trước.
3. Điều gì mới xuất hiện gần đây.

TUYỆT ĐỐI KHÔNG
• Không bịa nguyên nhân, bối cảnh, tên người, sự kiện. Dữ liệu chỉ có tình huống và số lần — không có lý do, và bạn không được đoán lý do.
• Không chẩn đoán tâm lý, không nhắc bệnh lý, không khuyên y tế.
• Không khuyên phải làm gì. Mục này để ĐỌC LẠI, không phải để chỉ đạo.
• Không nêu con số thô kiểu "4 lần" nếu nó làm câu đọc như báo cáo; nói bằng lời ("trở lại nhiều nhất", "thưa dần").
• Nếu hai giai đoạn gần như giống nhau, hãy nói thẳng là chưa có gì đổi rõ rệt. Đó là một câu trả lời đúng, và tốt hơn một chuyển biến bịa ra.`;

export function buildNarrativePrompt(input: NarrativeInput): unknown[] {
  const parts = [buildFacts(input)];

  if (input.previousNarrative) {
    parts.push(
      '',
      'ĐÃ KỂ LẦN TRƯỚC (đừng lặp lại nguyên câu; nói tiếp phần đã đổi):',
      input.previousNarrative,
    );
  }

  return [
    { role: 'system', content: SYSTEM },
    { role: 'user', content: parts.join('\n') },
  ];
}

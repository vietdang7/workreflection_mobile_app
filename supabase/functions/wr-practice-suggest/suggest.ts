// Lời dặn + phép thử cho gợi ý thực hành (`wr-practice-suggest`).
//
// Tách khỏi `index.ts` để test không cần mạng. Mô hình Hybrid: AI chỉ ĐỀ XUẤT
// ba cách + một câu hỏi; khung bốn bước do app dựng bằng luật
// (`buildUserPracticeSteps`), và mọi thứ AI trả về phải qua phép thử ở đây
// (máy chủ) rồi qua lớp đối soát "đã thử" ở app (`mergeAiMentorOptions`).

import { stripMarkdown } from '../_shared/strip_markdown.ts';
import type { WrLocale } from '../_shared/locale.ts';

export interface PracticeIntakeInput {
  title: string;
  situation: string;
  goal: string;
  tried: string | null;
}

export interface SuggestedOption {
  title: string;
  fit: string;
  tradeoff: string;
}

export interface Suggestion {
  options: SuggestedOption[];
  question: string;
}

/// Trần độ dài mỗi ô người dùng gõ — chặn ai đó dán cả trang để đốt token.
export const MAX_FIELD_CHARS = 400;

/// Trần chữ của từng phần AI viết. Thẻ trên màn hình hẹp; dài hơn là vỡ thẻ.
export const LIMITS = {
  titleWords: 8,
  sentenceWords: 32,
  questionWords: 28,
} as const;

/// Độ dài XIN model viết — chặt hơn [LIMITS] (phép thử). Đây là chỗ quyết định
/// độ trễ: model sinh bao nhiêu chữ thì chờ bấy nhiêu, `max_tokens` chỉ là
/// trần. Lần chạy thật 20/10 viết câu ~20 chữ, mất 9,3 giây trong khung 12.
/// Phép thử nới hơn để model lố vài chữ vẫn dùng được, không rơi về bộ luật.
export const ASK = {
  titleWords: 7,
  sentenceWords: 18,
  questionWords: 20,
} as const;

function clip(v: unknown): string {
  return String(v ?? '').replace(/\s+/g, ' ').trim().slice(0, MAX_FIELD_CHARS);
}

/// Đọc thân yêu cầu. Null khi thiếu ba ô bắt buộc (tên · tình huống · mong muốn).
export function parseIntake(body: unknown): PracticeIntakeInput | null {
  const b = (body ?? {}) as Record<string, unknown>;
  const title = clip(b.title);
  const situation = clip(b.situation);
  const goal = clip(b.goal);
  const tried = clip(b.tried);
  if (!title || !situation || !goal) return null;
  return { title, situation, goal, tried: tried || null };
}

export function buildMessages(intake: PracticeIntakeInput, locale: WrLocale): unknown[] {
  const en = locale === 'en';
  const system = en
    ? `You help a working adult practise one small change at work. They describe a situation, what they want to be different, and possibly what they already tried without success. Propose exactly 3 concrete, realistic ways to try, fitted to their context, plus 1 reflective question to ask themselves after trying.

Rules:
1. Never suggest again what they already tried, nor a close variant of it.
2. Each way is something they can do in one real situation this week. No generic advice like "communicate better".
3. "title": at most ${ASK.titleWords} words, starts with a verb. "fit": one sentence starting with "Fits when", at most ${ASK.sentenceWords} words. "tradeoff": one sentence on what it costs them, at most ${ASK.sentenceWords} words.
4. "question": one open question ending with "?", at most ${ASK.questionWords} words.
5. Plain text only: no markdown, no emoji, no em dash. Do not mention names, phone numbers or any personal details. Do not diagnose or label the person.
6. Write in English.

Return ONLY a json object. Each element of "options" must contain all three keys title, fit and tradeoff together:
{"options":[{"title":"","fit":"","tradeoff":""},{"title":"","fit":"","tradeoff":""},{"title":"","fit":"","tradeoff":""}],"question":""}`
    : `Bạn giúp một người đi làm thực hành một thay đổi nhỏ trong công việc. Họ kể một tình huống, điều họ muốn khác đi, và có thể cả điều đã thử mà chưa có kết quả. Hãy đề xuất đúng 3 cách làm cụ thể, thực tế, hợp với bối cảnh của họ, và 1 câu hỏi để họ tự hỏi sau khi thử.

Quy tắc:
1. Tuyệt đối không gợi ý lại điều họ đã thử, kể cả một biến thể gần giống.
2. Mỗi cách là việc làm được trong một tình huống thật ngay tuần này. Không khuyên chung chung kiểu "giao tiếp tốt hơn".
3. "title": tối đa ${ASK.titleWords} chữ, mở đầu bằng động từ. "fit": một câu, mở đầu bằng "Phù hợp khi", tối đa ${ASK.sentenceWords} chữ. "tradeoff": một câu nói cái giá họ phải chấp nhận, tối đa ${ASK.sentenceWords} chữ.
4. "question": một câu hỏi mở, kết thúc bằng "?", tối đa ${ASK.questionWords} chữ.
5. Chỉ chữ trơn: không markdown, không emoji, không dấu gạch dài. Không nhắc tên người, số điện thoại hay thông tin cá nhân. Không chẩn đoán hay dán nhãn con người họ.
6. Viết bằng tiếng Việt, xưng "bạn".

Chỉ trả về một object json. Mỗi phần tử của "options" phải có đủ cả ba khoá title, fit, tradeoff trong cùng một object:
{"options":[{"title":"","fit":"","tradeoff":""},{"title":"","fit":"","tradeoff":""},{"title":"","fit":"","tradeoff":""}],"question":""}`;

  const user = en
    ? `Theme: ${intake.title}\nSituation: ${intake.situation}\nWants to be different: ${intake.goal}\nAlready tried without success: ${intake.tried ?? '(nothing stated)'}`
    : `Chủ đề: ${intake.title}\nTình huống đang gặp: ${intake.situation}\nMong muốn khác đi: ${intake.goal}\nĐã thử mà chưa có kết quả: ${intake.tried ?? '(không nêu)'}`;

  return [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ];
}

export function parseJsonLoose(raw: string): unknown {
  const s = raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '');
  try {
    return JSON.parse(s);
  } catch (_) {
    const a = s.indexOf('{');
    const b = s.lastIndexOf('}');
    if (a < 0 || b <= a) return null;
    try {
      return JSON.parse(s.slice(a, b + 1));
    } catch (_) {
      return null;
    }
  }
}

function words(s: string): number {
  return s.split(/\s+/).filter(Boolean).length;
}

/// Chữ AI viết: lột markdown, bỏ gạch dài, gọn khoảng trắng.
function clean(v: unknown): string {
  return stripMarkdown(String(v ?? ''))
    .replace(/\s*[—–]\s*/g, ', ')
    .replace(/\s+/g, ' ')
    .trim();
}

/// Gộp các mảnh của cùng một cách.
///
/// Chạy thật 20/10/2026, DeepSeek trả mỗi cách thành HAI object liền nhau:
/// `{title, fit}` rồi `{tradeoff}`. Nội dung đúng, chỉ sai khuôn — loại hết là
/// phí một lượt tốt. Mảnh nào chưa đủ ba khoá thì nhận thêm khoá còn thiếu từ
/// mảnh kế tiếp, miễn mảnh đó không mở một cách mới (không có `title` khi mình
/// đã có `title`).
export function mergeFragments(raw: unknown[]): Record<string, unknown>[] {
  const out: Record<string, unknown>[] = [];
  let cur: Record<string, unknown> | null = null;
  const has = (o: Record<string, unknown>, k: string) =>
    typeof o[k] === 'string' && String(o[k]).trim() !== '';
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const r = item as Record<string, unknown>;
    const opensNew = has(r, 'title');
    const prev: Record<string, unknown> | null = cur;
    if (prev && !(opensNew && has(prev, 'title'))) {
      const keys = ['title', 'fit', 'tradeoff'];
      const canTake = keys.some((k) => has(r, k) && !has(prev, k));
      const clashes = keys.some((k) => has(r, k) && has(prev, k));
      if (canTake && !clashes) {
        cur = Object.assign({}, prev, r) as Record<string, unknown>;
        continue;
      }
    }
    if (cur) out.push(cur);
    cur = { ...r };
  }
  if (cur) out.push(cur);
  return out;
}

/// Còn sót số điện thoại / email / nhãn PII trong chữ AI viết thì loại.
const PII_LEFTOVER_RE = /@|\[(?:HỌ TÊN|EMAIL|SỐ|ĐỊA CHỈ|NGÀY SINH|LIÊN KẾT)|\d{6,}/u;

/// Phép thử phía máy chủ. Trả null kèm lý do khi không dùng được — app khi đó
/// dựng bằng luật (lớp 2), người dùng không thấy lỗi nào.
export function review(parsed: unknown): { ok: Suggestion | null; reason?: string } {
  const p = (parsed ?? {}) as Record<string, unknown>;
  const rawOptions = mergeFragments(Array.isArray(p.options) ? p.options : []);
  const options: SuggestedOption[] = [];
  const seen = new Set<string>();
  for (const o of rawOptions) {
    const r = o;
    const opt = {
      title: clean(r.title).replace(/[.。]+$/, ''),
      fit: clean(r.fit),
      tradeoff: clean(r.tradeoff),
    };
    if (!opt.title || !opt.fit || !opt.tradeoff) continue;
    if (words(opt.title) > LIMITS.titleWords + 2) continue;
    if (words(opt.fit) > LIMITS.sentenceWords || words(opt.tradeoff) > LIMITS.sentenceWords) continue;
    if (PII_LEFTOVER_RE.test(`${opt.title} ${opt.fit} ${opt.tradeoff}`)) continue;
    const key = opt.title.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    options.push(opt);
  }
  if (options.length < 3) return { ok: null, reason: `options=${options.length}` };

  let question = clean(p.question);
  if (question && !question.endsWith('?')) question = '';
  if (question && (words(question) > LIMITS.questionWords + 4 || PII_LEFTOVER_RE.test(question))) {
    question = '';
  }
  // Câu hỏi hỏng không kéo cả bản gợi ý xuống: app giữ câu bước 4 mặc định.
  return { ok: { options: options.slice(0, 3), question } };
}

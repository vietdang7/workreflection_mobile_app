// Edge Function `wr-polish` — lớp 3 của Diễn giải sâu (nhóm C).
//
// Nguồn: `WorkReflection_DienGiaiSau_NoiDung.docx` §7.
//
// ---------------------------------------------------------------------------
// HÀM NÀY LÀM ĐÚNG MỘT VIỆC, VÀ NÓ NHỎ HƠN VẺ NGOÀI
// ---------------------------------------------------------------------------
//
// §7: "Vai trò duy nhất của AI ở đây là viết lại một câu đã hoàn chỉnh cho mượt
// hơn và bớt lặp. AI không nhận dữ liệu thô, không tự phân tích, không tự kết
// luận."
//
// Câu ĐÚNG đã được app dựng xong ở lớp 2 (`wr_deep_interpretation.dart`) trước
// khi gọi tới đây. Hàm này nhận đúng chuỗi đó và trả về một chuỗi dễ đọc hơn.
// Không có dữ liệu cá nhân nào khác đi lên: không Episode, không điểm
// Self-Check, không mã tình huống.
//
// Hệ quả đáng nói: BỎ HẲN hàm này thì sản phẩm vẫn chạy đúng. §7.3 nói rõ có
// thể tắt bằng một cờ cấu hình. Vì vậy mọi nhánh hỏng ở đây đều trả 200 kèm
// `polished: null` chứ không ném lỗi — app đã có sẵn câu để hiện.
//
// ---------------------------------------------------------------------------
// VÌ SAO CÓ BỘ NHỚ ĐỆM
// ---------------------------------------------------------------------------
//
// §7.3: "Không gọi mỗi lần mở màn hình. Chỉ gọi một lần khi nội dung diễn giải
// được tạo mới, rồi lưu lại kết quả."
//
// Câu diễn giải chỉ đổi khi dữ liệu nền đổi, mà dữ liệu nền đổi vài lần một
// tháng. Không đệm thì mỗi lần mở màn Diễn giải sâu là một lượt gọi model cho
// đúng một câu chưa hề khác đi.
//
// Khoá đệm là BĂM CỦA CHÍNH CÂU GỐC. Câu đổi thì khoá đổi, nên bộ đệm tự hết
// hạn đúng lúc cần hết hạn — không cần cột thời gian, không cần dọn dẹp.
//
// ---------------------------------------------------------------------------
// SECRET CẦN ĐẶT TRƯỚC KHI DEPLOY
//
//   supabase secrets set OPENROUTER_API_KEY=sk-or-v1-...   (dùng chung wr-chat)
// ---------------------------------------------------------------------------

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { stripMarkdown } from '../_shared/strip_markdown.ts';
import {
  POLISH_SYSTEM_PROMPT,
  inspectPolished,
  sourceHash,
} from './guard.ts';

/// Cùng model với `wr-chat` và `wr-narrative`. Ghim bản có ngày, không dùng
/// alias `-latest` — xem ghi chú dài ở `wr-chat/index.ts`.
const MODEL = Deno.env.get('WR_POLISH_MODEL') ??
  'deepseek/deepseek-v4-flash-0731';

/// Trần độ dài. Câu gốc dài nhất của lớp 2 chừng 80 chữ, và quy tắc 7 buộc bản
/// viết lại không được dài hơn 20%.
const MAX_OUTPUT_TOKENS = 320;

/// Trần chờ PHÍA MÁY CHỦ.
///
/// Rộng hơn hẳn 2 giây của rào chắn 3, và cố ý như vậy: app đã tự bỏ cuộc sau
/// 2 giây rồi (§7.2). Nhưng lượt gọi này vẫn đáng chạy nốt, vì kết quả được ghi
/// vào bộ đệm và lần mở màn SAU sẽ đọc được ngay. Cắt ở 2 giây tại đây thì
/// không lượt nào kịp vào đệm, và lớp 3 vĩnh viễn không bao giờ hiện.
const UPSTREAM_TIMEOUT_MS = 20_000;

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

/// Trần độ dài chuỗi nhận vào. Câu lớp 2 dài nhất chừng 400 ký tự; 2000 là
/// rộng rãi mà vẫn chặn được ai đó bơm cả một bài văn lên để đốt token.
const MAX_INPUT_CHARS = 2000;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

/// Không viết lại được lần này — KHÔNG phải lỗi.
///
/// Trả 200 kèm `polished: null`. App có sẵn câu gốc nên không có gì hỏng, và
/// `reason` để đọc log xem rào chắn nào đang huỷ nhiều nhất.
function plain(reason: string) {
  return json({ polished: null, reason });
}

async function isPremium(db: SupabaseClient, userId: string): Promise<boolean> {
  const { data } = await db
    .from('cc_profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle();
  return (data?.role ?? '').toLowerCase() === 'premium';
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') return plain('method_not_allowed');

  const openRouterKey = Deno.env.get('OPENROUTER_API_KEY');
  if (!openRouterKey) {
    console.error('THIẾU secret OPENROUTER_API_KEY — lớp 3 tắt.');
    return plain('no_api_key');
  }

  // ── 1 · Xác thực ────────────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) return plain('unauthenticated');

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const authClient = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: authError } = await authClient.auth.getUser();
  const user = userData?.user;
  if (authError || !user) return plain('unauthenticated');

  const db = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // ── 2 · Gói ─────────────────────────────────────────────────────────────
  //
  // Diễn giải sâu là Premium. Chặn ở đây nữa vì khoá trên giao diện chỉ ngăn
  // người dùng NHÌN THẤY, không ngăn ai gọi thẳng vào hàm — và mỗi lượt gọi là
  // tiền thật trả cho model.
  if (!(await isPremium(db, user.id))) return plain('premium_only');

  // ── 3 · Câu gốc ─────────────────────────────────────────────────────────
  let original = '';
  try {
    const body = await req.json();
    original = String(body?.text ?? '').trim();
  } catch (_) {
    return plain('bad_request');
  }
  if (original.length === 0) return plain('empty_input');
  if (original.length > MAX_INPUT_CHARS) return plain('input_too_long');

  const hash = await sourceHash(original);

  // ── 4 · Bộ nhớ đệm ──────────────────────────────────────────────────────
  const cached = await db
    .from('wr_polished_text')
    .select('polished')
    .eq('user_id', user.id)
    .eq('source_hash', hash)
    .maybeSingle();
  if (cached.data?.polished) {
    return json({ polished: cached.data.polished, reason: 'cache' });
  }

  // ── 5 · Gọi model ───────────────────────────────────────────────────────
  let raw = '';
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    const res = await fetch(OPENROUTER_URL, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${openRouterKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://workreflection.app',
        'X-Title': 'WorkReflection Mobile',
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: 'system', content: POLISH_SYSTEM_PROMPT },
          { role: 'user', content: original },
        ],
        // Thấp nhất trong ba hàm. Đây là biên tập câu chữ, không phải sáng tác:
        // nhiệt độ cao ở đây đọc ra thành viết lại nội dung.
        temperature: 0.3,
        max_tokens: MAX_OUTPUT_TOKENS,
        reasoning: { enabled: false },
      }),
    });
    if (!res.ok) {
      console.error(`OpenRouter ${res.status}`);
      return plain('upstream_error');
    }
    const payload = await res.json();
    raw = stripMarkdown(
      String(payload?.choices?.[0]?.message?.content ?? ''),
    ).trim();
  } catch (e) {
    const aborted = e instanceof DOMException && e.name === 'AbortError';
    console.error(aborted ? 'OpenRouter quá hạn chờ' : `OpenRouter lỗi: ${e}`);
    return plain(aborted ? 'upstream_timeout' : 'upstream_error');
  } finally {
    clearTimeout(timer);
  }

  // ── 6 · Ba rào chắn ─────────────────────────────────────────────────────
  const rejected = inspectPolished(original, raw);
  if (rejected !== null) {
    // Ghi log để đội nội dung biết rào nào đang huỷ nhiều — một tỷ lệ huỷ cao
    // là dấu hiệu prompt cần sửa, không phải dấu hiệu tắt lớp 3.
    console.warn(`Huỷ bản viết lại: ${rejected}`);
    return plain(rejected);
  }

  // ── 7 · Ghi đệm ─────────────────────────────────────────────────────────
  //
  // Best-effort. Ghi hỏng thì lần sau gọi lại model — tốn thêm một lượt, không
  // ai thấy gì khác.
  const { error: cacheError } = await db.from('wr_polished_text').upsert({
    user_id: user.id,
    source_hash: hash,
    polished: raw,
  }, { onConflict: 'user_id,source_hash' });
  if (cacheError) console.error('Không ghi được đệm:', cacheError.message);

  return json({ polished: raw, reason: 'generated' });
});

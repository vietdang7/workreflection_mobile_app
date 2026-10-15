// Edge Function `wr-experience-read` — viết khối "Bạn đang khó ở chỗ nào" ở
// Hiểu mình › Trải nghiệm của bạn › Từ những lần bạn nhìn lại.
//
// Nguồn: "Logic đọc hiểu mình.docx" §2 (Cloud & Coral, 15/10/2026). Mục 9 của
// tài liệu đã chốt: câu hình dạng và câu phân biệt do AI sinh.
//
// ---------------------------------------------------------------------------
// VÌ SAO KHÔNG GỘP VÀO `wr-narrative`
// ---------------------------------------------------------------------------
//
// `wr-narrative` là Premium và đọc 30 lần gần nhất. Khối này nằm ở phần "dữ
// liệu của người dùng", tài liệu §1 ghi rõ là MIỄN PHÍ, và đọc TOÀN BỘ lịch sử.
// Thêm một nhánh miễn phí vào một hàm Premium đang chạy là đổi cổng tiền của
// nó; một hàm riêng thì không đụng gì tới thứ đang chạy.
//
// ---------------------------------------------------------------------------
// TIẾT KIỆM
// ---------------------------------------------------------------------------
//
// Miễn phí nghĩa là ai cũng gọi được, nên:
//   · Nhớ đệm theo nguyên liệu: cùng danh sách chuyện + cùng dòng tự viết +
//     cùng ngôn ngữ thì trả lại bản đã viết (`wr_experience_readings`). Tài
//     liệu §2: "Sinh một lần, lưu cùng bản đọc, không sinh lại ở mỗi màn."
//   · Trần [DAILY_LIMIT] lượt gọi model mỗi người mỗi 24 giờ.
//
// ---------------------------------------------------------------------------
// SECRET: DEEPSEEK_API_KEY, dùng chung mọi hàm AI (`_shared/deepseek.ts`).
// ---------------------------------------------------------------------------

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { hasAiConsent } from '../_shared/ai_consent.ts';
import {
  deepSeekFetch,
  deepSeekKey,
  deepSeekModel,
  deepSeekText,
} from '../_shared/deepseek.ts';
import { pick, readLocale, readLocaleHeader, WrLocale } from '../_shared/locale.ts';
import {
  buildMessages,
  fingerprint,
  parseJsonLoose,
  parsePillars,
  validateAll,
} from './reading.ts';

const MAX_OUTPUT_TOKENS = 700;
const UPSTREAM_TIMEOUT_MS = 45_000;
const DAILY_LIMIT = 8;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-wr-locale',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

/// Không viết được lần này — KHÔNG phải lỗi. App gọi tự động khi mở màn, nên
/// mọi nhánh "không có" đều trả 200 để màn hình im lặng hiện số đếm.
function skip(reason: string) {
  return json({ generated: false, reason, pillars: {} });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  let locale: WrLocale = readLocaleHeader(req);
  if (req.method !== 'POST') {
    return json({ error: pick(locale, 'Yêu cầu không hợp lệ.', 'Invalid request.') }, 405);
  }

  const apiKey = deepSeekKey();
  if (!apiKey) {
    console.error('THIẾU secret DEEPSEEK_API_KEY — hàm không thể chạy.');
    return skip('not_configured');
  }

  // ── 1 · Xác thực ────────────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return json({ error: pick(locale, 'Cần đăng nhập.', 'Please sign in.') }, 401);
  }
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const authClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: authError } = await authClient.auth.getUser();
  const user = userData?.user;
  if (authError || !user) {
    return json(
      { error: pick(locale, 'Phiên đăng nhập đã hết hạn.', 'Your session has expired.') },
      401,
    );
  }

  const db = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });

  // ── 2 · Chưa cho phép gửi sang AI thì dừng ──────────────────────────────
  //
  // Hàm này gửi chính những dòng người dùng tự viết sang DeepSeek.
  // Guideline 5.1.1(i), xem `_shared/ai_consent.ts`.
  if (!(await hasAiConsent(db, user.id))) {
    return skip('ai_consent_required');
  }

  // ── 3 · Nguyên liệu ─────────────────────────────────────────────────────
  let body: unknown;
  try {
    body = await req.json();
  } catch (_) {
    return skip('bad_request');
  }
  // Header là nguồn chính; thân có ghi ngôn ngữ thì theo thân.
  if ((body as Record<string, unknown> | null)?.locale !== undefined) {
    locale = readLocale(body);
  }
  const pillars = parsePillars(body);
  if (pillars.length === 0) return skip('not_enough_data');

  const key = await fingerprint(pillars, locale);

  // ── 4 · Đã viết cho đúng nguyên liệu này thì trả lại ────────────────────
  const { data: cached } = await db
    .from('wr_experience_readings')
    .select('result')
    .eq('user_id', user.id)
    .eq('fingerprint', key)
    .eq('locale', locale)
    .maybeSingle();
  if (cached) {
    return json({ generated: false, cached: true, locale, pillars: cached.result ?? {} });
  }

  // ── 5 · Trần mỗi ngày ───────────────────────────────────────────────────
  const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  const { count } = await db
    .from('wr_experience_readings')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .gte('created_at', since);
  if ((count ?? 0) >= DAILY_LIMIT) return skip('daily_limit');

  // ── 6 · Gọi model ───────────────────────────────────────────────────────
  let reply: string;
  try {
    reply = await callModel(apiKey, buildMessages(pillars, locale));
  } catch (e) {
    const aborted = e instanceof DOMException && e.name === 'AbortError';
    console.error(aborted ? 'DeepSeek quá hạn chờ' : `DeepSeek lỗi: ${e}`);
    return skip('upstream_error');
  }
  if (!reply) return skip('empty_reply');

  // ── 7 · Phép thử trước khi hiển thị ─────────────────────────────────────
  //
  // Nhóm nào trượt thì im lặng. Vẫn ghi lại kết quả (kể cả rỗng) để lần mở sau
  // không gọi model lại cho cùng nguyên liệu: câu trượt một lần thường trượt
  // lại, và chờ thêm một lần nhìn lại mới là nguyên liệu mới.
  const result = validateAll(parseJsonLoose(reply), pillars, locale);
  const dropped = pillars.map((p) => p.pillar).filter((p) => !result[p]);
  if (dropped.length > 0) {
    console.warn(`Phép thử loại nhóm ${dropped.join(',')}: ${reply.slice(0, 600)}`);
  }

  const { error: writeError } = await db.from('wr_experience_readings').insert({
    user_id: user.id,
    fingerprint: key,
    locale,
    result,
    model: deepSeekModel(),
  });
  if (writeError) console.error('Không ghi được bản đọc:', writeError.message);

  return json({ generated: true, cached: false, locale, pillars: result });
});

async function callModel(key: string, messages: unknown[]): Promise<string> {
  const res = await deepSeekFetch(key, messages, {
    // Đọc lại dữ liệu, không trò chuyện: nhiệt độ thấp để khỏi bịa thêm.
    temperature: 0.3,
    maxTokens: MAX_OUTPUT_TOKENS,
    json: true,
    timeoutMs: UPSTREAM_TIMEOUT_MS,
  });
  if (!res.ok) {
    console.error(`DeepSeek ${res.status}: ${(await res.text()).slice(0, 500)}`);
    return '';
  }
  return deepSeekText(res);
}

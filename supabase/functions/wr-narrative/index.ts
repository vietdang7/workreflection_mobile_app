// Edge Function `wr-narrative` — sinh "Diễn biến theo thời gian" cho tab Hành
// trình.
//
// ---------------------------------------------------------------------------
// VÌ SAO HÀM NÀY RA ĐỜI
// ---------------------------------------------------------------------------
//
// Bảng `wr_pattern_narratives` có từ migration 20260722000000 và app đã đọc nó
// từ ngày đó: thẻ navy mở đầu tab Hành trình (`_NarrativeCard`) và màn
// `/wr/journey/narrative` đều lấy nội dung từ đây. Nhưng KHÔNG có một dòng code
// nào trong toàn bộ hệ thống ghi vào bảng — không app, không Edge Function,
// không SQL. Chú thích RLS ghi "SELECT only — AI backend ghi", và cái backend ấy
// chưa từng được viết.
//
// Hệ quả: mọi người dùng, kể cả Premium đã để lại hàng chục mảnh ký ức, đều thấy
// vĩnh viễn đúng một câu "Chưa đủ dữ liệu để kể lại diễn biến. Ghi thêm vài lần
// nữa…". Khách báo lại 2026-08-24 sau 21 mảnh ký ức: "diễn biến theo thời gian
// không được đọc". Câu chữ ấy hứa rằng ghi thêm sẽ có — một lời hứa không có gì
// đứng sau.
//
// ---------------------------------------------------------------------------
// KHÁC GÌ `wr-chat`
// ---------------------------------------------------------------------------
//
// `wr-chat` trả lời một câu hỏi cụ thể, người dùng đang ngồi chờ. Ở đây không ai
// chờ: app gọi lúc mở tab rồi để đó, có thì thẻ tự thay chữ ở lần dựng sau. Nên
// hàm này được phép chậm hơn, nhưng phải TIẾT KIỆM — mỗi lần mở tab mà gọi model
// một lần là đốt tiền cho cùng một câu chuyện chưa hề đổi. Toàn bộ mục "3 · Có
// đáng kể lại không" tồn tại vì lý do đó.
//
// ---------------------------------------------------------------------------
// SECRET CẦN ĐẶT TRƯỚC KHI DEPLOY
//
//   supabase secrets set OPENROUTER_API_KEY=sk-or-v1-...   (dùng chung wr-chat)
//
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY do nền tảng cấp.
// ---------------------------------------------------------------------------

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { buildNarrativePrompt, type NarrativeInput } from './prompt.ts';
import {
  MIN_EPISODES,
  MIN_NEW_EPISODES,
  decideRegeneration,
  type EpisodeRow,
  type NarrativeRow,
} from './regeneration.ts';

// ---------------------------------------------------------------------------
// Cấu hình
// ---------------------------------------------------------------------------

/// Ghim đúng bản có ngày, cùng model với `wr-chat` — xem ghi chú dài ở
/// `wr-chat/index.ts` về việc vì sao không dùng alias `-latest`.
const MODEL = Deno.env.get('WR_NARRATIVE_MODEL') ??
  'deepseek/deepseek-v4-flash-0731';

/// Số Episode nạp làm nguyên liệu.
///
/// Bằng đúng `kRecentSituationsWindow` bên app (v2.0 §4.1: "tối đa 30 mục gần
/// nhất"). Diễn biến kể về cùng cửa sổ mà mọi khối khác đang đọc, nếu không thẻ
/// này sẽ nói về một quãng thời gian không nơi nào khác trong app nhắc tới.
const EPISODE_WINDOW = 30;

/// Trần độ dài. ~180 chữ tiếng Việt là đủ cho ba tới bốn câu; thẻ navy trên
/// Home chỉ cao chừng đó trước khi phải cuộn.
const MAX_OUTPUT_TOKENS = 420;

const UPSTREAM_TIMEOUT_MS = 60_000;

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

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

/// Không sinh được lần này — KHÔNG phải lỗi.
///
/// Trả 200 chứ không phải 4xx/5xx: "chưa đủ dữ liệu" và "chuyện chưa đổi" là hai
/// trạng thái bình thường của tính năng này, và app cần đọc được `needed` để nói
/// đúng còn thiếu bao nhiêu lần. Ném lỗi ở đây thì phía app chỉ còn một câu
/// chung chung — đúng cái bẫy đã làm thẻ im lặng suốt mấy tháng.
function skip(reason: string, extra: Record<string, unknown> = {}) {
  return json({ generated: false, reason, ...extra });
}

function fail(userMessage: string, status: number) {
  return json({ generated: false, reason: 'error', error: userMessage }, status);
}

// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return fail('Yêu cầu không hợp lệ.', 405);
  }

  const openRouterKey = Deno.env.get('OPENROUTER_API_KEY');
  if (!openRouterKey) {
    console.error('THIẾU secret OPENROUTER_API_KEY — hàm không thể chạy.');
    return fail('Chưa kể lại được lúc này.', 503);
  }

  // ── 1 · Xác thực ────────────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return fail('Cần đăng nhập.', 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const authClient = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: authError } = await authClient.auth.getUser();
  const user = userData?.user;
  if (authError || !user) {
    return fail('Phiên đăng nhập đã hết hạn.', 401);
  }

  const db = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // ── 2 · Gói ─────────────────────────────────────────────────────────────
  //
  // Diễn giải qua thời gian là Premium (Hai Lớp v1.2 §III) và thẻ bên app đã
  // khoá đúng như vậy. Chặn lại ở đây nữa vì khoá trên giao diện chỉ ngăn người
  // dùng NHÌN THẤY, không ngăn ai gọi thẳng vào hàm — và mỗi lượt gọi là tiền
  // thật trả cho model.
  if (!(await isPremium(db, user.id))) {
    return skip('premium_only');
  }

  // ── 3 · Có đáng kể lại không ────────────────────────────────────────────
  const [episodesResult, lastResult] = await Promise.all([
    db
      .from('wr_reflection_episodes')
      .select('situation_code, human_need, energy, opened_at, draft_meaning')
      .eq('user_id', user.id)
      .not('situation_code', 'is', null)
      .order('opened_at', { ascending: false })
      .limit(EPISODE_WINDOW),
    db
      .from('wr_pattern_narratives')
      .select('id, narrative, period_start, period_end, created_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(1),
  ]);

  if (episodesResult.error) {
    console.error('Đọc Episode lỗi:', episodesResult.error.message);
    return fail('Chưa kể lại được lúc này.', 503);
  }

  const episodes = (episodesResult.data ?? []) as EpisodeRow[];
  const previous = (lastResult.data?.[0] ?? null) as NarrativeRow | null;

  const decision = decideRegeneration(episodes, previous);
  if (!decision.regenerate) {
    return skip(decision.reason, {
      episodeCount: episodes.length,
      needed: decision.needed,
      // Bản cũ vẫn còn giá trị: app đang hiển thị nó, và biết nó tồn tại thì
      // thẻ chọn đúng giữa "chưa có gì để kể" và "chưa có gì MỚI để kể".
      hasNarrative: previous !== null,
      minEpisodes: MIN_EPISODES,
      minNewEpisodes: MIN_NEW_EPISODES,
    });
  }

  // ── 4 · Nguyên liệu ─────────────────────────────────────────────────────
  const titles = await resolveTitles(
    db,
    episodes.map((e) => e.situation_code).filter((c): c is string => !!c),
  );

  const input: NarrativeInput = {
    episodes,
    titles,
    previousNarrative: previous?.narrative ?? null,
  };

  // ── 5 · Gọi model ───────────────────────────────────────────────────────
  let narrative: string;
  try {
    narrative = await callModel(openRouterKey, buildNarrativePrompt(input));
  } catch (e) {
    const aborted = e instanceof DOMException && e.name === 'AbortError';
    console.error(aborted ? 'OpenRouter quá hạn chờ' : `OpenRouter lỗi: ${e}`);
    // Không ai đang ngồi chờ câu này, nên hỏng thì im lặng bỏ qua: lần mở tab
    // sau sẽ thử lại, và tới lúc đó thẻ vẫn đang hiện bản kể trước đó.
    return skip('upstream_error');
  }

  if (!narrative) {
    return skip('empty_reply');
  }

  // ── 6 · Ghi lại ─────────────────────────────────────────────────────────
  //
  // Ghi dòng MỚI chứ không cập nhật dòng cũ: bảng này là một chuỗi các lần kể,
  // và màn `/wr/journey/narrative` liệt kê chúng theo giai đoạn. Đè lên dòng cũ
  // là xoá mất chính thứ làm nên chữ "theo thời gian".
  const { error: writeError } = await db.from('wr_pattern_narratives').insert({
    user_id: user.id,
    period_start: decision.periodStart,
    period_end: decision.periodEnd,
    narrative,
  });

  if (writeError) {
    console.error('Không ghi được diễn biến:', writeError.message);
    return skip('write_failed');
  }

  return json({
    generated: true,
    narrative,
    periodStart: decision.periodStart,
    periodEnd: decision.periodEnd,
    episodeCount: episodes.length,
    model: MODEL,
  });
});

// ---------------------------------------------------------------------------
// Tiện ích
// ---------------------------------------------------------------------------

/// Hai nguồn quyền, hợp lúc đọc — đúng như `wrEntitlementProvider` bên app và
/// như `wr-chat` làm (khách chốt 2026-08-01: Premium trên web thì Premium luôn
/// trên app). Không đồng bộ hai bảng.
async function isPremium(db: SupabaseClient, userId: string): Promise<boolean> {
  try {
    const { data: profile } = await db
      .from('cc_profiles')
      .select('role')
      .eq('id', userId)
      .maybeSingle();
    const role = String(profile?.role ?? '').trim().toLowerCase();
    if (role === 'premium' || role === 'admin') return true;
  } catch (_) { /* còn nguồn thứ hai */ }

  try {
    const { data: ent } = await db
      .from('wr_entitlements')
      .select('plan, valid_until')
      .eq('user_id', userId)
      .maybeSingle();
    if (ent?.plan === 'premium') {
      // valid_until rỗng = không hạn, đúng quy ước WrEntitlement.isPremium.
      return !ent.valid_until || new Date(ent.valid_until) > new Date();
    }
  } catch (_) {
    /* không đọc được thì coi như miễn phí — an toàn về phía chi phí */
  }
  return false;
}

/// Tra tiêu đề tiếng Việt của các mã tình huống.
async function resolveTitles(
  db: SupabaseClient,
  codes: string[],
): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  const unique = [...new Set(codes)];
  if (unique.length === 0) return out;
  try {
    const { data } = await db
      .from('wr_situations')
      .select('code, text')
      .in('code', unique);
    for (const row of data ?? []) {
      const text = String(row.text ?? '').trim();
      if (text) out.set(row.code as string, text);
    }
  } catch (_) { /* không tra được thì prompt dùng mã, vẫn kể được */ }
  return out;
}

async function callModel(apiKey: string, messages: unknown[]): Promise<string> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    const res = await fetch(OPENROUTER_URL, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://workreflection.app',
        'X-Title': 'WorkReflection Mobile',
      },
      body: JSON.stringify({
        model: MODEL,
        messages,
        // Thấp hơn `wr-chat` (0.7): đây là bài đọc lại dữ liệu, không phải trò
        // chuyện. Nhiệt độ cao ở đây đọc ra thành bịa thêm chi tiết.
        temperature: 0.4,
        max_tokens: MAX_OUTPUT_TOKENS,
        reasoning: { enabled: false },
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      console.error(`OpenRouter ${res.status}: ${detail.slice(0, 500)}`);
      return '';
    }
    const payload = await res.json();
    return String(payload?.choices?.[0]?.message?.content ?? '').trim();
  } finally {
    clearTimeout(timer);
  }
}

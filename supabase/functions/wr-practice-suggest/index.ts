// Edge Function `wr-practice-suggest` — AI gợi ý ba cách + một câu hỏi cho chủ
// đề thực hành người dùng tự thêm (màn "Bạn muốn thêm chủ đề nào?").
//
// ---------------------------------------------------------------------------
// MÔ HÌNH HYBRID
//
// AI chỉ ĐỀ XUẤT. Khung bốn bước (Nhận diện → Phần của tôi → Chọn một cách →
// Câu hỏi cho lần sau) do app dựng bằng luật, và app luôn có sẵn bộ ba cách
// theo luật (`buildUserThemeMentorOptions`). Hàm này hỏng, chậm, hết lượt hay
// bị từ chối quyền AI đều trả `{generated:false, reason}` với mã 200 — app im
// lặng dùng bộ luật, người dùng không bao giờ thấy màn lỗi.
//
// ---------------------------------------------------------------------------
// HẠN NGẠCH (người dùng chốt 20/10/2026)
//
//   • Free: 2 lần có AI, TRỌN ĐỜI — chỉ đếm lần thành công.
//   • Premium: không giới hạn, chỉ có trần chống lạm dụng mỗi ngày.
//
// Đếm ở bảng `wr_practice_suggestions` (migration 20261020090000). Không đếm
// được thì CHẶN — cho qua khi hỏng là mở toang vòi credit.
//
// Tuỳ chọn (secret, đổi không cần deploy):
//   WR_PRACTICE_AI_FREE_LIMIT   số lần trọn đời cho gói Free (mặc định 2)
//   WR_PRACTICE_AI_DAILY_LIMIT  trần mỗi 24 giờ cho mọi gói (mặc định 20)
// ---------------------------------------------------------------------------

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { hasAiConsent } from '../_shared/ai_consent.ts';
import { deepSeekFetch, deepSeekKey, deepSeekModel, deepSeekText }
  from '../_shared/deepseek.ts';
import { pick, readLocale, readLocaleHeader, WrLocale } from '../_shared/locale.ts';
import { describeCounts, loadPiiIdentity, redactPiiDetailed }
  from '../_shared/pii_redact.ts';
import { buildMessages, parseIntake, parseJsonLoose, review } from './suggest.ts';

const FREE_LIMIT = Number(Deno.env.get('WR_PRACTICE_AI_FREE_LIMIT') ?? '2');
const DAILY_LIMIT = Number(Deno.env.get('WR_PRACTICE_AI_DAILY_LIMIT') ?? '20');

/// App chờ tối đa 12 giây rồi dùng bộ luật. Máy chủ cắt sớm hơn một chút để
/// không đốt token cho một câu trả lời không ai còn chờ.
const UPSTREAM_TIMEOUT_MS = 11_000;

/// Ba thẻ ngắn + một câu hỏi, một ngôn ngữ: ~300 token là đủ. Đây chỉ là trần
/// cho ca xấu nhất (model viết lan man) — độ trễ thường ngày do độ dài xin
/// trong lời dặn (`ASK` ở `suggest.ts`) quyết định, không phải số này.
const MAX_OUTPUT_TOKENS = 600;

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

function skip(reason: string) {
  return json({ generated: false, reason });
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

  // Chốt chặn thật của Guideline 5.1.1(i) — app có `ensureAiConsent`, nhưng
  // bản build cũ hay một lời gọi thẳng bằng token thì không qua cổng đó.
  if (!(await hasAiConsent(db, user.id))) return skip('ai_consent_required');

  let body: unknown;
  try {
    body = await req.json();
  } catch (_) {
    return skip('bad_request');
  }
  if ((body as Record<string, unknown> | null)?.locale !== undefined) {
    locale = readLocale(body);
  }
  const intake = parseIntake(body);
  if (!intake) return skip('bad_request');

  // ── Gói ─────────────────────────────────────────────────────────────────
  // Hai nguồn, hợp lúc đọc — giống `wr-chat` và `wrEntitlementProvider`.
  let isPremium = false;
  try {
    const { data: profile } = await db
      .from('cc_profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();
    const role = (profile?.role ?? '').trim().toLowerCase();
    isPremium = role === 'premium' || role === 'admin';
  } catch (_) { /* còn nguồn thứ hai */ }
  if (!isPremium) {
    try {
      const { data: ent } = await db
        .from('wr_entitlements')
        .select('plan, valid_until')
        .eq('user_id', user.id)
        .maybeSingle();
      if (ent?.plan === 'premium') {
        isPremium = !ent.valid_until || new Date(ent.valid_until) > new Date();
      }
    } catch (_) { /* mặc định an toàn về phía chi phí */ }
  }

  // ── Hạn ngạch ───────────────────────────────────────────────────────────
  {
    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { count, error } = await db
      .from('wr_practice_suggestions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('created_at', since);
    if (error) {
      console.error('Không đếm được lượt trong ngày:', error.message);
      return skip('quota_unavailable');
    }
    if ((count ?? 0) >= DAILY_LIMIT) return skip('daily_limit');
  }
  if (!isPremium) {
    const { count, error } = await db
      .from('wr_practice_suggestions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('ok', true);
    if (error) {
      console.error('Không đếm được lượt trọn đời:', error.message);
      return skip('quota_unavailable');
    }
    if ((count ?? 0) >= FREE_LIMIT) return skip('free_limit');
  }

  // ── Khử PII ─────────────────────────────────────────────────────────────
  // Người ta hay kể tình huống kèm tên đồng nghiệp, số điện thoại sếp. Model
  // không cần mấy thứ đó để gợi ý cách làm.
  const identity = await loadPiiIdentity(db, user.id);
  const counts: string[] = [];
  const scrub = (s: string) => {
    const r = redactPiiDetailed(s, { identity });
    counts.push(describeCounts(r.counts));
    return r.text;
  };
  const safe = {
    title: scrub(intake.title),
    situation: scrub(intake.situation),
    goal: scrub(intake.goal),
    tried: intake.tried ? scrub(intake.tried) : null,
  };
  console.log(`PII đã khử: ${counts.join(' | ')}`);

  // ── Gọi model ───────────────────────────────────────────────────────────
  let reply = '';
  let reason = '';
  try {
    const res = await deepSeekFetch(apiKey, buildMessages(safe, locale), {
      // Thấp: cần cách làm thực tế, không cần bay bổng.
      temperature: 0.3,
      maxTokens: MAX_OUTPUT_TOKENS,
      json: true,
      timeoutMs: UPSTREAM_TIMEOUT_MS,
    });
    if (res.ok) {
      reply = await deepSeekText(res);
    } else {
      reason = `upstream_${res.status}`;
      console.error(`DeepSeek ${res.status}: ${(await res.text()).slice(0, 500)}`);
    }
  } catch (e) {
    const aborted = e instanceof DOMException && e.name === 'AbortError';
    reason = aborted ? 'timeout' : 'upstream_error';
    console.error(aborted ? 'DeepSeek quá hạn chờ' : `DeepSeek lỗi: ${e}`);
  }

  const checked = reply ? review(parseJsonLoose(reply)) : { ok: null, reason: reason || 'empty_reply' };
  if (!checked.ok) {
    if (reply) console.warn(`Phép thử loại (${checked.reason}): ${reply.slice(0, 600)}`);
  }

  // Ghi cả lần hỏng: trần ngày đếm mọi lượt gọi model; trần trọn đời Free chỉ
  // đếm `ok = true`, để một lần DeepSeek vấp không ăn mất lượt của người ta.
  const { error: logError } = await db.from('wr_practice_suggestions').insert({
    user_id: user.id,
    ok: checked.ok !== null,
    locale,
    model: deepSeekModel(),
  });
  if (logError) console.error('Không ghi được lượt gợi ý:', logError.message);

  if (!checked.ok) return skip(checked.reason ?? 'rejected');
  return json({ generated: true, locale, ...checked.ok });
});

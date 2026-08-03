// Edge Function `wr-chat` — cầu nối giữa app và OpenRouter cho tính năng
// Trò chuyện (AI Chatbox System Prompt v1.0).
//
// ---------------------------------------------------------------------------
// VÌ SAO CÓ HÀM NÀY THAY VÌ APP GỌI THẲNG OPENROUTER
//
// Khoá OpenRouter gắn với ví tiền thật. Nhúng vào APK thì bất kỳ ai giải nén
// bản cài cũng lấy được và tiêu tiền của khách, và đổi khoá sẽ phải phát hành
// lại app. Ở đây khoá là một secret của Supabase, app không bao giờ thấy nó.
//
// Ba việc chỉ làm được ở phía máy chủ, và là lý do thứ hai để hàm này tồn tại:
//   • Hạn mức gói miễn phí. Đếm ở máy khách thì máy khách tự quyết.
//   • Ranh giới Free/Premium ở mục 7 của prompt. Gói được đọc từ database, nếu
//     để app khai báo thì ai cũng khai mình Premium.
//   • Lịch sử hội thoại nạp lại cho model. Nếu app gửi lên thì nó gửi được cả
//     lượt "assistant" bịa ra, tức tiêm chữ thẳng vào ngữ cảnh và vượt qua danh
//     sách cấm ở mục 6.
//
// ---------------------------------------------------------------------------
// SECRET CẦN ĐẶT TRƯỚC KHI DEPLOY
//
//   supabase secrets set OPENROUTER_API_KEY=sk-or-v1-...
//
// SUPABASE_URL và SUPABASE_SERVICE_ROLE_KEY do nền tảng tự cấp, không cần đặt.
// ---------------------------------------------------------------------------

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { buildSystemPrompt } from './system_prompt.ts';
import { buildUserContext } from './user_context.ts';
import { conversationTitle, shapeReply } from './reply_shaping.ts';

// ---------------------------------------------------------------------------
// Cấu hình
// ---------------------------------------------------------------------------

/// Model chạy tính năng này.
///
/// Ghim đúng bản có ngày, CỐ Ý không dùng alias `~deepseek/deepseek-v4-flash-latest`.
/// Alias sẽ tự trỏ sang model khác khi DeepSeek phát hành bản mới, và system
/// prompt v1.0 đã được thử nghiệm theo hành vi của đúng bản này. Đổi model là
/// một quyết định có kiểm chứng, không phải một việc xảy ra lúc nửa đêm.
///
/// So sánh 2026-08-03 giữa `deepseek-v4-flash` (24/04) và bản 0731: cùng cửa sổ
/// 1M token, cùng bộ tham số, nhưng 0731 mới hơn, đã re-post-train, và rẻ hơn
/// 36% ($0.09/$0.18 so với $0.14/$0.28 mỗi triệu token).
const MODEL = Deno.env.get('WR_CHAT_MODEL') ?? 'deepseek/deepseek-v4-flash-0731';

/// Số lượt hỏi mỗi ngày của gói miễn phí (giờ VN, xem `wr_chat_used_today`).
const FREE_DAILY_LIMIT = Number(Deno.env.get('WR_CHAT_FREE_LIMIT') ?? '10');

/// Trần cho gói Premium.
///
/// Khách chốt "Premium không giới hạn", và con số này KHÔNG mâu thuẫn với điều
/// đó: đây là chốt chặn chống lạm dụng, không phải hạn mức bán hàng. Nó ở đây để
/// một tài khoản bị chiếm không đốt sạch credit trong một đêm. Bỏ trần đi thì sự
/// cố đầu tiên sẽ là hoá đơn.
///
/// Nâng từ 100 lên 300 theo yêu cầu khách 2026-08-03. Chi phí xấu nhất của một
/// tài khoản chạm trần: 300 lượt × (~6k token vào + ~300 ra) ≈ 0,18 USD một
/// ngày. Nhân với số tài khoản Premium là ra trần thiệt hại nếu bị lạm dụng
/// đồng loạt — con số đó vẫn nhỏ, nên nâng trần là an toàn.
const PREMIUM_DAILY_LIMIT = Number(Deno.env.get('WR_CHAT_PREMIUM_LIMIT') ?? '300');

/// Những email được phép tự bật/tắt gói để xem thử, giống công tắc trong app.
///
/// VÌ SAO CÓ: bản đầu hàm này cố ý bỏ qua công tắc Premium thử nghiệm, lý do là
/// công tắc nằm ở SharedPreferences trên máy nên không được phép mở hạn mức tiêu
/// tiền thật. Đúng về bảo mật, nhưng sai về hậu quả: cả app đổi theo công tắc
/// còn riêng chatbox thì không, nên chủ sản phẩm bật Premium lên xem thử mà thấy
/// trợ lý vẫn trả lời y như gói miễn phí, và tưởng ranh giới hai gói bị hỏng.
///
/// Cách chữa giữ được cả hai: app CỨ GỬI công tắc lên, nhưng máy chủ chỉ nghe
/// khi email của người gọi nằm trong danh sách này. Email lấy từ token đã xác
/// thực, không lấy từ thân yêu cầu, nên người dùng thường có gửi cờ cũng vô ích.
///
/// GIỮ ĐỒNG BỘ với `kPremiumTogglePermittedEmails` trong
/// `lib/core/logic/wr_premium_override.dart`. Đặt secret WR_PREMIUM_TOGGLE_EMAILS
/// để đổi mà không phải deploy lại.
const PREMIUM_TOGGLE_EMAILS = new Set(
  (Deno.env.get('WR_PREMIUM_TOGGLE_EMAILS') ??
    'thedangs7@gmail.com,ngduythong1412@gmail.com')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean),
);

/// Số lượt gần nhất nạp lại làm ngữ cảnh.
///
/// 20 lượt là đủ để giữ mạch một cuộc trò chuyện mà không kéo cả nhật ký nhiều
/// tháng vào mỗi lần gọi. Cửa sổ của model là 1M token nên giới hạn này là để
/// giữ chi phí và độ trễ, không phải vì model không chứa nổi.
const HISTORY_LIMIT = 20;

/// Chặn ở đây thay vì để model tự cắt: một câu hỏi dài hơn thế gần như luôn là
/// dán nhầm cả tài liệu vào ô chat.
const MAX_MESSAGE_CHARS = 2000;

/// Trần độ dài câu trả lời.
///
/// Hạ từ 700 xuống 300 ngày 2026-08-03. Đo trên 11 câu trả lời thật: 7 câu dài
/// hơn ba câu, tức vi phạm mục 9 ở phần lớn lượt. Trần 700 quá rộng nên nó
/// không hề cản, và model tự do viết thành bài.
///
/// 300 token đủ cho ba câu tiếng Việt thoải mái, kể cả nhánh mục 8 vốn cần đủ
/// ba phần. Đây là hàng rào cứng đi kèm luật trong prompt, không thay thế nó:
/// cắt bằng token có thể cụt câu, nên prompt vẫn phải là thứ dạy model dừng
/// đúng chỗ.
const MAX_OUTPUT_TOKENS = 300;

/// Bỏ cuộc sau ngần này. Người dùng đang nhìn con trỏ nhấp nháy trên điện thoại,
/// chờ lâu hơn nữa thì thà báo lỗi để họ gửi lại.
const UPSTREAM_TIMEOUT_MS = 45_000;

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ---------------------------------------------------------------------------
// Tiện ích
// ---------------------------------------------------------------------------

type ChatRow = { role: 'user' | 'assistant'; content: string };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

/// Câu báo lỗi hiển thị thẳng cho người dùng.
///
/// Tiếng Việt, không có mã lỗi, không có tên nhà cung cấp: mục 6 cấm lộ chi
/// tiết hệ thống, và "OpenRouter 502" thì người dùng cũng không làm gì được.
function fail(userMessage: string, status: number, extra: Record<string, unknown> = {}) {
  return json({ error: userMessage, ...extra }, status);
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
    // Cấu hình thiếu là lỗi của người vận hành, không phải của người dùng. Ghi
    // ra log để người vận hành thấy, còn người dùng chỉ cần biết là chưa dùng
    // được.
    console.error('THIẾU secret OPENROUTER_API_KEY — hàm không thể chạy.');
    return fail('Tính năng trò chuyện đang tạm nghỉ. Bạn thử lại sau nhé.', 503);
  }

  // ── 1 · Xác thực ────────────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return fail('Cần đăng nhập để trò chuyện.', 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;

  // Client mang đúng token của người gọi, chỉ dùng để hỏi "anh là ai". Không
  // dùng service role ở bước này: service role sẽ trả lời được cho bất kỳ token
  // nào, kể cả token đã hỏng.
  const authClient = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: authError } = await authClient.auth.getUser();
  const user = userData?.user;
  if (authError || !user) {
    return fail('Phiên đăng nhập đã hết hạn. Bạn đăng nhập lại nhé.', 401);
  }

  // Từ đây trở đi dùng service role: đọc gói, đếm hạn mức, và ghi lượt trò
  // chuyện đều là những việc bảng `wr_chat_messages` cố ý không cho client làm.
  const db = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // ── 2 · Đọc câu hỏi ─────────────────────────────────────────────────────
  let message: string;
  let requestedConversationId: string | null;
  /// Công tắc gói do app gửi lên. null = không động vào, dùng gói thật.
  let premiumOverride: boolean | null = null;
  try {
    const body = await req.json();
    message = String(body?.message ?? '').trim();
    premiumOverride = typeof body?.premiumOverride === 'boolean'
      ? body.premiumOverride
      : null;
    // Rỗng nghĩa là "mở cuộc mới". App gửi null khi người dùng bấm nút cuộc trò
    // chuyện mới, hoặc khi vào màn lần đầu và chưa có cuộc nào.
    const raw = body?.conversationId;
    requestedConversationId = typeof raw === 'string' && raw.length > 0
      ? raw
      : null;
  } catch (_) {
    return fail('Yêu cầu không hợp lệ.', 400);
  }

  if (message.length === 0) {
    return fail('Bạn viết vài chữ rồi gửi nhé.', 400);
  }
  if (message.length > MAX_MESSAGE_CHARS) {
    return fail(
      `Câu này dài quá, bạn rút ngắn dưới ${MAX_MESSAGE_CHARS} ký tự giúp mình nhé.`,
      400,
    );
  }

  // ── 3 · Gói của người dùng ──────────────────────────────────────────────
  //
  // HAI NGUỒN, HỢP LÚC ĐỌC, đúng như `wrEntitlementProvider` bên app (khách
  // chốt 2026-08-01: Premium trên web thì Premium luôn trên app). Không đồng bộ
  // hai bảng — cách đó đã làm hỏng một lần, xem migration 20260731160000 và bản
  // lùi 20260731170000.
  //
  // Cố ý KHÔNG đọc công tắc Premium thử nghiệm: công tắc đó nằm ở
  // SharedPreferences trên máy, chỉ dùng để xem giao diện, và nó không được
  // phép mở hạn mức tiêu tiền thật.
  let isPremium = false;
  try {
    const { data: profile } = await db
      .from('cc_profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();
    const role = (profile?.role ?? '').trim().toLowerCase();
    isPremium = role === 'premium' || role === 'admin';
  } catch (_) {
    /* đọc hỏng thì còn nguồn thứ hai bên dưới */
  }

  if (!isPremium) {
    try {
      const { data: ent } = await db
        .from('wr_entitlements')
        .select('plan, valid_until')
        .eq('user_id', user.id)
        .maybeSingle();
      if (ent?.plan === 'premium') {
        // valid_until rỗng = không hạn, đúng quy ước của WrEntitlement.isPremium.
        isPremium = !ent.valid_until || new Date(ent.valid_until) > new Date();
      }
    } catch (_) {
      /* không đọc được thì coi như miễn phí — mặc định an toàn về phía chi phí */
    }
  }

  // Công tắc thử nghiệm, áp SAU hai nguồn thật và chỉ cho email được phép.
  //
  // Email đọc từ token đã xác thực ở bước 1, KHÔNG đọc từ thân yêu cầu: người
  // dùng thường gửi kèm cờ này thì cờ bị bỏ qua, đúng như trước khi có nó.
  //
  // Hạn mức vẫn tính theo gói THẬT. Công tắc để xem trợ lý trả lời khác ra sao,
  // không phải để mở thêm lượt tiêu tiền — đúng lo ngại ban đầu, chỉ là khoanh
  // lại đúng phần cần khoanh.
  const callerEmail = (user.email ?? '').trim().toLowerCase();
  const mayToggle = PREMIUM_TOGGLE_EMAILS.has(callerEmail);
  const limit = isPremium ? PREMIUM_DAILY_LIMIT : FREE_DAILY_LIMIT;
  if (premiumOverride !== null && mayToggle) {
    isPremium = premiumOverride;
  }

  // ── 4 · Hạn mức trong ngày ──────────────────────────────────────────────
  let usedToday = 0;
  {
    const { data, error } = await db.rpc('wr_chat_used_today', {
      p_user_id: user.id,
    });
    if (error) {
      // Không đếm được thì CHẶN, không cho qua. Cho qua khi hỏng là biến một sự
      // cố database thành một cái vòi credit mở toang.
      console.error('wr_chat_used_today lỗi:', error.message);
      return fail('Chưa gửi được lúc này. Bạn thử lại sau một chút nhé.', 503);
    }
    usedToday = Number(data ?? 0);
  }

  if (usedToday >= limit) {
    return fail(
      isPremium
        ? 'Bạn đã trò chuyện khá nhiều hôm nay. Mai mình tiếp tục nhé.'
        : 'Hôm nay bạn đã dùng hết lượt trò chuyện của gói miễn phí. '
          + 'Mai lượt sẽ được làm mới, hoặc bạn xem thử gói Premium để trò chuyện thoải mái hơn.',
      429,
      { usedToday, limit, isPremium, quotaExhausted: true },
    );
  }

  // ── 5 · Cuộc trò chuyện ─────────────────────────────────────────────────
  //
  // XÁC MINH QUYỀN SỞ HỮU, không tin id app gửi lên. Thiếu bước `.eq('user_id')`
  // là ai cũng đọc được cuộc trò chuyện của người khác chỉ bằng cách đoán một
  // uuid — service role bỏ qua RLS nên ở đây không có lưới an toàn nào khác.
  let conversationId: string | null = null;
  if (requestedConversationId) {
    const { data } = await db
      .from('wr_chat_conversations')
      .select('id')
      .eq('id', requestedConversationId)
      .eq('user_id', user.id)
      .maybeSingle();
    conversationId = (data?.id as string | undefined) ?? null;
    if (!conversationId) {
      return fail('Không mở được cuộc trò chuyện này.', 404);
    }
  }

  // ── 6 · Lịch sử hội thoại và ngữ cảnh cá nhân ───────────────────────────
  //
  // Đọc từ database chứ không nhận từ app: xem phần đầu file.
  //
  // Lịch sử bó trong ĐÚNG cuộc trò chuyện này. Cuộc mới thì không có lịch sử —
  // đó chính là điều nút "cuộc trò chuyện mới" hứa với người dùng.
  //
  // Hai truy vấn độc lập nên chạy song song: nối tiếp thì người dùng chờ tổng
  // hai vòng, cho hai thứ không cần chờ nhau.
  const [historyResult, userContext] = await Promise.all([
    conversationId
      ? db
        .from('wr_chat_messages')
        .select('role, content')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: false })
        .limit(HISTORY_LIMIT)
      : Promise.resolve({ data: [] as ChatRow[] }),
    // Gói quyết định cả NỘI DUNG khối ngữ cảnh, không chỉ lời dặn kèm theo.
    buildUserContext(db, user.id, isPremium),
  ]);
  const historyRows = historyResult.data;

  // Truy vấn lấy mới-nhất-trước để `limit` cắt đúng đầu gần đây; model cần đọc
  // theo thứ tự thời gian nên đảo lại ở đây.
  const history: ChatRow[] = ((historyRows ?? []) as ChatRow[]).slice().reverse();

  // ── 6 · Gọi model ───────────────────────────────────────────────────────
  const messages = [
    { role: 'system', content: buildSystemPrompt(isPremium, userContext) },
    ...history.map((m) => ({ role: m.role, content: m.content })),
    { role: 'user', content: message },
  ];

  let reply: string;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

    const res = await fetch(OPENROUTER_URL, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${openRouterKey}`,
        'Content-Type': 'application/json',
        // OpenRouter dùng hai header này để gắn nhãn nguồn gọi trên trang thống
        // kê. Không bắt buộc, nhưng có thì đọc hoá đơn mới biết tiền đi đâu.
        'HTTP-Referer': 'https://workreflection.app',
        'X-Title': 'WorkReflection Mobile',
      },
      body: JSON.stringify({
        model: MODEL,
        messages,
        temperature: 0.7,
        max_tokens: MAX_OUTPUT_TOKENS,
        // Tắt reasoning: đây là trò chuyện ngắn có giọng văn quy định sẵn,
        // không phải bài toán suy luận. Bật lên chỉ thêm độ trễ và token trả
        // tiền cho phần người dùng không bao giờ đọc.
        reasoning: { enabled: false },
      }),
    }).finally(() => clearTimeout(timer));

    if (!res.ok) {
      const detail = await res.text();
      console.error(`OpenRouter ${res.status}: ${detail.slice(0, 500)}`);
      return fail('Mình chưa trả lời được lúc này. Bạn thử gửi lại nhé.', 502);
    }

    const payload = await res.json();
    reply = (payload?.choices?.[0]?.message?.content ?? '').trim();
    if (!reply) {
      console.error('OpenRouter trả về nội dung rỗng:', JSON.stringify(payload).slice(0, 500));
      return fail('Mình chưa trả lời được lúc này. Bạn thử gửi lại nhé.', 502);
    }
  } catch (e) {
    const aborted = e instanceof DOMException && e.name === 'AbortError';
    console.error(aborted ? 'OpenRouter quá hạn chờ' : `OpenRouter lỗi: ${e}`);
    return fail(
      aborted
        ? 'Mình nghĩ hơi lâu và chưa kịp trả lời. Bạn gửi lại giúp mình nhé.'
        : 'Mình chưa trả lời được lúc này. Bạn thử gửi lại nhé.',
      502,
    );
  }

  // ── 8 · Nắn câu trả lời ─────────────────────────────────────────────────
  //
  // Gỡ thẻ hành động, lột Markdown, ép nút dịu lại ở nhánh mục 8. Chạy TRƯỚC
  // khi ghi vào database: lưu nguyên thẻ `[[ACTION:...]]` thì lần sau nạp lại
  // làm ngữ cảnh, model sẽ học theo và rải thẻ dày hơn.
  const shaped = shapeReply(reply);
  if (!shaped.text) {
    console.error('Câu trả lời rỗng sau khi nắn:', reply.slice(0, 300));
    return fail('Mình chưa trả lời được lúc này. Bạn thử gửi lại nhé.', 502);
  }

  // ── 9 · Ghi lại cả hai lượt ─────────────────────────────────────────────
  //
  // Ghi SAU khi đã có câu trả lời, không phải trước. Ghi trước thì một lần gọi
  // hỏng sẽ vừa trừ lượt của người ta vừa để lại một câu hỏi treo không có câu
  // đáp, và câu treo đó còn được nạp lại làm ngữ cảnh ở lần sau.
  //
  // Cuộc trò chuyện cũng được tạo ở ĐÂY chứ không phải lúc người dùng bấm nút
  // "cuộc trò chuyện mới": bấm nút rồi đổi ý không gõ gì sẽ đẻ ra một cuộc rỗng
  // nằm lại trong lịch sử mãi mãi. Cuộc nào có mặt trong danh sách cũng là cuộc
  // đã thật sự nói được một câu.
  let writeError: string | null = null;
  if (conversationId === null) {
    const { data, error } = await db
      .from('wr_chat_conversations')
      .insert({ user_id: user.id, title: conversationTitle(message) })
      .select('id')
      .single();
    if (error) writeError = error.message;
    else conversationId = data.id as string;
  }

  if (conversationId !== null) {
    // ĐẶT created_at TƯỜNG MINH, lệch nhau một phần nghìn giây.
    //
    // `default now()` trong Postgres tính MỘT LẦN cho cả câu lệnh, nên hai dòng
    // ghi cùng một lần insert nhận đúng một mốc thời gian. Sắp xếp theo cột đó
    // thành ra không xác định: test đầu-cuối 2026-08-03 đọc lại thấy lượt trợ lý
    // đứng TRƯỚC câu hỏi của người dùng.
    //
    // Hỏng hai chỗ cùng lúc: người dùng mở lại cuộc cũ thấy câu trả lời nằm trên
    // câu mình hỏi, và Edge Function nạp lịch sử theo đúng thứ tự lộn ấy để làm
    // ngữ cảnh, tức là model đọc cuộc trò chuyện ngược.
    const askedAt = new Date();
    const answeredAt = new Date(askedAt.getTime() + 1);

    // Một lần insert hai dòng để không có khoảnh khắc nào lịch sử chỉ có câu hỏi.
    const { error } = await db.from('wr_chat_messages').insert([
      {
        user_id: user.id,
        conversation_id: conversationId,
        created_at: askedAt.toISOString(),
        role: 'user',
        content: message,
      },
      {
        user_id: user.id,
        conversation_id: conversationId,
        created_at: answeredAt.toISOString(),
        role: 'assistant',
        content: shaped.text,
        model: MODEL,
      },
    ]);
    if (error) writeError = error.message;

    // Đẩy cuộc này lên đầu danh sách. Best-effort: hỏng thì lượt vẫn lưu được,
    // chỉ là thứ tự trong màn lịch sử hơi cũ cho tới lượt sau.
    await db
      .from('wr_chat_conversations')
      .update({ last_message_at: new Date().toISOString() })
      .eq('id', conversationId);
  }

  if (writeError) {
    // Câu trả lời đã có rồi thì vẫn đưa cho người dùng đọc. Nuốt nó đi để giữ
    // database sạch là bắt người ta trả giá cho một lỗi họ không gây ra. Ghi log
    // để người vận hành biết lượt này không vào lịch sử.
    console.error('Không ghi được lượt trò chuyện:', writeError);
  }

  return json({
    reply: shaped.text,
    action: shaped.action,
    conversationId,
    model: MODEL,
    isPremium,
    usedToday: usedToday + 1,
    limit,
    // Lượt này không lưu được thì app biết mà không hiển thị nhầm là đã lưu.
    persisted: !writeError,
  });
});

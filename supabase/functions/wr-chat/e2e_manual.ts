// Test ĐẦU-CUỐI tầng HTTP, hạn mức và RLS của `wr-chat`, đánh vào bản đã deploy.
//
// ---------------------------------------------------------------------------
// VÌ SAO CẦN RIÊNG FILE NÀY
//
// `deno test` trong thư mục này chỉ kiểm phần logic thuần: nắn câu trả lời, dựng
// ngữ cảnh, ranh giới gói. Còn xác thực, hạn mức theo ngày, quyền sở hữu cuộc
// trò chuyện và RLS thì chỉ lộ ra khi có một token thật đi qua một máy chủ thật.
//
// Đúng khoảng mù đó đã giấu một lỗi suốt nhiều vòng đo: hai lượt ghi cùng một
// lệnh insert nhận cùng `created_at`, khiến lịch sử đọc ra lộn thứ tự. Mọi bài đo
// trước gọi thẳng OpenRouter nên không bao giờ chạm tới.
//
// ---------------------------------------------------------------------------
// CÁCH CHẠY
//
//   supabase projects api-keys --project-ref sukpcxevcjnhiuyaoqxi
//
//   SB_ANON=<anon> SB_SERVICE=<service_role> \
//     deno run --allow-net --allow-env \
//     supabase/functions/wr-chat/e2e_manual.ts
//
// ⚠ ĐÁNH VÀO DỰ ÁN THẬT, dùng chung với web. File tạo hai tài khoản thử rồi XOÁ
//   ở cuối (xoá tài khoản kéo theo lượt trò chuyện của họ). Tốn hai lượt gọi
//   model thật. KHÔNG đặt tên kết thúc bằng `_test.ts`: `deno test` sẽ nhặt phải rồi
//   đỏ vì thiếu khoá.
//
// KHÔNG ghi khoá vào file này, truyền qua biến môi trường.
// ---------------------------------------------------------------------------

const REF = Deno.env.get('SB_PROJECT_REF') ?? 'sukpcxevcjnhiuyaoqxi';
const BASE = `https://${REF}.supabase.co`;
const FN = `${BASE}/functions/v1/wr-chat`;
const ANON = Deno.env.get('SB_ANON');
const SR = Deno.env.get('SB_SERVICE');

if (!ANON || !SR) {
  console.error('Thiếu SB_ANON hoặc SB_SERVICE. Xem hướng dẫn ở đầu file.');
  Deno.exit(2);
}

let pass = 0, fail = 0;
function check(name: string, ok: boolean, detail = '') {
  if (ok) { pass++; console.log(`✅ ${name}`); }
  else { fail++; console.log(`❌ ${name}${detail ? `\n     │ ${detail}` : ''}`); }
}

const admin = (path: string, init: RequestInit = {}) =>
  fetch(`${BASE}${path}`, {
    ...init,
    headers: {
      apikey: SR,
      Authorization: `Bearer ${SR}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });

async function makeUser(tag: string) {
  const email = `wr-chat-e2e-${tag}-${Date.now()}@example.com`;
  const password = `Test-${crypto.randomUUID()}`;
  const r = await admin('/auth/v1/admin/users', {
    method: 'POST',
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!r.ok) throw new Error(`không tạo được tài khoản thử: ${await r.text()}`);
  const id = (await r.json()).id as string;
  const si = await fetch(`${BASE}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: ANON!, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const jwt = (await si.json()).access_token as string;
  return { id, email, jwt };
}

const alice = await makeUser('a');
console.log(`Tài khoản thử: ${alice.email}\n`);

try {
  check('đăng nhập lấy được token', typeof alice.jwt === 'string' && alice.jwt.length > 20);

  const call = (body: unknown, jwt = alice.jwt) =>
    fetch(FN, {
      method: 'POST',
      headers: { apikey: ANON!, Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    });

  // ── Kiểm tra đầu vào ───────────────────────────────────────────────────
  {
    const r = await call({ message: '   ' });
    const j = await r.json().catch(() => ({}));
    check('câu rỗng → 400 kèm câu tiếng Việt', r.status === 400 && /viết vài chữ/i.test(j.error ?? ''), `${r.status}`);
  }
  {
    const r = await call({ message: 'a'.repeat(2001) });
    const j = await r.json().catch(() => ({}));
    check('câu quá 2000 ký tự → 400', r.status === 400 && /dài quá/i.test(j.error ?? ''), `${r.status}`);
  }
  {
    const r = await call('{ khong-phai-json');
    check('thân yêu cầu hỏng → 400', r.status === 400, `${r.status}`);
  }
  {
    const r = await call({ message: 'chào', conversationId: crypto.randomUUID() });
    check('cuộc trò chuyện không thuộc về mình → 404', r.status === 404, `${r.status}`);
  }

  // ── RLS: client KHÔNG được tự ghi ──────────────────────────────────────
  //
  // Đây là hàng rào giữ cho model không bị tiêm chữ giả vào ngữ cảnh. Ghi được
  // lượt `assistant` nghĩa là bịa được lời trợ lý rồi nạp lại cho chính nó đọc.
  for (
    const [table, row] of [
      ['wr_chat_messages', { user_id: alice.id, role: 'assistant', content: 'lượt bịa' }],
      ['wr_chat_conversations', { user_id: alice.id, title: 'tự tạo' }],
    ] as const
  ) {
    const r = await fetch(`${BASE}/rest/v1/${table}`, {
      method: 'POST',
      headers: { apikey: ANON!, Authorization: `Bearer ${alice.jwt}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(row),
    });
    check(`client tự ghi vào ${table} → BỊ CHẶN`, r.status >= 400, `được ghi với mã ${r.status}`);
  }

  // ── Một lượt thật ──────────────────────────────────────────────────────
  let convId = '';
  {
    const r = await call({ message: 'Sáng nay mình im lặng trong cuộc họp dù có ý kiến khác.' });
    const j = await r.json().catch(() => ({}));
    check('lượt hợp lệ → 200 và có câu trả lời', r.status === 200 && typeof j.reply === 'string' && j.reply.length > 0, `${r.status} ${JSON.stringify(j).slice(0, 200)}`);
    check('tài khoản mới mặc định là gói MIỄN PHÍ', j.isPremium === false, `isPremium=${j.isPremium}`);
    check('hạn mức đúng của gói miễn phí', j.limit === 10, `limit=${j.limit}`);
    check('đếm đúng một lượt đã dùng', j.usedToday === 1, `usedToday=${j.usedToday}`);
    check('báo đã lưu được', j.persisted === true, `persisted=${j.persisted}`);
    check('trả về id cuộc trò chuyện mới', typeof j.conversationId === 'string');
    check('câu trả lời KHÔNG lọt thẻ hành động', !/\[\[ACTION/.test(j.reply ?? ''), j.reply);
    convId = j.conversationId ?? '';
  }

  // ── Ghi xuống database ─────────────────────────────────────────────────
  {
    const rows = await admin(
      `/rest/v1/wr_chat_messages?user_id=eq.${alice.id}&select=role,conversation_id&order=created_at`,
    ).then((r) => r.json());
    // Thứ tự này từng sai: `default now()` tính một lần cho cả câu lệnh nên hai
    // dòng trùng mốc thời gian, và lượt trợ lý đọc ra TRƯỚC câu hỏi.
    check('lưu đúng hai lượt, người trước trợ lý sau',
      Array.isArray(rows) && rows.length === 2 && rows[0].role === 'user' && rows[1].role === 'assistant',
      JSON.stringify(rows).slice(0, 200));
    check('cả hai lượt gắn đúng cuộc trò chuyện',
      Array.isArray(rows) && rows.every((x: { conversation_id: string }) => x.conversation_id === convId));
  }
  {
    const rows = await admin(
      `/rest/v1/wr_chat_conversations?user_id=eq.${alice.id}&select=title`,
    ).then((r) => r.json());
    check('tiêu đề cuộc lấy từ câu đầu người dùng gõ',
      Array.isArray(rows) && rows.length === 1 && /im lặng/i.test(rows[0].title ?? ''),
      JSON.stringify(rows).slice(0, 200));
  }

  // ── Công tắc Premium bị bỏ qua với email thường ────────────────────────
  {
    const r = await call({ message: 'Phân tích mẫu hình của mình đi.', conversationId: convId, premiumOverride: true });
    const j = await r.json().catch(() => ({}));
    check('email KHÔNG được phép khai Premium → vẫn miễn phí',
      r.status === 200 && j.isPremium === false, `isPremium=${j.isPremium} status=${r.status}`);
  }

  // ── Hết hạn mức ────────────────────────────────────────────────────────
  {
    // Bơm cho đủ trần bằng service role thay vì gọi model 10 lần: chỗ cần kiểm
    // là nhánh CHẶN, không phải khả năng sinh chữ.
    await admin('/rest/v1/wr_chat_messages', {
      method: 'POST',
      body: JSON.stringify(Array.from({ length: 10 }, () => ({
        user_id: alice.id, conversation_id: convId, role: 'user', content: 'lượt lấp chỗ',
      }))),
    });
    const r = await call({ message: 'còn trả lời được nữa không', conversationId: convId });
    const j = await r.json().catch(() => ({}));
    check('vượt hạn mức → 429', r.status === 429, `${r.status}`);
    check('429 kèm cờ quotaExhausted để app mời nâng gói', j.quotaExhausted === true);
    check('429 nói đúng là hết lượt gói miễn phí', /gói miễn phí/i.test(j.error ?? ''), j.error);
  }

  // ── Người khác không chạm được vào cuộc này ────────────────────────────
  const bob = await makeUser('b');
  try {
    const rows = await fetch(
      `${BASE}/rest/v1/wr_chat_messages?conversation_id=eq.${convId}&select=content`,
      { headers: { apikey: ANON!, Authorization: `Bearer ${bob.jwt}` } },
    ).then((r) => r.json());
    check('người khác đọc cuộc này → RLS trả về rỗng',
      Array.isArray(rows) && rows.length === 0, JSON.stringify(rows).slice(0, 200));

    const hijack = await call({ message: 'chen vào cuộc của người khác', conversationId: convId }, bob.jwt);
    check('người khác gửi vào cuộc này → 404', hijack.status === 404, `${hijack.status}`);
  } finally {
    await admin(`/auth/v1/admin/users/${bob.id}`, { method: 'DELETE' });
  }
} finally {
  await admin(`/auth/v1/admin/users/${alice.id}`, { method: 'DELETE' });
  console.log(`\nĐã xoá tài khoản thử ${alice.email}`);
}

console.log(`\n${'#'.repeat(60)}\nĐẠT ${pass}/${pass + fail}`);
if (fail > 0) Deno.exit(1);

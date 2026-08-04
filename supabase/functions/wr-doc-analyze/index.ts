// Edge Function `wr-doc-analyze` — đọc tài liệu bối cảnh (JD · CV) bằng AI.
//
// ---------------------------------------------------------------------------
// VÌ SAO CÓ HÀM NÀY
//
// Người dùng tải JD hoặc CV lên, và cho tới trước hàm này thì file chỉ nằm im
// trong Storage: trợ lý trò chuyện phải tự khai "tôi không đọc được", phần đối
// chiếu kỹ năng phải quay sang `role_text` người dùng tự gõ, và màn Tài liệu
// bối cảnh không nói được gì hơn ngoài ngày tải lên. Hàm này là bước còn thiếu.
//
// Đặt ở máy chủ vì ba lý do, cùng lý do của `wr-chat`:
//   • Khoá OpenRouter gắn với ví tiền thật, không được nằm trong APK.
//   • Ranh giới Free/Premium đọc từ database; để app khai thì ai cũng khai
//     mình Premium.
//   • File nằm trong bucket riêng tư `context-docs`; tải nó về cần service role.
//
// ---------------------------------------------------------------------------
// SECRET
//
//   supabase secrets set OPENROUTER_API_KEY=sk-or-v1-...
//
// Tuỳ chọn:
//   WR_DOC_MODEL            model đọc tài liệu (mặc định google/gemini-2.5-flash)
//   WR_DOC_ANALYSIS_FREE    'true' = mở phân tích cho cả gói miễn phí
//   WR_DOC_DAILY_LIMIT      số lần phân tích mỗi ngày mỗi người (mặc định 10)
// ---------------------------------------------------------------------------

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { buildExtractionPrompt, normalizeAnalysis } from './analysis.ts';

/// Model đọc tài liệu.
///
/// KHÁC model của `wr-chat`: DeepSeek chỉ nhận chữ, mà thứ người dùng tải lên
/// là ảnh chụp hoặc PDF. Đây phải là model đọc được hình. Ghim bản cụ thể qua
/// secret khi cần; mặc định chọn bản rẻ, nhanh, đọc tốt tiếng Việt.
const MODEL = Deno.env.get('WR_DOC_MODEL') ?? 'google/gemini-2.5-flash';

/// Mở phân tích cho gói miễn phí.
///
/// Mặc định TẮT: mỗi lần phân tích là một lần gọi model đọc cả trang tài liệu,
/// đắt hơn nhiều so với một lượt chat. Để được bằng secret vì đây là quyết định
/// kinh doanh, không phải quyết định kỹ thuật — đổi nó không nên cần deploy.
const ANALYSIS_FREE =
  (Deno.env.get('WR_DOC_ANALYSIS_FREE') ?? '').trim().toLowerCase() === 'true';

/// Trần mỗi người mỗi ngày. Chống lạm bấm "Phân tích lại", không phải hạn mức
/// bán hàng.
const DAILY_LIMIT = Number(Deno.env.get('WR_DOC_DAILY_LIMIT') ?? '10');

/// Tài liệu lớn hơn ngần này thì từ chối trước khi tốn tiền gọi model.
const MAX_FILE_BYTES = 12 * 1024 * 1024;

/// Đọc một trang tài liệu lâu hơn trả lời một câu chat.
const UPSTREAM_TIMEOUT_MS = 90_000;

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const BUCKET = 'context-docs';

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

/// Câu báo lỗi hiện thẳng cho người dùng: tiếng Việt, không mã lỗi, không tên
/// nhà cung cấp.
function fail(userMessage: string, status: number, extra: Record<string, unknown> = {}) {
  return json({ error: userMessage, ...extra }, status);
}

/// Kiểu file suy từ đuôi đường dẫn.
///
/// Không tin `content-type` Storage trả về: bản upload cũ ghi cứng `image/$ext`
/// cho mọi file, nên một file PDF cũ đang mang nhãn `image/pdf`.
function mimeOf(path: string): string | null {
  const ext = path.split('.').pop()?.toLowerCase() ?? '';
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'pdf':
      return 'application/pdf';
    default:
      return null;
  }
}

/// Bytes → base64, cắt khúc.
///
/// `String.fromCharCode(...bytes)` trên một file vài MB làm tràn stack — lỗi
/// này chỉ xuất hiện với file lớn, tức là sẽ không thấy khi thử với ảnh nhỏ.
function toBase64(bytes: Uint8Array): string {
  const CHUNK = 0x8000;
  let binary = '';
  for (let i = 0; i < bytes.length; i += CHUNK) {
    binary += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(binary);
}

/// Bóc JSON ra khỏi câu trả lời của model.
///
/// Đã yêu cầu JSON thuần, nhưng model vẫn có lúc bọc trong ```json. Thử lần
/// lượt thay vì tin một dạng duy nhất rồi hỏng cả lần phân tích vì ba dấu ngoặc.
function parseJsonLoose(raw: string): Record<string, unknown> | null {
  const attempts: string[] = [raw.trim()];
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced) attempts.push(fenced[1].trim());
  const braced = raw.slice(raw.indexOf('{'), raw.lastIndexOf('}') + 1);
  if (braced.length > 2) attempts.push(braced.trim());

  for (const candidate of attempts) {
    try {
      const parsed = JSON.parse(candidate);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch (_) { /* thử dạng tiếp theo */ }
  }
  return null;
}

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
    return fail('Phân tích tài liệu đang tạm nghỉ. Bạn thử lại sau nhé.', 503);
  }

  // ── 1 · Xác thực ────────────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return fail('Cần đăng nhập để phân tích tài liệu.', 401);
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
    return fail('Phiên đăng nhập đã hết hạn. Bạn đăng nhập lại nhé.', 401);
  }

  const db = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // ── 2 · Tài liệu nào ────────────────────────────────────────────────────
  let documentId: string;
  try {
    const body = await req.json();
    documentId = String(body?.documentId ?? '').trim();
  } catch (_) {
    return fail('Yêu cầu không hợp lệ.', 400);
  }
  if (!documentId) return fail('Thiếu tài liệu cần phân tích.', 400);

  // XÁC MINH QUYỀN SỞ HỮU. Service role bỏ qua RLS, nên thiếu `.eq('user_id')`
  // là ai cũng đọc được JD/CV của người khác chỉ bằng cách đoán một uuid.
  const { data: doc } = await db
    .from('wr_context_documents')
    .select('id, user_id, doc_type, file_path, analysis_status')
    .eq('id', documentId)
    .eq('user_id', user.id)
    .maybeSingle();
  if (!doc) return fail('Không tìm thấy tài liệu này.', 404);

  // ── 3 · Gói ─────────────────────────────────────────────────────────────
  //
  // Hai nguồn, hợp lúc đọc — giống hệt `wr-chat` và `wrEntitlementProvider`.
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

  if (!isPremium && !ANALYSIS_FREE) {
    return fail(
      'Đọc và phân tích tài liệu nằm trong gói Premium.',
      402,
      { needsPremium: true },
    );
  }

  // ── 4 · Trần mỗi ngày ───────────────────────────────────────────────────
  {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { count, error } = await db
      .from('wr_context_documents')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('analyzed_at', since);
    if (error) {
      // Không đếm được thì CHẶN. Cho qua khi hỏng là biến một sự cố database
      // thành một cái vòi credit mở toang.
      console.error('Đếm hạn mức lỗi:', error.message);
      return fail('Chưa phân tích được lúc này. Bạn thử lại sau nhé.', 503);
    }
    if ((count ?? 0) >= DAILY_LIMIT) {
      return fail(
        'Hôm nay bạn đã phân tích khá nhiều tài liệu. Mai mình tiếp tục nhé.',
        429,
        { quotaExhausted: true },
      );
    }
  }

  // ── 5 · Lấy file ────────────────────────────────────────────────────────
  const filePath = String(doc.file_path ?? '');
  const mime = mimeOf(filePath);
  if (!mime) {
    await db
      .from('wr_context_documents')
      .update({
        analysis_status: 'failed',
        analysis_error: 'Định dạng file chưa đọc được.',
      })
      .eq('id', documentId);
    return fail(
      'Định dạng tài liệu này chưa đọc được. Bạn thử ảnh chụp hoặc file PDF nhé.',
      415,
    );
  }

  await db
    .from('wr_context_documents')
    .update({ analysis_status: 'processing', analysis_error: null })
    .eq('id', documentId);

  /// Ghi lại thất bại rồi trả lời người dùng — để lần sau mở màn hình còn thấy
  /// vì sao hỏng, thay vì một dòng "đang xử lý" treo vĩnh viễn.
  const failAndMark = async (userMessage: string, reason: string, status: number) => {
    await db
      .from('wr_context_documents')
      .update({ analysis_status: 'failed', analysis_error: reason })
      .eq('id', documentId);
    return fail(userMessage, status);
  };

  let base64: string;
  try {
    const { data: blob, error } = await db.storage.from(BUCKET).download(filePath);
    if (error || !blob) throw error ?? new Error('file rỗng');
    const buf = new Uint8Array(await blob.arrayBuffer());
    if (buf.byteLength === 0) {
      return await failAndMark('Tài liệu này rỗng.', 'file rỗng', 422);
    }
    if (buf.byteLength > MAX_FILE_BYTES) {
      return await failAndMark(
        'Tài liệu này nặng quá. Bạn thử bản nhẹ hơn nhé.',
        `file ${buf.byteLength} byte, quá ${MAX_FILE_BYTES}`,
        413,
      );
    }
    base64 = toBase64(buf);
  } catch (e) {
    console.error(`Tải file từ Storage lỗi: ${e}`);
    return await failAndMark(
      'Chưa mở được tài liệu này. Bạn thử tải lên lại nhé.',
      'không tải được file từ Storage',
      502,
    );
  }

  // ── 6 · Gọi model ───────────────────────────────────────────────────────
  const dataUrl = `data:${mime};base64,${base64}`;
  const isPdf = mime === 'application/pdf';
  const content = [
    { type: 'text', text: buildExtractionPrompt(String(doc.doc_type ?? 'other')) },
    isPdf
      ? {
        type: 'file',
        file: {
          filename: filePath.split('/').pop() ?? 'tai-lieu.pdf',
          file_data: dataUrl,
        },
      }
      : { type: 'image_url', image_url: { url: dataUrl } },
  ];

  const callUpstream = () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
    return fetch(OPENROUTER_URL, {
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
        messages: [{ role: 'user', content }],
        // Nhiệt độ thấp: đây là việc ĐỌC một tài liệu có sẵn, không phải viết
        // sáng tạo. Sáng tạo ở đây nghĩa là bịa thêm dòng không có trong JD.
        temperature: 0.1,
        max_tokens: 2400,
        response_format: { type: 'json_object' },
        // PDF đi qua bộ đọc chữ của OpenRouter. `pdf-text` là engine miễn phí,
        // đọc được PDF có lớp chữ; PDF scan (ảnh) sẽ rơi về đường đọc hình của
        // chính model.
        ...(isPdf
          ? { plugins: [{ id: 'file-parser', pdf: { engine: 'pdf-text' } }] }
          : {}),
      }),
    }).finally(() => clearTimeout(timer));
  };

  let raw: string;
  try {
    let res = await callUpstream();
    // Thử lại đúng một lần với lỗi có thể tự khỏi — cùng lý do đã ghi trong
    // `wr-chat`: nhà cung cấp vấp một nhịp không nên thành lỗi của người dùng.
    if (res.status === 429 || res.status >= 500) {
      console.warn(`OpenRouter ${res.status}, thử lại một lần.`);
      await new Promise((r) => setTimeout(r, 800));
      res = await callUpstream();
    }
    if (!res.ok) {
      const detail = await res.text();
      console.error(`OpenRouter ${res.status}: ${detail.slice(0, 500)}`);
      return await failAndMark(
        'Chưa đọc được tài liệu này. Bạn thử lại sau nhé.',
        `nhà cung cấp trả ${res.status}`,
        502,
      );
    }
    const payload = await res.json();
    raw = String(payload?.choices?.[0]?.message?.content ?? '').trim();
    if (!raw) {
      return await failAndMark(
        'Chưa đọc được tài liệu này. Bạn thử lại sau nhé.',
        'model trả về rỗng',
        502,
      );
    }
  } catch (e) {
    const aborted = e instanceof DOMException && e.name === 'AbortError';
    console.error(aborted ? 'OpenRouter quá hạn chờ' : `OpenRouter lỗi: ${e}`);
    return await failAndMark(
      aborted
        ? 'Tài liệu này đọc lâu quá. Bạn thử lại giúp mình nhé.'
        : 'Chưa đọc được tài liệu này. Bạn thử lại sau nhé.',
      aborted ? 'quá hạn chờ' : 'lỗi mạng tới nhà cung cấp',
      502,
    );
  }

  // ── 7 · Chuẩn hoá ───────────────────────────────────────────────────────
  const parsed = parseJsonLoose(raw);
  if (!parsed) {
    console.error('Không bóc được JSON:', raw.slice(0, 400));
    return await failAndMark(
      'Chưa đọc được tài liệu này. Bạn thử lại sau nhé.',
      'model trả về không phải JSON',
      502,
    );
  }

  const { analysis, extractedText } = normalizeAnalysis(parsed);

  // Không đọc ra chữ nào = ảnh mờ, ảnh chụp nghiêng, hoặc không phải tài liệu.
  // Nói thẳng để người dùng chụp lại, thay vì lưu một bản phân tích rỗng ruột
  // rồi để mọi tính năng phía sau nói chuyện trên không khí.
  if (extractedText.trim().length < 40) {
    return await failAndMark(
      'Mình chưa đọc được chữ trong tài liệu này. Bạn thử chụp rõ hơn nhé.',
      'không trích được chữ',
      422,
    );
  }

  // ── 8 · Lưu ─────────────────────────────────────────────────────────────
  const { error: saveError } = await db
    .from('wr_context_documents')
    .update({
      extracted_text: extractedText,
      analysis,
      analysis_status: 'ready',
      analysis_error: null,
      analyzed_at: new Date().toISOString(),
      analysis_model: MODEL,
    })
    .eq('id', documentId);

  if (saveError) {
    console.error('Không lưu được kết quả phân tích:', saveError.message);
    return fail('Đã đọc xong nhưng chưa lưu được. Bạn thử lại nhé.', 500);
  }

  return json({
    documentId,
    status: 'ready',
    analysis,
    extractedText,
    model: MODEL,
  });
});

// Viết lại phần nhận định của Báo cáo khảo sát bằng AI.
//
// ---------------------------------------------------------------------------
// HÀM NÀY DÙNG CHUNG VỚI BẢN WEB
//
// `ai-personalize` có từ thời bản web (repo `workreflection`), deploy trên cùng
// project Supabase `sukpcxevcjnhiuyaoqxi`. Tệp này là bản sao trong repo app,
// chép từ bản đang chạy (version 21) rồi thêm đúng một thứ: cổng chặn xin phép.
// Sửa bên nào cũng phải chép sang bên kia, nếu không lần deploy sau sẽ ghi đè
// mất phần của bên còn lại.
//
// ---------------------------------------------------------------------------
// VÌ SAO PHẢI THÊM CỔNG CHẶN — VÀ VÌ SAO CHẶN CÓ ĐIỀU KIỆN
//
// Hàm gửi vị trí, thâm niên, phòng ban và điểm khảo sát sang OpenRouter →
// Google (Gemini). App gọi nó TỰ ĐỘNG lúc mở màn Báo cáo, người dùng không bấm
// gì cả. Không chặn thì dữ liệu rời máy trước khi kịp hỏi — đúng thứ App Store
// Guideline 5.1.1(i) cấm, và là lý do bản 1.0 (6) bị từ chối ngày 06/09/2026.
//
// Nhưng chặn thẳng tay theo `wr_ai_consent` thì bản WEB chết theo: người dùng
// web không có màn xin phép nào, nên không ai có hàng trong bảng đó, và tính
// năng cá nhân hoá báo cáo bên web sẽ tắt câm. Nên chia hai nhánh:
//
//   • Yêu cầu đến từ app (`source === 'wr_mobile'`): BẮT BUỘC đã đồng ý.
//   • Yêu cầu khác (web): chỉ chặn khi người dùng đó ĐÃ TỪ CHỐI trong app.
//     Không có hàng nào thì cho đi tiếp như trước.
//
// Nhánh hai không phải phần thừa: đã nói "tắt rồi thì app ngừng gửi" thì tắt
// phải có nghĩa ở mọi cửa, kể cả cửa web mở ra cùng một dữ liệu.
//
// `verify_jwt = false` (kế thừa từ bản web) nên không tin được người gọi là ai
// — user_id lấy từ `cc_reports` theo `reportId`, không lấy từ body.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY");

const OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1/chat/completions";
const MODEL_NAME = "google/gemini-3.1-flash-lite-preview";
const REQUEST_TIMEOUT_MS = 30_000;

/// Phải khớp `kWrAiDisclosureVersion` trong `lib/core/logic/wr_ai_disclosure.dart`.
/// Lên 2 ngày 09/09/2026 khi bản công bố thêm chính luồng này.
const AI_DISCLOSURE_VERSION = 2;

const AI_CONSENT_REQUIRED_MESSAGE =
  "Bạn chưa cho phép gửi dữ liệu sang dịch vụ AI. Vào Tài khoản → Xử lý dữ " +
  "liệu bằng AI để xem app gửi những gì và bật lên.";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ─── Cổng chặn xin phép ─────────────────────────────────────

type ConsentState = "granted" | "declined" | "unknown";

/// Đọc trạng thái đồng ý của chủ báo cáo [reportId].
///
/// Trả "unknown" khi chưa có hàng nào — người dùng web bình thường rơi vào đây.
/// Lỗi đọc cũng trả "declined": không đọc được thì coi như chưa được phép, chứ
/// không gửi liều.
async function consentStateForReport(reportId: string): Promise<ConsentState> {
  try {
    const { data: report, error: reportErr } = await supabaseAdmin
      .from("cc_reports")
      .select("user_id")
      .eq("id", reportId)
      .maybeSingle();

    if (reportErr) {
      console.error("[ai-personalize] không đọc được cc_reports:", reportErr.message);
      return "declined";
    }
    if (!report?.user_id) return "unknown";

    const { data, error } = await supabaseAdmin
      .from("wr_ai_consent")
      .select("version, granted_at, revoked_at")
      .eq("user_id", report.user_id)
      .maybeSingle();

    if (error) {
      console.error("[ai-personalize] không đọc được wr_ai_consent:", error.message);
      return "declined";
    }
    if (!data) return "unknown";

    const granted = data.granted_at ? Date.parse(data.granted_at) : NaN;
    if (Number.isNaN(granted)) return "declined";

    const version = Number(data.version ?? 0);
    if (version < AI_DISCLOSURE_VERSION) return "declined";

    const revoked = data.revoked_at ? Date.parse(data.revoked_at) : NaN;
    if (!Number.isNaN(revoked) && revoked >= granted) return "declined";

    return "granted";
  } catch (e) {
    console.error("[ai-personalize] lỗi khi kiểm quyền:", e);
    return "declined";
  }
}

// ─── Section schemas ────────────────────────────────────────

const SECTION_SCHEMAS: Record<string, string[]> = {
  model: ["quote", "intro", "structure_desc", "culture_desc", "activity_desc"],
  reflection: [
    "intro",
    "item1_desc",
    "item2_desc",
    "item3_desc",
    "pauses_intro",
    "pause1",
    "pause2",
    "pause3",
  ],
  relationship: [
    "header_quote",
    "misconception_text",
    "misconception_quote",
    "asset1_desc",
    "asset2_desc",
    "asset3_desc",
    "asset4_desc",
    "asset5_desc",
    "closing_quote",
  ],
};

const SYSTEM_PROMPT = `Bạn là content writer cho Cloud & Coral, nền tảng wellness nơi làm việc.
Nhiệm vụ: rephrase nội dung tiếng Việt với câu từ hơi khác nhưng GIỮ NGUYÊN ý nghĩa, cảm xúc, giọng văn chuyên nghiệp.
Giọng empathetic, coaching, chuyên nghiệp. Không thêm thông tin mới.
Với layer yếu nhất (bottleneck) của người dùng, dùng giọng đồng cảm và khuyến khích hơn.
Output JSON đúng schema được yêu cầu. Chỉ output JSON, không markdown.`;

function buildUserPrompt(
  section: string,
  userContext: Record<string, unknown>,
  scoreContext: Record<string, unknown>,
  defaultContent: Record<string, string>,
): string {
  const schemaKeys = SECTION_SCHEMAS[section];

  const schemaDescription = schemaKeys
    .map((key) => `  "${key}": "string"`)
    .join(",\n");

  return `## Thông tin người dùng
- Vị trí: ${userContext.position || "Không rõ"}
- Thâm niên: ${userContext.tenure || "Không rõ"}
- Phòng ban: ${userContext.department || "Không rõ"}

## Điểm số
- Điểm Cấu trúc (Structure): ${scoreContext.structure ?? "N/A"}
- Điểm Văn hóa (Culture): ${scoreContext.culture ?? "N/A"}
- Điểm Hoạt động (Activity): ${scoreContext.activity ?? "N/A"}
- Điểm tổng: ${scoreContext.total ?? "N/A"}
- ESI: ${scoreContext.esi ?? "N/A"}
- Layer yếu nhất (bottleneck): ${scoreContext.bottleneck ?? "N/A"}
- Mức điểm: ${scoreContext.scoreLevel ?? "N/A"}

## Nội dung gốc cần rephrase (section: ${section})
${JSON.stringify(defaultContent, null, 2)}

## Yêu cầu output JSON schema
{
${schemaDescription}
}

Rephrase từng field trong nội dung gốc. Giữ nguyên ý nghĩa, thay đổi câu từ tự nhiên. Output ĐÚNG JSON schema trên.`;
}

function validateResponseKeys(
  parsed: Record<string, unknown>,
  section: string,
): boolean {
  const expectedKeys = SECTION_SCHEMAS[section];
  if (!expectedKeys) return false;

  for (const key of expectedKeys) {
    if (typeof parsed[key] !== "string") {
      return false;
    }
  }
  return true;
}

// ─── Generate handler ───────────────────────────────────────

async function handleGenerate(
  reportId: string,
  section: string,
  userContext: Record<string, unknown>,
  scoreContext: Record<string, unknown>,
  defaultContent: Record<string, string>,
  source: string | null,
): Promise<Response> {
  // Validate section
  if (!SECTION_SCHEMAS[section]) {
    return jsonResponse(
      { error: `Invalid section: ${section}. Must be one of: model, reflection, relationship` },
      400,
    );
  }

  // Check cache first.
  //
  // Đọc cache đặt TRƯỚC cổng chặn là cố ý: bản đã sinh từ trước nằm sẵn trong
  // bảng của mình, trả lại nó không gửi thêm gì cho ai. Chặn cả đường này là
  // phạt người dùng vì một lần gửi đã xảy ra rồi.
  const { data: cached } = await supabaseAdmin
    .from("cc_ai_personalization_cache")
    .select("content, status")
    .eq("report_id", reportId)
    .eq("section", section)
    .eq("status", "completed")
    .maybeSingle();

  if (cached) {
    return jsonResponse({
      content: cached.content,
      fromCache: true,
    });
  }

  // Từ đây trở xuống là gửi dữ liệu ra ngoài — phải xin phép trước.
  const consent = await consentStateForReport(reportId);
  const blocked = source === "wr_mobile"
    ? consent !== "granted"
    : consent === "declined";

  if (blocked) {
    return jsonResponse(
      { error: AI_CONSENT_REQUIRED_MESSAGE, code: "ai_consent_required" },
      403,
    );
  }

  // Upsert row with processing status
  const { error: upsertError } = await supabaseAdmin
    .from("cc_ai_personalization_cache")
    .upsert(
      {
        report_id: reportId,
        section,
        content: {},
        model_name: MODEL_NAME,
        status: "processing",
        error_message: null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "report_id,section" },
    );

  if (upsertError) {
    console.error("[ai-personalize] upsert error:", upsertError.message);
  }

  // Call OpenRouter API with timeout
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const userPrompt = buildUserPrompt(section, userContext, scoreContext, defaultContent);

    const openRouterRes = await fetch(OPENROUTER_BASE_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL_NAME,
        response_format: { type: "json_object" },
        temperature: 0.7,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPrompt },
        ],
      }),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!openRouterRes.ok) {
      const errorBody = await openRouterRes.text();
      console.error("[ai-personalize] OpenRouter error:", errorBody);

      await supabaseAdmin
        .from("cc_ai_personalization_cache")
        .update({
          status: "failed",
          error_message: `OpenRouter API error: ${openRouterRes.status}`,
          updated_at: new Date().toISOString(),
        })
        .eq("report_id", reportId)
        .eq("section", section);

      return jsonResponse(
        { error: "AI generation failed", details: errorBody },
        502,
      );
    }

    const openRouterData = await openRouterRes.json();
    const rawContent = openRouterData?.choices?.[0]?.message?.content;

    if (!rawContent) {
      console.error("[ai-personalize] No content in OpenRouter response:", openRouterData);

      await supabaseAdmin
        .from("cc_ai_personalization_cache")
        .update({
          status: "failed",
          error_message: "No content in AI response",
          updated_at: new Date().toISOString(),
        })
        .eq("report_id", reportId)
        .eq("section", section);

      return jsonResponse({ error: "No content in AI response" }, 502);
    }

    // Parse and validate JSON response
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(rawContent);
    } catch (parseErr) {
      console.error("[ai-personalize] JSON parse error:", parseErr, "raw:", rawContent);

      await supabaseAdmin
        .from("cc_ai_personalization_cache")
        .update({
          status: "failed",
          error_message: `JSON parse error: ${(parseErr as Error).message}`,
          updated_at: new Date().toISOString(),
        })
        .eq("report_id", reportId)
        .eq("section", section);

      return jsonResponse(
        { error: "Failed to parse AI response as JSON" },
        502,
      );
    }

    if (!validateResponseKeys(parsed, section)) {
      const expectedKeys = SECTION_SCHEMAS[section].join(", ");
      console.error(
        "[ai-personalize] Invalid response keys. Expected:",
        expectedKeys,
        "Got:",
        Object.keys(parsed),
      );

      await supabaseAdmin
        .from("cc_ai_personalization_cache")
        .update({
          status: "failed",
          error_message: `Invalid response schema. Expected keys: ${expectedKeys}`,
          updated_at: new Date().toISOString(),
        })
        .eq("report_id", reportId)
        .eq("section", section);

      return jsonResponse(
        { error: "AI response does not match expected schema", expectedKeys },
        502,
      );
    }

    // Update cache with completed status
    const { error: updateError } = await supabaseAdmin
      .from("cc_ai_personalization_cache")
      .update({
        content: parsed,
        status: "completed",
        error_message: null,
        updated_at: new Date().toISOString(),
      })
      .eq("report_id", reportId)
      .eq("section", section);

    if (updateError) {
      console.warn("[ai-personalize] cache update failed:", updateError.message);
    }

    return jsonResponse({
      content: parsed,
      fromCache: false,
    });
  } catch (err) {
    clearTimeout(timeoutId);

    const isTimeout = (err as Error).name === "AbortError";
    const errorMessage = isTimeout
      ? "AI generation timed out after 30 seconds"
      : (err as Error).message;

    console.error("[ai-personalize] request error:", errorMessage);

    await supabaseAdmin
      .from("cc_ai_personalization_cache")
      .update({
        status: "failed",
        error_message: errorMessage,
        updated_at: new Date().toISOString(),
      })
      .eq("report_id", reportId)
      .eq("section", section);

    return jsonResponse(
      { error: errorMessage },
      isTimeout ? 504 : 502,
    );
  }
}

// ─── Main handler ───────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!OPENROUTER_API_KEY) {
      return jsonResponse({ error: "OPENROUTER_API_KEY is not configured" }, 500);
    }

    const body = await req.json();
    const { action } = body;

    if (!action) {
      return jsonResponse({ error: "Missing action" }, 400);
    }

    switch (action) {
      case "generate": {
        const { reportId, section, userContext, scoreContext, defaultContent, source } = body as {
          reportId: string;
          section: string;
          userContext: Record<string, unknown>;
          scoreContext: Record<string, unknown>;
          defaultContent: Record<string, string>;
          source?: string;
        };

        if (!reportId) {
          return jsonResponse({ error: "Missing reportId" }, 400);
        }

        if (!section) {
          return jsonResponse({ error: "Missing section" }, 400);
        }

        if (!defaultContent) {
          return jsonResponse({ error: "Missing defaultContent" }, 400);
        }

        return await handleGenerate(
          reportId,
          section,
          userContext || {},
          scoreContext || {},
          defaultContent,
          typeof source === "string" ? source : null,
        );
      }

      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    console.error("[ai-personalize] error:", err);
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});

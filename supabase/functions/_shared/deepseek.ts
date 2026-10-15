// Gọi thẳng DeepSeek API — đường AI DUY NHẤT của app từ 15/10/2026.
//
// Trước đó mọi hàm đi qua OpenRouter (trừ `wr-chat`, chuyển ngày 12/10). Tài
// khoản OpenRouter hết credit từ 14/10 và mọi hàm còn lại trả 402 trong im
// lặng: người dùng chỉ thấy phần AI trống. Gom về một chỗ để lần sau đổi nhà
// cung cấp chỉ sửa một file.
//
// SECRET: `supabase secrets set DEEPSEEK_API_KEY=sk-...`
// Tuỳ chọn: `DEEPSEEK_MODEL` (mặc định `deepseek-chat`, cùng `wr-chat`).

export const DEEPSEEK_URL = 'https://api.deepseek.com/chat/completions';

export function deepSeekKey(): string | undefined {
  return Deno.env.get('DEEPSEEK_API_KEY') || undefined;
}

export function deepSeekModel(): string {
  return Deno.env.get('DEEPSEEK_MODEL') ?? 'deepseek-chat';
}

export interface DeepSeekOptions {
  temperature: number;
  maxTokens?: number;
  /// Bắt model trả đúng một object JSON (`response_format: json_object`).
  /// DeepSeek đòi chữ "json" xuất hiện trong prompt khi bật cờ này.
  json?: boolean;
  timeoutMs: number;
}

/// Một lượt gọi. Trả nguyên `Response` để nơi gọi tự quyết thử lại / báo lỗi.
export async function deepSeekFetch(
  key: string,
  messages: unknown[],
  opts: DeepSeekOptions,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), opts.timeoutMs);
  try {
    return await fetch(DEEPSEEK_URL, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: deepSeekModel(),
        messages,
        temperature: opts.temperature,
        ...(opts.maxTokens ? { max_tokens: opts.maxTokens } : {}),
        ...(opts.json ? { response_format: { type: 'json_object' } } : {}),
      }),
    });
  } finally {
    clearTimeout(timer);
  }
}

/// Chữ trong câu trả lời, rỗng khi không có.
export async function deepSeekText(res: Response): Promise<string> {
  const data = await res.json();
  return String(data?.choices?.[0]?.message?.content ?? '').trim();
}

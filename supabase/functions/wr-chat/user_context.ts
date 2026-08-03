// Ngữ cảnh thật của người dùng, nạp vào mỗi lượt trò chuyện.
//
// ---------------------------------------------------------------------------
// VÌ SAO PHẢI CÓ FILE NÀY
//
// Bản đầu của `wr-chat` chỉ đưa cho model system prompt và lịch sử chat. Chạy
// thử với lịch sử RỖNG, model trả lời:
//
//   "Mình để ý bạn hay nhắc đến việc ngại lên tiếng trong các cuộc trò chuyện
//    gần đây."
//
// Nó chưa từng thấy một dòng dữ liệu nào của người đó. Câu này chép thẳng từ ví
// dụ mẫu ở mục 7 của chính system prompt và phát biểu như một quan sát thật.
// Với sản phẩm có mệnh đề nền "con người kiến tạo ý nghĩa, AI nhìn thấy mẫu
// hình", bịa mẫu hình là kiểu hỏng tệ nhất: người dùng biết mình chưa kể gì.
//
// Nên hai việc, cùng lúc:
//   1. Đưa dữ liệu THẬT vào, để mục 7 có cái mà dựa vào.
//   2. Khi không có dữ liệu, nói thẳng với model là không có, kèm lệnh cấm suy
//      diễn. Xem [NO_DATA_RULE].
//
// ---------------------------------------------------------------------------
// NGUỒN SỰ THẬT
//
// Kiến trúc Dữ liệu v2.0 §4.3, "Nguyên tắc bắt buộc: một nguồn sự thật duy
// nhất": `recentSituationIds` là nguồn DUY NHẤT được phép trả lời "người này
// đang phản chiếu nhiều về điều gì". Và bảng Episode CHÍNH LÀ recentSituationIds
// (`situation_code` được vá vào ngay ở bước Notice).
//
// Nên ở đây đọc `wr_reflection_episodes`, KHÔNG đọc `wr_pattern_counts`. Trên DB
// thật hai bảng đó cho hai con số khác nhau cho cùng một tình huống của cùng
// một người, vì mỗi bảng ghi ở một thời điểm khác trong luồng. Xem
// `lib/core/logic/wr_repeated_situations.dart` để biết đầy đủ vì sao.
//
// ---------------------------------------------------------------------------
// ⚠ TUYỆT ĐỐI KHÔNG ĐƯA MÃ NỘI BỘ VÀO KHỐI NÀY
//
// Mục 6 của system prompt cấm model nói ra "S1", "C2", "A3", tên bảng, tên
// trường. Cách chắc chắn nhất để nó không nói ra là nó không bao giờ nhìn thấy.
// Vì vậy `situation_code` được đổi sang TIÊU ĐỀ tiếng Việt trước khi ghép vào
// prompt, và không có tên cột nào xuất hiện trong chuỗi trả về.

import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2';

/// Cửa sổ recentSituationIds (v2.0 §4.1: tối đa 30 mục gần nhất).
const RECENT_WINDOW = 30;

/// Số tháng dựng thành mốc thời gian.
///
/// Sáu tháng là đủ để trả lời "tháng trước so với tháng này" và "mấy tháng nay
/// mình có đỡ hơn không", mà chưa dài tới mức người dùng đã là một người khác so
/// với đầu khoảng.
const TREND_MONTHS = 6;

/// Trần số Episode kéo về để dựng mốc tháng.
///
/// Cần nhiều hơn [RECENT_WINDOW] vì mốc tháng tính trên cả khoảng, không chỉ 30
/// lần gần nhất. Vẫn phải có trần: không ai nhìn lại 400 lần trong sáu tháng, và
/// nếu có thì vài chục lần cũ nhất cũng không đổi được bức tranh.
const EPISODE_FETCH_LIMIT = 400;

/// Số tình huống lặp lại đưa vào ngữ cảnh (v2.0 §4.3: ba tình huống cao nhất).
const TOP_REPEATED = 3;

/// Số lần tối thiểu để gọi là "trở đi trở lại".
///
/// CỐ Ý là 2, không phải 3 như ngưỡng hiển thị ở tab Hiểu
/// (`kRepeatedSituationsMinCount`). Hai câu hỏi khác nhau: màn hình hỏi "điều gì
/// đáng dựng thành một mục cho người ta đọc", còn ở đây hỏi "trợ lý được phép
/// biết gì về người đang nói chuyện". Hai lần đã đủ để nói "bạn có nhắc lại
/// chuyện này", trong khi chưa đủ để dựng một mục trên màn hình.
const REPEATED_MIN_COUNT = 2;

/// Tên tiếng Việt của ba nhu cầu nền tảng, đúng từ mục 3 của system prompt.
///
/// Ánh xạ từ giá trị trong database sang chữ người đọc được. Model chỉ thấy cột
/// bên phải, nên nó không có gì để lỡ miệng.
const NEED_LABELS: Record<string, string> = {
  ro_rang: 'Rõ ràng',
  ket_noi: 'Kết nối',
  thich_nghi: 'Thích nghi',
  phat_trien: 'Phát triển',
};

/// Luật cấm suy diễn khi không có dữ liệu.
///
/// Đây là phần QUAN TRỌNG NHẤT của file. Không có nó thì model rơi lại đúng lỗi
/// đã mô tả ở đầu file: mượn ví dụ trong prompt làm quan sát về người thật.
const NO_DATA_RULE = `
Bạn CHƯA có dữ liệu nào về người này: họ chưa ghi lại lần nhìn lại nào trong app.

Vì vậy, trong lượt này bạn KHÔNG ĐƯỢC nói những câu như "mình để ý bạn hay...",
"mẫu hình rõ nhất của bạn là...", "gần đây bạn thường...", hay bất kỳ phát biểu
nào về thói quen, mẫu hình, hay lịch sử của họ. Bạn không biết những điều đó.
Các ví dụ trong tài liệu phía trên là ví dụ minh hoạ, KHÔNG phải dữ liệu của
người đang nói chuyện với bạn.

Nếu họ hỏi về mẫu hình hoặc hướng phát triển của mình, hãy nói thật một cách nhẹ
nhàng: bạn cần họ ghi lại vài lần nhìn lại trước đã, rồi mời họ kể một chuyện cụ
thể vừa xảy ra.`;

/// Nhắc lại khi CÓ dữ liệu: chỉ được dùng đúng những gì đã cho.
///
/// Đoạn về mốc thời gian được thêm sau lần chạy thử 2026-08-03: hỏi "tháng
/// trước tôi có tiến bộ gì so với tháng này" thì model lái sang thứ nó biết rồi
/// gọi đó là "một bước chuyển đáng chú ý", trong khi ngữ cảnh lúc đó không có
/// trục thời gian nào. Giờ có mốc tháng thật để dựa vào, và có luật buộc nó nói
/// thật khi câu hỏi vượt ra ngoài khoảng đã cho.
const HAS_DATA_RULE = `
Chỉ dùng đúng những gì liệt kê ở trên. Không suy ra thêm sự kiện, con số, hay
mẫu hình nào khác. Nếu người dùng hỏi một điều mà dữ liệu trên không trả lời
được, nói thật là bạn chưa có đủ để nói về điều đó.

Về so sánh theo thời gian: chỉ so sánh bằng đúng các mốc tháng đã liệt kê. Nếu
họ hỏi về một khoảng thời gian không có trong danh sách đó, hoặc hỏi về một thay
đổi mà các con số trên không cho thấy, nói thẳng là bạn chưa đủ dữ liệu để so
sánh khoảng đó, thay vì mượn một điều khác rồi gọi nó là tiến bộ. Số lần nhìn
lại nhiều hơn hay ít hơn KHÔNG có nghĩa là tốt lên hay xấu đi, đừng diễn giải
theo hướng đó.`;

/// Luật riêng cho gói miễn phí, đi kèm khối dữ liệu ĐÃ bị lược.
///
/// VÌ SAO CÓ: chạy thử A/B 2026-08-03 với cùng ngữ cảnh, chỉ đổi cờ gói. Câu
/// "mấy tháng nay tôi có thay đổi gì không" thuộc trục trí tuệ ở mục 7, nhưng
/// người dùng Free nhận được nguyên một bản phân tích xu hướng, KHÔNG hề bị
/// chặn. Lý do đơn giản: lúc đó cả hai gói cùng nhận một khối dữ liệu, và ranh
/// giới chỉ nằm ở một dòng dặn dò. Model đọc thấy số liệu theo tháng thì nó đọc
/// ra, rồi mới gắn thêm một câu mời mua Premium ở cuối.
///
/// Nên ranh giới phải nằm ở DỮ LIỆU, không phải ở lời dặn: mốc tháng chỉ được
/// ghép vào ngữ cảnh của người Premium. Thứ model không nhìn thấy thì nó không
/// lỡ miệng được, còn một dòng dặn dò thì lúc theo lúc không.
const FREE_GATE_RULE = `
Người này đang dùng gói MIỄN PHÍ, và khối dữ liệu trên đã được lược bớt cho đúng
gói: bạn KHÔNG có số lần theo từng tháng và KHÔNG có xu hướng thay đổi theo thời
gian của họ. Đừng dựng một xu hướng lên từ những gì còn lại.

Khi họ hỏi một điều thuộc trục trí tuệ ở mục 7 (mẫu hình theo thời gian, mấy
tháng nay họ có thay đổi gì, nên phát triển hướng nào tiếp, nên chọn chủ đề thực
hành nào, kết quả bài tự đánh giá nói lên điều gì về họ), trả lời đúng ba nhịp
sau và không hơn:

  1. MỘT câu duy nhất nêu điều bạn để ý thấy, lấy từ khối dữ liệu trên.
  2. Nói rõ phần đầy đủ thuộc gói Premium.
  3. Mời họ xem thử.

Không giải thích điều đó nghĩa là gì, không nối thêm nguyên nhân, không suy ra
nhu cầu nào đang nổi lên, không khuyên họ nên làm gì tiếp. Chính phần diễn giải
mới là thứ họ chưa mở, nên nói ra là phát không cái đang bán.`;

// ---------------------------------------------------------------------------

type Episode = {
  situation_code: string | null;
  human_need: string | null;
  opened_at: string | null;
};

/// Đọc và dựng khối ngữ cảnh cho [userId].
///
/// Không bao giờ ném: một truy vấn hỏng chỉ làm mất phần đó của ngữ cảnh, và
/// mất ngữ cảnh thì rơi về [NO_DATA_RULE], tức là im lặng an toàn. Ném lỗi ở
/// đây sẽ làm hỏng cả lượt trò chuyện vì một thứ chỉ là phần bổ trợ.
/// [isPremium] KHÔNG chỉ đổi lời dặn, nó đổi chính những gì được ghép vào khối:
/// mốc thời gian theo tháng là trục trí tuệ ở mục 7 nên chỉ người Premium mới
/// được thấy. Xem [FREE_GATE_RULE] để biết vì sao gác bằng lời dặn là không đủ.
export async function buildUserContext(
  db: SupabaseClient,
  userId: string,
  isPremium: boolean,
): Promise<string> {
  const lines: string[] = [];

  // ── Lần nhìn lại đã ghi ────────────────────────────────────────────────
  //
  // Không lọc theo trạng thái: §4.3 tính từ lúc CHỌN tình huống, nên một phiên
  // bỏ dở giữa chừng vẫn là một lần người ta đã chạm vào chuyện đó.
  let episodes: Episode[] = [];
  let firstEver: string | null = null;
  try {
    const [recent, earliest] = await Promise.all([
      db
        .from('wr_reflection_episodes')
        .select('situation_code, human_need, opened_at')
        .eq('user_id', userId)
        .order('opened_at', { ascending: false })
        .limit(EPISODE_FETCH_LIMIT),
      // Lần đầu tiên trong đời, không giới hạn khoảng: nó cho model biết mình
      // đang nói chuyện với người mới dùng hôm qua hay người đã đi cùng nửa
      // năm. Hai người đó cần hai cách nói khác nhau.
      db
        .from('wr_reflection_episodes')
        .select('opened_at')
        .eq('user_id', userId)
        .order('opened_at', { ascending: true })
        .limit(1),
    ]);
    episodes = (recent.data ?? []) as Episode[];
    firstEver = (earliest.data?.[0]?.opened_at as string | null) ?? null;
  } catch (_) {
    /* mất phần này thì phần dưới vẫn dựng được */
  }

  // Cửa sổ 30 gần nhất — giữ ĐÚNG ngữ nghĩa recentSituationIds của v2.0 §4.1.
  // Mốc tháng bên dưới dùng cả `episodes`, nhưng "đang phản chiếu nhiều về điều
  // gì" thì vẫn chỉ được hỏi cửa sổ 30, không được nới ra theo.
  const recentWindow = episodes.slice(0, RECENT_WINDOW);

  if (episodes.length > 0) {
    const last = episodes[0]?.opened_at;
    if (last) lines.push(`Lần nhìn lại gần nhất: ${formatDate(last)}.`);
    if (firstEver) {
      lines.push(`Lần nhìn lại đầu tiên của họ: ${formatDate(firstEver)}.`);
    }
  }

  // ── Mốc thời gian ──────────────────────────────────────────────────────
  //
  // Không có phần này thì mọi câu hỏi so sánh ("tháng trước so với tháng này")
  // đều không có gì để dựa vào, và model sẽ nống một điều nó biết lên thành một
  // kết luận về tiến bộ. Đúng lỗi đã bắt được ngày 2026-08-03.
  //
  // CHỈ CHO PREMIUM. Mục 7 xếp "phân tích Pattern sâu theo thời gian" vào trục
  // trí tuệ, và chính ví dụ mẫu cho người Free trong tài liệu cũng gọi tên "xu
  // hướng thay đổi theo thời gian" là phần thuộc Premium. Đưa khối này cho gói
  // miễn phí là tự tay phát không thứ đang bán.
  const monthly = isPremium ? monthlyBuckets(episodes) : [];
  if (monthly.length > 0) {
    lines.push('Số lần nhìn lại theo tháng, mới nhất trước:');
    for (const m of monthly) {
      const needPart = m.topNeed ? `, chủ yếu quanh nhu cầu ${m.topNeed}` : '';
      lines.push(`  • ${m.label}: ${m.count} lần${needPart}`);
    }
    lines.push(
      `Chỉ có số liệu của ${TREND_MONTHS} tháng gần nhất, không có dữ liệu xa hơn.`,
    );
  }

  // ── Tình huống trở đi trở lại ──────────────────────────────────────────
  const counts = new Map<string, number>();
  for (const e of recentWindow) {
    if (e.situation_code) {
      counts.set(e.situation_code, (counts.get(e.situation_code) ?? 0) + 1);
    }
  }

  const repeated = [...counts.entries()]
    .filter(([, n]) => n >= REPEATED_MIN_COUNT)
    .sort((a, b) => b[1] - a[1])
    .slice(0, TOP_REPEATED);

  if (repeated.length > 0) {
    // Đổi mã sang tiêu đề. Mã nào không tra được thì BỎ HẲN, không đưa mã thô
    // vào thay thế — xem cảnh báo ở đầu file.
    const titles = await resolveTitles(db, repeated.map(([code]) => code));
    const named = repeated
      .filter(([code]) => titles.has(code))
      .map(([code, n]) => `  • "${titles.get(code)}" — ${n} lần`);
    if (named.length > 0) {
      lines.push(
        `Những tình huống họ đã chọn nhiều lần (trong ${recentWindow.length} lần gần nhất):`,
      );
      lines.push(...named);
    }
  }

  // ── Nhu cầu chủ đạo ────────────────────────────────────────────────────
  const topNeed = dominantNeed(recentWindow);
  if (topNeed) {
    lines.push(
      `Nhu cầu xuất hiện nhiều nhất trong các lần nhìn lại gần đây: ${topNeed}.`,
    );
  }

  // ── Điều họ tự rút ra gần nhất ─────────────────────────────────────────
  //
  // Đây là chữ của CHÍNH người dùng, không phải của hệ thống. Nó là chất liệu
  // quý nhất trong cả khối này, và cũng là thứ trợ lý được phép nhắc lại
  // nguyên văn mà không sợ diễn giải sai ý ai.
  try {
    const { data } = await db
      .from('wr_insights')
      .select('content, saved_at')
      .eq('user_id', userId)
      .order('saved_at', { ascending: false })
      .limit(2);
    for (const row of data ?? []) {
      const content = String(row.content ?? '').trim();
      if (content) {
        lines.push(
          `Điều họ tự rút ra (${formatDate(row.saved_at)}): "${truncate(content, 300)}"`,
        );
      }
    }
  } catch (_) { /* bỏ qua */ }

  // ── Chủ đề Thực hành đang theo ─────────────────────────────────────────
  try {
    const { data: enrollments } = await db
      .from('wr_practice_enrollments')
      .select('theme_id, completed_steps, completed_at')
      .eq('user_id', userId)
      .is('completed_at', null);

    const ids = (enrollments ?? []).map((e) => e.theme_id).filter(Boolean);
    if (ids.length > 0) {
      const { data: themes } = await db
        .from('wr_practice_themes')
        .select('theme_id, title')
        .in('theme_id', ids);
      const byId = new Map(
        (themes ?? []).map((t) => [t.theme_id as string, t.title as string]),
      );
      for (const e of enrollments ?? []) {
        const title = byId.get(e.theme_id as string);
        if (!title) continue;
        const done = Array.isArray(e.completed_steps)
          ? e.completed_steps.length
          : 0;
        lines.push(
          `Chủ đề thực hành đang theo: "${title}" (đã xong ${done} bước).`,
        );
      }
    }
  } catch (_) { /* bỏ qua */ }

  // ── Bài tự đánh giá ────────────────────────────────────────────────────
  //
  // CỐ Ý chỉ đưa NGÀY, không đưa điểm ba trục. Diễn giải sâu kết quả bài này
  // thuộc trục trí tuệ ở mục 7; đưa điểm vào là mở sẵn cửa cho model diễn giải
  // qua đường hội thoại, kể cả với người dùng gói miễn phí.
  //
  // NHƯNG phải NÓI RA là không có kết quả, không được im lặng bỏ trống. Chạy thử
  // 2026-08-03: chỉ đưa mỗi ngày làm bài thì CẢ HAI gói đều bịa ra kết quả —
  // "bài tự đánh giá của bạn cho thấy nhu cầu Kết nối nổi lên nhiều nhất" —
  // trong khi ngữ cảnh không hề có một con điểm nào. Model thấy một cái tên bài
  // không kèm nội dung thì nó tự điền nội dung, lấy từ phần dữ liệu khác ở gần
  // đó. Đúng lỗi bịa mẫu hình mà [NO_DATA_RULE] sinh ra để chặn, chỉ là ở một
  // trường khác.
  try {
    const { data } = await db
      .from('wr_sca_self_check_responses')
      .select('taken_at')
      .eq('user_id', userId)
      .order('taken_at', { ascending: false })
      .limit(1);
    const takenAt = data?.[0]?.taken_at;
    if (takenAt) {
      lines.push(
        `Họ đã làm bài tự đánh giá ngắn, lần gần nhất ${formatDate(takenAt)}. `
          + `Bạn KHÔNG có kết quả của bài đó, chỉ biết là họ đã làm. Nếu họ hỏi `
          + `bài đó nói gì về họ, nói thật là bạn không xem được kết quả ở đây và `
          + `mời họ mở phần kết quả trong app. Tuyệt đối không đoán kết quả từ các `
          + `dữ liệu khác ở trên.`,
      );
    }
  } catch (_) { /* bỏ qua */ }

  // ── Ghép ───────────────────────────────────────────────────────────────
  if (lines.length === 0) return NO_DATA_RULE;

  return `

---

DỮ LIỆU THẬT VỀ NGƯỜI ĐANG NÓI CHUYỆN VỚI BẠN

Phần dưới đây lấy từ chính những gì họ đã ghi lại trong app. Đây là dữ liệu thật,
khác với các ví dụ minh hoạ ở tài liệu phía trên.

${lines.join('\n')}
${HAS_DATA_RULE}${isPremium ? '' : FREE_GATE_RULE}`;
}

// ---------------------------------------------------------------------------

/// Nhu cầu xuất hiện nhiều nhất, đã đổi sang tên tiếng Việt. Null nếu không có.
function dominantNeed(episodes: Episode[]): string | null {
  const counts = new Map<string, number>();
  for (const e of episodes) {
    if (e.human_need) {
      counts.set(e.human_need, (counts.get(e.human_need) ?? 0) + 1);
    }
  }
  const top = [...counts.entries()].sort((a, b) => b[1] - a[1])[0];
  return top ? (NEED_LABELS[top[0]] ?? null) : null;
}

type MonthBucket = {
  label: string;
  count: number;
  topNeed: string | null;
};

/// Gom Episode theo tháng, mới nhất trước, tối đa [TREND_MONTHS] tháng.
///
/// Chia theo GIỜ VIỆT NAM, không theo UTC. Một lần nhìn lại lúc 1 giờ sáng ngày
/// mùng 1 sẽ rơi vào tháng trước nếu tính theo UTC, và người dùng sẽ thấy con số
/// lệch với chính cái họ nhớ mình đã làm.
///
/// CỐ Ý bỏ hẳn tháng không có lần nào, thay vì hiện "0 lần". Một tháng trống
/// thường là tháng người ta bận, ốm, hoặc đang ổn nên không cần nhìn lại. Bày nó
/// ra thành một con số 0 giữa danh sách là mời model diễn giải một khoảng lặng
/// thành một thất bại.
export function monthlyBuckets(episodes: Episode[]): MonthBucket[] {
  const now = new Date();
  const cutoff = new Date(now);
  cutoff.setMonth(cutoff.getMonth() - (TREND_MONTHS - 1));
  cutoff.setDate(1);
  cutoff.setHours(0, 0, 0, 0);

  const groups = new Map<string, Episode[]>();
  for (const e of episodes) {
    if (!e.opened_at) continue;
    const d = new Date(e.opened_at);
    if (Number.isNaN(d.getTime()) || d < cutoff) continue;
    const key = monthKey(d);
    const list = groups.get(key);
    if (list) list.push(e);
    else groups.set(key, [e]);
  }

  return [...groups.entries()]
    // Khoá dạng `yyyy-mm` nên so sánh chuỗi cũng chính là so sánh thời gian.
    .sort((a, b) => b[0].localeCompare(a[0]))
    .slice(0, TREND_MONTHS)
    .map(([key, list]) => {
      const [y, m] = key.split('-');
      return {
        label: `Tháng ${m}/${y}`,
        count: list.length,
        topNeed: dominantNeed(list),
      };
    });
}

/// `yyyy-mm` theo giờ Việt Nam.
function monthKey(d: Date): string {
  // `en-CA` cho ra `yyyy-mm-dd`, cắt lấy bảy ký tự đầu là được `yyyy-mm`.
  return d
    .toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' })
    .slice(0, 7);
}

/// Tra tiêu đề tiếng Việt của các mã tình huống.
async function resolveTitles(
  db: SupabaseClient,
  codes: string[],
): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  if (codes.length === 0) return out;
  try {
    const { data } = await db
      .from('wr_situations')
      .select('code, text')
      .in('code', codes);
    for (const row of data ?? []) {
      const text = String(row.text ?? '').trim();
      if (text) out.set(row.code as string, text);
    }
  } catch (_) { /* không tra được thì trả map rỗng, phần gọi sẽ bỏ mục đó */ }
  return out;
}

/// Ngày dạng dd/mm/yyyy, theo giờ Việt Nam.
function formatDate(iso: string | null): string {
  if (!iso) return 'không rõ';
  try {
    const d = new Date(iso);
    // `en-GB` cho ra dd/mm/yyyy, đúng thứ tự người Việt đọc.
    return d.toLocaleDateString('en-GB', { timeZone: 'Asia/Ho_Chi_Minh' });
  } catch (_) {
    return 'không rõ';
  }
}

function truncate(s: string, max: number): string {
  return s.length <= max ? s : `${s.slice(0, max)}…`;
}

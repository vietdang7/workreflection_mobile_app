// Có đáng kể lại một lần nữa không — logic thuần, không chạm mạng.
//
// Tách khỏi `index.ts` để test được bằng `deno test` mà không cần Supabase hay
// OpenRouter. Đây là phần duy nhất của hàm quyết định TIÊU TIỀN hay không, nên
// nó là phần đáng test nhất.

/// Số lần nhìn lại tối thiểu để kể được lần đầu.
///
/// Dưới 5 thì chưa có "diễn biến" nào để kể — chỉ có vài sự việc rời rạc, và ép
/// model kể sẽ ra một đoạn văn suy diễn từ hai ba dòng dữ liệu. Đó đúng là kiểu
/// nội dung làm người dùng mất niềm tin vào mọi thứ còn lại trong app.
export const MIN_EPISODES = 5;

/// Số lần nhìn lại MỚI cần có trước khi kể lại.
///
/// Không có ngưỡng này thì mỗi lần mở tab Hành trình là một lượt gọi model, cho
/// cùng một câu chuyện chưa hề đổi. Ba lần là đủ để có thứ mới để nói mà không
/// bắt người dùng chờ quá lâu mới thấy thẻ đổi chữ.
export const MIN_NEW_EPISODES = 3;

export type EpisodeRow = {
  situation_code: string | null;
  human_need: string | null;
  energy: string | null;
  opened_at: string | null;
  draft_meaning: string | null;
};

export type NarrativeRow = {
  id: string;
  narrative: string;
  period_start: string | null;
  period_end: string | null;
  created_at: string;
};

export type Decision =
  | {
    regenerate: true;
    periodStart: string | null;
    periodEnd: string | null;
  }
  | {
    regenerate: false;
    /// Mã lý do, app dịch sang câu chữ. Không gửi câu tiếng Việt từ đây: cùng
    /// một lý do được nói khác nhau ở thẻ Hành trình và ở màn đầy đủ.
    reason: 'not_enough_data' | 'up_to_date';
    /// Còn thiếu bao nhiêu lần nữa. Đây là thứ câu "Ghi thêm vài lần nữa" của
    /// bản cũ không có, và vì không có nên nó không bao giờ đếm ngược.
    needed: number;
  };

/// Ngày dạng YYYY-MM-DD theo giờ Việt Nam — đúng kiểu cột `date` của Postgres.
///
/// `en-CA` là mẹo quen thuộc để lấy ISO date từ `toLocaleDateString`; cùng cách
/// `wr-chat/user_context.ts` đang dùng.
export function vnDate(iso: string | null | undefined): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });
}

/// [episodes] sắp MỚI NHẤT TRƯỚC (đúng thứ tự truy vấn ở `index.ts`).
export function decideRegeneration(
  episodes: EpisodeRow[],
  previous: NarrativeRow | null,
): Decision {
  if (episodes.length < MIN_EPISODES) {
    return {
      regenerate: false,
      reason: 'not_enough_data',
      needed: MIN_EPISODES - episodes.length,
    };
  }

  // Mốc giai đoạn lấy từ chính dữ liệu, không lấy "hôm nay": thẻ nói về quãng
  // người dùng đã đi, không phải về lúc máy chủ chạy hàm.
  const dates = episodes
    .map((e) => vnDate(e.opened_at))
    .filter((d): d is string => d !== null)
    .sort();
  const periodStart = dates[0] ?? null;
  const periodEnd = dates[dates.length - 1] ?? null;

  if (previous === null) {
    return { regenerate: true, periodStart, periodEnd };
  }

  // Đếm theo `created_at` của lần kể trước, KHÔNG theo `period_end`.
  //
  // `period_end` là ngày của Episode mới nhất lúc ấy — mà một người có thể ghi
  // thêm ba lần nữa trong CÙNG ngày đó. So với `period_end` thì ba lần ấy đều bị
  // coi là cũ và câu chuyện đứng im dù đã có thêm nguyên liệu. `created_at` là
  // mốc "lần trước ta đã đọc tới đâu", và đó mới đúng là câu hỏi ở đây.
  const cutoff = new Date(previous.created_at).getTime();
  const fresh = Number.isNaN(cutoff)
    ? episodes.length
    : episodes.filter((e) => {
      if (!e.opened_at) return false;
      const t = new Date(e.opened_at).getTime();
      return !Number.isNaN(t) && t > cutoff;
    }).length;

  if (fresh < MIN_NEW_EPISODES) {
    return {
      regenerate: false,
      reason: 'up_to_date',
      needed: MIN_NEW_EPISODES - fresh,
    };
  }

  return { regenerate: true, periodStart, periodEnd };
}

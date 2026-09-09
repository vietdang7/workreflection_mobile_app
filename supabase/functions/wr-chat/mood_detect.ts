// Đoán cảm xúc đang nói tới trong cuộc trò chuyện.
//
// ---------------------------------------------------------------------------
// VÌ SAO CẦN
//
// Nút "Xem điều gì đó nhẹ nhàng" mở Thư viện Nội dung Cảm xúc. Màn thư viện lọc
// theo cảm xúc CHECK-IN HÔM NAY. Nhưng người vào từ chat thường chưa check-in —
// họ mở app, gõ thẳng "khá là căng thẳng", rồi bấm nút. Không có check-in nào để
// bám, màn thư viện bày cả sáu nhóm.
//
// Khách phát hiện 2026-09-09: "nhấn vào thì chuyển tới trang gợi ý theo cảm xúc
// nhưng phần mềm lại gợi ý toàn bộ các mục thay vì theo cảm xúc hiện tại".
//
// Đó đúng là điều khách đã bác một lần rồi, ở đường vào từ Home (chốt
// 2026-07-29): đang mệt mà phải lướt qua năm nhóm mới tới nhóm của mình là bắt
// người ta làm việc đúng lúc họ ít sức nhất. Đường vào từ chat còn tệ hơn — họ
// VỪA MỚI nói ra mình đang thế nào, và app hỏi lại bằng cách bày hết ra.
//
// Cảm xúc ấy đã nằm sẵn trong lượt trò chuyện. Hàm này lấy nó ra.
//
// ---------------------------------------------------------------------------
// VÌ SAO DÒ TỪ KHOÁ CHỨ KHÔNG HỎI MODEL
//
// Cùng lý lẽ với `reply_shaping.ts`: prompt lo phần model làm ĐÚNG, tầng này lo
// phần model làm SAI. Thêm một thẻ `[[MOOD:...]]` vào prompt thì có thêm một thứ
// model phải nhớ, và nhánh an toàn trong `shapeReply` — chỗ TỰ ép nút "calm" khi
// model quên đặt thẻ — sẽ không có cảm xúc nào đi kèm. Đúng lượt quan trọng nhất
// lại là lượt hụt.
//
// Dò từ khoá chạy được ở mọi nhánh, kể cả nhánh ép.
//
// ---------------------------------------------------------------------------
// KHÔNG ĐOÁN ĐƯỢC THÌ TRẢ NULL
//
// Không có cảm xúc mặc định. Đoán bừa thành "căng thẳng" rồi mở đúng một nhóm là
// giấu mất năm nhóm còn lại của một người mà ta không hiểu đang thế nào — tệ hơn
// hẳn việc bày cả sáu. App nhận null thì quay về cách cũ.

/// Sáu giá trị của `wr_checkins.mood`, khớp enum `Mood` bên Dart.
export type ChatMood =
  | 'stressed'
  | 'tired'
  | 'foggy'
  | 'outofsync'
  | 'okay'
  | 'happy';

/// Từ khoá của từng cảm xúc.
///
/// CỐ Ý KHÔNG CHỒNG NHAU. Nếu vừa liệt "mệt" vừa liệt "mệt mỏi" thì một câu chứa
/// "mệt mỏi" đếm thành hai điểm, và cách chấm điểm bên dưới sẽ nghiêng theo số
/// lượng từ khoá ta gõ vào danh sách chứ không theo điều người dùng nói. Mỗi
/// cụm ở đây là dạng NGẮN NHẤT còn giữ nghĩa, để nó phủ luôn các dạng dài hơn.
///
/// So khớp trên chuỗi thường, không dùng `\b`: trong JavaScript `\w` chỉ gồm
/// chữ cái ASCII, nên `\bmệt\b` không chạy đúng với tiếng Việt có dấu.
const MOOD_KEYWORDS: Record<ChatMood, readonly string[]> = {
  stressed: [
    'căng thẳng',
    'căng quá',
    'áp lực',
    'stress',
    'quá tải',
    'ngộp',
    'dồn dập',
    'lo lắng',
    'bồn chồn',
    'deadline',
  ],
  tired: [
    'mệt',
    'kiệt sức',
    'đuối',
    'uể oải',
    'rã rời',
    'hết pin',
    'cạn sức',
    'buồn ngủ',
  ],
  foggy: [
    'mơ hồ',
    'mông lung',
    'hoang mang',
    'chưa rõ',
    'không rõ',
    'lạc hướng',
    'mất phương hướng',
    'rối bời',
    'chưa biết bắt đầu',
  ],
  outofsync: [
    'lệch',
    'không ăn khớp',
    'bất đồng',
    'mâu thuẫn',
    'hiểu lầm',
    'không cùng hướng',
    'không hợp nhau',
  ],
  okay: [
    'ổn',
    'bình thường',
  ],
  happy: [
    'vui',
    'hào hứng',
    'phấn khởi',
    'nhẹ nhõm',
    'hạnh phúc',
    'tự hào',
    'thoải mái',
  ],
};

/// Thứ tự phân định khi hai cảm xúc cùng điểm.
///
/// Nhóm khó đứng trước nhóm tích cực, CÓ CHỦ Ý. Câu "công việc vẫn ổn nhưng tôi
/// khá căng thẳng" có một điểm cho `okay` và một điểm cho `stressed`; mở thư
/// viện ở nhóm "Khá ổn" cho người vừa nói mình căng thẳng là đọc sai họ. Và nút
/// dẫn tới đây chỉ hiện ở những lượt cần dịu lại, nên nghiêng về phía khó là
/// nghiêng đúng hướng.
const MOOD_PRIORITY: readonly ChatMood[] = [
  'stressed',
  'tired',
  'foggy',
  'outofsync',
  'happy',
  'okay',
];

/// Nhóm cảm xúc khó — phần duy nhất được phép suy ra từ lời TRỢ LÝ.
///
/// Xem [detectMood] để biết vì sao lời trợ lý bị giới hạn.
const DIFFICULT_MOODS: readonly ChatMood[] = [
  'stressed',
  'tired',
  'foggy',
  'outofsync',
];

/// Phủ định đứng ngay trước từ khoá.
///
/// "không căng thẳng" và "đỡ mệt rồi" mà tính thành có cảm xúc đó là hiểu ngược
/// hẳn. Cho phép một chữ đệm ở giữa để bắt được "không còn vui", "chưa thấy mệt".
///
/// Chữ đệm phải kèm khoảng trắng ĐẰNG SAU nó. Bản đầu viết `\S{0,6}$` và trượt
/// đúng ca "chưa thấy mệt": cửa sổ nhìn lại là "chưa thấy " với dấu cách ở cuối,
/// mà `\S` thì không nuốt được dấu cách ấy.
const NEGATION_RE = /(không|chưa|chẳng|hết|đỡ|bớt|ko)\s+(\S{1,6}\s+)?$/;

/// Đếm số từ khoá của [mood] xuất hiện trong [text] mà không bị phủ định.
function scoreMood(text: string, mood: ChatMood): number {
  let score = 0;
  for (const keyword of MOOD_KEYWORDS[mood]) {
    let from = 0;
    while (true) {
      const at = text.indexOf(keyword, from);
      if (at < 0) break;
      // Chỉ nhìn khoảng ngay trước từ khoá. Từ khoá tự chứa chữ "không" ("không
      // rõ") không bị chính nó phủ định vì cửa sổ này nằm TRƯỚC nó.
      if (!NEGATION_RE.test(text.slice(Math.max(0, at - 14), at))) {
        score += 1;
        break; // Mỗi từ khoá tính một điểm, nhắc lại không nhân lên.
      }
      from = at + keyword.length;
    }
  }
  return score;
}

/// Cảm xúc có điểm cao nhất trong [text], hoặc null.
function moodOf(text: string, among: readonly ChatMood[]): ChatMood | null {
  const lower = text.toLowerCase();
  let best: ChatMood | null = null;
  let bestScore = 0;
  for (const mood of MOOD_PRIORITY) {
    if (!among.includes(mood)) continue;
    const score = scoreMood(lower, mood);
    // So sánh `>` chứ không `>=`: bằng điểm thì giữ cảm xúc đứng trước trong
    // [MOOD_PRIORITY], đó chính là luật phân định.
    if (score > bestScore) {
      best = mood;
      bestScore = score;
    }
  }
  return best;
}

/// Cảm xúc hiện tại của người dùng, đọc từ lượt trò chuyện.
///
/// [userTexts] xếp từ GẦN NHẤT tới xa dần — câu vừa gõ đứng đầu. Người ta đổi
/// cảm giác trong một cuộc trò chuyện, và câu mới nhất là câu đúng lúc này.
///
/// [assistantText] chỉ dùng khi lời người dùng không nói ra cảm xúc nào, và khi
/// đó CHỈ nhận nhóm khó. Trợ lý hay viết "để bạn thoải mái hơn", "mong bạn thấy
/// nhẹ nhõm" — đó là điều nó chúc, không phải điều người dùng đang thấy. Nhận cả
/// nhóm tích cực từ lời trợ lý là mở thư viện ở nhóm "Đang vui" cho một người vừa
/// kể chuyện tệ.
export function detectMood(
  userTexts: readonly string[],
  assistantText = '',
): ChatMood | null {
  for (const text of userTexts) {
    const mood = moodOf(text, MOOD_PRIORITY);
    if (mood !== null) return mood;
  }
  return assistantText ? moodOf(assistantText, DIFFICULT_MOODS) : null;
}

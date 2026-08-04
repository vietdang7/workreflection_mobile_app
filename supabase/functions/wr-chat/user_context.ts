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

/// Số lần nhìn lại được kéo về KÈM NỘI DUNG người dùng đã viết.
///
/// Ba, không nhiều hơn. Mỗi lần nhìn lại có thể mang theo sáu đoạn ghi chú tự
/// viết cộng một câu ý nghĩa và một việc nhỏ; mười lần là đủ đẩy phần dữ liệu
/// dài hơn cả system prompt, và thứ bị chen mất sẽ là các luật an toàn.
const DETAIL_EPISODE_COUNT = 3;

/// Trần ký tự cho mỗi đoạn người dùng tự viết.
const NOTE_MAX = 400;

/// Trong bao nhiêu giờ thì coi là "họ vừa nhìn lại xong".
///
/// Đây là bản lề của [JUST_REFLECTED_RULE]. 24 giờ vì người ta hay ghi lại buổi
/// tối rồi mở app nói chuyện sáng hôm sau — hai mốc đó phải nằm cùng một cửa sổ,
/// nếu không trợ lý sẽ mời họ làm lại đúng việc họ vừa làm tối qua.
const JUST_REFLECTED_HOURS = 24;

/// Nhãn tiếng Việt cho từng đoạn ghi chú trong một lần nhìn lại.
///
/// ⚠ Khoá bên trái là tên bước nội bộ. Mục 6 cấm model nói ra tên mô hình nội
/// bộ, nên KHÔNG BAO GIỜ ghép khoá vào chuỗi trả về — chỉ ghép cột bên phải.
/// Mã nào không có trong bảng này thì bỏ hẳn đoạn đó.
const NOTE_LABELS: Record<string, string> = {
  notice: 'Điều họ nhận thấy',
  name: 'Cách họ gọi tên cảm giác đó',
  explore: 'Điều họ thấy khi nghĩ sâu hơn',
  reframe: 'Cách họ nhìn lại theo hướng khác',
  commit: 'Điều họ định làm',
  preserve: 'Điều họ muốn giữ lại',
};

/// Thứ tự đọc các đoạn ghi chú, theo đúng thứ tự người dùng đã đi qua.
///
/// `notes` là jsonb nên thứ tự khoá do database trả về, không đảm bảo. Đọc lộn
/// thứ tự thì một lần nhìn lại mạch lạc biến thành một mớ rời rạc.
const NOTE_ORDER = ['notice', 'name', 'explore', 'reframe', 'commit', 'preserve'];

/// Trạng thái nghĩa là người dùng đã đi hết một vòng nhìn lại.
const FINISHED_STATES = new Set([
  'meaning_confirmed',
  'committed',
  'integrated',
]);

const ENERGY_LABELS: Record<string, string> = {
  good: 'đang khoẻ',
  ok: 'tạm ổn',
  low: 'đang xuống sức',
};

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
được, nói thật là bạn chưa có đủ để nói về điều đó.`;

/// Luật so sánh thời gian — CHỈ ghép cho gói Premium.
///
/// Trước đây nằm chung trong [HAS_DATA_RULE] nên áp cho cả hai gói, và nó ĐÁNH
/// NHAU với [FREE_GATE_RULE]: người Free hỏi "so sánh tháng này với tháng trước"
/// thì luật này thắng, trợ lý trả lời "mình chưa có đủ dữ liệu để so sánh".
///
/// Câu đó SAI SỰ THẬT về chính người đang hỏi. Họ có dữ liệu; thứ họ không có là
/// quyền xem phần tổng hợp theo thời gian. Nói "bạn chưa đủ dữ liệu" khiến người
/// đã ghi lại vài chục lần tưởng app không ghi nhận gì của mình, và đó là cách
/// tệ nhất để mất một người dùng đang chăm chỉ.
const TIME_COMPARISON_RULE = `

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

QUAN TRỌNG: khi họ hỏi so sánh giữa các tháng hay hỏi mình đã thay đổi ra sao,
TUYỆT ĐỐI KHÔNG nói "bạn chưa có đủ dữ liệu" hay "mình chỉ thấy một lần nhìn lại
của bạn". Họ CÓ dữ liệu, chỉ là phần tổng hợp theo thời gian không nằm trong gói
của họ. Nói nhầm câu kia là bảo một người đã chăm chỉ ghi lại rằng app không ghi
nhận gì của họ. Dùng đúng ba nhịp bên dưới thay vì nói về chuyện thiếu dữ liệu.

Khi họ hỏi một điều thuộc trục trí tuệ ở mục 7 (mẫu hình theo thời gian, mấy
tháng nay họ có thay đổi gì, nên phát triển hướng nào tiếp, nên chọn chủ đề thực
hành nào, DIỄN GIẢI SÂU kết quả bài tự đánh giá), trả lời đúng ba nhịp sau và
không hơn:

  1. MỘT câu duy nhất nêu điều bạn để ý thấy, lấy từ khối dữ liệu trên.
  2. Nói rõ phần đầy đủ thuộc gói Premium.
  3. Mời họ xem thử.

Không giải thích điều đó nghĩa là gì, không nối thêm nguyên nhân, không suy ra
nhu cầu nào đang nổi lên, không khuyên họ nên làm gì tiếp. Chính phần diễn giải
mới là thứ họ chưa mở, nên nói ra là phát không cái đang bán.

Ngược lại, ĐỪNG gác quá tay. Những việc sau mục 7 xếp vào trục hành động và họ
hoàn toàn có quyền: kể một tình huống, nói về cảm xúc lúc này, bắt đầu một lần
nhìn lại, chọn một chủ đề thực hành để bắt đầu, và xem kết quả TỔNG QUAN của bài
tự đánh giá. Với những việc này cứ trả lời bình thường, không nhắc gì tới
Premium.`;

/// Họ VỪA nhìn lại xong — đừng mời họ làm lại lần nữa.
///
/// VÌ SAO CÓ: khách chụp màn ngày 2026-08-03. Người dùng vừa đi hết một vòng
/// Reflection, quay sang khung chat nói "tôi vừa làm xong reflection này rồi",
/// và trợ lý vẫn mời họ ghi lại thành một Reflection. Rồi khi họ nói "bạn xem
/// thử reflection tôi vừa làm", trợ lý trả lời nó không có quyền đọc.
///
/// Cả hai câu đều sai, và sai theo cách làm hỏng niềm tin nhanh nhất: bảo một
/// người hãy làm việc họ vừa làm xong, rồi nói mình không thấy được thứ họ vừa
/// bỏ công viết. Với sản phẩm mà toàn bộ giá trị nằm ở chỗ "những gì bạn ghi lại
/// sẽ được nhìn thấy", đó là phủ nhận đúng lời hứa nền tảng.
///
/// Chữa ở tầng dữ liệu trước — nội dung lần nhìn lại giờ nằm ngay trong khối
/// trên — rồi mới tới lời dặn này cho phần model tự quyết.
const JUST_REFLECTED_RULE = `
Họ VỪA đi qua một lần nhìn lại trong vòng một ngày nay, và nội dung của lần đó
nằm ngay trong khối dữ liệu trên.

Vì vậy trong lượt này:
  • KHÔNG mời họ "ghi lại thành một Reflection" nữa, và KHÔNG đặt thẻ
    [[ACTION:reflect]]. Họ vừa làm xong việc đó. Mời lại là bảo họ làm hai lần
    cùng một việc, và cho thấy bạn không nhìn ra thứ họ vừa bỏ công viết.
  • Nếu họ bảo bạn xem lại lần nhìn lại vừa rồi, hãy XEM THẬT: nội dung ở trên
    chính là nó. TUYỆT ĐỐI KHÔNG nói "mình không có quyền truy cập" hay "mình chỉ
    dựa được vào những gì bạn chia sẻ trong cuộc trò chuyện này". Câu đó sai sự
    thật, vì bạn đang cầm chính những chữ họ đã viết.
  • Cách trả lời đúng: nhắc lại một chi tiết CỤ THỂ họ đã viết, để họ biết bạn
    đọc thật, rồi hỏi một câu mở về chính chi tiết đó.

Chỉ khi họ kể một chuyện MỚI, khác hẳn với lần nhìn lại ở trên, thì mới cân nhắc
mời ghi lại một lần nữa.`;

/// Cho người dùng Free: được xem tổng quan, KHÔNG được diễn giải sâu.
///
/// Mục 7 xếp "kết quả tổng quan (không diễn giải sâu) của SCA Self-Check" vào
/// TRỤC HÀNH ĐỘNG, tức Free có quyền. Nhưng "diễn giải sâu kết quả Self-Check"
/// lại nằm ở trục trí tuệ. Ranh giới đi ngay giữa một bảng điểm, nên phải nói
/// thật rõ đâu là đọc số và đâu là giải nghĩa số.
const SELF_CHECK_FREE_RULE = `Người này dùng gói miễn phí nên bạn ĐƯỢC đọc lại các con số trên và nói trục nào đang thấp nhất, đó là kết quả tổng quan họ có quyền xem. Nhưng KHÔNG được giải nghĩa sâu: không nối điểm số với tính cách hay thói quen của họ, không suy ra nguyên nhân vì sao trục đó thấp, không khuyên phải làm gì để nâng nó lên. Phần diễn giải đó thuộc gói Premium, nói rõ như vậy rồi mời họ xem thử.`;

/// Cho người dùng Premium: được diễn giải, vẫn ở thể điều kiện.
///
/// "Vẫn ở thể điều kiện" không phải câu khách sáo: mục 4.2 cấm chẩn đoán, và một
/// bảng điểm là thứ dễ kéo model sang giọng phán quyết nhất trong cả khối này.
const SELF_CHECK_PREMIUM_RULE = `Người này có gói Premium nên bạn ĐƯỢC diễn giải sâu kết quả trên: nối nó với những gì họ đã nhìn lại, chỉ ra điều kiện làm việc nào đang hỗ trợ hay cản trở họ. Giữ đúng thể điều kiện của mục 4.2, đây là quan sát về điều kiện công việc chứ không phải kết luận về con người họ, và hỏi lại xem họ thấy có đúng không. Bài này đo điều kiện làm việc, KHÔNG đo năng lực hay giá trị của họ.`;

/// Đổi điểm thành một cụm chữ đọc được.
///
/// Ngưỡng lấy nguyên từ `bandForScore` trong
/// `lib/core/logic/wr_self_check_narrative.dart` — cùng một bài, người dùng thấy
/// một nhãn trên màn hình kết quả rồi trợ lý gọi tên khác thì họ sẽ tưởng có hai
/// kết quả khác nhau.
///
/// Chữ mô tả ĐIỀU KIỆN LÀM VIỆC, không mô tả con người: "đang bị cản nhiều" nói
/// về hoàn cảnh, còn "bạn đang yếu ở khoản này" là một phán quyết mục 4.2 cấm.
function bandLabel(score: number): string {
  if (score >= 4.2) return 'đang khá thuận';
  if (score >= 3.5) return 'tạm ổn';
  if (score >= 2.8) return 'đang có vướng';
  return 'đang bị cản nhiều';
}

// ---------------------------------------------------------------------------

type Episode = {
  situation_code: string | null;
  human_need: string | null;
  opened_at: string | null;
};

/// Một lần nhìn lại KÈM những gì người dùng đã tự viết trong đó.
///
/// Tách khỏi [Episode] vì hai truy vấn khác nhau: [Episode] kéo về tới 400 dòng
/// để dựng mốc tháng nên chỉ được lấy ba cột, còn kiểu này chỉ lấy ba dòng nên
/// mới gánh nổi phần chữ.
type EpisodeDetail = {
  opened_at: string | null;
  state: string | null;
  energy: string | null;
  situation_code: string | null;
  intention: string | null;
  notes: Record<string, unknown> | null;
  draft_meaning: string | null;
  tiny_action: string | null;
  reflect_choice: string | null;
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

  // ── NỘI DUNG các lần nhìn lại gần nhất ─────────────────────────────────
  //
  // Trước bản này khối ngữ cảnh chỉ có NGÀY, MÃ TÌNH HUỐNG và SỐ ĐẾM — tức là
  // trợ lý biết người ta đã nhìn lại bao nhiêu lần, nhưng không biết một chữ nào
  // họ đã viết. Nên khi được hỏi thẳng "xem thử reflection tôi vừa làm", nó trả
  // lời đúng theo những gì nó có: "mình không có quyền truy cập nội dung".
  //
  // Câu đó đọc như một giới hạn về quyền, nhưng thật ra là một khoảng trống
  // trong ngữ cảnh. Dữ liệu vẫn nằm đó, chỉ là chưa ai đưa cho nó.
  //
  // KHÔNG gác theo gói. Mục 7 xếp "tự xem dữ liệu thô của chính mình" vào TRỤC
  // HÀNH ĐỘNG, tức quyền của cả người dùng miễn phí. Thứ thuộc Premium là phần
  // TỔNG HỢP qua thời gian, và phần đó vẫn gác nguyên ở khối mốc tháng bên dưới.
  let latestFinishedAt: string | null = null;
  try {
    const { data } = await db
      .from('wr_reflection_episodes')
      .select(
        'opened_at, state, energy, situation_code, intention, notes, '
          + 'draft_meaning, tiny_action, reflect_choice',
      )
      .eq('user_id', userId)
      .order('opened_at', { ascending: false })
      .limit(DETAIL_EPISODE_COUNT);

    const details = (data ?? []) as unknown as EpisodeDetail[];
    const titles = await resolveTitles(
      db,
      details.map((d) => d.situation_code).filter((c): c is string => !!c),
    );

    const blocks = details
      .map((d) => describeEpisode(d, titles))
      .filter((b): b is string => b !== null);

    if (blocks.length > 0) {
      lines.push(
        'Nội dung những lần nhìn lại gần nhất của họ, chính chữ họ tự viết:',
      );
      lines.push(...blocks);
    }

    // Mốc cho [JUST_REFLECTED_RULE]. Chỉ tính lần đã ĐI HẾT vòng: một phiên mở
    // ra rồi bỏ giữa chừng không phải là "vừa làm xong", và mời người đó quay
    // lại hoàn thành nốt mới là việc đúng.
    for (const d of details) {
      if (d.opened_at && FINISHED_STATES.has(String(d.state ?? ''))) {
        latestFinishedAt = d.opened_at;
        break;
      }
    }
  } catch (_) { /* mất phần này thì phần dưới vẫn dựng được */ }

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
  //
  // HAI BẢNG, không phải một. Bản đầu chỉ đọc `wr_insights`, là bảng của luồng
  // cũ. Luồng Reflection v2.0 ghi điều người dùng xác nhận vào
  // `wr_reflection_insights` (xem `insertInsight` trong
  // `lib/core/data/wr_intelligence_repository.dart`), nên toàn bộ phần chắt lọc
  // nhất của những lần nhìn lại gần đây chưa bao giờ tới được trợ lý.
  //
  // Đọc cả hai và trộn theo thời gian. Bỏ bảng cũ đi thì mất dữ liệu của người
  // đã dùng app từ trước; giữ mỗi bảng cũ thì đúng lỗi đang chữa.
  try {
    const [fresh, legacy] = await Promise.all([
      db
        .from('wr_reflection_insights')
        .select('content, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(2),
      db
        .from('wr_insights')
        .select('content, saved_at')
        .eq('user_id', userId)
        .order('saved_at', { ascending: false })
        .limit(2),
    ]);

    const merged = [
      ...(fresh.data ?? []).map((r) => ({
        content: r.content,
        at: r.created_at as string | null,
      })),
      ...(legacy.data ?? []).map((r) => ({
        content: r.content,
        at: r.saved_at as string | null,
      })),
    ]
      .filter((r) => String(r.content ?? '').trim())
      .sort((a, b) => (b.at ?? '').localeCompare(a.at ?? ''))
      .slice(0, 2);

    for (const row of merged) {
      lines.push(
        `Điều họ tự rút ra (${formatDate(row.at)}): `
          + `"${truncate(String(row.content).trim(), 300)}"`,
      );
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
  // Trước 2026-08-03 ở đây chỉ đưa NGÀY làm bài, vì sợ điểm rò sang gói miễn
  // phí. Sai hai đường: mục 7 cho người Free xem "kết quả tổng quan, không diễn
  // giải sâu" nên giấu hết là thiếu quyền của họ, còn Premium thì chẳng còn gì
  // để diễn giải sâu. Từ khi ranh giới gác ở tầng dữ liệu, nỗi lo cũ hết hiệu
  // lực: hai gói nhận hai khối khác nhau ngay từ đầu.
  //
  // ⚠ KHÔNG BAO GIỜ đưa tên ba cột (`structure/culture/activity`) vào đây. Ghép
  // lại đúng là cụm "Structure Culture Activity" mà mục 6 cấm tuyệt đối. Dùng
  // tên tiếng Việt app đang hiện trên màn hình, xem `SelfCheckPillar.displayName`
  // trong `lib/core/logic/wr_self_check_questions.dart`.
  try {
    const { data } = await db
      .from('wr_sca_self_check_responses')
      .select('structure_score, culture_score, activity_score, taken_at')
      .eq('user_id', userId)
      .order('taken_at', { ascending: false })
      .limit(1);
    const row = data?.[0];
    if (row?.taken_at) {
      const pillars: [string, unknown][] = [
        ['Sự rõ ràng', row.structure_score],
        ['Mối quan hệ', row.culture_score],
        ['Cách làm việc', row.activity_score],
      ];
      // Lọc null TRƯỚC khi ép kiểu. `Number(null)` cho ra 0 chứ không phải NaN,
      // nên một bản ghi chưa tính được điểm sẽ lọt qua thành "0.0 trên 5, đang
      // bị cản nhiều" — một kết quả thảm hại hoàn toàn bịa, đọc lên cho đúng
      // người vừa làm bài. Test bắt được trước khi lên bản chạy.
      const scored = pillars
        .filter(([, v]) => v !== null && v !== undefined && v !== '')
        .map(([name, v]) => [name, Number(v)] as [string, number])
        .filter(([, v]) => Number.isFinite(v));

      if (scored.length === 0) {
        // Có bản ghi nhưng chưa tính được điểm. Vẫn phải NÓI RA là không có,
        // đừng bỏ trống: model thấy tên một bài mà không thấy nội dung thì nó
        // tự điền, lấy từ phần dữ liệu khác ở gần đó. Đúng lỗi bịa mẫu hình mà
        // [NO_DATA_RULE] sinh ra để chặn, chỉ là ở một trường khác.
        lines.push(
          `Họ đã làm bài tự đánh giá ngắn, lần gần nhất ${formatDate(row.taken_at)}. `
            + `Bạn KHÔNG có kết quả của bài đó. Nếu họ hỏi bài đó nói gì về họ, nói `
            + `thật là bạn không xem được kết quả ở đây và mời họ mở trong app. `
            + `Tuyệt đối không đoán kết quả từ các dữ liệu khác ở trên.`,
        );
      } else {
        lines.push(
          `Bài tự đánh giá ngắn, làm gần nhất ${formatDate(row.taken_at)}, thang điểm 1 đến 5:`,
        );
        for (const [name, v] of scored) {
          lines.push(`  • ${name}: ${v.toFixed(1)} trên 5 (${bandLabel(v)})`);
        }
        const lowest = scored.slice().sort((a, b) => a[1] - b[1])[0];
        lines.push(`Trục thấp nhất của họ hiện là "${lowest[0]}".`);
        lines.push(isPremium ? SELF_CHECK_PREMIUM_RULE : SELF_CHECK_FREE_RULE);
      }
    }
  } catch (_) { /* bỏ qua */ }

  // ── Cơ hội phát triển ──────────────────────────────────────────────────
  //
  // CHỈ PREMIUM. Mục 3 nói thẳng đây là gợi ý "chỉ dành cho Premium", và mục 7
  // xếp Cơ hội phát triển vào trục trí tuệ.
  //
  // ⚠ `suggestion_text` và `confidence_note` KHÔNG ĐƯỢC TÁCH RỜI. Ràng buộc
  // NOT NULL trên hai cột đó (migration 20260728000003) là để không thể tạo ra
  // một gợi ý thiếu ghi chú độ chính xác ngay từ tầng dữ liệu. Đưa mỗi câu gợi ý
  // vào đây rồi để model đọc trần ra là phá đúng ràng buộc ấy ở tầng cuối cùng,
  // nơi không còn hàng rào nào phía sau.
  if (isPremium) {
    try {
      const { data } = await db
        .from('wr_growth_opportunities')
        .select('suggestion_text, confidence_note, generated_at')
        .eq('user_id', userId)
        .order('generated_at', { ascending: false })
        .limit(1);
      const row = data?.[0];
      const suggestion = String(row?.suggestion_text ?? '').trim();
      const note = String(row?.confidence_note ?? '').trim();
      // Thiếu một trong hai thì BỎ HẲN. Nửa cặp còn lại không dùng được: gợi ý
      // trần là một lời khuyên chắc nịch mà mục 4.2 cấm, còn ghi chú trần thì
      // chẳng nói về điều gì.
      if (suggestion && note) {
        lines.push(
          `Hướng phát triển hệ thống đã tổng hợp cho họ (${formatDate(row?.generated_at ?? null)}): `
            + `"${truncate(suggestion, 400)}"`,
        );
        lines.push(
          `Ghi chú độ chính xác đi kèm gợi ý đó: "${truncate(note, 300)}". `
            + `Nếu bạn nhắc tới gợi ý trên, PHẢI nói kèm ý của ghi chú này trong `
            + `cùng lượt trả lời, không được tách rời. Gợi ý này luôn ở thể điều `
            + `kiện, là một hướng đáng cân nhắc chứ không phải kết luận về họ.`,
        );
      }
    } catch (_) { /* bỏ qua */ }
  }

  // ── Hồ sơ công việc đã tải lên ─────────────────────────────────────────
  //
  // Từ 2026-08-04, Edge Function `wr-doc-analyze` đọc JD/CV bằng model nhìn
  // được hình và lưu chữ đã trích vào `extracted_text` + bản phân tích có cấu
  // trúc vào `analysis`. Nên ở đây có hai nhánh KHÁC HẲN nhau, và phải tách
  // rạch ròi:
  //
  //   • Tài liệu đã phân tích xong → đưa nội dung thật cho model đọc.
  //   • Tài liệu chưa phân tích (đang chờ, hoặc hỏng) → nói thẳng là chưa đọc
  //     được, y như trước.
  //
  // Không được nhập nhèm hai nhánh. Nếu chỉ nói "họ có tải JD lên" mà không
  // kèm nội dung, model sẽ rơi lại đúng lỗi đã bắt hai lần: thấy một cái tên
  // không kèm nội dung thì tự điền nội dung từ dữ liệu khác ở gần đó. Với JD/CV
  // thì kiểu bịa đó đặc biệt tệ, vì người dùng tin rằng trợ lý đang đọc hồ sơ
  // thật của họ.
  if (isPremium) {
    try {
      const { data } = await db
        .from('wr_context_documents')
        .select('doc_type, analysis_status, extracted_text, analysis, analyzed_at')
        .eq('user_id', userId)
        .order('uploaded_at', { ascending: false })
        .limit(5);
      const rows = data ?? [];

      const docName = (t: unknown) => {
        const s = String(t ?? '').toLowerCase();
        return s === 'jd' ? 'mô tả công việc' : s === 'cv' ? 'hồ sơ năng lực' : 'tài liệu công việc';
      };

      // ── Nhánh 1: đã đọc được ──────────────────────────────────────────
      const ready = rows.filter((d) => String(d.analysis_status ?? '') === 'ready');
      for (const d of ready.slice(0, 2)) {
        const a = (d.analysis ?? {}) as Record<string, unknown>;
        const name = docName(d.doc_type);
        const parts: string[] = [];

        const title = String(a.title ?? '').trim();
        const org = String(a.organization ?? '').trim();
        if (title) parts.push(`chức danh: ${title}`);
        if (org) parts.push(`nơi làm việc: ${org}`);

        const summary = String(a.summary ?? '').trim();
        if (summary) parts.push(`tóm tắt: ${truncate(summary, 400)}`);

        const listOf = (key: string, label: string, max: number) => {
          const arr = Array.isArray(a[key]) ? (a[key] as unknown[]) : [];
          const items = arr
            .map((x) => String(x ?? '').trim())
            .filter(Boolean)
            .slice(0, max);
          if (items.length > 0) parts.push(`${label}: ${items.join('; ')}`);
        };
        listOf('responsibilities', 'trách nhiệm chính', 6);
        listOf('requirements', 'yêu cầu', 6);
        listOf('skills', 'kỹ năng được nêu', 8);

        if (parts.length > 0) {
          lines.push(
            `${name.charAt(0).toUpperCase() + name.slice(1)} họ đã tải lên `
              + `(đọc ngày ${formatDate(d.analyzed_at ?? null)}) — ${parts.join(' · ')}.`,
          );
        }

        // Chữ nguyên văn, cắt ngắn. Có bản tóm tắt rồi vẫn cần đoạn này: người
        // dùng hay hỏi về một dòng cụ thể trong JD ("chỗ này nói gì"), mà bản
        // tóm tắt thì không giữ được câu chữ của họ.
        const rawText = String(d.extracted_text ?? '').trim();
        if (rawText) {
          lines.push(
            `Trích nguyên văn từ ${name} đó: "${truncate(rawText, 1500)}". `
              + `Đây là chữ đọc được từ chính tài liệu của họ, bạn được phép nhắc `
              + `lại và bàn về nó. Nhưng CHỈ những gì có trong đoạn trên — không `
              + `suy ra thêm phần tài liệu bị cắt, không đoán mức lương, tên công `
              + `ty hay kinh nghiệm nếu chúng không xuất hiện ở đây.`,
          );
        }
      }

      // ── Nhánh 2: chưa đọc được ────────────────────────────────────────
      const pending = rows.filter((d) => {
        const s = String(d.analysis_status ?? '');
        return s !== 'ready';
      });
      if (pending.length > 0) {
        const names = [...new Set(pending.map((d) => docName(d.doc_type)))].join(' và ');
        const failed = pending.some((d) => String(d.analysis_status ?? '') === 'failed');
        lines.push(
          `Họ có tải lên ${names} nhưng bản đó ${
            failed ? 'chưa đọc được' : 'đang được đọc, chưa xong'
          }. Bạn KHÔNG biết nội dung của nó. Nếu họ hỏi, nói thật là bạn chưa xem `
            + `được và mời họ kể điều quan trọng nhất trong đó. Tuyệt đối không đoán `
            + `nội dung, không suy ra chức danh, kỹ năng hay kinh nghiệm của họ từ `
            + `bất kỳ dữ liệu nào khác ở trên.`,
        );
      }
    } catch (_) { /* bỏ qua */ }
  }

  // ── Ghép ───────────────────────────────────────────────────────────────
  if (lines.length === 0) return NO_DATA_RULE;

  return `

---

DỮ LIỆU THẬT VỀ NGƯỜI ĐANG NÓI CHUYỆN VỚI BẠN

Phần dưới đây lấy từ chính những gì họ đã ghi lại trong app. Đây là dữ liệu thật,
khác với các ví dụ minh hoạ ở tài liệu phía trên.

${lines.join('\n')}
${HAS_DATA_RULE}${isPremium ? TIME_COMPARISON_RULE : FREE_GATE_RULE}${
    isJustReflected(latestFinishedAt) ? JUST_REFLECTED_RULE : ''
  }`;
}

// ---------------------------------------------------------------------------

/// Dựng một lần nhìn lại thành mấy dòng chữ đọc được. Null nếu rỗng ruột.
///
/// Trả null khi người dùng chưa viết chữ nào — mở luồng rồi thoát ngay chẳng
/// hạn. Một mục chỉ có ngày tháng mà không có nội dung là đúng cái bẫy đã sập ba
/// lần trong file này: model thấy một cái tên không kèm nội dung thì nó tự điền.
///
/// ⚠ Chỉ ghép TIÊU ĐỀ tiếng Việt của tình huống. Mã như "C2-sit-01" nằm trong
/// danh sách cấm ở mục 6; tra không ra tiêu đề thì bỏ hẳn dòng đó.
export function describeEpisode(
  d: EpisodeDetail,
  titles: Map<string, string>,
): string | null {
  const parts: string[] = [];

  const title = d.situation_code ? titles.get(d.situation_code) : null;
  if (title) parts.push(`  tình huống họ chọn: "${title}"`);

  const energy = ENERGY_LABELS[String(d.energy ?? '')];
  if (energy) parts.push(`  lúc đó họ ${energy}`);

  const intention = String(d.intention ?? '').trim();
  if (intention) {
    parts.push(`  điều họ muốn nhìn rõ hơn: "${truncate(intention, NOTE_MAX)}"`);
  }

  // `notes` là jsonb: thứ tự khoá do database quyết, nên phải tự sắp lại theo
  // đúng thứ tự người dùng đã đi qua.
  const notes = (d.notes ?? {}) as Record<string, unknown>;
  for (const key of NOTE_ORDER) {
    const label = NOTE_LABELS[key];
    const value = String(notes[key] ?? '').trim();
    if (label && value) {
      parts.push(`  ${label}: "${truncate(value, NOTE_MAX)}"`);
    }
  }

  const meaning = String(d.draft_meaning ?? '').trim();
  if (meaning) {
    parts.push(`  điều họ rút ra: "${truncate(meaning, NOTE_MAX)}"`);
  }

  const action = String(d.tiny_action ?? '').trim();
  if (action) {
    parts.push(`  việc nhỏ họ nhận sẽ làm: "${truncate(action, NOTE_MAX)}"`);
  }

  // `reflect_choice` chỉ ghép khi KHÁC `tiny_action`. Hai trường này trùng nhau
  // ở phần lớn trường hợp, và lặp lại cùng một câu hai lần trong ngữ cảnh khiến
  // model tưởng đó là hai việc riêng biệt.
  const choice = String(d.reflect_choice ?? '').trim();
  if (choice && choice !== action) {
    parts.push(`  câu họ chọn từ các gợi ý: "${truncate(choice, NOTE_MAX)}"`);
  }

  if (parts.length === 0) return null;

  const when = formatDate(d.opened_at);
  const done = FINISHED_STATES.has(String(d.state ?? ''))
    ? 'đã đi hết vòng'
    : 'còn dở, chưa đi hết vòng';
  return [`• Lần nhìn lại ngày ${when} (${done}):`, ...parts].join('\n');
}

/// Lần nhìn lại đã xong có nằm trong [JUST_REFLECTED_HOURS] giờ vừa qua không.
export function isJustReflected(
  iso: string | null,
  now: Date = new Date(),
): boolean {
  if (!iso) return false;
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return false;
  // Chặn cả mốc ở TƯƠNG LAI. Lệch giờ máy người dùng có thể đẩy `opened_at` lên
  // trước hiện tại vài phút, và một hiệu số âm vẫn nhỏ hơn ngưỡng nên sẽ lọt
  // qua như thể vừa xảy ra — đúng thì cũng may rủi, nên chặn cho tường minh.
  const hours = (now.getTime() - t) / 3_600_000;
  return hours >= 0 && hours <= JUST_REFLECTED_HOURS;
}

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

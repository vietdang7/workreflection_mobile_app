// Luồng Reflect 5 bước — Kiến trúc Dữ liệu v2.0 §V, bảng "ánh xạ Domain vào UI
// thật", đối chiếu trực tiếp `WorkReflection_Sprint2_Mockup (2).html`
// §screenReflectFlow.
//
// Pure Dart, không phụ thuộc Flutter.
//
// ---------------------------------------------------------------------------
// Vì sao có file này (lỗi đang chữa, 2026-07-31)
// ---------------------------------------------------------------------------
//
// §V quy định bước ĐẦU TIÊN của mọi phiên là CHẠM một trong năm chip tình huống
// (đã lọc theo cảm xúc check-in), hoặc "Điều khác" để tự mô tả. Chỉ nhánh "Điều
// khác" mới phải viết. Đó là chỗ duy nhất `situation_code` được ghi, và
// `situation_code` là nguyên liệu của TẤT CẢ phần thống kê phía sau:
//
//   recentSituationIds → Tình huống lặp lại · Nhu cầu chủ đạo (§4.3)
//                      → chiều SCA hoạt động nhiều nhất  (§XIII)
//                      → gợi ý Practice Theme ở tab Phát triển
//
// Bản trước bản này đi lệch ở hai chỗ, và cả hai đều làm mất `situation_code`:
//
//   1. Sau check-in, app chèn thêm một màn "Chọn khoảnh khắc" (6 Human Moment
//      Archetype của HXA §2.5) rồi mới vào chuỗi câu hỏi. §V và §9.1 không có
//      màn này: "Home dẫn thẳng vào luồng 5 bước ngay sau khi người dùng chạm
//      chọn cảm xúc check-in".
//
//   2. Bước đầu của chuỗi là Pattern `notice` — MỘT Ô CHỮ TRỐNG. Chip tình
//      huống bị đẩy xuống Pattern `name`, mà `name` chỉ có trong 4 trên 6
//      archetype: `growth` và `recovery` KHÔNG có bước đó. Ai chọn "mệt mỏi"
//      hoặc "muốn tiến bộ" thì đi hết phiên mà không bao giờ được đưa ra một
//      lựa chọn nào — viết tay từ đầu tới cuối, và Episode khép lại với
//      `situation_code = NULL`.
//
// Hệ quả đo được trên DB thật: 10 trên 16 Episode có `situation_code = NULL`,
// nên "Tình huống lặp lại" trống trơn dù người dùng đã phản tư 16 lần.
//
// HumanMoment KHÔNG bị bỏ — HXA §2.5 gọi nó là "bộ từ vựng nền tảng", không
// phải một màn hình. Nó được suy ra từ cảm xúc check-in ở [momentForMood] và
// vẫn ghi xuống `wr_reflection_episodes.human_moment` như cũ.

import '../models/checkin.dart';
import '../models/wr_content.dart';
import '../models/wr_episode.dart';

// ---------------------------------------------------------------------------
// Năm bước của §V
// ---------------------------------------------------------------------------

/// Số bước của luồng, dùng cho thanh tiến trình.
///
/// Cố định 5 cho MỌI phiên (§V). Khác hẳn bản trước: chuỗi Pattern dài ngắn tuỳ
/// archetype (3 tới 5 bước), nên hai người cùng đi hết một phiên lại thấy hai
/// thanh tiến trình khác nhau.
const int kReflectStepCount = 5;

/// Tiến trình của bước thứ [step] (0-based), theo đúng công thức của mockup:
/// `Math.round(((i+1)/5)*100)`.
double reflectProgress(int step) => (step + 1) / kReflectStepCount;

/// Hai bước duy nhất ghi chữ của người dùng vào `notes` trong luồng §V.
///
///   notice  → nhãn tình huống đã chạm (hoặc câu tự mô tả ở nhánh "Điều khác")
///   explore → "chi tiết cụ thể" không bắt buộc ở bước Ý nghĩa
///
/// Cố định ở đây thay vì đọc `patternSequences[moment]`: hai archetype `arrival`
/// và `celebration` không có `explore` trong chuỗi của chúng, nên đọc theo
/// archetype sẽ NUỐT MẤT phần chi tiết người dùng vừa viết khi họ check-in
/// "khá ổn" hoặc "đang vui".
const List<ReflectionPattern> kReflectCapturePatterns = [
  ReflectionPattern.notice,
  ReflectionPattern.explore,
];

// ---------------------------------------------------------------------------
// Cảm xúc check-in → Human Moment Archetype
// ---------------------------------------------------------------------------

/// Archetype ứng với cảm xúc vừa chạm ở lưới check-in (HXA §2.5).
///
/// Bốn ô check-in của §V khớp gần như một-một với bốn trong sáu archetype:
///
///   căng thẳng → Confusion   "có điều gì đó không ổn, chưa gọi tên được"
///   mệt mỏi    → Recovery    "vừa trải qua điều mất năng lượng"
///   khá ổn     → Arrival     "dừng lại check-in, không cần có vấn đề lớn"
///   đang vui   → Celebration "vừa làm được điều đáng tự hào"
///
/// Hai archetype còn lại (Decision, Growth) không có lối vào từ Home, đúng §9.1:
/// Home chỉ có bốn ô cảm xúc. Chúng vẫn sống trong model, dùng cho phiên mở lại
/// và cho lối vào qua màn năng lượng.
HumanMoment momentForMood(Mood mood) => switch (mood) {
      Mood.stressed => HumanMoment.confusion,
      Mood.tired => HumanMoment.recovery,
      Mood.okay => HumanMoment.arrival,
      Mood.happy => HumanMoment.celebration,
    };

// ---------------------------------------------------------------------------
// Bước 0 — Notice
// ---------------------------------------------------------------------------

/// Câu hỏi của bước chọn tình huống, nguyên văn mockup §screenReflectFlow i===0.
///
/// Ngôi "tôi" chứ không phải "bạn" — §9.2: nội dung Situation là tiếng nói nội
/// tâm của chính người dùng.
const String kNoticePrompt = 'Điều gì gần giống với hôm nay của tôi nhất?';

/// Nhãn của mục "Điều khác", nguyên văn mockup (`SITUATIONS` id `other`).
const String kOtherSituationLabel = 'Điều khác, để tôi tự mô tả';

/// Nhãn nhỏ trên ô neo ở bước Notice — điều gần nhất người dùng đã chọn trong
/// cụm cảm xúc này. Xem `anchorSituation` để hiểu vì sao ô này phải luôn có.
const String kAnchorBadge = 'Lần trước';

/// Nhãn cảm xúc check-in ở dạng một dòng, để ghép vào câu văn.
///
/// Lưới check-in ở Home giữ một bản sinh đôi có ngắt dòng (`kCheckinOptions`),
/// vì bốn ô vuông cần chữ xuống dòng đúng chỗ. Ở đây phải là một dòng liền:
/// nhãn này nằm GIỮA một câu, không đứng riêng trong một ô.
String moodCheckinLabel(Mood mood) => switch (mood) {
      Mood.stressed => 'Tôi đang căng thẳng',
      Mood.tired => 'Tôi mệt mỏi cần nghỉ ngơi',
      Mood.okay => 'Tôi khá ổn',
      Mood.happy => 'Tôi đang vui',
    };

/// Dòng phụ dưới câu hỏi bước Notice.
///
/// Nói rõ vì sao năm chip này lại là năm chip này — nếu không, danh sách trông
/// như bốc ngẫu nhiên và người dùng không hiểu tại sao mình không thấy điều
/// mình đang gặp.
String noticeSubtitle(String? moodLabel) {
  if (moodLabel == null || moodLabel.isEmpty) {
    return 'Chọn điều gần đúng nhất, không cần hoàn hảo.';
  }
  return 'Những tình huống dưới đây thường xuất hiện khi ai đó chọn '
      '"$moodLabel".';
}

// ---------------------------------------------------------------------------
// Bước 1 — Meaning
// ---------------------------------------------------------------------------

/// Câu hỏi bước Ý nghĩa cho nhánh "Điều khác" (mockup i===1, `s.custom`).
const String kCustomDetailPrompt = 'Chuyện gì cụ thể đã xảy ra?';

/// Câu hỏi bước Ý nghĩa: câu Reflection của tình huống đã chọn.
///
/// [reflectionQuestion] null nghĩa là nhánh "Điều khác" hoặc thư viện chưa nối
/// được sang story — cả hai đều lùi về câu hỏi chung, KHÔNG bịa một câu riêng.
String detailPrompt(String? reflectionQuestion) {
  final q = reflectionQuestion?.trim();
  return (q == null || q.isEmpty) ? kCustomDetailPrompt : q;
}

/// Dòng phụ nói rõ bước này bỏ trống được (§V: "viết chi tiết cụ thể, không bắt
/// buộc"). Thiếu câu này thì ô chữ trông như một câu hỏi bắt buộc trả lời.
const String kDetailOptionalNote =
    'Một câu ngắn cũng được. Bỏ trống cũng không sao.';

// ---------------------------------------------------------------------------
// Bước 2 — Insight
// ---------------------------------------------------------------------------

/// Câu Aha mặc định cho nhánh "Điều khác", nguyên văn mockup.
///
/// §V: "Aha dùng câu mặc định cố định thay vì theo tình huống". Có một câu cố
/// định là có chủ đích — bước Insight của mockup luôn mở bằng một câu đã viết
/// sẵn để người dùng sửa, không bao giờ mở bằng ô trống.
const String kDefaultAha =
    'Dừng lại để gọi tên một trải nghiệm cụ thể đã là bước phản chiếu quan '
    'trọng nhất, dù tôi chưa chắc chắn về ý nghĩa của nó.';

/// Câu Aha để điền sẵn ở bước Insight.
///
/// Ưu tiên câu của chính tình huống; không có thì dùng câu mặc định. Không bao
/// giờ trả chuỗi rỗng: ô trống ở bước này là quay lại đúng lỗi đang chữa.
String ahaFor(String? situationAha) {
  final aha = situationAha?.trim();
  return (aha == null || aha.isEmpty) ? kDefaultAha : aha;
}

// ---------------------------------------------------------------------------
// Nhãn tình huống để ghi vào `notes`
// ---------------------------------------------------------------------------

/// Chữ được ghi vào `notes['notice']` cho bước 0.
///
/// Chạm chip thì ghi đúng nhãn chip; nhánh "Điều khác" chưa có gì để ghi ở bước
/// này (câu tự mô tả nằm ở bước 1), nên trả null.
String? noticeNoteFor(WrSituation? situation) => situation?.text;

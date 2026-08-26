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
/// Hai cảm xúc thêm 24/08/2026 cùng rơi vào Confusion:
///
///   mơ hồ      → Confusion   "chưa rõ phạm vi, chưa biết ai quyết định"
///   lệch nhau  → Confusion   "biết tin sau cùng, nhịp phối hợp không khớp"
///
/// Cả hai đúng nguyên văn định nghĩa Confusion của HXA §2.5 — "có điều gì đó
/// không ổn, chưa gọi tên được". Chúng KHÔNG bị trộn làm một: phần phân biệt
/// nằm ở cụm chiều (S1 với S2 ở [kMoodDimensions]), tức ở chính danh sách tình
/// huống người dùng nhìn thấy, chứ không ở nhãn archetype.
///
/// Hai archetype còn lại (Decision, Growth) không có lối vào từ Home, đúng §9.1.
/// Chúng vẫn sống trong model, dùng cho phiên mở lại và cho lối vào qua màn
/// năng lượng.
HumanMoment momentForMood(Mood mood) => switch (mood) {
      Mood.stressed => HumanMoment.confusion,
      Mood.tired => HumanMoment.recovery,
      Mood.foggy => HumanMoment.confusion,
      Mood.outofsync => HumanMoment.confusion,
      Mood.okay => HumanMoment.arrival,
      Mood.happy => HumanMoment.celebration,
    };

// ---------------------------------------------------------------------------
// Bước 0 — Notice
// ---------------------------------------------------------------------------

/// Câu hỏi của bước chọn tình huống, nguyên văn mockup v16
/// §screenReflectFlow i===0.
///
/// Ngôi "BẠN" từ 24/08/2026 (changelog §1.3). Trước đó là "…hôm nay của tôi
/// nhất?" theo §9.2, với lý do nội dung Situation là tiếng nói nội tâm của
/// chính người dùng. Khách đảo lại lập luận đó: đây là một CÂU HỎI app đặt ra,
/// không phải một câu người dùng tự nói — để ngôi "tôi" thì người dùng đang tự
/// độc thoại, còn ngôi "bạn" mới ra một cuộc trò chuyện.
///
/// Ranh giới mới nằm ở chỗ khác: câu HỎI dùng "bạn", còn giọng KỂ (story, aha,
/// nhãn "Điều khác") vẫn giữ "tôi" — xem [kOtherSituationLabel].
const String kNoticePrompt = 'Điều gì gần giống với ngày hôm nay của bạn nhất?';

/// Nhãn của mục "Điều khác", nguyên văn mockup v16 (`SITUATIONS` id `other`).
///
/// GIỮ ngôi "tôi" dù §1.3 đã đổi mọi câu hỏi sang "bạn": đây không phải câu hỏi
/// mà là một lựa chọn người dùng tự nói ra. Mockup v16 cũng giữ nguyên chuỗi
/// này sau khi đã đổi ngôi toàn bộ phần còn lại.
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
      Mood.foggy => 'Tôi thấy mơ hồ',
      Mood.outofsync => 'Tôi thấy mọi thứ lệch nhau',
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

/// Đoạn giải thích đặt NGAY DƯỚI nhãn bước, TRƯỚC khi vào câu chuyện.
///
/// Changelog §1.1: người dùng cần hiểu đây là tình huống nhiều người khác cũng
/// từng gặp, và hiểu vai trò của bước này trong luồng phản chiếu. Không có đoạn
/// này thì màn mở thẳng bằng một câu chuyện lạ, không rõ của ai và để làm gì.
const String kFamiliarStoryIntro =
    'Đây là tình huống mà nhiều người ở vị trí tương tự cũng từng gặp, không '
    'chỉ riêng bạn. Đọc thử, nếu thấy quen thì đây sẽ là điểm bắt đầu để cùng '
    'nhìn sâu hơn ở các bước tiếp theo.';

/// Lời mời viết, đặt dưới câu Reflection ở nhánh CÓ tình huống.
///
/// Changelog §1.1 viết lại đoạn này và bỏ hẳn cụm "Không bắt buộc" — nó "mang
/// giọng cấp phép/biểu mẫu". Gợi ý cụ thể "ai, khi nào, chuyện gì" vẫn còn
/// nguyên nhưng nằm trong câu văn, không liệt kê như checklist.
///
/// §V "không bắt buộc" nói bằng hành vi — nút "Tiếp tục" không bao giờ bị khoá
/// dù ô chữ trống (xem `wr_detail_screen`).
///
/// Vế cuối "Có thể bỏ trống cũng không sao" thêm ở họp 26_1. Changelog §1.1 đã
/// bỏ cụm "Không bắt buộc" vì giọng cấp phép/biểu mẫu, và khách vẫn giữ nguyên
/// ý đó — nhưng lời mời có điều kiện thôi thì chưa đủ: người dùng đọc xong vẫn
/// không chắc bỏ trống có đi tiếp được không, nên ngồi cố nghĩ ra một câu.
/// "Có thể bỏ trống cũng không sao" là nguyên văn khách đọc trong họp.
const String kStoryDetailInvite =
    'Nếu điều này giống với chuyện của bạn, hãy kể lại khoảnh khắc đó theo '
    'cách của riêng bạn. Có thể bắt đầu từ lúc nào, với ai, chuyện gì đã xảy '
    'ra. Có thể bỏ trống cũng không sao.';

/// Dòng phụ của nhánh "Điều khác", nguyên văn mockup v16 i===1 `s.custom`.
///
/// Nhánh này không có câu chuyện nào để đối chiếu nên vẫn cần nói thẳng bắt đầu
/// từ đâu.
const String kCustomDetailNote =
    'Không cần đầy đủ, chỉ cần bắt đầu từ: ai, khi nào, và chuyện gì đã xảy ra.';

/// Gợi ý trong ô chữ ở nhánh CÓ tình huống.
///
/// Changelog §1.1: đổi từ gợi ý chung chung sang ví dụ có cấu trúc thời gian –
/// nhân vật – sự kiện. Ba dấu chấm lửng là chủ đích: chúng để trống đúng ba chỗ
/// người viết cần điền.
const String kStoryDetailHint = 'Ví dụ: Sáng nay, trong cuộc họp với..., lúc...';

/// Gợi ý trong ô chữ ở nhánh "Điều khác" — dài hơn vì không có câu chuyện nào
/// đứng trước làm mẫu.
const String kCustomDetailHint =
    'Ví dụ: Sáng nay, trong cuộc họp với anh Nam, lúc mình vừa nêu ý kiến thì...';

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

/// Câu Aha của bước Insight.
///
/// Ưu tiên câu của chính tình huống; không có thì dùng câu mặc định. Không bao
/// giờ trả chuỗi rỗng: từ 24/08 câu này là toàn bộ nội dung của Lớp 2, rỗng thì
/// lớp đó thành một thẻ trắng.
String ahaFor(String? situationAha) {
  final aha = situationAha?.trim();
  return (aha == null || aha.isEmpty) ? kDefaultAha : aha;
}

// ---------------------------------------------------------------------------
// Bước 2 — Insight, HAI LỚP (changelog 24/08/2026 §1.2)
// ---------------------------------------------------------------------------
//
// Trước đây: hệ thống đưa sẵn câu "aha" ở ngôi thứ nhất, người dùng chỉ có thể
// chấp nhận hoặc chỉnh sửa lại. Nghĩa là câu trả lời có mặt TRƯỚC câu hỏi, và
// phần lớn người dùng bấm qua.
//
// Từ 24/08 bước này chia hai lớp trong cùng một bước:
//
//   Lớp 1 — mời người dùng tự hoàn thành câu mở dở "Với tôi, điều này xảy ra
//           vì…". Có lối thoát "Chưa muốn viết, bỏ qua bước này".
//   Lớp 2 — sau khi viết (hoặc bỏ qua) MỚI hiện câu aha, và đổi khung hiển thị
//           từ trích dẫn ngôi "tôi" sang "Nhiều người khác cũng từng thấy điều
//           này".
//
// Chỗ đắt giá là THỨ TỰ, không phải câu chữ: cùng một câu aha, đặt trước thì nó
// là đáp án cho sẵn, đặt sau thì nó là một góc nhìn để đối chiếu với điều người
// dùng vừa tự nghĩ ra.

/// Nhãn bước ở Lớp 1 — chính là vế đầu của câu mở dở.
const String kInsightStemEyebrow = 'Với tôi, điều này...';

/// Nhãn bước ở Lớp 2.
const String kInsightAhaEyebrow = 'Một góc nhìn khác';

/// Vế đầu của câu mở dở. Người dùng viết tiếp phần sau chữ "vì".
const String kInsightStemPrefix = 'Với tôi, điều này xảy ra vì';

/// Câu mở dở hiển thị nguyên vẹn (có dấu ba chấm) ở Lớp 1.
const String kInsightStemPrompt = '$kInsightStemPrefix...';

/// Dòng phụ ở Lớp 1 — nói rõ không có đáp án đúng, để ô chữ không đọc ra như
/// một bài kiểm tra.
const String kInsightStemNote =
    'Không có câu trả lời đúng, chỉ cần viết điều bạn đang thực sự nghĩ.';

/// Gợi ý trong ô chữ ở Lớp 1, nguyên văn mockup v16.
const String kInsightStemHint =
    '...vì đây không phải lần đầu / vì mình chưa từng nói ra / ...';

/// Nhãn của khối gợi ý nằm DƯỚI ô chữ ở Lớp 1.
const String kInsightSuggestionsLabel = 'CHƯA BIẾT VIẾT GÌ? THỬ MỘT TRONG SỐ NÀY';

/// Những vế viết tiếp có thể chạm để điền thẳng vào ô.
///
/// Họp 26_1: "Người dùng có thể bấm vào các câu gợi ý để viết lại theo ý mình".
///
/// Ba câu đầu lấy đúng từ [kInsightStemHint] — chúng đã nằm sẵn trong gợi ý mờ
/// của ô chữ, nhưng gợi ý mờ thì biến mất ngay khi người dùng gõ chữ đầu tiên,
/// tức là mất đúng lúc người ta cần nó nhất.
///
/// Chạm vào là ĐIỀN, không phải chèn thêm: người dùng sửa tiếp ngay trong ô.
const List<String> kInsightStemSuggestions = [
  'đây không phải lần đầu',
  'mình chưa từng nói ra điều đó',
  'mình chưa rõ mình đang mong đợi gì',
  'mình sợ nói ra sẽ làm mọi thứ căng hơn',
];

/// Nhãn của lối thoát ở Lớp 1.
const String kInsightSkipLabel = 'Chưa muốn viết, bỏ qua bước này';

/// Nhãn nút chính ở Lớp 1.
const String kInsightRevealLabel = 'Xem một góc nhìn khác';

/// Nhãn khối "điều bạn vừa viết" ở Lớp 2.
const String kInsightYourWordsLabel = 'Điều bạn vừa viết';

/// Nhãn khối câu aha ở Lớp 2.
///
/// Đây là chỗ đổi lớn nhất của §1.2: bỏ khung trích dẫn ngôi "tôi", thay bằng
/// một câu chuẩn hoá/xã hội hoá. Cùng một câu aha, khung "tôi nhận ra…" bảo
/// người dùng phải nghĩ như vậy, còn khung này chỉ nói có người khác cũng nghĩ
/// vậy.
const String kInsightNormalizingLabel = 'Nhiều người khác cũng từng thấy điều này';

/// Câu chốt dưới khối aha ở Lớp 2.
const String kInsightAhaNote =
    'Điều này không phải để đúng hay sai, chỉ là một cách nhìn khác bạn có thể '
    'mang theo.';

/// Câu người dùng vừa viết, đã ghép với vế mở dở.
///
/// Trả null nếu [stem] rỗng — Lớp 2 không hiện khối "Điều bạn vừa viết" khi
/// người dùng chọn bỏ qua.
String? insightStemSentence(String stem) {
  final s = stem.trim();
  return s.isEmpty ? null : '$kInsightStemPrefix $s';
}

/// Nội dung cuối cùng ghi vào `draft_meaning`, theo đúng `acceptInsight()` của
/// mockup: bản GỘP giữa phần người dùng viết và câu aha.
///
/// Ghép chứ không chọn một trong hai, vì hai vế trả lời hai câu hỏi khác nhau —
/// vế đầu là lý do của riêng người dùng, vế sau là góc nhìn chung. Giữ cả hai
/// thì Career Memory về sau đọc lại được cả hai.
///
/// Chỉ thêm dấu chấm khi vế đầu chưa tự kết thúc bằng dấu câu: mockup nối cứng
/// `'. '` nên ai gõ sẵn dấu chấm sẽ ra "…nói ra.. Câu aha".
String mergeInsight({required String stem, required String aha}) {
  final sentence = insightStemSentence(stem);
  final tail = aha.trim();
  if (sentence == null) return tail;
  if (tail.isEmpty) return sentence;
  final needsStop = !RegExp(r'[.!?…]$').hasMatch(sentence);
  return '$sentence${needsStop ? '.' : ''} $tail';
}

/// Tách ngược phần người dùng đã viết ra khỏi [insightStemSentence].
///
/// Dùng khi mở lại một phiên còn dở: ô chữ ở Lớp 1 phải hiện đúng chữ cũ, không
/// hiện kèm vế mở dở (vế đó đã nằm sẵn trên thẻ phía trên ô chữ).
String stemFromNote(String? note) {
  final text = note?.trim();
  if (text == null || text.isEmpty) return '';
  if (!text.startsWith(kInsightStemPrefix)) return text;
  return text.substring(kInsightStemPrefix.length).trim();
}

// ---------------------------------------------------------------------------
// Nhãn tình huống để ghi vào `notes`
// ---------------------------------------------------------------------------

/// Chữ được ghi vào `notes['notice']` cho bước 0.
///
/// Chạm chip thì ghi đúng nhãn chip; nhánh "Điều khác" chưa có gì để ghi ở bước
/// này (câu tự mô tả nằm ở bước 1), nên trả null.
String? noticeNoteFor(WrSituation? situation) => situation?.text;

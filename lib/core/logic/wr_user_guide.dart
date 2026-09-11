// Nội dung màn "Hướng dẫn sử dụng" — yêu cầu §4 họp 26_1: "thêm phần hướng dẫn
// sử dụng trong mục Hồ sơ, làm nổi bật Chatbot".
//
// NGUỒN CHỮ HIỆN HÀNH: `FileTam/workreflection/WorkReflection_HDSD_InApp_v4.html`
// (khách gửi 10/09/2026). Bản v4 thay TRỌN bộ chữ soạn hồi 26/08 — không phải
// sửa vài câu, mà là đổi cách chia mục. Ba thứ đổi đáng ghi lại:
//
//   1. "Chatbot" → "Trợ lý AI" ở mọi chỗ người dùng đọc thấy. Tên cũ chỉ tồn
//      tại trong hai file hướng dẫn này, phần còn lại của app gọi là "trợ lý
//      trò chuyện", nên đổi ở đây là app bớt một tên chứ không thêm.
//
//   2. Bốn tab tách thành BỐN MỤC riêng, thay cho một bảng hai cột. Bảng cũ
//      trả lời "tab nào cho câu hỏi nào" trong bốn dòng, nhưng không nói được
//      bên trong mỗi tab có gì — mà đó mới là thứ người mở hướng dẫn đang tìm.
//
//   3. "Chọn cảm xúc" tách ra khỏi luồng nhìn lại. Trước đây bộ chữ kể năm
//      bước liền một mạch; v4 kể "ba bước để bắt đầu" rồi "bốn bước nhìn lại".
//      Bốn mới là con số ĐÚNG với app: `reflectProgress` chỉ được gọi ở bốn
//      màn (step · detail · meaning · commit), còn ô cảm xúc nằm ở tab Hôm nay
//      trước khi luồng mở ra. `kReflectStepCount = 5` là mẫu số của thanh tiến
//      trình (tính cả màn đóng lại), không phải số bước người dùng phải làm —
//      nên nó KHÔNG còn được dùng ở đây nữa.
//
// Bản chữ dài đọc ngoài app: `docs/huong_dan_su_dung.md`.
//
// Pure Dart, không phụ thuộc Flutter — để test được bộ chữ mà không phải dựng
// widget, và để mọi con số ở đây đọc từ ĐÚNG hằng số mà app đang chạy.
//
// ---------------------------------------------------------------------------
// Vì sao các con số không được gõ tay
// ---------------------------------------------------------------------------
//
// Một trang hướng dẫn sai số là tệ hơn không có trang nào: người dùng đọc "đủ 2
// lần thì hiện" rồi ngồi đếm, trong khi app đã đổi ngưỡng từ lâu. Nên mọi ngưỡng
// trong bộ chữ này nội suy từ hằng số nguồn:
//
//   kSelfCheckQuestions.length                           → Số câu Self-Check
//   kRepeatedSituationsMinCount · kRepeatedSituationsTop → Vòng lặp quen thuộc
//   kCareerHealthThreshold                               → Career Snapshot
//   kSkillThreshold                                      → Kỹ năng đã hình thành
//   kReflectionsPerPracticeTheme                         → Chủ đề thực hành mới
//
// Đổi ngưỡng ở file logic là chữ ở đây tự đổi theo, không ai phải nhớ quay lại
// sửa hướng dẫn. Chỗ nào v4 viết con số trần ("khoảng 3 phút", "10 đến 12
// người") thì giữ nguyên chữ — đó là ước lượng của khách, không phải ngưỡng
// nào trong mã.
//
// ---------------------------------------------------------------------------
// Mục "Gói Premium có gì" — đã BỎ 26/08, v4 ĐƯA LẠI
// ---------------------------------------------------------------------------
//
// Bản 26/08 gỡ mục này vì sợ Guideline 3.1.1 soi một bảng kê tính năng trả tiền
// nằm trong app trong khi luồng mua đang bị ẩn. v4 đưa lại, và lần này giữ:
// 3.1.1 quản CÁCH MUA chứ không cấm mô tả tính năng, mà chính màn Paywall trong
// app đã liệt kê đúng những dòng đó từ đầu — giấu ở hướng dẫn không làm rủi ro
// nhỏ đi, chỉ làm người dùng khó biết mình đang thiếu gì.
//
// Ranh giới vẫn giữ: mục này nói tính năng LÀM GÌ, không có giá, không có nút
// mua, không có đường dẫn ra web. Chỗ nói chuyện tiền vẫn là màn Paywall, nơi
// luật của kho được áp đúng một lần (`wr_store_policy.dart`).

import '../l10n/wr_tr.dart';
import 'wr_career_health.dart';
import 'wr_practice_theme_grant.dart';
import 'wr_repeated_situations.dart';
import 'wr_self_check_questions.dart';
import 'wr_skill_formation.dart';

// ---------------------------------------------------------------------------
// Khối nội dung
// ---------------------------------------------------------------------------

/// Một khối trong thân của mục hướng dẫn.
///
/// Sealed để màn hình `switch` cho đủ nhánh — thêm một kiểu khối mới mà quên
/// dựng widget cho nó thì compiler báo, chứ không phải người dùng phát hiện ra
/// bằng một khoảng trống trên màn.
sealed class WrGuideBlock {
  const WrGuideBlock();
}

/// Đoạn văn thường.
class WrGuideText extends WrGuideBlock {
  const WrGuideText(this.text);
  final String text;
}

/// Tiêu đề nhỏ trong thân một mục (`<h4>` của bản v4).
///
/// Có kiểu riêng thay vì mượn [WrGuideBullets] với nhãn in đậm: chấm tròn của
/// bullet nói "đây là một phần tử trong danh sách", còn ba khối của "Hiểu mình"
/// là ba thứ khác nhau đặt cạnh nhau chứ không phải ba mục cùng loại.
class WrGuideHeading extends WrGuideBlock {
  const WrGuideHeading(this.text);
  final String text;
}

/// Sắc thái của một khối lưu ý.
enum WrGuideNoteTone {
  /// Điều dễ hiểu nhầm, mẹo dùng — nền teal nhạt.
  teal,

  /// Thứ chỉ có ở bản Premium — nền coral nhạt.
  ///
  /// Tách tông riêng chứ không dùng chung teal: hai loại này nói hai chuyện
  /// khác hẳn nhau, và người đọc lướt cần phân biệt được "mẹo dùng" với "chỗ
  /// này bạn chưa mở" mà không phải đọc hết câu.
  coral,
}

/// Câu lưu ý — dùng cho điều dễ hiểu nhầm chứ không phải để nhấn mạnh cho đẹp.
/// Mỗi mục nhiều nhất một khối loại này.
class WrGuideNote extends WrGuideBlock {
  const WrGuideNote(this.text, {this.tone = WrGuideNoteTone.teal});
  final String text;
  final WrGuideNoteTone tone;
}

/// Danh sách gạch đầu dòng. [WrGuideBullet.label] in đậm, phần còn lại thường.
class WrGuideBullets extends WrGuideBlock {
  const WrGuideBullets(this.items);
  final List<WrGuideBullet> items;
}

class WrGuideBullet {
  const WrGuideBullet(this.label, this.text);
  final String label;
  final String text;
}

/// Danh sách dấu tích — dùng cho "gói Premium mở thêm những gì".
///
/// Khác [WrGuideBullets] ở chỗ mỗi dòng là một câu trọn vẹn, không có nhãn in
/// đậm: đây là danh sách để đối chiếu, không phải để tra cứu từng mục.
class WrGuideChecks extends WrGuideBlock {
  const WrGuideChecks(this.items, {this.footnote});
  final List<String> items;

  /// Dòng chữ nhỏ khép lại danh sách.
  final String? footnote;
}

/// Các bước đánh số.
class WrGuideSteps extends WrGuideBlock {
  const WrGuideSteps(this.items);
  final List<WrGuideStep> items;
}

class WrGuideStep {
  const WrGuideStep(this.title, this.text, {this.optional = false});
  final String title;
  final String text;

  /// Bỏ qua được. Nói ra ở đúng bước, chứ không gom xuống một câu cuối trang:
  /// người bỏ dở giữa chừng là người không đọc tới câu cuối.
  final bool optional;
}

/// Hỏi — đáp.
class WrGuideQa extends WrGuideBlock {
  const WrGuideQa(this.items);
  final List<WrGuideQaItem> items;
}

class WrGuideQaItem {
  const WrGuideQaItem(this.question, this.answer);
  final String question;
  final String answer;
}

// ---------------------------------------------------------------------------
// Mục
// ---------------------------------------------------------------------------

/// Biểu tượng của một mục (`.ico` của bản v4).
///
/// Là ENUM chứ không phải `IconData`: file này pure Dart, kéo
/// `package:flutter` vào đây là mất luôn khả năng test bộ chữ mà không dựng
/// widget. Chỗ đổi enum sang glyph nằm ở `guide_screen.dart`, và vì `switch`
/// bên đó vét cạn nên thêm một giá trị ở đây mà quên chọn glyph thì compiler
/// chặn, không phải người dùng phát hiện bằng một ô trống.
enum WrGuideIcon {
  /// Mục mở đầu — la bàn.
  compass,

  /// Ba bước để bắt đầu — lá cờ. Tông coral.
  flag,

  /// Hôm nay — con mắt.
  eye,

  /// Hiểu mình — bóng đèn.
  bulb,

  /// Phát triển — tia chớp.
  bolt,

  /// Hành trình — đường đi lên.
  trend,

  /// Thông tin công việc — cặp tài liệu.
  briefcase,

  /// Hồ sơ — hình người.
  person,

  /// Gói Premium — vương miện. Tông coral.
  crown,

  /// Câu hỏi thường gặp — dấu hỏi.
  question,
}

/// Một mục gập/mở được trên màn hướng dẫn.
class WrGuideSection {
  const WrGuideSection({
    required this.id,
    required this.group,
    required this.icon,
    required this.title,
    required this.summary,
    required this.blocks,
    this.openByDefault = false,
  });

  /// Mã ổn định — dùng làm `Key` của widget và làm mỏ neo cho test. Không đổi
  /// theo tiêu đề, vì tiêu đề là chữ khách còn sửa.
  final String id;

  /// Nhãn nhóm in nhỏ phía trên mục. Các mục liền nhau cùng nhãn thì chỉ mục
  /// đầu in ra — mười một mục xếp thẳng một hàng đọc ra là một danh sách dài,
  /// còn chia thành bốn cụm thì mắt biết mình đang ở đâu.
  final String group;

  /// Biểu tượng trong vòng tròn bên trái tiêu đề.
  final WrGuideIcon icon;

  final String title;

  /// Một dòng đọc được khi mục đang đóng. Không có nó thì màn hướng dẫn đóng
  /// lại chỉ còn là những cái tiêu đề, và người dùng phải mở từng cái để đoán
  /// bên trong có gì.
  final String summary;

  final List<WrGuideBlock> blocks;

  /// Mở sẵn khi vào màn. Chỉ mục đầu tiên — mở hết thì bằng với không gập.
  final bool openByDefault;
}

// ---------------------------------------------------------------------------
// Bộ chữ
// ---------------------------------------------------------------------------

/// Đoạn mở đầu, nằm ngay dưới tiêu đề màn.
String get kGuideIntro => tr(
    'Bạn sẽ mất khoảng 3 phút để xem toàn bộ hướng dẫn. Hoặc bạn có thể chọn '
    'đọc nhanh các mục đang cần tìm hiểu.',
    'Reading the whole guide takes about 3 minutes. Or you can jump straight '
    'to the part you need.');

/// Thẻ Trợ lý AI — tách khỏi danh sách gập/mở và đặt TRÊN nó.
///
/// Khách chốt ở họp 26_1 là hướng dẫn phải làm nổi bật trợ lý. Một mục thứ tư
/// trong danh sách mười một mục thì không nổi bật; một thẻ riêng, luôn mở, có
/// nút mở thẳng trợ lý thì có.
String get kGuideChatTitle => tr('Trợ lý AI', 'AI assistant');

String get kGuideChatSubtitle => tr('Hỗ trợ bạn mọi lúc', 'Here whenever you need it');

String get kGuideChatLead => tr(
    'Biểu tượng trò chuyện nằm ở góc dưới bên phải màn hình, có mặt trên cả '
    'bốn tab. Bạn dùng được ngay cả khi đang ở gói miễn phí.',
    'The chat icon sits at the bottom right of the screen, on all four tabs. '
    'You can use it even on the free plan.');

String get kGuideChatWhy => tr(
    'Trợ lý tự động đọc hồ sơ và các ghi nhận của bạn, nhờ đó trả lời sát hơn '
    'với bối cảnh của bạn mà không cần bạn giải thích lại từ đầu.',
    'The assistant reads your profile and everything you have recorded, so its '
    'answers fit your situation without you explaining from scratch.');

/// Nhãn nhỏ trên cụm ví dụ câu hỏi.
String get kGuideChatExamplesLabel => tr('Thử hỏi', 'Try asking');

/// Ví dụ câu hỏi. Để người dùng thấy ngay mình hỏi được kiểu gì — lời mời
/// "hỏi bất cứ điều gì" là lời mời khó nhận nhất.
///
/// Ba câu, mỗi câu gói trong một dòng. Bốn câu dài đẩy thẻ này cao gần bằng
/// một màn điện thoại, và khi thẻ chiếm trọn màn đầu thì danh sách mục phía
/// dưới không còn ai biết là có.
List<String> get kGuideChatExamples => [
      tr('Tôi hay bực chuyện gì nhất?', 'What annoys me most?'),
      tr('Tôi có đang tiến bộ không?', 'Am I making progress?'),
      tr('Với JD này tôi thiếu kỹ năng gì?', 'What skills am I missing for this JD?'),
    ];

String get kGuideChatCta => tr('Mở Trợ lý AI', 'Open the AI assistant');

String get kGuideChatCaveat => tr(
    'Dữ liệu bạn nhập càng chi tiết, phản hồi càng sát thực tế. Trợ lý hỗ trợ '
    'bạn nhìn lại công việc, không thay thế chuyên gia tâm lý.',
    'The more detail you record, the closer the answers get. The assistant '
    'helps you look back on work; it does not replace a therapist.');

/// Dòng khép màn, dựng thành thẻ bấm được để mở trợ lý.
String get kGuideClosingCta => tr(
    'Bạn cần hỗ trợ thêm? Hỏi Trợ lý AI.', 'Need more help? Ask the AI assistant.');

/// Đường tới trợ lý. Cùng một đường với bong bóng nổi ở shell — nếu đổi thì
/// đổi một chỗ.
const String kGuideChatRoute = '/wr/ask';

// Nhãn nhóm. Tách hằng vì mỗi nhãn dùng lại ở nhiều mục, và vì màn hình so
// sánh chuỗi để biết khi nào phải in nhãn ra.
String get kGuideGroupStart => tr('Bắt đầu', 'Getting started');
String get kGuideGroupTabs => tr('Bốn tab chính', 'The four tabs');
String get kGuideGroupWork => tr('Thông tin công việc', 'Your work');
String get kGuideGroupAccount => tr('Tài khoản và hỗ trợ', 'Account and help');

/// Toàn bộ mục của màn hướng dẫn, đúng thứ tự hiển thị.
List<WrGuideSection> wrGuideSections() => [
      // ---------------------------------------------------------------- Bắt đầu
      WrGuideSection(
        id: 'what',
        icon: WrGuideIcon.compass,
        group: kGuideGroupStart,
        title: tr('WorkReflection là gì', 'What WorkReflection is'),
        summary: tr('Một hai phút mỗi ngày, không phải app ghi chú',
            'A minute or two a day, not a notes app'),
        openByDefault: true,
        blocks: [
          WrGuideText(
            tr('WorkReflection không đơn thuần là một ứng dụng ghi chú.',
                'WorkReflection is not simply a notes app.'),
          ),
          WrGuideText(
            tr(
                'Đây là không gian để bạn dành vài phút mỗi ngày ghi nhận lại '
                'những gì đang diễn ra trong công việc. Qua thời gian, những sự '
                'việc tưởng chừng rời rạc sẽ được phác họa thành các điểm nghẽn '
                'hoặc xu hướng phát triển rõ nét, cung cấp cho bạn chất liệu '
                'thực tế để tự định hướng.',
                'It is a space to spend a few minutes a day recording what is '
                'happening at work. Over time, events that felt scattered take '
                'shape as clear sticking points or directions of growth, giving '
                'you real material to steer by.'),
          ),
          WrGuideNote(
            tr(
                'Tối ưu thời gian: Mỗi lần dùng chỉ mất 1 đến 2 phút. Bạn có '
                'thể viết ngắn gọn hoặc bỏ trống nếu chưa sẵn sàng.',
                'Easy on your time: each session takes 1 to 2 minutes. Write '
                'briefly, or leave it blank if you are not ready.'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'start',
        icon: WrGuideIcon.flag,
        group: kGuideGroupStart,
        title: tr('Ba bước để bắt đầu', 'Three steps to get going'),
        summary: tr('Chạm một cái là xong bước đầu', 'One tap and the first step is done'),
        blocks: [
          WrGuideSteps([
            WrGuideStep(
              tr('Chọn cảm xúc ở tab Hôm nay.', 'Pick a feeling on the Today tab.'),
              tr('Đây là cách nhanh nhất để bắt đầu, chỉ cần một lần chạm.',
                  'This is the quickest way in — it takes one tap.'),
            ),
            WrGuideStep(
              tr('Đi qua bốn bước nhìn lại.', 'Go through the four look-back steps.'),
              tr(
                  'Mỗi bước chỉ vài dòng, có thể bỏ trống phần viết nếu bạn '
                  'chưa sẵn sàng.',
                  'Each step is a few lines, and you can leave the writing '
                  'blank if you are not ready.'),
            ),
            WrGuideStep(
              tr('Quay lại đều đặn.', 'Come back regularly.'),
              tr(
                  'Sau khoảng $kCareerHealthThreshold lần, hệ thống bắt đầu '
                  'nhận ra những gì đang lặp lại với bạn.',
                  'After around $kCareerHealthThreshold times, the app starts '
                  'to notice what keeps repeating for you.'),
            ),
          ]),
        ],
      ),

      // ------------------------------------------------------------ Bốn tab
      WrGuideSection(
        id: 'today',
        icon: WrGuideIcon.eye,
        group: kGuideGroupTabs,
        title: tr('Hôm nay', 'Today'),
        summary: tr('Nơi bạn bắt đầu mỗi ngày, chỉ với một lần chạm.',
            'Where each day starts, with a single tap.'),
        blocks: [
          WrGuideHeading(tr('Chọn cảm xúc', 'Pick a feeling')),
          WrGuideText(
            tr(
                'Sáu lựa chọn mô tả trạng thái công việc của bạn lúc này: Căng '
                'thẳng, Mệt mỏi, Mơ hồ, Mọi thứ lệch nhau, Khá ổn, Đang vui. '
                'Lựa chọn này quyết định những tình huống và bài đọc bạn nhận '
                'được ngay sau đó.',
                'Six options describing how work feels right now: Tense, Worn '
                'out, Unclear, Everything is out of step, Doing okay, Feeling '
                'good. What you pick decides the situations and readings you '
                'get next.'),
          ),
          WrGuideHeading(tr('Bốn bước nhìn lại', 'The four look-back steps')),
          WrGuideSteps([
            WrGuideStep(
              tr('Chọn tình huống.', 'Pick a situation.'),
              tr(
                  'Vài tình huống công việc quen thuộc hiện ra, chọn cái gần '
                  'giống với điều bạn vừa trải qua. Nếu không có cái nào đúng, '
                  'bạn tự mô tả được.',
                  'A few familiar work situations appear; pick the one closest '
                  'to what you just went through. If none fits, describe your '
                  'own.'),
            ),
            WrGuideStep(
              tr('Đọc một câu chuyện.', 'Read a story.'),
              tr(
                  'Một câu chuyện ngắn về tình huống tương tự. Bạn có thể kể '
                  'lại chuyện của mình, hoặc chỉ đọc và cảm nhận.',
                  'A short story about a similar situation. You can tell yours '
                  'in return, or simply read it.'),
              optional: true,
            ),
            WrGuideStep(
              tr('Xem một góc nhìn khác.', 'See another angle.'),
              tr(
                  'Bạn tự viết trước, sau đó hệ thống đưa ra một đúc kết phổ '
                  'biến để bạn đối chiếu. Bạn chọn đồng ý hoặc không.',
                  'You write first, then the app offers a common takeaway to '
                  'compare against. You choose whether you agree.'),
            ),
            WrGuideStep(
              tr('Chọn bước tiếp theo.', 'Choose a next step.'),
              tr('Một vài gợi ý hành động nhỏ, phù hợp với điều bạn vừa nhận ra.',
                  'A few small suggested actions, matched to what you just saw.'),
              optional: true,
            ),
          ]),
          WrGuideNote(
            tr(
                'Không có câu trả lời đúng hay sai ở bất kỳ bước nào. Để trống '
                'cũng không sao, miễn là bạn đã dành một phút để nghĩ về nó.',
                'There is no right or wrong answer at any step. Leaving it '
                'blank is fine, as long as you took a minute to think about it.'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'understand',
        icon: WrGuideIcon.bulb,
        group: kGuideGroupTabs,
        title: tr('Hiểu mình', 'Understand'),
        summary: tr('Nhận diện những mẫu hình đang lặp lại trong công việc của bạn.',
            'Spot the patterns repeating in your work.'),
        blocks: [
          WrGuideHeading(
            tr('${kSelfCheckQuestions.length} câu hỏi phản chiếu (Self-Check)',
                '${kSelfCheckQuestions.length} reflective questions (Self-Check)'),
          ),
          WrGuideText(
            tr(
                'Bộ câu hỏi ngắn khoảng 3 đến 4 phút, giúp hệ thống hiểu rõ hơn '
                'trạng thái hiện tại của bạn qua ba khía cạnh: Sự rõ ràng, Mối '
                'quan hệ, và Cách làm việc. Bạn có thể cập nhật lại bất cứ khi '
                'nào thấy công việc có gì thay đổi.',
                'A short set of questions, about 3 to 4 minutes, that helps the '
                'app read where you are across three sides: Clarity, '
                'Relationships, and Ways of working. Update it whenever work '
                'changes.'),
          ),
          WrGuideHeading('Career Snapshot'),
          WrGuideText(
            tr(
                'Cùng ba khía cạnh đó, nhìn từ hai phía đặt cạnh nhau: điều bạn '
                'tự đánh giá qua Self-Check, và điều đang thực sự lặp lại trong '
                'các lần nhìn lại của bạn. Hai cột này không phải lúc nào cũng '
                'khớp nhau, và chính khoảng lệch đó thường là điều đáng chú ý '
                'nhất. Cột hành vi mở ra khi bạn có đủ $kCareerHealthThreshold '
                'lần nhìn lại.',
                'The same three sides, seen from two directions side by side: '
                'what you rate yourself in Self-Check, and what actually keeps '
                'coming back in your look-backs. The two columns do not always '
                'agree, and that gap is usually the most telling part. The '
                'behaviour column opens once you have $kCareerHealthThreshold '
                'look-backs.'),
          ),
          WrGuideHeading(tr('Những vòng lặp quen thuộc', 'Familiar loops')),
          WrGuideText(
            tr(
                'Danh sách các tình huống đã quay trở lại nhiều lần với bạn, '
                'kèm số lần xuất hiện. Tính từ $kRepeatedSituationsMinCount lần '
                'trở lên, hiện $kRepeatedSituationsTop dòng, còn lại nằm sau '
                '"Xem thêm".',
                'A list of the situations that have come back to you, with how '
                'many times each appeared. Counted from '
                '$kRepeatedSituationsMinCount times up, showing '
                '$kRepeatedSituationsTop lines, with the rest behind "See more".'),
          ),
          WrGuideNote(
            tr(
                'Premium: Diễn giải sâu đọc ý nghĩa của khoảng lệch giữa hai '
                'cột, và theo dõi nó thay đổi ra sao qua thời gian.',
                'Premium: a deeper reading of what the gap between the two '
                'columns means, and how it shifts over time.'),
            tone: WrGuideNoteTone.coral,
          ),
        ],
      ),
      WrGuideSection(
        id: 'growth',
        icon: WrGuideIcon.bolt,
        group: kGuideGroupTabs,
        title: tr('Phát triển', 'Grow'),
        summary: tr('Các chủ đề thực hành được hệ thống đề xuất riêng cho bạn.',
            'Practice themes the app picks out for you.'),
        blocks: [
          WrGuideHeading(tr('Chủ đề trọng tâm', 'Your focus theme')),
          WrGuideText(
            tr(
                'Sau khi bạn tích lũy đủ $kReflectionsPerPracticeTheme lần nhìn '
                'lại, ứng dụng sẽ tự động gợi ý chủ đề phù hợp nhất với bạn. '
                'Bạn cũng có thể hoàn thành Self-Check để mở khóa ngay mà không '
                'cần chờ.',
                'Once you have $kReflectionsPerPracticeTheme look-backs, the '
                'app suggests the theme that fits you best. You can also finish '
                'the Self-Check to unlock it straight away.'),
          ),
          WrGuideHeading(tr('Thói quen đang rèn luyện', 'Habits you are building')),
          WrGuideText(
            tr(
                'Mỗi chủ đề chia thành các bước thực hành nhỏ. Bạn đánh dấu mỗi '
                'lần thực hành, hệ thống theo dõi tiến độ giúp bạn. Giữ được '
                '$kSkillThreshold lần thì đó được ghi nhận là một kỹ năng đã '
                'hình thành.',
                'Each theme breaks into small practice steps. Tick one off each '
                'time you do it and the app tracks your progress. Hold it '
                '$kSkillThreshold times and it is recorded as a skill you have '
                'formed.'),
          ),
          WrGuideHeading(
              tr('Mức độ tương thích với công việc', 'How well it fits your job')),
          WrGuideText(
            tr(
                'Thêm vài dòng mô tả công việc (JD) bạn đang làm, hệ thống sẽ '
                'giúp bạn nhìn rõ những kỹ năng đang phát huy tốt và đâu là '
                'những khoảng trống cần hoàn thiện thêm.',
                'Add a few lines of the job description you work to, and the '
                'app shows which skills are serving you well and where the gaps '
                'still are.'),
          ),
          WrGuideHeading(tr('Trà Chiều Nghề Nghiệp', 'Career Afternoon Tea')),
          WrGuideText(
            tr(
                'Những buổi gặp gỡ ngoài đời thực, quy mô nhỏ khoảng 10 đến 12 '
                'người, xoay quanh một chủ đề công việc cụ thể mỗi buổi.',
                'Small in-person gatherings of about 10 to 12 people, each '
                'built around one specific work topic.'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'journey',
        icon: WrGuideIcon.trend,
        group: kGuideGroupTabs,
        title: tr('Hành trình', 'Journey'),
        summary: tr('Lưu giữ Career Memory và theo dõi tiến trình qua thời gian.',
            'Keeps your Career Memory and tracks how you move over time.'),
        blocks: [
          WrGuideText(
            tr(
                'Mỗi lần bạn nhìn lại đều để lại một ghi nhận ở đây. Đây không '
                'phải một cuốn nhật ký thông thường, mà là một tập hợp có hệ '
                'thống gồm bốn nhóm thông tin:',
                'Every look-back leaves a record here. This is not an ordinary '
                'diary but an organised collection of four kinds of entry:'),
          ),
          WrGuideBullets([
            WrGuideBullet(
              tr('Câu chuyện.', 'Stories.'),
              tr('Mỗi lần bạn hoàn thành một lượt nhìn lại.',
                  'One for every look-back you complete.'),
            ),
            WrGuideBullet(
              tr('Cột mốc.', 'Milestones.'),
              tr('Những lần đầu tiên đáng nhớ, ví dụ lần đầu bạn hoàn thành Self-Check.',
                  'Memorable firsts, such as the first time you finish a Self-Check.'),
            ),
            WrGuideBullet(
              tr('Chủ đề.', 'Themes.'),
              tr(
                  'Khi một điều lặp lại đủ nhiều, hệ thống sẽ gọi tên nó để bạn '
                  'dễ nhận ra sợi dây liên kết.',
                  'When something repeats enough, the app names it so the '
                  'thread is easier to see.'),
            ),
            WrGuideBullet(
              tr('Insight.', 'Insights.'),
              tr('Nhận định tổng hợp từ nhiều lần nhìn lại gần nhau. Dành cho gói Premium.',
                  'A reading drawn from several look-backs close together. Premium only.'),
            ),
          ]),
          WrGuideText(
            tr('Bấm vào một mục bất kỳ để xem thêm chi tiết.',
                'Tap any entry to see more detail.'),
          ),
        ],
      ),

      // ------------------------------------------------------ Thông tin công việc
      WrGuideSection(
        id: 'work',
        icon: WrGuideIcon.briefcase,
        group: kGuideGroupWork,
        title: tr('Cập nhật bối cảnh công việc', 'Update your work context'),
        summary: tr('Để gợi ý bám sát công việc thật của bạn hơn.',
            'So the suggestions stay close to the job you actually do.'),
        blocks: [
          WrGuideText(
            tr(
                'Chia sẻ vai trò hiện tại của bạn, chỉ một dòng cũng đủ. Dựa '
                'vào đây, các bài thực hành sẽ được phác thảo riêng cho công '
                'việc của bạn.',
                'Tell us your current role — one line is enough. From that, the '
                'practice work is sketched around your job.'),
          ),
          WrGuideText(
            tr(
                'Nếu có sẵn file JD hoặc CV, bạn có thể tải lên để hệ thống có '
                'thêm dữ liệu phân tích. Đây là phần không bắt buộc.',
                'If you already have a JD or CV file, upload it to give the app '
                'more to work from. This part is optional.'),
          ),
          WrGuideHeading(tr('Nếu công ty chưa có JD', 'If your company has no JD')),
          WrGuideText(
            tr(
                'Bạn có thể tự phác thảo nhanh theo 5 bước hướng dẫn: Khởi '
                'động, Vị trí và mục tiêu, Nhiệm vụ chính, Kết quả và kỹ năng, '
                'Mối quan hệ và điều kiện làm việc. Mỗi bước chỉ mất 2 đến 3 '
                'phút, bạn có thể dừng lại và quay lại làm tiếp bất cứ lúc nào.',
                'You can sketch one in 5 guided steps: Warm-up, Role and goals, '
                'Main duties, Outcomes and skills, Relationships and working '
                'conditions. Each step takes 2 to 3 minutes, and you can stop '
                'and pick it up again any time.'),
          ),
        ],
      ),

      // ------------------------------------------------------ Tài khoản và hỗ trợ
      WrGuideSection(
        id: 'profile',
        icon: WrGuideIcon.person,
        group: kGuideGroupAccount,
        title: tr('Hồ sơ của bạn', 'Your profile'),
        summary: tr('Quản lý thông tin cá nhân, dữ liệu và gói dịch vụ.',
            'Manage your details, your data and your plan.'),
        blocks: [
          WrGuideText(
            tr(
                'Tổng hợp toàn bộ bối cảnh cá nhân, môi trường và công việc của '
                'bạn. Bạn có thể kiểm tra hoặc cập nhật lại bất cứ lúc nào tại '
                'đây.',
                'Everything about you, your environment and your work in one '
                'place. Check or update it here any time.'),
          ),
          WrGuideText(
            tr(
                'Thông tin càng sát thực tế, Trợ lý AI càng đưa ra những tư vấn '
                'chính xác cho bối cảnh của bạn.',
                'The closer your details are to reality, the more accurate the '
                'AI assistant is for your situation.'),
          ),
          WrGuideText(
            tr(
                'Tại đây bạn cũng quản lý được gói dịch vụ đang dùng, và cài '
                'đặt nhắc nhở hằng ngày nếu muốn.',
                'This is also where you manage your plan and set a daily '
                'reminder if you want one.'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'premium',
        icon: WrGuideIcon.crown,
        group: kGuideGroupAccount,
        title: tr('Gói Premium có gì', 'What Premium includes'),
        summary: tr('Những gì được mở thêm so với gói miễn phí.',
            'What opens up beyond the free plan.'),
        blocks: [
          WrGuideChecks(
            [
              tr('Diễn giải sâu và theo dõi xu hướng cho Self-Check.',
                  'A deeper reading and trend tracking for your Self-Check.'),
              tr('AI Insight cá nhân hóa trong Career Memory.',
                  'Personalised AI insights in your Career Memory.'),
              tr('Xem toàn bộ Career Memory, không giới hạn số ghi nhận.',
                  'See your whole Career Memory, with no limit on entries.'),
              tr('Không giới hạn số chủ đề thực hành cùng lúc.',
                  'No limit on how many practice themes you run at once.'),
              tr('Góc nhìn phát triển, tổng hợp từ toàn bộ hành trình của bạn.',
                  'A development view drawn from your whole journey.'),
            ],
            // Không có giá, không có nút mua — xem ghi chú đầu file.
            footnote: tr('Bạn có thể xem chi tiết và nâng cấp bất cứ lúc nào từ trang Hồ sơ.',
                'You can see the details and upgrade any time from your Profile.'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'faq',
        icon: WrGuideIcon.question,
        group: kGuideGroupAccount,
        title: tr('Vài câu hay được hỏi', 'Questions people ask'),
        summary: tr('Các câu hỏi phổ biến về quyền riêng tư và cách dùng.',
            'Common questions about privacy and how to use it.'),
        blocks: [
          WrGuideQa([
            WrGuideQaItem(
              tr('Tôi có bắt buộc nhìn lại mỗi ngày không?',
                  'Do I have to look back every day?'),
              tr(
                  'Không bắt buộc. Ứng dụng hoạt động tốt nhất khi bạn dùng đều '
                  'đặn, nhưng bạn có thể quay lại bất cứ khi nào phù hợp với '
                  'mình.',
                  'No. The app works best when you use it regularly, but come '
                  'back whenever it suits you.'),
            ),
            WrGuideQaItem(
              tr('Những gì tôi viết có ai khác đọc được không?',
                  'Can anyone else read what I write?'),
              tr(
                  'Không. Nội dung bạn viết là riêng tư, chỉ phục vụ việc cá '
                  'nhân hóa gợi ý dành cho chính bạn.',
                  'No. What you write is private and is only used to '
                  'personalise your own suggestions.'),
            ),
            WrGuideQaItem(
              tr('Tôi bỏ trống phần viết thì có sao không?',
                  'Does it matter if I leave the writing blank?'),
              tr(
                  'Hoàn toàn không sao. Việc bạn dừng lại để nghĩ về nó đã là '
                  'phần quan trọng nhất rồi.',
                  'Not at all. Stopping to think about it is the part that '
                  'matters most.'),
            ),
            WrGuideQaItem(
              tr('Tôi có thể hủy Premium bất cứ lúc nào không?',
                  'Can I cancel Premium any time?'),
              tr('Có. Bạn quản lý hoặc hủy gói Premium từ trang Hồ sơ.',
                  'Yes. You manage or cancel Premium from your Profile.'),
            ),
            WrGuideQaItem(
              tr('Công ty tôi đã có JD rồi thì sao?',
                  'What if my company already has a JD?'),
              tr('Bạn tải lên file JD hoặc CV sẵn có, không cần viết mới cùng ứng dụng.',
                  'Upload the JD or CV you have — no need to write a new one here.'),
            ),
          ]),
        ],
      ),
    ];

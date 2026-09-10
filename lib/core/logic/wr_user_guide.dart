// Nội dung màn "Hướng dẫn sử dụng" — yêu cầu §4 họp 26_1: "thêm phần hướng dẫn
// sử dụng trong mục Hồ sơ, làm nổi bật Chatbot".
//
// Bản chữ gốc: `docs/huong_dan_su_dung.md` (nháp 25/08/2026). File này là bản
// rút cho màn hình, KHÔNG phải bản sao: tài liệu Word đọc một mạch từ trên
// xuống, còn màn hình phải mở được đúng mục người dùng đang cần.
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
//   kRepeatedSituationsMinCount · kRepeatedSituationsTop → Tình huống lặp lại
//   kCareerHealthThreshold                               → Career Health Check
//   kSkillThreshold                                      → Kỹ năng đã hình thành
//   kReflectionsPerPracticeTheme                         → Chủ đề thực hành mới
//   kReflectStepCount                                    → Số bước một lần nhìn lại
//
// Đổi ngưỡng ở file logic là chữ ở đây tự đổi theo, không ai phải nhớ quay lại
// sửa hướng dẫn.
//
// ---------------------------------------------------------------------------
// KHÔNG có bảng so sánh gói ở đây (quyết định 26/08/2026)
// ---------------------------------------------------------------------------
//
// Bản đầu có một mục "Miễn phí và Đầy đủ" — bảng hai cột dấu tick dựng từ chính
// những chỗ đang khoá trong app. Đã BỎ vì app còn phải qua App Review: một bảng
// kê tính năng trả tiền nằm trong màn hướng dẫn là đúng thứ Guideline 3.1.1
// soi, nhất là khi luồng mua đang được ẩn trên cả hai kho (xem
// `wr_store_policy.dart`).
//
// Cùng lý do đó, hai thứ nữa đã bỏ khỏi bộ chữ này: nhãn "Đầy đủ" cạnh tên
// tính năng, và câu "bản miễn phí đọc được tuần hiện tại" ở mục Hành trình.
// Màn hướng dẫn chỉ nói tính năng LÀM GÌ, không nói gói nào có.
//
// Đừng thêm lại. Chỗ nói về gói là màn Paywall, nơi luật của kho được áp đúng
// một lần. Mục 9 của `docs/huong_dan_su_dung.md` giữ bảng đó cho bản tài liệu
// đọc ngoài app, không dựng vào màn hình.

import '../l10n/wr_tr.dart';
import 'wr_career_health.dart';
import 'wr_practice_theme_grant.dart';
import 'wr_reflect_flow.dart';
import 'wr_repeated_situations.dart';
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

/// Câu lưu ý — nền teal nhạt, dùng cho điều dễ hiểu nhầm chứ không phải để
/// nhấn mạnh cho đẹp. Mỗi mục nhiều nhất một khối loại này.
class WrGuideNote extends WrGuideBlock {
  const WrGuideNote(this.text);
  final String text;
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

/// Bảng hai cột chữ — dùng cho "tab nào trả lời câu hỏi gì".
class WrGuideTwoColumn extends WrGuideBlock {
  const WrGuideTwoColumn(this.rows);
  final List<WrGuideTwoColumnRow> rows;
}

class WrGuideTwoColumnRow {
  const WrGuideTwoColumnRow(this.left, this.right);
  final String left;
  final String right;
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

/// Một mục gập/mở được trên màn hướng dẫn.
class WrGuideSection {
  const WrGuideSection({
    required this.id,
    required this.title,
    required this.summary,
    required this.blocks,
    this.openByDefault = false,
  });

  /// Mã ổn định — dùng làm `Key` của widget và làm mỏ neo cho test. Không đổi
  /// theo tiêu đề, vì tiêu đề là chữ khách còn sửa.
  final String id;

  final String title;

  /// Một dòng đọc được khi mục đang đóng. Không có nó thì màn hướng dẫn đóng
  /// lại chỉ còn là tám cái tiêu đề, và người dùng phải mở từng cái để đoán
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
String get kGuideIntro => tr('Đọc hết mất khoảng ba phút, nhưng bạn không cần đọc hết. '
    'Mở đúng mục bạn đang thắc mắc là đủ.', 'Reading it all takes about three minutes, but you do not have to. '
    'Opening the part you are wondering about is enough.');

/// Thẻ Chatbot — tách khỏi danh sách gập/mở và đặt TRÊN nó.
///
/// Khách chốt ở họp 26_1 là hướng dẫn phải "làm nổi bật Chatbot". Một mục thứ
/// tư trong danh sách tám mục thì không nổi bật; một thẻ coral đặc, luôn mở,
/// có nút mở thẳng Chatbot thì có.
String get kGuideChatTitle => tr('Chatbot — hỏi được bất cứ lúc nào', 'Chatbot — ask any time');

String get kGuideChatLead => tr('Bong bóng màu cam ở góc dưới bên phải, có mặt ở cả bốn tab. Bản miễn phí '
    'dùng được đầy đủ.', 'The orange bubble at the bottom right, on all four tabs. The free '
    'version has it in full.');

String get kGuideChatWhy => tr('Nó đã đọc hồ sơ và toàn bộ những lần bạn nhìn lại, nên bạn không phải kể '
    'lại từ đầu — chỗ này khác hẳn Google hay ChatGPT.', 'It has already read your profile and every look back you have done, so '
    'you never start from scratch — that is what makes it different from '
    'Google or ChatGPT.');

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

String get kGuideChatCaveat => tr('Càng ghi nhiều thì trả lời càng sát. Không thay bác sĩ hay chuyên gia '
    'tâm lý.', 'The more you record, the closer the answers get. Not a substitute for a '
    'doctor or a therapist.');

/// Đường tới Chatbot. Cùng một đường với bong bóng nổi ở shell — nếu đổi thì
/// đổi một chỗ.
const String kGuideChatRoute = '/wr/ask';

/// Toàn bộ mục của màn hướng dẫn, đúng thứ tự hiển thị.
List<WrGuideSection> wrGuideSections() => [
      WrGuideSection(
        id: 'what',
        title: tr('WorkReflection là gì', 'What WorkReflection is'),
        summary: tr('Một hai phút mỗi ngày, không phải app ghi chú', 'A minute or two a day, not a notes app'),
        openByDefault: true,
        blocks: [
          WrGuideText(
            tr('Đây không phải app ghi chú, cũng không phải app chấm điểm bạn.', 'This is not a notes app, and it is not scoring you.'),
          ),
          WrGuideText(
            tr('Nó là chỗ để mỗi ngày bạn dừng lại một hai phút, gọi tên điều vừa '
            'xảy ra ở chỗ làm, và để phần mềm giữ lại giúp bạn. Sau vài tuần, '
            'những chuyện tưởng là lẻ tẻ sẽ hiện ra thành một hình dạng — và đó '
            'mới là thứ đáng đọc.', 'It is a place to stop for a minute or two each day, name what just '
            'happened at work, and let the app hold on to it for you. After a '
            'few weeks, things that felt scattered start to show a shape — and '
            'that is the part worth reading.'),
          ),
          WrGuideNote(
            tr('Một lần dùng chỉ mất 1–2 phút. Không cần viết dài. Bỏ trống cũng '
            'không sao.', 'One session takes 1–2 minutes. No need to write much. Leaving it '
            'blank is fine.'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'tabs',
        title: tr('Bốn tab, mỗi tab một câu hỏi', 'Four tabs, one question each'),
        summary: tr('Hôm nay · Hiểu mình · Phát triển · Hành trình', 'Today · Understand · Grow · Journey'),
        blocks: [
          WrGuideTwoColumn([
            WrGuideTwoColumnRow(tr('Hôm nay', 'Today'), tr('Hôm nay tôi thế nào?', 'How am I today?')),
            WrGuideTwoColumnRow(tr('Hiểu mình', 'Understand'), tr('Điều gì đang lặp lại ở tôi?', 'What keeps repeating in me?')),
            WrGuideTwoColumnRow(tr('Phát triển', 'Grow'), tr('Tôi nên luyện điều gì?', 'What should I practise?')),
            WrGuideTwoColumnRow(tr('Hành trình', 'Journey'), tr('Tôi đã đi qua những gì?', 'What have I been through?')),
          ]),
          WrGuideText(
            tr('Ảnh đại diện ở góc trên bên phải mở Hồ sơ của bạn — thông tin cá '
            'nhân, gói đang dùng, đổi mật khẩu, xuất dữ liệu, và chính trang '
            'hướng dẫn này.', 'The avatar at the top right opens your Profile — personal details, '
            'your plan, changing your password, exporting your data, and this '
            'guide.'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'daily',
        title: tr('Nhìn lại mỗi ngày', 'Looking back each day'),
        summary: tr('$kReflectStepCount bước, bắt đầu từ tab Hôm nay', '$kReflectStepCount steps, starting on the Today tab'),
        blocks: [
          WrGuideSteps([
            WrGuideStep(
              tr('Chọn cảm xúc', 'Pick a feeling'),
              tr('Sáu ô ở tab Hôm nay. Chạm ô đúng nhất với lúc này. Không ô nào '
                  'là "sai".', 'Six tiles on the Today tab. Tap the one closest to right now. '
                  'None of them is "wrong".'),
            ),
            WrGuideStep(
              tr('Chọn tình huống', 'Pick a situation'),
              tr('Phần mềm đưa ra vài tình huống hay gặp ở chỗ làm. Chọn cái gần '
                  'nhất, hoặc chọn "Điều khác" rồi tự viết.', 'The app offers a few situations that come up often at work. Pick '
                  'the closest, or pick "Something else" and write your own.'),
            ),
            WrGuideStep(
              tr('Một câu chuyện quen thuộc', 'A familiar story'),
              tr('Phần mềm kể một tình huống giống của bạn rồi hỏi một câu. Bên '
                  'dưới có ô để viết chi tiết của riêng bạn.', 'The app tells a situation like yours and asks one question. '
                  'Below it there is room to write your own details.'),
              optional: true,
            ),
            WrGuideStep(
              tr('Điều bạn nhận ra', 'What you noticed'),
              tr('Chưa biết viết gì thì chạm một câu gợi ý bên dưới — nó điền sẵn '
                  'vào ô, bạn viết tiếp hoặc để nguyên.', 'Not sure what to write? Tap one of the prompts below — it fills '
                  'the box in for you, and you carry on or leave it.'),
            ),
            WrGuideStep(
              tr('Một bước nhỏ', 'One small step'),
              tr('Bốn lựa chọn để chạm, không phải ô trống bắt gõ. Lựa chọn đầu '
                  'gắn nhãn "Gợi ý" là riêng cho tình huống bạn vừa nhìn lại.', 'Four options to tap, not a blank box demanding typing. The first '
                  'one, marked "Suggested", is picked for the situation you '
                  'just looked back on.'),
              optional: true,
            ),
          ]),
          WrGuideNote(
            tr('Chọn một tình huống có sẵn giúp phần mềm nối lần này với những lần '
            'trước. Tự viết thì vẫn được lưu, nhưng nó đứng riêng — không góp '
            'vào phần "điều đang lặp lại".', 'Picking a ready-made situation lets the app connect this time to the '
            'earlier ones. Writing your own is still saved, but it stands alone '
            '— it does not feed into "what keeps repeating".'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'understand',
        title: tr('Hiểu mình', 'Understand'),
        summary: tr('Điều gì đang lặp lại ở bạn', 'What keeps repeating in you'),
        blocks: [
          WrGuideBullets([
            WrGuideBullet(
              tr('Điều bạn đang tìm kiếm', 'What you are looking for'),
              tr('nhu cầu nổi lên nhiều nhất từ những lần bạn ghi. Không phải chữ '
                  'viết sẵn: phần mềm đếm từng tình huống bạn đã chọn.', 'the need that comes up most across what you record. Not stock '
                  'text: the app counts every situation you have picked.'),
            ),
            WrGuideBullet(
              tr('Những vòng lặp quen thuộc', 'Familiar loops'),
              tr('điều nào đã quay lại từ $kRepeatedSituationsMinCount lần trở '
                  'lên. Hiện $kRepeatedSituationsTop dòng, còn lại nằm sau '
                  '"Xem thêm".', 'what has come back $kRepeatedSituationsMinCount times or more. '
                  'Shows $kRepeatedSituationsTop lines, the rest sit behind '
                  '"See more".'),
            ),
            WrGuideBullet(
              tr('Trải nghiệm hiện tại', 'Where you are now'),
              tr('ba mặt của trải nghiệm đi làm, đọc từ bộ 15 câu tự soi nếu bạn '
                  'đã làm.', 'three sides of working life, read from the 15 self-check '
                  'questions if you have done them.'),
            ),
            WrGuideBullet(
              'Career Health Check',
              tr('đủ $kCareerHealthThreshold lần nhìn lại thì bức tranh tổng thể '
                  'mở ra, đọc từ chính hành vi của bạn.', 'once you reach $kCareerHealthThreshold look-backs the whole '
                  'picture opens, read from what you actually do.'),
            ),
          ]),
          WrGuideNote(
            tr('Một lần nhìn lại được tính khi bạn đã chọn một tình huống. Chạm ô '
            'cảm xúc rồi rời đi thì lần đó chưa vào.', 'A look back counts once you have picked a situation. Tapping a '
            'feeling and leaving does not count.'),
          ),
        ],
      ),
      WrGuideSection(
        id: 'growth',
        title: tr('Phát triển', 'Grow'),
        summary: tr('Chủ đề thực hành phần mềm tự thêm cho bạn', 'Practice themes the app adds for you'),
        blocks: [
          WrGuideText(
            tr('Cứ mỗi $kReflectionsPerPracticeTheme lần nhìn lại, phần mềm TỰ '
            'thêm một chủ đề thực hành — không có danh sách để chọn, không có '
            'nút "Bắt đầu". Chủ đề đến từ chính những điều đang lặp lại ở bạn.', 'Every $kReflectionsPerPracticeTheme look-backs, the app ADDS a '
            'practice theme by itself — no list to choose from, no "Start" '
            'button. The theme comes from what keeps repeating in you.'),
          ),
          WrGuideText(
            tr('Mỗi chủ đề có vài bước nhỏ. Làm xong một bước thì đánh dấu. Ba '
            'bước đầu chỉ là làm quen; giữ được $kSkillThreshold lần thì phần '
            'mềm mới ghi nhận đó là một kỹ năng đã hình thành.', 'Each theme has a few small steps. Tick one off when you finish it. '
            'The first three are only getting familiar; hold it for '
            '$kSkillThreshold and the app records it as a skill you have '
            'formed.'),
          ),
          WrGuideBullets([
            WrGuideBullet(
              tr('Thông tin công việc', 'Work details'),
              tr('tải JD hoặc CV lên, phần mềm đọc và đối chiếu với những gì bạn '
                  'đã ghi.', 'upload a JD or CV and the app reads it, setting it against what '
                  'you have recorded.'),
            ),
            WrGuideBullet(
              tr('Tự viết JD', 'Write your own JD'),
              tr('5 buổi, mỗi buổi một câu hỏi, cuối cùng ra một bản mô tả công '
                  'việc bằng chính chữ của bạn.', '5 sessions, one question each, ending with a job description in '
                  'your own words.'),
            ),
          ]),
        ],
      ),
      WrGuideSection(
        id: 'journey',
        title: tr('Hành trình', 'Journey'),
        summary: tr('Career Memory và diễn biến theo thời gian', 'Career Memory and how things move over time'),
        blocks: [
          WrGuideBullets([
            WrGuideBullet(
              tr('Diễn biến theo thời gian', 'How things are moving'),
              tr('phần mềm kể lại điều gì đang đổi trong bạn. Đoạn dài hiện gọn '
                  'trong 4 dòng, chạm để mở rộng.', 'the app tells you what is changing in you. Longer passages show '
                  'as 4 lines; tap to expand.'),
            ),
            WrGuideBullet(
              'Career Memory',
              tr('dòng thời gian những ghi nhận trên hành trình sự nghiệp: câu '
                  'chuyện, cột mốc, chủ đề, insight. Chạm một mục để đọc vì '
                  'sao nó được ghi lại.', 'a timeline of what you have recorded on your career journey: '
                  'stories, milestones, themes, insights. Tap an entry to read '
                  'why it was kept.'),
            ),
            WrGuideBullet(
              tr('Trò chuyện về hành trình', 'Talk about your journey'),
              tr('một lối vào nữa của Chatbot, cho ai đang đọc dở phần này.', 'one more way into the Chatbot, for anyone reading this part.'),
            ),
          ]),
        ],
      ),
      WrGuideSection(
        id: 'profile',
        title: tr('Hồ sơ của bạn', 'Your profile'),
        summary: tr('Thông tin, gói, dữ liệu và tài khoản', 'Details, plan, data and account'),
        blocks: [
          WrGuideBullets([
            WrGuideBullet(
              tr('Thông tin của bạn', 'Your details'),
              tr('vai trò, số năm kinh nghiệm, ngành, quy mô công ty… Mọi trường '
                  'đều tuỳ chọn, khai thêm thì phần mềm đọc bạn sát hơn.', 'role, years of experience, industry, company size… Every field '
                  'is optional; the more you fill in, the closer the app reads '
                  'you.'),
            ),
            WrGuideBullet(tr('Bản Premium', 'Premium'), tr('xem gói đang dùng.', 'see the plan you are on.')),
            WrGuideBullet(
              tr('Khảo sát tổ chức', 'Organisation survey'),
              tr('tuỳ chọn, không đổi lấy quyền lợi nào trong ứng dụng.', 'optional, and it does not buy you anything in the app.'),
            ),
            WrGuideBullet(
              tr('Ngôn ngữ · mật khẩu · xuất dữ liệu · xoá tài khoản', 'Language · password · export data · delete account'),
              tr('xuất và xoá được bất cứ lúc nào, không phải hỏi ai.', 'export and delete any time, without asking anyone.'),
            ),
          ]),
        ],
      ),
      WrGuideSection(
        id: 'faq',
        title: tr('Vài câu hay được hỏi', 'Questions people ask'),
        summary: tr('Bỏ vài ngày · riêng tư · viết ngắn', 'Missing days · privacy · writing briefly'),
        blocks: [
          WrGuideQa([
            WrGuideQaItem(
              tr('Bỏ vài ngày không ghi có sao không?', 'Does it matter if I miss a few days?'),
              tr('Không. Không có chuỗi ngày nào bị mất, không có ai nhắc bạn có '
                  'lỗi. Quay lại lúc nào cũng được.', 'No. No streak is lost, nobody tells you off. Come back whenever '
                  'you like.'),
            ),
            WrGuideQaItem(
              tr('Dữ liệu của tôi có riêng tư không?', 'Is my data private?'),
              tr('Có. Không ai ngoài bạn đọc được những gì bạn ghi. Xuất hoặc xoá '
                  'được bất cứ lúc nào trong Hồ sơ.', 'Yes. Nobody but you can read what you write. Export or delete it '
                  'any time from your Profile.'),
            ),
            WrGuideQaItem(
              tr('Tôi viết ngắn quá thì có sao không?', 'Does it matter if I write very little?'),
              tr('Không. Một dòng cũng được, bỏ trống cũng được. Việc bạn dừng lại '
                  'một nhịp mới là phần quan trọng.', 'No. One line is fine, blank is fine. Stopping for a beat is the '
                  'part that matters.'),
            ),
            WrGuideQaItem(
              tr('Sao mấy hôm đầu chưa thấy phần mềm nói gì?', 'Why has the app not said anything in the first few days?'),
              tr('Vì nó chưa đủ để nói. Những phần đọc-ra chỉ mở khi đã có đủ dữ '
                  'liệu — nói sớm là đoán bừa. Chỗ nào chưa mở đều ghi rõ còn '
                  'thiếu bao nhiêu.', 'Because it does not have enough to say yet. The reading parts '
                  'only open once there is enough data — saying it early would '
                  'be guessing. Anything still closed says how much is left.'),
            ),
          ]),
        ],
      ),
    ];

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
    required this.group,
    required this.title,
    required this.summary,
    required this.blocks,
    this.openByDefault = false,
  });

  /// Mã ổn định — dùng làm `Key` của widget và làm mỏ neo cho test. Không đổi
  /// theo tiêu đề, vì tiêu đề là chữ khách còn sửa.
  final String id;

  /// Nhãn nhóm hiện phía trên mục đầu tiên của nhóm.
  ///
  /// Tám thẻ trắng giống hệt nhau xếp thẳng một cột đọc ra là một danh sách
  /// không có hình dạng — mắt không bám vào đâu để biết mình đang ở đoạn nào.
  /// Ba nhãn nhóm chia nó thành ba chặng có nghĩa, mà không phải gập thêm một
  /// tầng nữa.
  ///
  /// Là CHỮ nên nằm ở đây cùng bộ chữ, không nằm trong widget. Các mục cùng
  /// nhóm phải đứng LIỀN NHAU — màn hình chỉ in nhãn khi nhóm đổi.
  final String group;

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
const String kGuideIntro =
    'Đọc hết mất khoảng ba phút, nhưng bạn không cần đọc hết. '
    'Mở đúng mục bạn đang thắc mắc là đủ.';

/// Thẻ Chatbot — tách khỏi danh sách gập/mở và đặt TRÊN nó.
///
/// Khách chốt ở họp 26_1 là hướng dẫn phải "làm nổi bật Chatbot". Một mục thứ
/// tư trong danh sách tám mục thì không nổi bật; một thẻ coral đặc, luôn mở,
/// có nút mở thẳng Chatbot thì có.
const String kGuideChatTitle = 'Chatbot — hỏi được bất cứ lúc nào';

const String kGuideChatLead =
    'Bong bóng màu cam ở góc dưới bên phải, có mặt ở cả bốn tab. Bản miễn phí '
    'dùng được đầy đủ.';

const String kGuideChatWhy =
    'Nó đã đọc hồ sơ và toàn bộ những lần bạn nhìn lại, nên bạn không phải kể '
    'lại từ đầu — chỗ này khác hẳn Google hay ChatGPT.';

/// Ví dụ câu hỏi. Để người dùng thấy ngay mình hỏi được kiểu gì — lời mời
/// "hỏi bất cứ điều gì" là lời mời khó nhận nhất.
///
/// Ba câu, mỗi câu gói trong một dòng. Bốn câu dài đẩy thẻ này cao gần bằng
/// một màn điện thoại, và khi thẻ chiếm trọn màn đầu thì danh sách mục phía
/// dưới không còn ai biết là có.
const List<String> kGuideChatExamples = [
  'Tôi hay bực chuyện gì nhất?',
  'Tôi có đang tiến bộ không?',
  'Với JD này tôi thiếu kỹ năng gì?',
];

const String kGuideChatCaveat =
    'Càng ghi nhiều thì trả lời càng sát. Không thay bác sĩ hay chuyên gia '
    'tâm lý.';

/// Đường tới Chatbot. Cùng một đường với bong bóng nổi ở shell — nếu đổi thì
/// đổi một chỗ.
const String kGuideChatRoute = '/wr/ask';

/// Toàn bộ mục của màn hướng dẫn, đúng thứ tự hiển thị.
List<WrGuideSection> wrGuideSections() => [
      WrGuideSection(
        id: 'what',
        group: 'Bắt đầu',
        title: 'WorkReflection là gì',
        summary: 'Một hai phút mỗi ngày, không phải app ghi chú',
        openByDefault: true,
        blocks: const [
          WrGuideText(
            'Đây không phải app ghi chú, cũng không phải app chấm điểm bạn.',
          ),
          WrGuideText(
            'Nó là chỗ để mỗi ngày bạn dừng lại một hai phút, gọi tên điều vừa '
            'xảy ra ở chỗ làm, và để phần mềm giữ lại giúp bạn. Sau vài tuần, '
            'những chuyện tưởng là lẻ tẻ sẽ hiện ra thành một hình dạng — và đó '
            'mới là thứ đáng đọc.',
          ),
          WrGuideNote(
            'Một lần dùng chỉ mất 1–2 phút. Không cần viết dài. Bỏ trống cũng '
            'không sao.',
          ),
        ],
      ),
      WrGuideSection(
        id: 'tabs',
        group: 'Bắt đầu',
        title: 'Bốn tab, mỗi tab một câu hỏi',
        summary: 'Hôm nay · Hiểu mình · Phát triển · Hành trình',
        blocks: const [
          WrGuideTwoColumn([
            WrGuideTwoColumnRow('Hôm nay', 'Hôm nay tôi thế nào?'),
            WrGuideTwoColumnRow('Hiểu mình', 'Điều gì đang lặp lại ở tôi?'),
            WrGuideTwoColumnRow('Phát triển', 'Tôi nên luyện điều gì?'),
            WrGuideTwoColumnRow('Hành trình', 'Tôi đã đi qua những gì?'),
          ]),
          WrGuideText(
            'Ảnh đại diện ở góc trên bên phải mở Hồ sơ của bạn — thông tin cá '
            'nhân, gói đang dùng, đổi mật khẩu, xuất dữ liệu, và chính trang '
            'hướng dẫn này.',
          ),
        ],
      ),
      WrGuideSection(
        id: 'daily',
        group: 'Bắt đầu',
        title: 'Nhìn lại mỗi ngày',
        summary: '$kReflectStepCount bước, bắt đầu từ tab Hôm nay',
        blocks: const [
          WrGuideSteps([
            WrGuideStep(
              'Chọn cảm xúc',
              'Sáu ô ở tab Hôm nay. Chạm ô đúng nhất với lúc này. Không ô nào '
                  'là "sai".',
            ),
            WrGuideStep(
              'Chọn tình huống',
              'Phần mềm đưa ra vài tình huống hay gặp ở chỗ làm. Chọn cái gần '
                  'nhất, hoặc chọn "Điều khác" rồi tự viết.',
            ),
            WrGuideStep(
              'Một câu chuyện quen thuộc',
              'Phần mềm kể một tình huống giống của bạn rồi hỏi một câu. Bên '
                  'dưới có ô để viết chi tiết của riêng bạn.',
              optional: true,
            ),
            WrGuideStep(
              'Điều bạn nhận ra',
              'Chưa biết viết gì thì chạm một câu gợi ý bên dưới — nó điền sẵn '
                  'vào ô, bạn viết tiếp hoặc để nguyên.',
            ),
            WrGuideStep(
              'Một bước nhỏ',
              'Bốn lựa chọn để chạm, không phải ô trống bắt gõ. Lựa chọn đầu '
                  'gắn nhãn "Gợi ý" là riêng cho tình huống bạn vừa nhìn lại.',
              optional: true,
            ),
          ]),
          WrGuideNote(
            'Chọn một tình huống có sẵn giúp phần mềm nối lần này với những lần '
            'trước. Tự viết thì vẫn được lưu, nhưng nó đứng riêng — không góp '
            'vào phần "điều đang lặp lại".',
          ),
        ],
      ),
      WrGuideSection(
        id: 'understand',
        group: 'Từng tab một',
        title: 'Hiểu mình',
        summary: 'Điều gì đang lặp lại ở bạn',
        blocks: [
          WrGuideBullets([
            const WrGuideBullet(
              'Điều bạn đang tìm kiếm',
              'nhu cầu nổi lên nhiều nhất từ những lần bạn ghi. Không phải chữ '
                  'viết sẵn: phần mềm đếm từng tình huống bạn đã chọn.',
            ),
            WrGuideBullet(
              'Tình huống lặp lại',
              'điều nào đã quay lại từ $kRepeatedSituationsMinCount lần trở '
                  'lên. Hiện $kRepeatedSituationsTop dòng, còn lại nằm sau '
                  '"Xem thêm".',
            ),
            const WrGuideBullet(
              'Trải nghiệm hiện tại',
              'ba mặt của trải nghiệm đi làm, đọc từ bộ 15 câu tự soi nếu bạn '
                  'đã làm.',
            ),
            WrGuideBullet(
              'Career Health Check',
              'đủ $kCareerHealthThreshold lần nhìn lại thì bức tranh tổng thể '
                  'mở ra, đọc từ chính hành vi của bạn.',
            ),
          ]),
          const WrGuideNote(
            'Một lần nhìn lại được tính khi bạn đã chọn một tình huống. Chạm ô '
            'cảm xúc rồi rời đi thì lần đó chưa vào.',
          ),
        ],
      ),
      WrGuideSection(
        id: 'growth',
        group: 'Từng tab một',
        title: 'Phát triển',
        summary: 'Chủ đề thực hành phần mềm tự thêm cho bạn',
        blocks: [
          WrGuideText(
            'Cứ mỗi $kReflectionsPerPracticeTheme lần nhìn lại, phần mềm TỰ '
            'thêm một chủ đề thực hành — không có danh sách để chọn, không có '
            'nút "Bắt đầu". Chủ đề đến từ chính những điều đang lặp lại ở bạn.',
          ),
          WrGuideText(
            'Mỗi chủ đề có vài bước nhỏ. Làm xong một bước thì đánh dấu. Ba '
            'bước đầu chỉ là làm quen; giữ được $kSkillThreshold lần thì phần '
            'mềm mới ghi nhận đó là một kỹ năng đã hình thành.',
          ),
          const WrGuideBullets([
            WrGuideBullet(
              'Thông tin công việc',
              'tải JD hoặc CV lên, phần mềm đọc và đối chiếu với những gì bạn '
                  'đã ghi.',
            ),
            WrGuideBullet(
              'Tự viết JD',
              '5 buổi, mỗi buổi một câu hỏi, cuối cùng ra một bản mô tả công '
                  'việc bằng chính chữ của bạn.',
            ),
          ]),
        ],
      ),
      WrGuideSection(
        id: 'journey',
        group: 'Từng tab một',
        title: 'Hành trình',
        summary: 'Career Memory và diễn biến theo thời gian',
        blocks: const [
          WrGuideBullets([
            WrGuideBullet(
              'Diễn biến theo thời gian',
              'phần mềm kể lại điều gì đang đổi trong bạn. Đoạn dài hiện gọn '
                  'trong 4 dòng, chạm để mở rộng.',
            ),
            WrGuideBullet(
              'Career Memory',
              'dòng thời gian những mảnh ký ức nghề nghiệp: câu chuyện, cột '
                  'mốc, chủ đề, insight. Chạm một mục để đọc vì sao nó được '
                  'ghi lại.',
            ),
            WrGuideBullet(
              'Trò chuyện về hành trình',
              'một lối vào nữa của Chatbot, cho ai đang đọc dở phần này.',
            ),
          ]),
        ],
      ),
      WrGuideSection(
        id: 'profile',
        group: 'Tài khoản & thắc mắc',
        title: 'Hồ sơ của bạn',
        summary: 'Thông tin, gói, dữ liệu và tài khoản',
        blocks: const [
          WrGuideBullets([
            WrGuideBullet(
              'Thông tin của bạn',
              'vai trò, số năm kinh nghiệm, ngành, quy mô công ty… Mọi trường '
                  'đều tuỳ chọn, khai thêm thì phần mềm đọc bạn sát hơn.',
            ),
            WrGuideBullet('Bản Premium', 'xem gói đang dùng.'),
            WrGuideBullet(
              'Khảo sát tổ chức',
              'tuỳ chọn, không đổi lấy quyền lợi nào trong ứng dụng.',
            ),
            WrGuideBullet(
              'Ngôn ngữ · mật khẩu · xuất dữ liệu · xoá tài khoản',
              'xuất và xoá được bất cứ lúc nào, không phải hỏi ai.',
            ),
          ]),
        ],
      ),
      WrGuideSection(
        id: 'faq',
        group: 'Tài khoản & thắc mắc',
        title: 'Vài câu hay được hỏi',
        summary: 'Bỏ vài ngày · riêng tư · viết ngắn',
        blocks: const [
          WrGuideQa([
            WrGuideQaItem(
              'Bỏ vài ngày không ghi có sao không?',
              'Không. Không có chuỗi ngày nào bị mất, không có ai nhắc bạn có '
                  'lỗi. Quay lại lúc nào cũng được.',
            ),
            WrGuideQaItem(
              'Dữ liệu của tôi có riêng tư không?',
              'Có. Không ai ngoài bạn đọc được những gì bạn ghi. Xuất hoặc xoá '
                  'được bất cứ lúc nào trong Hồ sơ.',
            ),
            WrGuideQaItem(
              'Tôi viết ngắn quá thì có sao không?',
              'Không. Một dòng cũng được, bỏ trống cũng được. Việc bạn dừng lại '
                  'một nhịp mới là phần quan trọng.',
            ),
            WrGuideQaItem(
              'Sao mấy hôm đầu chưa thấy phần mềm nói gì?',
              'Vì nó chưa đủ để nói. Những phần đọc-ra chỉ mở khi đã có đủ dữ '
                  'liệu — nói sớm là đoán bừa. Chỗ nào chưa mở đều ghi rõ còn '
                  'thiếu bao nhiêu.',
            ),
          ]),
        ],
      ),
    ];

import '../l10n/wr_tr.dart';
// "Cùng tạo JD của bạn" — 5 bước ngắn.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §6, mockup v16 `screenJdBuilder`.
//
// TỪ VỰNG: khách 09/09/2026 (§11) đổi "buổi" → "bước" trên toàn màn. Các đoạn
// trích §6 dưới đây đã sửa theo từ mới cho đọc liền mạch; bản gốc §6 viết
// "buổi". Cùng một thứ.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.
//
// ---------------------------------------------------------------------------
// Vì sao chia 5 bước
// ---------------------------------------------------------------------------
//
// §6: "Dành cho người dùng mà công ty chưa có JD sẵn. Thay vì đưa nguyên form
// tư vấn 8 trường vào app trong một lần, chia thành 5 bước ngắn (2–3 phút/bước),
// có thể làm rải rác trong tuần."
//
// Cách chia không tuỳ tiện: bước 1 KHÔNG hỏi trường JD nào cả, chỉ ba câu đời
// thường để làm nóng trí nhớ. Ai chưa quen viết JD mà bị hỏi thẳng "vì sao vị
// trí này tồn tại" thì bỏ ngang ngay ở ô đầu tiên.
//
// ---------------------------------------------------------------------------
// Ba việc bản thật phải làm khác mockup
// ---------------------------------------------------------------------------
//
// §6 để lại đúng ba ghi chú cho dev, và cả ba đều nằm ở file này hoặc ở màn
// dùng nó:
//
//   1. "Thanh nút Bước 1–5 ở cuối màn hình chỉ phục vụ xem trước cho demo —
//      bản thật nên khoá bước sau cho đến khi hoàn thành bước trước, không cho
//      nhảy cóc tự do."                              → [canOpenJdDay]
//   2. "Nút Dừng ở đây, làm tiếp sau hiện CHƯA lưu dữ liệu đã nhập (chỉ là
//      demo) — cần thiết kế cơ chế lưu nháp thật."   → `WrJdRepository.save`
//   3. "Dữ liệu JD cần một cấu trúc lưu trữ thống nhất (không chỉ local
//      state)."                                     → bảng `wr_jd_drafts`

/// Một bước trong luồng.
class WrJdDay {
  const WrJdDay({
    required this.number,
    required this.title,
    required this.eyebrow,
    required this.fields,
    this.intro,
  });

  /// 1–5.
  final int number;

  /// Tiêu đề bước, nguyên văn mockup.
  final String title;

  /// Nhãn nhỏ phía trên tiêu đề, gồm cả thời lượng ước tính.
  final String eyebrow;

  /// Đoạn dẫn ở đầu bước. Chỉ bước 1 có — nó phải giải thích vì sao đang hỏi
  /// mấy câu chuyện phiếm thay vì hỏi thẳng vào JD.
  final String? intro;

  final List<WrJdField> fields;
}

/// Kiểu ô nhập. Quyết định luôn chiều cao và bàn phím.
enum WrJdFieldKind {
  /// Một dòng, gạch chân — dùng cho chức danh, phòng ban…
  line,

  /// Nhiều dòng.
  paragraph,

  /// Nhiều dòng, cao hơn — dùng cho danh sách nhiệm vụ.
  list,
}

/// Một ô trong một bước.
class WrJdField {
  const WrJdField({
    required this.column,
    required this.label,
    required this.hint,
    this.kind = WrJdFieldKind.paragraph,
    this.guide,
    this.example,
  });

  /// Tên CỘT trong `wr_jd_drafts`. Dùng thẳng làm khoá khi đọc và ghi — không
  /// có bảng ánh xạ trung gian nào để mà lệch.
  final String column;

  /// Nhãn hoặc câu hỏi.
  final String label;

  /// Gợi ý trong ô.
  final String hint;

  final WrJdFieldKind kind;

  /// Khối "Cách viết" — hướng dẫn ngắn, chỉ ở những ô mà người chưa quen viết
  /// JD dễ tắc.
  final String? guide;

  /// Ví dụ cụ thể. Một câu trừu tượng đọc xong vẫn không biết bắt đầu từ đâu.
  final String? example;
}

/// Tổng số bước.
const int kJdDayCount = 5;

/// Năm bước, nguyên văn nội dung mockup v16 `screenJdBuilder`.
List<WrJdDay> get kJdDays => [
  WrJdDay(
    number: 1,
    title: tr('Khởi động', 'Warm-up'),
    eyebrow: tr('Bước 1 / 5 · khoảng 2 phút', 'Step 1 / 5 · about 2 minutes'),
    intro: tr('Đừng áp lực phải viết đúng chuẩn. Hãy thoải mái trả lời những câu '
        'hỏi, chia sẻ của bạn sẽ là chất liệu để tạo nên bản JD hoàn chỉnh.', 'No pressure to get the wording right. Just answer freely; what you '
        'share becomes the material for the finished JD.'),
    fields: [
      WrJdField(
        column: 'warmup_repeated',
        label: tr('Việc gì bạn lặp đi lặp lại mỗi ngày, mỗi tuần?', 'What do you do over and over, every day or every week?'),
        hint: tr('Ví dụ: Sáng nào cũng kiểm tra đơn hàng mới, gọi xác nhận với '
            'khách...', 'For example: Check new orders every morning, call customers to '
            'confirm...'),
      ),
      WrJdField(
        column: 'warmup_blocked',
        label: tr('Nếu bạn nghỉ phép một tuần, việc gì sẽ bị ùn lại vì không ai '
            'làm thay?', 'If you took a week off, what would pile up because nobody else '
            'could do it?'),
        hint: tr('Ví dụ: Không ai xử lý được khiếu nại của khách vì chỉ mình mình '
            'biết quy trình...', 'For example: Nobody could handle customer complaints because only '
            'I know the process...'),
      ),
      WrJdField(
        column: 'warmup_asked_about',
        label: tr('Đồng nghiệp hoặc sếp thường nhờ/hỏi bạn về việc gì nhất?', 'What do colleagues or your manager come to you for most?'),
        hint: tr('Ví dụ: Sếp hay hỏi mình về tình trạng đơn hàng trễ...', 'For example: My manager always asks me about late orders...'),
      ),
    ],
  ),
  WrJdDay(
    number: 2,
    title: tr('Vị trí & mục tiêu', 'Role & purpose'),
    eyebrow: tr('Bước 2 / 5 · khoảng 3 phút', 'Step 2 / 5 · about 3 minutes'),
    fields: [
      WrJdField(
        column: 'job_title',
        label: tr('Chức danh công việc', 'Job title'),
        hint: tr('VD: Nhân viên Chăm sóc khách hàng', 'e.g. Customer Care Officer'),
        kind: WrJdFieldKind.line,
      ),
      WrJdField(
        column: 'department',
        label: tr('Bộ phận / Phòng ban', 'Team / department'),
        hint: tr('VD: Phòng Kinh doanh', 'e.g. Sales'),
        kind: WrJdFieldKind.line,
      ),
      WrJdField(
        column: 'reports_to',
        label: tr('Báo cáo trực tiếp cho', 'Reports to'),
        hint: tr('VD: Trưởng phòng Kinh doanh', 'e.g. Sales Manager'),
        kind: WrJdFieldKind.line,
      ),
      WrJdField(
        column: 'seniority',
        label: tr('Cấp bậc / Thâm niên', 'Level / seniority'),
        hint: tr('VD: Nhân viên chính thức, 2 năm kinh nghiệm', 'e.g. Permanent staff, 2 years of experience'),
        kind: WrJdFieldKind.line,
      ),
      WrJdField(
        column: 'purpose',
        label: tr('Vì sao vị trí này tồn tại?', 'Why does this role exist?'),
        hint: tr('Viết mục tiêu công việc của bạn...', 'Write the purpose of your role...'),
        guide: tr('Cách viết: Tóm tắt 1-2 câu. Trả lời: "Nếu vị trí này không tồn '
            'tại, công ty sẽ thiếu điều gì?"', 'How to write it: One or two sentences. Answer: "If this role did '
            'not exist, what would the company be missing?"'),
        example: tr('Đảm bảo đơn hàng của khách được xử lý chính xác, đúng hạn.', 'Make sure customer orders are handled accurately and on time.'),
      ),
    ],
  ),
  WrJdDay(
    number: 3,
    title: tr('Nhiệm vụ chính', 'Main duties'),
    eyebrow: tr('Bước 3 / 5 · khoảng 3 phút', 'Step 3 / 5 · about 3 minutes'),
    fields: [
      WrJdField(
        column: 'main_tasks',
        label: tr('Những nhiệm vụ chính bạn đang làm là gì?', 'What are the main things you do?'),
        hint: tr('Liệt kê nhiệm vụ chính, mỗi dòng một việc...', 'List your main duties, one per line...'),
        kind: WrJdFieldKind.list,
        // §6: "đã bỏ việc chia % theo mảng ra khỏi luồng chính, để riêng thành
        // tính năng nâng cao". Câu hướng dẫn vẫn nhắc tới nó để người kiêm
        // nhiệm nhiều mảng biết là chưa bị bỏ quên.
        guide: tr('Cách viết: Liệt kê mỗi dòng một nhiệm vụ, bắt đầu bằng động từ '
            'hành động (xử lý, tổng hợp, phối hợp...). Nếu kiêm nhiệm nhiều '
            'mảng, có thể tách theo mảng ở bước nâng cao sau.', 'How to write it: One duty per line, starting with an action verb '
            '(handle, compile, coordinate...). If you cover several areas, you '
            'can split them by area in the advanced step later.'),
        example: tr('Xử lý đơn hàng và khiếu nại khách hàng. Tổng hợp báo cáo '
            'doanh số tuần. Phối hợp với kho vận để xác nhận tồn kho.', 'Handle orders and customer complaints. Compile the weekly sales '
            'report. Coordinate with the warehouse to confirm stock.'),
      ),
    ],
  ),
  WrJdDay(
    number: 4,
    title: tr('Kết quả & kỹ năng', 'Results & skills'),
    eyebrow: tr('Bước 4 / 5 · khoảng 3 phút', 'Step 4 / 5 · about 3 minutes'),
    fields: [
      WrJdField(
        column: 'outcomes',
        label: tr('Kết quả cụ thể công việc của bạn tạo ra là gì?', 'What concrete results does your work produce?'),
        hint: tr('Viết kết quả và chỉ số công việc của bạn...', 'Write your results and the numbers behind them...'),
        guide: tr('Cách viết: Càng có số liệu càng tốt. Nếu công ty chưa giao KPI '
            'chính thức, hãy tự ước lượng dựa trên thực tế.', 'How to write it: Numbers help. If the company has not set formal '
            'KPIs, estimate from what actually happens.'),
        example: tr('Xử lý trung bình 40 đơn/ngày, tỷ lệ giao đúng hạn từ 95% trở '
            'lên.', 'Handle around 40 orders a day, with on-time delivery at 95% or '
            'better.'),
      ),
      WrJdField(
        column: 'skills',
        label: tr('Kiến thức, kỹ năng và công cụ bạn dùng?', 'What knowledge, skills and tools do you use?'),
        hint: tr('Viết kỹ năng và công cụ bạn đang sử dụng...', 'Write the skills and tools you actually use...'),
        guide: tr('Cách viết: Chia thành kỹ năng chuyên môn, kỹ năng mềm, và phần '
            'mềm/công cụ đang dùng thực tế.', 'How to write it: Split it into technical skills, people skills, '
            'and the software or tools you really use.'),
      ),
    ],
  ),
  WrJdDay(
    number: 5,
    title: tr('Mối quan hệ & điều kiện làm việc', 'Working relationships & conditions'),
    eyebrow: tr('Bước 5 / 5 · khoảng 2 phút', 'Step 5 / 5 · about 2 minutes'),
    fields: [
      WrJdField(
        column: 'collaborators',
        label: tr('Bạn phối hợp với ai trong công việc?', 'Who do you work with?'),
        hint: tr('Viết những phòng ban, đồng nghiệp hoặc đối tác bạn thường làm '
            'việc cùng...', 'Write the teams, colleagues or partners you usually work '
            'with...'),
        example: tr('Phối hợp thường xuyên với phòng Kho vận, Kế toán; làm việc '
            'trực tiếp với khách qua điện thoại.', 'Work closely with Warehouse and Accounting; deal with customers '
            'directly by phone.'),
      ),
      WrJdField(
        column: 'work_conditions',
        label: tr('Điều kiện làm việc của bạn ra sao?', 'What are your working conditions?'),
        hint: tr('Viết giờ làm việc, địa điểm, yêu cầu đặc thù nếu có...', 'Write your hours, location, and any particular requirements...'),
        example: tr('Làm giờ hành chính tại văn phòng, thỉnh thoảng tăng ca cuối '
            'tháng để chốt báo cáo.', 'Office hours at the office, with occasional overtime at month '
            'end to close the reports.'),
      ),
    ],
  ),
];

/// Câu chốt ở cuối bước 5, nguyên văn mockup.
///
/// §6: "kết thúc bằng banner xác nhận hoàn tất, giải thích dữ liệu sẽ được dùng
/// để cá nhân hoá gợi ý sau này". Nói ra dữ liệu đi đâu là điều kiện để người
/// dùng thấy việc viết năm bước có nghĩa.
String get kJdCompletionNote => tr('JD của bạn sẽ được lưu vào hồ sơ, giúp gợi ý phản chiếu và Cơ hội phát '
    'triển bám sát đúng công việc thật hơn.', 'Your JD is saved to your profile, so reflection prompts and Growth '
    'opportunities sit closer to the job you actually do.');

/// Toàn bộ cột nội dung, theo đúng thứ tự các bước.
List<String> jdColumns() => [
      for (final day in kJdDays)
        for (final f in day.fields) f.column,
    ];

/// Bước [day] có mở được không.
///
/// §6, ghi chú cho dev: "bản thật nên khoá bước sau cho đến khi hoàn thành bước
/// trước, không cho nhảy cóc tự do."
///
/// Ba luật, theo đúng thứ tự:
///   · bước 1 luôn mở — không có gì đứng trước nó,
///   · bước đã hoàn thành thì luôn mở lại được, kể cả khi làm không đúng thứ tự
///     (dữ liệu cũ, hoặc người dùng đã đi qua rồi quay lại sửa),
///   · còn lại: chỉ mở khi bước liền trước đã xong.
///
/// Khoá theo bước LIỀN TRƯỚC chứ không theo "tất cả các bước trước": một bản
/// ghi cũ thiếu bước 2 nhưng đã có bước 3, 4 thì luật kia sẽ khoá vĩnh viễn
/// bước 5 và người dùng không còn đường đi tiếp.
bool canOpenJdDay(int day, List<int> completedDays) {
  if (day < 1 || day > kJdDayCount) return false;
  if (day == 1) return true;
  if (completedDays.contains(day)) return true;
  return completedDays.contains(day - 1);
}

/// Bước nên mở khi người dùng vào lại màn.
///
/// Bước dở dang đang lưu, trừ khi nó đã bị khoá (dữ liệu lệch) — lúc đó lùi về
/// bước chưa xong đầu tiên còn mở được. Không bao giờ trả về một bước khoá:
/// mở màn ra ở một bước không bấm được gì là ngõ cụt.
int resumeJdDay(int currentDay, List<int> completedDays) {
  if (canOpenJdDay(currentDay, completedDays) &&
      !completedDays.contains(currentDay)) {
    return currentDay;
  }
  for (var d = 1; d <= kJdDayCount; d++) {
    if (!completedDays.contains(d) && canOpenJdDay(d, completedDays)) return d;
  }
  // Đã xong cả năm bước — mở lại bước cuối để đọc lại và sửa.
  return kJdDayCount;
}

/// Đã đi hết năm bước chưa.
bool isJdComplete(List<int> completedDays) =>
    List.generate(kJdDayCount, (i) => i + 1)
        .every(completedDays.contains);

/// Thêm [day] vào danh sách đã hoàn thành, không nhân đôi, giữ thứ tự tăng dần.
List<int> markJdDayDone(int day, List<int> completedDays) {
  if (completedDays.contains(day)) return completedDays;
  return [...completedDays, day]..sort();
}

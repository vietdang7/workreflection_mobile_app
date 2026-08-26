// "Viết JD cùng app" — 5 buổi ngắn.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §6, mockup v16 `screenJdBuilder`.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.
//
// ---------------------------------------------------------------------------
// Vì sao chia 5 buổi
// ---------------------------------------------------------------------------
//
// §6: "Dành cho người dùng mà công ty chưa có JD sẵn. Thay vì đưa nguyên form
// tư vấn 8 trường vào app trong một lần, chia thành 5 buổi ngắn (2–3 phút/buổi),
// có thể làm rải rác trong tuần."
//
// Cách chia không tuỳ tiện: buổi 1 KHÔNG hỏi trường JD nào cả, chỉ ba câu đời
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
//   1. "Thanh nút Buổi 1–5 ở cuối màn hình chỉ phục vụ xem trước cho demo —
//      bản thật nên khoá buổi sau cho đến khi hoàn thành buổi trước, không cho
//      nhảy cóc tự do."                              → [canOpenJdDay]
//   2. "Nút Dừng ở đây, làm tiếp sau hiện CHƯA lưu dữ liệu đã nhập (chỉ là
//      demo) — cần thiết kế cơ chế lưu nháp thật."   → `WrJdRepository.save`
//   3. "Dữ liệu JD cần một cấu trúc lưu trữ thống nhất (không chỉ local
//      state)."                                     → bảng `wr_jd_drafts`

/// Một buổi trong luồng.
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

  /// Tiêu đề buổi, nguyên văn mockup.
  final String title;

  /// Nhãn nhỏ phía trên tiêu đề, gồm cả thời lượng ước tính.
  final String eyebrow;

  /// Đoạn dẫn ở đầu buổi. Chỉ buổi 1 có — nó phải giải thích vì sao đang hỏi
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

/// Một ô trong một buổi.
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

/// Tổng số buổi.
const int kJdDayCount = 5;

/// Năm buổi, nguyên văn nội dung mockup v16 `screenJdBuilder`.
const List<WrJdDay> kJdDays = [
  WrJdDay(
    number: 1,
    title: 'Khởi động',
    eyebrow: 'Buổi 1 trên 5 · khoảng 2 phút',
    intro: 'Nếu chưa quen viết JD, đừng bắt đầu từ những trường chuẩn. Trả lời '
        'tự do vài câu hỏi đời thường sau, câu trả lời sẽ là nguyên liệu cho '
        'các buổi sau.',
    fields: [
      WrJdField(
        column: 'warmup_repeated',
        label: 'Việc gì bạn lặp đi lặp lại mỗi ngày, mỗi tuần?',
        hint: 'Ví dụ: Sáng nào cũng kiểm tra đơn hàng mới, gọi xác nhận với '
            'khách...',
      ),
      WrJdField(
        column: 'warmup_blocked',
        label: 'Nếu bạn nghỉ phép một tuần, việc gì sẽ bị ùn lại vì không ai '
            'làm thay?',
        hint: 'Ví dụ: Không ai xử lý được khiếu nại của khách vì chỉ mình mình '
            'biết quy trình...',
      ),
      WrJdField(
        column: 'warmup_asked_about',
        label: 'Đồng nghiệp hoặc sếp thường nhờ/hỏi bạn về việc gì nhất?',
        hint: 'Ví dụ: Sếp hay hỏi mình về tình trạng đơn hàng trễ...',
      ),
    ],
  ),
  WrJdDay(
    number: 2,
    title: 'Vị trí & mục tiêu',
    eyebrow: 'Buổi 2 trên 5 · khoảng 3 phút',
    fields: [
      WrJdField(
        column: 'job_title',
        label: 'Chức danh công việc',
        hint: 'VD: Nhân viên Chăm sóc khách hàng',
        kind: WrJdFieldKind.line,
      ),
      WrJdField(
        column: 'department',
        label: 'Bộ phận / Phòng ban',
        hint: 'VD: Phòng Kinh doanh',
        kind: WrJdFieldKind.line,
      ),
      WrJdField(
        column: 'reports_to',
        label: 'Báo cáo trực tiếp cho',
        hint: 'VD: Trưởng phòng Kinh doanh',
        kind: WrJdFieldKind.line,
      ),
      WrJdField(
        column: 'seniority',
        label: 'Cấp bậc / Thâm niên',
        hint: 'VD: Nhân viên chính thức, 2 năm kinh nghiệm',
        kind: WrJdFieldKind.line,
      ),
      WrJdField(
        column: 'purpose',
        label: 'Vì sao vị trí này tồn tại?',
        hint: 'Viết mục tiêu công việc của bạn...',
        guide: 'Cách viết: Tóm tắt 1-2 câu. Trả lời: "Nếu vị trí này không tồn '
            'tại, công ty sẽ thiếu điều gì?"',
        example: 'Đảm bảo đơn hàng của khách được xử lý chính xác, đúng hạn.',
      ),
    ],
  ),
  WrJdDay(
    number: 3,
    title: 'Nhiệm vụ chính',
    eyebrow: 'Buổi 3 trên 5 · khoảng 3 phút',
    fields: [
      WrJdField(
        column: 'main_tasks',
        label: 'Những nhiệm vụ chính bạn đang làm là gì?',
        hint: 'Liệt kê nhiệm vụ chính, mỗi dòng một việc...',
        kind: WrJdFieldKind.list,
        // §6: "đã bỏ việc chia % theo mảng ra khỏi luồng chính, để riêng thành
        // tính năng nâng cao". Câu hướng dẫn vẫn nhắc tới nó để người kiêm
        // nhiệm nhiều mảng biết là chưa bị bỏ quên.
        guide: 'Cách viết: Liệt kê mỗi dòng một nhiệm vụ, bắt đầu bằng động từ '
            'hành động (xử lý, tổng hợp, phối hợp...). Nếu kiêm nhiệm nhiều '
            'mảng, có thể tách theo mảng ở bước nâng cao sau.',
        example: 'Xử lý đơn hàng và khiếu nại khách hàng. Tổng hợp báo cáo '
            'doanh số tuần. Phối hợp với kho vận để xác nhận tồn kho.',
      ),
    ],
  ),
  WrJdDay(
    number: 4,
    title: 'Kết quả & kỹ năng',
    eyebrow: 'Buổi 4 trên 5 · khoảng 3 phút',
    fields: [
      WrJdField(
        column: 'outcomes',
        label: 'Kết quả cụ thể công việc của bạn tạo ra là gì?',
        hint: 'Viết kết quả và chỉ số công việc của bạn...',
        guide: 'Cách viết: Càng có số liệu càng tốt. Nếu công ty chưa giao KPI '
            'chính thức, hãy tự ước lượng dựa trên thực tế.',
        example: 'Xử lý trung bình 40 đơn/ngày, tỷ lệ giao đúng hạn từ 95% trở '
            'lên.',
      ),
      WrJdField(
        column: 'skills',
        label: 'Kiến thức, kỹ năng và công cụ bạn dùng?',
        hint: 'Viết kỹ năng và công cụ bạn đang sử dụng...',
        guide: 'Cách viết: Chia thành kỹ năng chuyên môn, kỹ năng mềm, và phần '
            'mềm/công cụ đang dùng thực tế.',
      ),
    ],
  ),
  WrJdDay(
    number: 5,
    title: 'Mối quan hệ & điều kiện làm việc',
    eyebrow: 'Buổi 5 trên 5 · khoảng 2 phút',
    fields: [
      WrJdField(
        column: 'collaborators',
        label: 'Bạn phối hợp với ai trong công việc?',
        hint: 'Viết những phòng ban, đồng nghiệp hoặc đối tác bạn thường làm '
            'việc cùng...',
        example: 'Phối hợp thường xuyên với phòng Kho vận, Kế toán; làm việc '
            'trực tiếp với khách qua điện thoại.',
      ),
      WrJdField(
        column: 'work_conditions',
        label: 'Điều kiện làm việc của bạn ra sao?',
        hint: 'Viết giờ làm việc, địa điểm, yêu cầu đặc thù nếu có...',
        example: 'Làm giờ hành chính tại văn phòng, thỉnh thoảng tăng ca cuối '
            'tháng để chốt báo cáo.',
      ),
    ],
  ),
];

/// Câu chốt ở cuối buổi 5, nguyên văn mockup.
///
/// §6: "kết thúc bằng banner xác nhận hoàn tất, giải thích dữ liệu sẽ được dùng
/// để cá nhân hoá gợi ý sau này". Nói ra dữ liệu đi đâu là điều kiện để người
/// dùng thấy việc viết năm buổi có nghĩa.
const String kJdCompletionNote =
    'JD của bạn sẽ được lưu vào hồ sơ, giúp gợi ý phản chiếu và Cơ hội phát '
    'triển bám sát đúng công việc thật hơn.';

/// Toàn bộ cột nội dung, theo đúng thứ tự các buổi.
List<String> jdColumns() => [
      for (final day in kJdDays)
        for (final f in day.fields) f.column,
    ];

/// Buổi [day] có mở được không.
///
/// §6, ghi chú cho dev: "bản thật nên khoá buổi sau cho đến khi hoàn thành buổi
/// trước, không cho nhảy cóc tự do."
///
/// Ba luật, theo đúng thứ tự:
///   · buổi 1 luôn mở — không có gì đứng trước nó,
///   · buổi đã hoàn thành thì luôn mở lại được, kể cả khi làm không đúng thứ tự
///     (dữ liệu cũ, hoặc người dùng đã đi qua rồi quay lại sửa),
///   · còn lại: chỉ mở khi buổi liền trước đã xong.
///
/// Khoá theo buổi LIỀN TRƯỚC chứ không theo "tất cả các buổi trước": một bản
/// ghi cũ thiếu buổi 2 nhưng đã có buổi 3, 4 thì luật kia sẽ khoá vĩnh viễn
/// buổi 5 và người dùng không còn đường đi tiếp.
bool canOpenJdDay(int day, List<int> completedDays) {
  if (day < 1 || day > kJdDayCount) return false;
  if (day == 1) return true;
  if (completedDays.contains(day)) return true;
  return completedDays.contains(day - 1);
}

/// Buổi nên mở khi người dùng vào lại màn.
///
/// Buổi dở dang đang lưu, trừ khi nó đã bị khoá (dữ liệu lệch) — lúc đó lùi về
/// buổi chưa xong đầu tiên còn mở được. Không bao giờ trả về một buổi khoá:
/// mở màn ra ở một buổi không bấm được gì là ngõ cụt.
int resumeJdDay(int currentDay, List<int> completedDays) {
  if (canOpenJdDay(currentDay, completedDays) &&
      !completedDays.contains(currentDay)) {
    return currentDay;
  }
  for (var d = 1; d <= kJdDayCount; d++) {
    if (!completedDays.contains(d) && canOpenJdDay(d, completedDays)) return d;
  }
  // Đã xong cả năm buổi — mở lại buổi cuối để đọc lại và sửa.
  return kJdDayCount;
}

/// Đã đi hết năm buổi chưa.
bool isJdComplete(List<int> completedDays) =>
    List.generate(kJdDayCount, (i) => i + 1)
        .every(completedDays.contains);

/// Thêm [day] vào danh sách đã hoàn thành, không nhân đôi, giữ thứ tự tăng dần.
List<int> markJdDayDone(int day, List<int> completedDays) {
  if (completedDays.contains(day)) return completedDays;
  return [...completedDays, day]..sort();
}

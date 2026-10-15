// Bản công bố việc gửi dữ liệu sang dịch vụ AI bên thứ ba.
//
// ---------------------------------------------------------------------------
// VÌ SAO CÓ FILE NÀY
//
// App Store từ chối bản 1.0 (6) ngày 06/09/2026 theo Guideline 5.1.1(i) và
// 5.1.2(i). Apple liệt kê bốn điều kiện, app phải làm ĐỦ CẢ BỐN thì mới được
// gửi dữ liệu cá nhân đi:
//
//   • Nói rõ dữ liệu gì sẽ được gửi.
//   • Nêu đích danh gửi cho ai.
//   • Xin phép người dùng TRƯỚC khi gửi.
//   • Chính sách quyền riêng tư ghi rõ thu thập gì, thu thập kiểu nào, dùng vào
//     việc gì, và bên thứ ba có mức bảo vệ tương đương.
//
// Và Apple nói thẳng một câu nữa, chính là câu bản trước đã trượt:
//
//   Note that only including this information in the app's Terms of Service or
//   Privacy Policy is not sufficient.
//
// Nghĩa là màn hình này KHÔNG thay thế được bằng một dòng link tới trang chính
// sách. Nó phải nằm trong app, phải đọc được trước khi bất cứ dữ liệu nào rời
// máy, và phải có một hành động đồng ý rõ ràng.
//
// ---------------------------------------------------------------------------
// NỘI DUNG PHẢI ĐÚNG SỰ THẬT, KHÔNG PHẢI ĐÚNG VĂN PHONG
//
// Mọi dòng dưới đây đã đối chiếu với mã nguồn thật:
//
//   `supabase/functions/wr-chat/user_context.ts`   — các bảng nạp vào ngữ cảnh
//   `supabase/functions/wr-doc-analyze/index.ts`   — đọc JD/CV
//   `supabase/functions/wr-narrative/index.ts`     — sinh Diễn biến
//   `supabase/functions/wr-experience-read/index.ts` — "Bạn đang khó ở chỗ nào"
//   `lib/features/video_report/data/…`             — đọc thành tiếng
//   `ai-personalize` (Edge Function, không nằm trong repo này) — viết lại phần
//                                                    nhận định của Báo cáo
//
// Luồng `ai-personalize` LỌT khỏi lần rà 07/09/2026 và chỉ lộ ra ngày
// 09/09 khi soát lại trước lúc nộp. Bài học: lần đó chỉ đọc
// `supabase/functions/` của repo này, mà hàm kia là di sản từ bản web — deploy
// trên cùng project Supabase, `verify_jwt=false`, không có tệp nguồn ở đây.
// Muốn biết app gửi gì đi đâu thì phải quét theo ĐIỂM GỌI trong `lib/`
// (`functions.invoke`, URL ngoài), không phải theo thư mục mã nguồn có sẵn.
//
// Đối chiếu 07/09/2026 cho thấy `cc_profiles` chỉ được đọc đúng cột `role` để
// biết gói Free hay Premium, và cột đó KHÔNG đi kèm sang model. Nên câu "không
// gửi tên và email" là nói thật, không phải nói cho êm tai. Sửa mã nguồn mà
// không sửa file này là biến bản công bố thành lời khai sai.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../l10n/wr_tr.dart';

/// Phiên bản bản công bố.
///
/// Nâng số này khi nội dung đổi về BẢN CHẤT — thêm một bên nhận dữ liệu, hoặc
/// gửi thêm một loại dữ liệu. Cả app sẽ hỏi lại những người đã đồng ý bản cũ.
///
/// KHÔNG nâng khi chỉ sửa câu chữ cho dễ đọc: hỏi lại vì một dấu phẩy là dạy
/// người dùng bấm "Đồng ý" mà không đọc, và như thế thì lần hỏi nào cũng vô
/// nghĩa.
///
/// Lên 3 ngày 15/10/2026: mọi luồng AI chuyển hẳn sang DeepSeek, bỏ OpenRouter
/// và Gemini. Tài liệu JD/CV và hồ sơ Báo cáo khảo sát giờ tới DeepSeek thay
/// vì Google, nên người đã đồng ý bản cũ được hỏi lại.
///
/// Phía máy chủ (`_shared/ai_consent.ts`) CỐ Ý vẫn nhận từ bản 2: nâng ở đó
/// trước khi bản app mới lên kho là cắt hết AI của người đang dùng bản cũ —
/// app cũ không có màn nào để đồng ý bản 3.
const int kWrAiDisclosureVersion = 3;

/// Một việc app làm có gửi dữ liệu ra ngoài.
class WrAiDataFlow {
  const WrAiDataFlow({
    required this.trigger,
    required this.data,
    required this.recipient,
  });

  /// Việc người dùng làm khiến dữ liệu được gửi đi.
  final String trigger;

  /// Dữ liệu cụ thể được gửi.
  final String data;

  /// Tên bên nhận, khớp với [kWrAiRecipients].
  final String recipient;
}

/// Một bên thứ ba nhận dữ liệu.
class WrAiRecipient {
  const WrAiRecipient({
    required this.name,
    required this.role,
    required this.privacyUrl,
  });

  final String name;

  /// Bên này làm gì với dữ liệu.
  final String role;

  /// Trang chính sách quyền riêng tư của chính bên đó.
  ///
  /// Apple đòi xác nhận bên thứ ba có mức bảo vệ tương đương; đường dẫn này để
  /// người dùng tự kiểm chứ không phải tin lời app.
  final String privacyUrl;
}

/// Các bên nhận dữ liệu.
///
/// Từ 15/10/2026 app gọi thẳng DeepSeek, không còn bên trung chuyển
/// (OpenRouter) hay mô hình thứ hai (Gemini).
///
/// Getter chứ không phải `const`: [WrAiRecipient.role] đi qua `tr()`, giữ
/// trong một hằng thì đóng băng ở ngôn ngữ lúc đọc lần đầu.
List<WrAiRecipient> get kWrAiRecipients => [
  WrAiRecipient(
    name: 'DeepSeek',
    role: tr(
      'Mô hình AI duy nhất của app: trả lời trong phần Trò chuyện, viết phần '
          'Diễn biến và phần Bạn đang khó ở chỗ nào, đọc tài liệu JD và CV, '
          'và viết phần nhận định của Báo cáo khảo sát.',
      'The app\'s only AI model: it replies in Chat, writes your story and '
          'Where it is hard for you, reads your JD and CV documents, and '
          'writes the commentary in the Survey report.',
    ),
    // KHÔNG phải `deepseek.com/privacy` — đường đó trả 404 (kiểm 07/09/2026).
    // Một liên kết chết ngay trong công bố quyền riêng tư còn tệ hơn không có.
    privacyUrl:
        'https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html',
  ),
  WrAiRecipient(
    name: 'Ausynclab',
    role: tr(
      'Chuyển đoạn chữ thành giọng nói khi bạn bật nghe.',
      'Turns text into speech when you switch on listening.',
    ),
    // Trỏ đúng văn bản cam kết, không trỏ trang chủ: dán nhãn "Chính sách
    // quyền riêng tư" lên một trang giới thiệu sản phẩm là nói không đúng.
    privacyUrl:
        'https://ausynclab.io/documents/ausynclab-information-commitment.pdf',
  ),
];

/// Từng luồng dữ liệu, nói theo việc người dùng làm chứ không theo tên hàm.
///
/// Người đọc màn hình này đang quyết định một chuyện về dữ liệu của họ. "Gọi
/// Edge Function wr-doc-analyze" không giúp họ quyết được gì; "khi bạn tải JD
/// lên để đọc" thì có.
List<WrAiDataFlow> get kWrAiDataFlows => [
  WrAiDataFlow(
    trigger: tr(
      'Khi bạn trò chuyện với trợ lý phản chiếu',
      'When you chat with the reflection assistant',
    ),
    data: tr(
      'Câu bạn vừa viết, các lượt trước trong cùng cuộc trò chuyện, và tóm '
          'tắt những điều bạn đã nhìn lại gần đây: tình huống bạn ghi, phần đọc, '
          'chủ đề đang thực hành, kết quả tự đánh giá.',
      'What you just wrote, the earlier turns in the same conversation, and a '
          'summary of what you have looked back on recently: the situations you '
          'logged, readings, the themes you are practising, your self-assessment '
          'results.',
    ),
    recipient: 'DeepSeek',
  ),
  WrAiDataFlow(
    trigger: tr(
      'Khi bạn tải JD hoặc CV lên để đọc',
      'When you upload a JD or CV to be read',
    ),
    data: tr(
      'Toàn bộ nội dung tài liệu đó, kể cả phần bạn không nhắc tới trong '
          'app.',
      'The whole document, including parts you never mention in the app.',
    ),
    recipient: 'DeepSeek',
  ),
  WrAiDataFlow(
    trigger: tr(
      'Khi phần mềm viết mục Diễn biến',
      'When the app writes your story',
    ),
    data: tr(
      'Các tình huống bạn đã ghi lại theo thời gian. Việc này chạy tự động '
          'khi bạn mở mục đó, không cần bạn bấm gì.',
      'The situations you have logged over time. This runs automatically '
          'when you open that screen, without you tapping anything.',
    ),
    recipient: 'DeepSeek',
  ),
  // `wr-experience-read` (15/10/2026). Cùng bên nhận và cùng loại dữ liệu với
  // mục Diễn biến (tình huống đã ghi + dòng tự viết), nên không nâng
  // [kWrAiDisclosureVersion]; nhưng vẫn khai riêng vì nó chạy ở một màn khác.
  WrAiDataFlow(
    trigger: tr(
      'Khi phần mềm viết mục "Bạn đang khó ở chỗ nào"',
      'When the app writes "Where it is hard for you"',
    ),
    data: tr(
      'Những tình huống đang quay lại trong một nhóm trải nghiệm, số lần, và '
          'các dòng bạn đã tự viết cho chúng. Việc này chạy tự động khi bạn mở '
          'phần Trải nghiệm của bạn, không cần bạn bấm gì.',
      'The situations that keep coming back in a group of experience, how '
          'often, and the lines you wrote for them. This runs automatically '
          'when you open Your experience, without you tapping anything.',
    ),
    recipient: 'DeepSeek',
  ),
  WrAiDataFlow(
    trigger: tr(
      'Khi bạn bật nghe đọc thành tiếng',
      'When you switch on read-aloud',
    ),
    data: tr('Đoạn chữ đang được đọc.', 'The text being read aloud.'),
    recipient: 'Ausynclab',
  ),
  WrAiDataFlow(
    trigger: tr(
      'Khi bạn mở Báo cáo khảo sát',
      'When you open the Survey report',
    ),
    data: tr(
      'Vị trí công việc, thâm niên và phòng ban bạn đã khai, cùng điểm ba '
          'lớp, điểm tổng, chỉ số ESI và lớp đang yếu nhất. Dùng để viết lại phần '
          'nhận định cho hợp với hoàn cảnh của bạn. Việc này chạy tự động khi bạn '
          'mở báo cáo, không cần bạn bấm gì.',
      'The job title, seniority and department you entered, plus your three '
          'layer scores, overall score, ESI and weakest layer. Used to rewrite '
          'the commentary to fit your situation. This runs automatically when '
          'you open the report, without you tapping anything.',
    ),
    recipient: 'DeepSeek',
  ),
];

/// Những thứ KHÔNG bao giờ được gửi.
///
/// Nói ra phần này vì nó là thứ người dùng thật sự lo, và vì nó đúng — đã đối
/// chiếu mã nguồn 07/09/2026.
List<String> get kWrAiNeverSent => [
  tr('Tên và địa chỉ email của bạn', 'Your name and email address'),
  tr('Mật khẩu', 'Your password'),
  tr('Thông tin thanh toán', 'Payment details'),
  tr('Ảnh đại diện', 'Your profile photo'),
];

/// Câu tóm tắt một dòng, dùng ở chỗ chật như thẻ nhắc trên màn Tài khoản.
String get kWrAiDisclosureSummary => tr(
  'Một số phần của app gửi nội dung bạn viết sang dịch vụ AI bên ngoài để xử '
      'lý. Bạn quyết định có cho phép hay không.',
  'Some parts of the app send what you write to outside AI services for '
      'processing. You decide whether to allow it.',
);

/// Câu nói rõ người dùng đổi ý được bất cứ lúc nào.
///
/// Không phải chữ cho đẹp: quyền rút lại là thứ phải có thật, và [kWrAiRevokePath]
/// dưới đây là chỗ nó nằm.
String get kWrAiRevokeNote => tr(
  'Bạn tắt lại bất cứ lúc nào trong Tài khoản → Xử lý dữ liệu bằng AI. Tắt '
      'rồi thì những phần cần AI sẽ ngừng hoạt động, phần còn lại của app vẫn '
      'dùng bình thường.',
  'You can switch this off at any time in Account → AI data processing. Once '
      'it is off, the parts that need AI stop working and the rest of the app '
      'works as usual.',
);

/// Đường dẫn màn quản lý lựa chọn này.
const String kWrAiRevokePath = '/wr/ai-consent';

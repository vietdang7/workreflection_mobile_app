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

/// Phiên bản bản công bố.
///
/// Nâng số này khi nội dung đổi về BẢN CHẤT — thêm một bên nhận dữ liệu, hoặc
/// gửi thêm một loại dữ liệu. Cả app sẽ hỏi lại những người đã đồng ý bản cũ.
///
/// KHÔNG nâng khi chỉ sửa câu chữ cho dễ đọc: hỏi lại vì một dấu phẩy là dạy
/// người dùng bấm "Đồng ý" mà không đọc, và như thế thì lần hỏi nào cũng vô
/// nghĩa.
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
/// Từ 09/09/2026 chỉ còn MỘT bên: các Edge Function gọi thẳng Google, không đi
/// qua OpenRouter nữa, và DeepSeek không còn nằm trên đường đi. Trước đó phải
/// kể ba tên vì OpenRouter chỉ là bên trung chuyển — ghi mỗi "gửi cho
/// OpenRouter" là giấu mất chuyện dữ liệu đi tiếp sang DeepSeek và Google.
///
/// Danh sách này phải khớp với mã nguồn của cả bốn Edge Function. Đổi nhà cung
/// cấp mà quên sửa đây là biến bản công bố thành lời khai sai — với người dùng
/// và với Apple.
const List<WrAiRecipient> kWrAiRecipients = [
  WrAiRecipient(
    name: 'Google (Gemini)',
    role: 'Mô hình trả lời trong phần Trò chuyện, viết phần Diễn biến, đọc tài '
        'liệu JD/CV bạn tải lên và viết lại phần nhận định của Báo cáo.',
    privacyUrl: 'https://policies.google.com/privacy',
  ),
  WrAiRecipient(
    name: 'Ausynclab',
    role: 'Chuyển đoạn chữ thành giọng nói khi bạn bật nghe.',
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
const List<WrAiDataFlow> kWrAiDataFlows = [
  WrAiDataFlow(
    trigger: 'Khi bạn trò chuyện với trợ lý phản chiếu',
    data: 'Câu bạn vừa viết, các lượt trước trong cùng cuộc trò chuyện, và tóm '
        'tắt những điều bạn đã nhìn lại gần đây: tình huống bạn ghi, insight, '
        'chủ đề đang thực hành, kết quả tự đánh giá.',
    recipient: 'Google (Gemini)',
  ),
  WrAiDataFlow(
    trigger: 'Khi bạn tải JD hoặc CV lên để đọc',
    data: 'Toàn bộ nội dung tài liệu đó, kể cả phần bạn không nhắc tới trong '
        'app.',
    recipient: 'Google (Gemini)',
  ),
  WrAiDataFlow(
    trigger: 'Khi phần mềm viết mục Diễn biến',
    data: 'Các tình huống bạn đã ghi lại theo thời gian. Việc này chạy tự động '
        'khi bạn mở mục đó, không cần bạn bấm gì.',
    recipient: 'Google (Gemini)',
  ),
  WrAiDataFlow(
    trigger: 'Khi bạn bật nghe đọc thành tiếng',
    data: 'Đoạn chữ đang được đọc.',
    recipient: 'Ausynclab',
  ),
  WrAiDataFlow(
    trigger: 'Khi bạn mở Báo cáo khảo sát',
    data: 'Vị trí công việc, thâm niên và phòng ban bạn đã khai, cùng điểm ba '
        'lớp, điểm tổng, chỉ số ESI và lớp đang yếu nhất. Dùng để viết lại phần '
        'nhận định cho hợp với hoàn cảnh của bạn. Việc này chạy tự động khi bạn '
        'mở báo cáo, không cần bạn bấm gì.',
    recipient: 'Google (Gemini)',
  ),
];

/// Những thứ KHÔNG bao giờ được gửi.
///
/// Nói ra phần này vì nó là thứ người dùng thật sự lo, và vì nó đúng — đã đối
/// chiếu mã nguồn 07/09/2026.
const List<String> kWrAiNeverSent = [
  'Tên và địa chỉ email của bạn',
  'Mật khẩu',
  'Thông tin thanh toán',
  'Ảnh đại diện',
];

/// Câu tóm tắt một dòng, dùng ở chỗ chật như thẻ nhắc trên màn Tài khoản.
const String kWrAiDisclosureSummary =
    'Một số phần của app gửi nội dung bạn viết sang dịch vụ AI bên ngoài để xử '
    'lý. Bạn quyết định có cho phép hay không.';

/// Câu nói rõ người dùng đổi ý được bất cứ lúc nào.
///
/// Không phải chữ cho đẹp: quyền rút lại là thứ phải có thật, và [kWrAiRevokePath]
/// dưới đây là chỗ nó nằm.
const String kWrAiRevokeNote =
    'Bạn tắt lại bất cứ lúc nào trong Tài khoản → Xử lý dữ liệu bằng AI. Tắt '
    'rồi thì những phần cần AI sẽ ngừng hoạt động, phần còn lại của app vẫn '
    'dùng bình thường.';

/// Đường dẫn màn quản lý lựa chọn này.
const String kWrAiRevokePath = '/wr/ai-consent';

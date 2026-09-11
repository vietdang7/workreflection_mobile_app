// Bản tiếng Anh cho phần WorkReflection.
//
// ---------------------------------------------------------------------------
// Vì sao KHÔNG đưa tất cả vào `.arb` như nửa còn lại của app
// ---------------------------------------------------------------------------
//
// App đang có sẵn `AppLocalizations` sinh từ `lib/l10n/app_vi.arb`, và phần
// onboarding · đăng nhập · khảo sát đi qua nó. Nhưng phần WorkReflection thì
// không: 49 file của phần này không gọi `AppLocalizations` một lần nào, và
// khoảng một nửa câu chữ của nó KHÔNG được dựng trong widget mà được dựng
// trong `lib/core/logic/*.dart` — thư viện câu Diễn giải sâu, câu Self-Check,
// câu tường thuật Story, câu của luồng Reflect.
//
// Những hàm đó là hàm thuần, không có `BuildContext`, nên không với tới
// `AppLocalizations.of(context)` được. Muốn dùng `.arb` thì phải luồn một tham
// số localizations qua khoảng một trăm hàm thuần và toàn bộ bài test đang khoá
// chúng — sửa chữ ký của mọi hàm sinh câu chỉ để đổi chỗ lấy chuỗi.
//
// Nên tầng này: một cặp câu đặt cạnh nhau ngay tại chỗ dùng.
//
//     Text(tr('Tiếp tục', 'Continue'))
//
// Ba cái được:
//   • hàm thuần dùng được, widget cũng dùng được, cùng một cách;
//   • đội nội dung đọc rà bản dịch ngay cạnh bản gốc, không phải nhảy qua lại
//     giữa file mã và hai file `.arb` theo một cái khoá đặt tên;
//   • mặc định là tiếng Việt, nên 2300 bài test đang khoá chuỗi tiếng Việt vẫn
//     xanh nguyên mà không phải sửa bài nào.
//
// Cái mất: không có số nhiều / giống theo ngôn ngữ như ICU của `.arb`. Chấp
// nhận được — hai ngôn ngữ đang hỗ trợ đều không chia giống, còn số nhiều thì
// các câu ở đây đã tự xử lý bằng cách viết lại vế câu.
//
// Phần đã nằm trong `.arb` GIỮ NGUYÊN ở `.arb`. Không chuyển qua đây: chuyển
// là đụng vào phần đang chạy đúng để đổi lấy sự đồng nhất trên giấy.
//
// ---------------------------------------------------------------------------
// Vì sao là biến toàn cục chứ không phải một provider
// ---------------------------------------------------------------------------
//
// Chính vì chỗ gọi là hàm thuần. `ref` cũng không với tới được như
// `BuildContext`. Biến này được `WorkReflectionApp.build` ghi lại mỗi lần
// `appLocaleProvider` đổi, và `main()` ghi lần đầu trước khung hình đầu tiên —
// nên không có cửa sổ nào mà màn hình đã dựng trong khi biến còn giá trị cũ.
library;

/// True khi app đang chạy tiếng Anh.
///
/// Chỉ hai chỗ được ghi: `main()` (giá trị lần đầu, đọc từ bộ nhớ máy) và
/// `WorkReflectionApp.build` (mỗi lần người dùng đổi ngôn ngữ trong Tài khoản).
/// Đọc thì ở đâu cũng được.
bool wrEnglish = false;

/// Chọn giữa bản tiếng Việt và bản tiếng Anh của cùng một câu.
///
/// [vi] là bản gốc — luôn là bản được duyệt nội dung. [en] là bản dịch.
String tr(String vi, String en) => wrEnglish ? en : vi;

/// Như [tr] nhưng cho chữ lấy từ database, nơi bản dịch có thể CHƯA có.
///
/// Khác [tr] ở đúng một điểm, và điểm đó là lý do nó tồn tại: [tr] nhận hai câu
/// do lập trình viên viết nên cả hai chắc chắn có mặt, còn ở đây [en] là một ô
/// trong bảng mà đội nội dung điền dần. Nên chưa điền thì **rơi về tiếng Việt**,
/// không hiện ô trống.
///
/// Coi chuỗi trắng ngang với null: một cột `text` vừa thêm bằng migration có
/// thể mang `''` thay vì NULL tuỳ cách nhập liệu, và người dùng nhìn thấy chip
/// trắng chữ thì không phân biệt được đó là lỗi hay là hết nội dung.
///
/// Nhờ vậy dịch được tới đâu dùng tới đó — không phải chờ dịch xong cả bảng
/// mới bật được lên.
String trDb(String vi, String? en) {
  if (!wrEnglish || en == null) return vi;
  final trimmed = en.trim();
  return trimmed.isEmpty ? vi : trimmed;
}

/// Hạ chữ hoa đầu câu khi một câu độc lập bị nhúng vào GIỮA một câu khác.
///
/// Tình huống trong `wr_situations` được viết như câu đứng một mình ("Tôi cứ ra
/// quyết định theo cảm xúc"), rồi thẻ "Hệ thống nhận ra" nhúng nó vào giữa:
/// *Bạn đã gặp tình huống "…" 2 lần*. Tiếng Việt không viết hoa giữa câu, nên
/// bản trước hạ chữ đầu xuống — đúng cho tiếng Việt.
///
/// Sang tiếng Anh thì cùng phép ấy hỏng ngay ở ca thường gặp nhất: đại từ **I**
/// viết hoa ở MỌI vị trí trong câu. `"I keep deciding…"` hoá `"i keep deciding…"`
/// và đọc ra như lỗi chính tả — nó xuất hiện đúng trên thẻ trang trọng nhất của
/// màn Hôm nay.
///
/// Nên chỉ hạ khi đang chạy tiếng Việt. Tiếng Anh giữ nguyên chữ tác giả viết:
/// một câu bắt đầu bằng chữ hoa nằm trong ngoặc kép giữa câu là cách viết bình
/// thường của tiếng Anh, không phải lỗi.
String midSentence(String text) => wrEnglish ? text : text.toLowerCase();

/// Mã ngôn ngữ đang bật, dạng gửi được lên máy chủ.
String get wrLocaleCode => wrEnglish ? 'en' : 'vi';

/// Header đính kèm mọi lượt gọi Edge Function.
///
/// Vì sao gửi CẢ header lẫn một trường trong thân yêu cầu: một nửa số câu lỗi
/// mà hàm trả về xảy ra trước lúc nó đọc được thân — sai method, thiếu
/// Authorization, hết phiên. Chỉ gửi trong thân thì đúng những câu lỗi hay gặp
/// nhất lại là những câu không bao giờ dịch được. Còn `wr-narrative` thì không
/// có thân nào cả, nó được gọi bằng POST rỗng.
///
/// Giữ đồng bộ với `WR_LOCALE_HEADER` trong `supabase/functions/_shared/locale.ts`.
Map<String, String> get wrLocaleHeaders => {'x-wr-locale': wrLocaleCode};

/// Đồng bộ [wrEnglish] từ mã ngôn ngữ của `appLocaleProvider` ('vi' / 'en').
///
/// Nhận mã chuỗi chứ không nhận `Locale`: `appLocaleProvider` giữ chuỗi, và
/// đổi kiểu ở đây nghĩa là mỗi nơi gọi phải tự dựng một `Locale` chỉ để vứt đi.
void wrSetLocale(String localeCode) {
  wrEnglish = localeCode == 'en';
}

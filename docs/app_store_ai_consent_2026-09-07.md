# Xin phép trước khi gửi dữ liệu sang AI — 07/09/2026

Dựng để gỡ **Guideline 5.1.1(i) và 5.1.2(i)** của lần từ chối 06/09/2026
(submission `4b138188-fa36-4886-8a47-23fe8a26c3bb`, bản 1.0 (6)).

Đây là lỗi thứ hai trong cùng lần từ chối đó; lỗi 3.1.1 về IAP xử lý riêng ở
`docs/app_store_iap_2026-09-07.md`.

## Apple nói gì

> The app appears to share the user's personal data with a third-party AI
> service but the app does not clearly explain what data is sent, identify who
> the data is sent to, and ask the user's permission before sharing the data.

Bốn điều kiện, phải làm **đủ cả bốn**:

1. Nói rõ dữ liệu gì sẽ được gửi.
2. Nêu đích danh gửi cho ai.
3. Xin phép **trước** khi gửi.
4. Chính sách quyền riêng tư ghi rõ thu thập gì, kiểu nào, dùng làm gì, và bên
   thứ ba có bảo vệ tương đương.

Và câu quyết định, chính là câu bản trước trượt:

> Note that only including this information in the app's Terms of Service or
> Privacy Policy is not sufficient.

Nghĩa là một dòng link tới trang chính sách **không thay thế được** màn xin phép
trong app.

## App đang gửi gì, cho ai

Đối chiếu mã nguồn 07/09/2026 — không phải phỏng đoán:

| Khi nào | Gửi gì | Đích | Nguồn |
|---|---|---|---|
| Trò chuyện | câu vừa viết + lịch sử cuộc + tóm tắt Episode, Career Memory, insight, chủ đề thực hành, kết quả self-check | OpenRouter → DeepSeek | `wr-chat/user_context.ts` |
| Tải JD/CV lên | **toàn văn tài liệu** | OpenRouter → Google Gemini | `wr-doc-analyze/index.ts` |
| Mở mục Diễn biến | các tình huống đã ghi theo thời gian — **chạy tự động** | OpenRouter → DeepSeek | `wr-narrative/index.ts` |
| Bật nghe đọc | đoạn chữ đang đọc | Ausynclab | `tts-proxy` |

Điểm đáng chú ý khi đọc mã: cả ba hàm chỉ đọc `cc_profiles.role` để biết gói
Free hay Premium, và **cột đó không đi kèm sang model**. Nên bản công bố nói
"không gửi tên và email" là nói thật, không phải nói cho êm tai.

## Đã làm

| Phần | Tệp |
|---|---|
| Nội dung công bố (thuần Dart, có version) | `lib/core/logic/wr_ai_disclosure.dart` |
| Đọc/ghi lựa chọn | `lib/core/data/wr_ai_consent_repository.dart` |
| Provider + controller | `lib/features/wr/ai_consent_providers.dart` |
| Màn xin phép + cổng chặn `ensureAiConsent` | `lib/core/widgets/wr_ai_consent_sheet.dart` |
| Màn xem lại / tắt đi | `lib/features/wr/presentation/wr_ai_consent_screen.dart` |
| Chốt chặn máy chủ | `supabase/functions/_shared/ai_consent.ts` |
| Bảng lưu | `supabase/migrations/20260907010000_wr_ai_consent.sql` |
| Test | `test/features/wr_ai_consent_test.dart` (23 test) |

Migration **đã push**; ba Edge Function **đã deploy và chạy thử thật**.

### Chặn ở hai tầng, không phải một

Cổng chặn phía app (`ensureAiConsent`) là chỗ người dùng nhìn thấy. Chốt chặn
phía máy chủ (`hasAiConsent`) mới là chỗ có quyền quyết định, vì cổng phía app
hỏng theo ba cách mà không ai hay:

- một màn hình mới quên gọi, không có gì nhắc;
- một bản build cũ còn trên máy ai đó, chưa hề có cổng chặn;
- bất cứ ai cầm token đăng nhập đều gọi thẳng Edge Function được.

Chốt chặn đặt **ngay sau bước xác thực, trước mọi truy vấn nạp dữ liệu** — kiểm
sau khi nạp là đã gom sẵn một đống dữ liệu riêng tư cho một yêu cầu lẽ ra bị từ
chối.

### Luồng Diễn biến phải xử lý khác ba luồng kia

`wrNarrativeRefreshProvider` chạy **tự động** khi mở mục Diễn biến — không có
nút nào để cổng chặn bám vào. Nên chặn nằm ngay trong provider, và máy chủ trả
`skip('ai_consent_required')` chứ không phải lỗi 403: một lỗi đỏ ở màn người
dùng vừa mở ra để *đọc* là vô lý. Lời mời bật lên nằm trên chính màn đó.

### Ba lỗ phát hiện khi rà lại trước khi push

Lượt rà "còn sót luồng nào không" tìm ra ba chỗ, chỗ thứ ba là lỗi nặng nhất
của cả đợt:

1. **`wr_mood_reader_screen`** gọi thẳng `api.ausynclab.io` từ app, không qua
   Edge Function nào — nghĩa là **không có chốt chặn phía máy chủ nào đỡ cho
   nó**. Cổng chặn trong màn là chốt duy nhất. Đã thêm.

2. **Video Report** (`video_report_providers`) gửi kịch bản đọc sang `tts-proxy`
   mà không xin phép. Đã chặn ở nhánh DỰNG MỚI; bản thu đã có sẵn thì phát lại
   không gửi gì nên không chặn.

3. **Tên và email người dùng ĐANG được gửi sang Ausynclab.**
   `NarrationScriptBuilder._intro` ghép thẳng `userName` vào câu mở đầu —
   *"Xin chào {tên thật}, đây là báo cáo phản chiếu của bạn."* — và `userName`
   lại **rơi về địa chỉ email** khi hồ sơ chưa có tên
   (`video_report_providers`: `full_name ?? email ?? ''`).

   Nghĩa là câu "không bao giờ gửi tên và email" trong `wr_ai_disclosure.dart`
   **và trong trang /privacy-policy vừa viết** là lời khai SAI.

   Đã sửa bằng cách **gỡ hẳn tham số `userName`** khỏi `build()`, không phải chỉ
   ngừng dùng nó — bỏ tham số đi thì không ai chèn lại được mà không nhận ra
   mình đang làm gì. Lời chào trên màn hình vẫn gọi tên bình thường:
   `VideoSceneView` dựng phần hiển thị tại máy, hoàn toàn tách khỏi đoạn chữ
   gửi đi.

Bài học: rà theo **điểm gọi ra ngoài** (`functions.invoke`, HTTP thẳng) chứ
đừng rà theo tên tính năng. Ba lỗ này đều nằm ngoài bốn "luồng" đã nghĩ tới lúc
thiết kế.

### Vài quyết định về hành vi, đều có lý do

- **Đã từ chối thì không hỏi lại.** Hỏi tới hỏi lui cho tới khi người ta bấm bừa
  là ép buộc, không phải xin phép. Muốn bật lại thì vào Tài khoản → Xử lý dữ
  liệu bằng AI.
- **Nút "Để sau" ngang hàng với nút "Đồng ý"**, không phải chữ mờ ở góc. Một lựa
  chọn bị vẽ cho khó thấy thì không còn là lựa chọn.
- **Ghi hỏng thì không đóng màn và không coi là đã đồng ý.** Trả về bừa là app
  tưởng được phép rồi gửi đi, trong khi máy chủ vẫn chặn — người dùng nhận một
  lỗi khó hiểu ở màn khác.
- **Đọc hỏng thì mặc định là CHƯA cho phép.** Đoán nhầm theo hướng đã-cho-phép
  là gửi dữ liệu đi khi chưa được phép. Chặn oan thì thử lại được; dữ liệu đã
  gửi thì không gọi về được.
- **`version` trong bảng** để khi thêm một bên nhận dữ liệu thì hỏi lại. Sửa câu
  chữ cho dễ đọc thì **không** nâng version — hỏi lại vì một dấu phẩy là dạy
  người dùng bấm đồng ý mà không đọc.

## Đã chạy thử thật những gì

Trên project `sukpcxevcjnhiuyaoqxi`, tài khoản demo App Review:

| Trường hợp | Kết quả |
|---|---|
| `wr-chat` khi chưa đồng ý | 403 + câu hướng dẫn vào Tài khoản |
| `wr-doc-analyze` khi chưa đồng ý | 403 |
| `wr-narrative` khi chưa đồng ý | 200 `{"generated":false,"reason":"ai_consent_required"}` |
| Ghi đồng ý bằng chính token người dùng | 201 — RLS cho chủ sở hữu ghi, đúng thiết kế |
| `wr-chat` sau khi đồng ý | 200, model trả lời bình thường |

Sau khi kiểm, hàng consent và cuộc trò chuyện thử **đã xoá** để tài khoản demo
trở lại trạng thái *chưa trả lời* — người duyệt Apple cần nhìn thấy màn xin phép
hiện ra, đó chính là thứ đang được chứng minh.

## Còn phải làm

### 1. Cập nhật trang chính sách quyền riêng tư — BẮT BUỘC

Điều kiện thứ 4 của Apple nằm ngoài repo này. Trang
`https://www.workreflection.app/privacy-policy` (repo web
`~/Documents/DuyThong/workreflection`) phải ghi rõ:

- thu thập dữ liệu gì, thu thập bằng cách nào;
- **mọi mục đích sử dụng**, gồm cả việc gửi sang dịch vụ AI bên thứ ba;
- nêu đích danh **OpenRouter, DeepSeek, Google (Gemini), Ausynclab**;
- xác nhận các bên đó có mức bảo vệ tương đương.

Nhật ký 05/08 ghi là đã bổ sung 3 mục cho phần di động nhưng **chưa commit, chưa
deploy** — cần kiểm lại và làm cho xong. Sửa app mà không sửa trang này thì vẫn
thiếu một trong bốn điều kiện.

### 2. Khai lại App Privacy trên App Store Connect

Mục *App Privacy* phải khai đúng các loại dữ liệu được thu thập và việc chia sẻ
với bên thứ ba. Khai thiếu ở đây là một lý do từ chối riêng, độc lập với mã
nguồn.

### 3. Điều khoản sử dụng

Paywall đang trỏ tới EULA mẫu của Apple vì workreflection.app chưa có trang điều
khoản riêng. Nếu làm trang riêng thì đổi `kAppleStandardEulaUrl` trong
`wr_paywall_screen.dart`.

### 4. Trả lời App Review

Nên nói rõ trong phần trả lời: app **có** gửi dữ liệu sang dịch vụ AI bên thứ
ba, đã bổ sung màn xin phép hiện trước lần đầu dùng, nêu đích danh bốn bên nhận,
và người dùng tắt lại được ở Tài khoản → Xử lý dữ liệu bằng AI.

### 5. Chạy thử trên máy thật

Chưa chạy `flutter run` trên thiết bị. Cần kiểm bằng mắt: màn xin phép hiện đúng
lúc chạm Trò chuyện lần đầu, bấm "Để sau" thì không gửi gì, và bật lại từ màn
Tài khoản thì các phần AI sống lại.

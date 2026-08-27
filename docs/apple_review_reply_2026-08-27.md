# Trả lời Apple — Guideline 2.1 Information Needed (27/08/2026)

## Apple từ chối vì gì

Không phải lỗi app. **2.1 Information Needed** là loại "thiếu hồ sơ": reviewer
chưa chạy app rồi bắt lỗi, họ dừng lại vì ô **App Review Information → Notes**
không đủ thông tin để họ hiểu app làm gì và tự đi hết các luồng.

Ô Notes bản 1.0 chỉ có 4 gạch đầu dòng (miễn phí · đăng nhập email · tài khoản
demo · chat AI). Apple đòi **7 mục**, trong đó mục nặng nhất là **video quay màn
hình trên máy thật** — cái này đã có kịch bản sẵn ở `kich_ban_quay_demo_apple.md`
từ 25/08 nhưng **chưa quay, chưa nộp**. Đó là khoản thiếu chính.

Không phải sửa dòng code nào. Không cần build lại. Chỉ trả lời trong App Store
Connect (Resolution Center) rồi bấm nộp lại bản build 2 đang có.

## Đã làm trên App Store Connect — 27/08

Ô **App Review Information → Notes** của bản 1.0 đã ghi đè bằng bản đủ 7 mục
(3.996/4.000 ký tự — ô này giới hạn 4.000, đây là lý do bài trong Resolution
Center dài hơn bài trong Notes). Đã bấm Save, chưa nộp gì cho Apple.

Dòng đầu mục 1 để nguyên chữ `>>> PASTE VIDEO LINK HERE BEFORE SUBMITTING <<<`.
**Phải thay bằng link Drive trước khi bấm nộp lại** — để nguyên là Apple đọc được.

Hai chỗ đã điền theo dữ liệu bạn cho: máy test **iPhone 15 Pro Max (iOS 26.6)**.

Trong lúc đối chiếu code phát hiện thêm: **thanh tab dưới cùng chỉ có icon, không
có chữ** (`shell_screen.dart:116` ghi rõ "NO text label"). Bài đầu tiên viết "Four
bottom tabs: Hôm nay, Hiểu mình…" là chỉ reviewer đi tìm nhãn chữ không tồn tại;
đã sửa thành mô tả theo icon — mắt (Hôm nay), bóng đèn (Hiểu mình), tia chớp
(Phát triển), nhịp sóng (Hành trình).

## Năm việc phải làm, theo thứ tự

1. **Chuẩn bị máy**: cập nhật iPhone lên iOS mới nhất, **xoá app rồi cài lại từ
   TestFlight** (để hộp xin quyền hiện lại được), chuẩn bị một email test chưa
   từng đăng ký.
2. **Quay video** theo `docs/kich_ban_quay_demo_apple.md` — đã viết lại thành bản
   2 ngày 27/08, 14 cảnh, có đủ ba thứ Apple hỏi mà bản cũ thiếu: đăng ký tài
   khoản, xoá tài khoản, hộp xin quyền.
3. **Tải video lên Google Drive**, đặt quyền "Bất kỳ ai có đường liên kết", tự
   kiểm bằng cửa sổ ẩn danh.
4. **Điền link video** vào bài trả lời dưới đây, và thay dòng
   `>>> PASTE VIDEO LINK HERE BEFORE SUBMITTING <<<` trong ô Notes trên App Store
   Connect. Máy test đã điền sẵn (iPhone 15 Pro Max, iOS 26.6).
5. **Dán bài trả lời** vào Resolution Center, đồng thời chép luôn vào ô App Review
   Information → Notes cho các lần nộp sau.

Ba điều cấm khi quay: **không để lọt giá tiền / QR thanh toán / SePay**, không có
nút đăng nhập bên thứ ba trong khung hình, không cắt ghép và không dùng dữ liệu
người thật. Giải thích ở kịch bản.

## Một chỗ sai trong hồ sơ cũ cần biết

Kịch bản bản 1 bảo người quay chạm vào "Chính sách quyền riêng tư" trong màn Hồ
sơ. **Trong app không có mục đó** (grep `lib/` ngày 27/08: không có chuỗi nào).
Chính sách chỉ tồn tại ở URL khai trong App Store Connect. Điều này **không vi
phạm** — Apple chỉ bắt có link trong app khi app bán gói thuê bao, mà app này thì
không. Nhưng bài trả lời phải nói đúng chỗ, đừng chỉ reviewer đi tìm một nút
không có.

---

## Bài trả lời — dán nguyên văn vào Resolution Center

> Thank you for the review. Please find the requested information below.
>
> **1. Screen recording**
> A screen recording captured on a physical iPhone running the latest iOS is
> available here: `<DÁN LINK GOOGLE DRIVE, quyền "Anyone with the link">`
>
> It is a single uncut take that starts from tapping the app icon on the Home
> Screen, and covers, in this order:
> - creating a new account with email and password, and the profile setup step
> - deleting that account from inside the app (Profile → "Xoá tài khoản" →
>   type-to-confirm dialog → the account is really deleted and the app returns
>   to the sign-in screen)
> - signing in with the demo account listed below
> - the full five-step daily reflection flow, which is the core feature
> - the photo library picker on the profile setup screen, and the microphone and
>   speech-recognition permission prompts (voice input is offered inside the
>   reflection flow)
> - the Understand, Develop and Journey tabs, and the AI chat
> - a slow pass over the whole profile screen, showing that the app contains no
>   purchase, price or upgrade offer anywhere
>
> **2. Devices and operating systems tested**
> iPhone 15 Pro Max (iOS 26.6).
> All testing was done on physical devices, with builds distributed through
> TestFlight. The app targets iPhone only and supports iOS 13.0 and later.
>
> **3. What the app does and who it is for**
> WorkReflection is a daily work-reflection companion for Vietnamese office
> workers and early-career professionals. The problem it solves: people
> experience the same difficult situations at work over and over (being
> interrupted in meetings, staying silent to avoid conflict, unclear feedback)
> but never notice the pattern, so nothing changes.
>
> The app asks the user for a short daily reflection — pick a mood, pick the
> situation, write one or two sentences about what they noticed. Over time the
> app counts which situations repeat, shows the user their own recurring
> patterns, suggests a small practice theme, and keeps a timeline of their
> career. All content is generated from the user's own entries. The app is in
> Vietnamese.
>
> The app is completely free. There are no in-app purchases, no subscriptions,
> and no purchase or pricing screens anywhere in the app.
>
> **4. Setup and access instructions**
> No setup, sample files or special configuration are needed. There is a single
> account type — every account has the same features.
>
> Demo account: `demo.review@workreflection.app` / `WrDemo!2026Review`
> This account is pre-populated with real usage data so that no screen appears
> empty. You may also create your own account with any email address; sign-up
> is immediate and requires no invitation or approval.
>
> The interface is in Vietnamese. After signing in you land on the Today tab.
> The four bottom tabs are icons with no text label: eye (Hôm nay / Today),
> lightbulb (Hiểu mình / Understand), bolt (Phát triển / Develop), wave
> (Hành trình / Journey). The profile avatar is at the top right, and a coral
> bubble button opens the AI assistant from any tab.
> - Core feature: on the Today tab, tap any mood tile. This starts the
>   five-step reflection flow: mood → situation → familiar story → what you
>   noticed → finish. It takes about a minute. Any text field in this flow can
>   also be dictated by tapping the microphone icon.
> - Patterns: the Hiểu mình tab shows repeating situations and a Career Health
>   Check, both computed from the account's own entries.
> - AI chat: Hành trình tab → "Trò chuyện về hành trình của bạn".
> - Export your data: profile avatar → "Xuất dữ liệu".
> - Account deletion: profile avatar (top right) → scroll to the bottom → "Xoá
>   tài khoản" → type the confirmation word → the account and its data are
>   deleted immediately, with no email or website step.
> - Privacy policy: https://www.workreflection.app/privacy-policy
>
> **5. External services used**
> - Supabase (supabase.com) — authentication (email and password only), the
>   database, file storage, and our own serverless backend functions. All user
>   data is stored here.
> - OpenRouter (openrouter.ai) — the gateway our backend uses to reach language
>   models. Two models are used: DeepSeek for the chat assistant and the pattern
>   summaries, and Google Gemini for reading a CV or job description that the
>   user chooses to upload.
> - AusyncLab (ausynclab.io) — Vietnamese text-to-speech, used only to read a
>   short reflection passage aloud.
>
> The app never calls a model provider directly. User text is sent to our own
> Supabase Edge Functions, which then call the provider. We do not sell user
> data and do not use it for advertising or for model training.
>
> There is no third-party sign-in, no analytics SDK, no advertising SDK, no
> tracking SDK and no payment processor in the app. Because the app does not
> track users across apps or websites, it does not present an App Tracking
> Transparency prompt.
>
> **6. Regional differences**
> There are none. The app behaves identically in every region. It is offered in
> Vietnamese only, and there is no region-specific content, pricing, or feature
> gating.
>
> **7. Regulated industry / third-party material**
> The app is not in a regulated industry. It does not provide medical, mental
> health, financial, or legal services — it is a personal journaling and
> self-reflection tool for work life. All text, prompts, questions, and artwork
> in the app were written and produced by us. The app contains no third-party
> protected material.
>
> **Additional notes**
>
> *User-generated content.* Everything a user writes is a private journal entry
> visible only to that user. There is no feed, no profile browsing, no comments,
> no messaging between users, and no way for one user to see another user's
> content — so there is nothing to report or block. The only other party in a
> conversation is the AI assistant, which answers using the user's own entries.
>
> *Permissions.* The app requests four permissions, each only at the moment the
> user taps the feature that needs it, and every feature remains usable if the
> permission is denied:
> - Microphone and speech recognition — to dictate a reflection answer instead
>   of typing it.
> - Photo library — to set a profile picture on the profile setup screen shown
>   right after registration.
> - Camera — to scan a QR code when checking in to an in-person workshop.
> The app does not request location, contacts, calendar, health data, or
> notifications-based tracking.
>
> *No purchases.* The app is free and contains no in-app purchase, no
> subscription, no pricing information, and no link that leads to a paid plan.
> The screen recording includes a slow pass over the profile screen so this can
> be verified.
>
> *Sign-in.* Sign-in uses our own email-and-password system only. There is no
> third-party or social login anywhere in the app.

---

## Kiểm lần cuối trước khi bấm nộp lại

- [ ] Video mở được bằng cửa sổ ẩn danh (không đòi đăng nhập Google)
- [ ] Video có đủ: mở app · đăng ký · xoá tài khoản · đăng nhập demo · luồng nhìn
      lại · hộp xin quyền micro · hộp xin quyền thư viện ảnh · chat AI
- [ ] Video **không** có giá tiền, QR thanh toán, nút đăng nhập Google
- [ ] Ô Notes trên App Store Connect **không còn dòng** `>>> PASTE VIDEO LINK
      HERE BEFORE SUBMITTING <<<` — đã thay bằng link thật
- [ ] Tài khoản demo đăng nhập được, vẫn là Premium, dữ liệu vẫn còn
- [ ] Đã chép bài trả lời sang App Review Information → Notes, không chỉ dán ở
      Resolution Center

## Lỗi phát hiện 27/08 — đổi ảnh đại diện không vào được

Màn "Chỉnh sửa hồ sơ" (`ProfileEditScreen`, nơi duy nhất có ô đổi ảnh đại diện)
khai route `/profile/edit` trong `app_router.dart:272` nhưng **không có chỗ nào
trong `lib/` gọi `push('/profile/edit')`** — route mồ côi. Nó chỉ mở ra được qua
`/profile/setup`, tức màn thiết lập ngay sau khi đăng ký.

Hệ quả: người dùng đã có tài khoản **không có đường nào đổi ảnh đại diện, cũng
không sửa được tên và các trường hồ sơ khác** trên màn đó.

Với hồ sơ Apple thì không sao — quay cảnh chọn ảnh ở màn thiết lập sau đăng ký là
đủ, và ô Notes đã sửa thành "during profile setup". Nhưng đây là **lỗi sản phẩm
thật**, nên đưa vào bản sau: thêm một mục trong màn Hồ sơ trỏ tới `/profile/edit`.
Sửa được trong vài phút nhưng phải dựng lại IPA, nên không làm trước lần nộp này.

## Việc phụ, không chặn lần nộp này

Chuỗi xin quyền micro trong `ios/Runner/Info.plist` vẫn viết theo app cũ: *"Nhập
câu trả lời khảo sát bằng giọng nói"* và *"Nhận dạng giọng nói để chọn câu trả
lời khảo sát"*. App không còn là app khảo sát; giờ ô nhập giọng nói nằm trong
luồng nhìn lại. Apple **có** soi mục này (Guideline 5.1.1), nhưng chuỗi hiện tại
vẫn nói đúng "dùng micro để nhập chữ" nên không phải lỗi. Sửa lại cho khớp ở lần
build sau — sửa bây giờ là phải dựng lại IPA, kéo dài thêm một vòng.

## Sau khi Apple duyệt

Chép nguyên bài này vào **App Review Information → Notes** của mọi bản sau, cập
nhật lại link video và danh sách máy test mỗi lần đổi. Apple nói rõ họ muốn thấy
sẵn ở đó, không phải hỏi lại từng lần.

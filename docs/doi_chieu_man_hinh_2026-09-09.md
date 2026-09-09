# Đối chiếu màn hình — file khách 09/09/2026 với app thật

Mục đích: gửi chị quản lý danh sách những màn **đang chạy trong app nhưng chưa có
trong file chỉnh sửa**, để chị bổ sung câu chữ.

Cách làm: liệt kê toàn bộ đường dẫn khai báo trong `lib/core/router/app_router.dart`
(73 màn), rồi truy ngược từng màn xem có lối vào thật từ 4 tab dưới cùng và màn
Tài khoản hay không.

**Kết quả: app có 42 màn đang dùng. File khách phủ 17 màn. Còn thiếu 25 màn.**
Ngoài ra có 31 màn còn nằm trong bản dựng nhưng không còn lối vào nào.

> Cập nhật 09/09 sau khi chạy app thật và chụp đủ: **24 màn đã có ảnh**, nằm ở
> `~/Desktop/WR-man-hinh-thieu-090926/` kèm file `00-DANH-SACH.md`. Màn chờ
> (Splash) không có chữ nên bỏ qua; màn thanh toán VietQR hoá ra đã bị khoá ở
> mọi bản build — xem đính chính ở §2.8.

> Lưu ý: phần "có lối vào" được truy từ mã nguồn, chưa bấm tay từng màn trên máy
> thật. Nếu cần chắc chắn tuyệt đối thì chạy app và đi hết một lượt — khoảng 1
> buổi.

---

## 1. Mười bảy màn đã có trong file khách

| Màn | Ảnh trong file |
|-----|----------------|
| Hôm nay (Home) | image2, image21 |
| Nhìn lại · bước Nhận diện tình huống | image18 |
| Nhìn lại · bước Chi tiết (câu chuyện quen thuộc) | image22 |
| Nhìn lại · bước Ý nghĩa — lớp 1 | image23 |
| Nhìn lại · bước Ý nghĩa — lớp 2 "Góc nhìn khác" | image12 |
| Nhìn lại · bước Lựa chọn | image24 |
| Nhìn lại · màn Đã lưu | image19 |
| Tab Hiểu mình | image20 |
| Tình huống lặp lại | image13 |
| Tab Phát triển (thẻ chủ đề) | image5 |
| Kỹ năng của bạn | image15 |
| Thông tin công việc | image11 |
| Cùng tạo JD | image17 |
| Tab Hành trình | image10 |
| Diễn biến theo thời gian (khoá Premium) | image4 |
| Thông tin của bạn | image6 |
| Self-Check (mở đầu · khoá Premium · so sánh) | image3, image1, image7 |
| Premium | image8 |

---

## 2. Hai mươi sáu màn ĐANG DÙNG nhưng CHƯA có trong file

### 2.1 Nhóm mở app lần đầu — 4 màn

| # | Màn | Vào từ đâu | Vì sao cần |
|---|-----|-----------|-----------|
| 1 | Màn chờ (Splash) | tự động | Không có chữ nào — bỏ qua được |
| 2 | **Giới thiệu 3 trang (Onboarding)** | lần đầu cài app | Khách đã chốt "giữ nguyên luồng", nhưng **câu chữ trên 3 trang này chưa từng được duyệt** |
| 3 | **Đăng nhập / Đăng ký** | sau onboarding | Màn đầu tiên người dùng thật đọc |
| 4 | **Thiết lập hồ sơ lần đầu** | ngay sau khi đăng ký | Bắt buộc đi qua, không bỏ được |

### 2.2 Nhóm Tài khoản — 4 màn

| # | Màn | Vào từ đâu |
|---|-----|-----------|
| 5 | **Tài khoản** (màn gốc, có avatar, gói, các mục cài đặt) | ảnh đại diện góc trên Home |
| 6 | **Sửa hồ sơ** | Tài khoản |
| 7 | **Hướng dẫn sử dụng** | Tài khoản |
| 8 | **Xử lý dữ liệu bằng AI** (đồng ý / rút lại) | Tài khoản | 

⚠ Màn số 8 là màn Apple bắt buộc phải có (Guideline 5.1.1). Câu chữ ở đây đã qua
một vòng rà cho App Store — sửa phải cẩn thận, xem `docs/app_store_ai_consent_2026-09-07.md`.

### 2.3 Nhóm Trò chuyện và Thư viện cảm xúc — 3 màn

| # | Màn | Vào từ đâu |
|---|-----|-----------|
| 9 | **Trò chuyện với trợ lý** | nút tròn màu cam nổi trên mọi tab |
| 10 | **Gợi ý theo cảm xúc** (danh sách bài) | Home, hoặc nút trong chat |
| 11 | **Bài đọc / bài nghe** | chạm một bài trong thư viện |

Màn số 9 là một trong những màn người dùng vào nhiều nhất, và hoàn toàn không có
trong file.

### 2.4 Nhóm Nhìn lại — 2 màn đầu của luồng — 2 màn

| # | Màn | Vào từ đâu |
|---|-----|-----------|
| 12 | **Năng lượng của bạn thế nào?** | nút "Ghi lại thành một Reflection" trong chat; hoặc bắt đầu lần nhìn lại mới khi còn phiên dở |
| 13 | **Điều gì đang diễn ra với bạn?** (6 khoảnh khắc) | ngay sau màn 12 |

Hai màn này không nằm trong đường đi chính (chạm ô cảm xúc ở Home là vào thẳng
bước Nhận diện), nên rất dễ bị bỏ sót khi chụp màn hình — nhưng người vào từ chat
thì bắt buộc đi qua.

### 2.5 Nhóm Phát triển — 4 màn

| # | Màn | Vào từ đâu |
|---|-----|-----------|
| 14 | **Danh sách chủ đề thực hành** | thẻ "Tiếp tục hôm nay" ở Home khi chưa theo chủ đề nào |
| 15 | **Chi tiết một chủ đề** (chuỗi các bước thực hành) | chạm một chủ đề |
| 16 | **Trà Chiều** | tab Phát triển |
| 17 | **Lịch Trà Chiều** | Trà Chiều |

Màn 15 là nơi người dùng thật sự làm bài thực hành — nhiều chữ, và chưa được duyệt.

### 2.6 Nhóm Hiểu mình / Hành trình mức chi tiết — 4 màn

| # | Màn | Vào từ đâu |
|---|-----|-----------|
| 18 | **Chi tiết một tình huống lặp lại** | chạm một dòng ở màn Tình huống lặp lại, hoặc thẻ "Hệ thống nhận ra" ở Home |
| 19 | **Chi tiết một lần nhìn lại** | chạm một mục trong Hành trình |
| 20 | **Career Memory đầy đủ** | tab Hành trình |
| 21 | **Diễn giải sâu & xu hướng Self-Check** (Premium) | kết quả Self-Check |

### 2.7 Nhóm Bối cảnh công việc — 4 màn

| # | Màn | Vào từ đâu |
|---|-----|-----------|
| 22 | **Tải JD / CV lên** | Thông tin công việc (file mới chỉ sửa *dòng dẫn* vào màn này, chưa sửa nội dung bên trong) |
| 23 | **Khảo sát tổ chức — giới thiệu** | Tài khoản |
| 24 | **Khảo sát tổ chức — trả lời câu hỏi** | tiếp màn 23 |
| 25 | **Khảo sát tổ chức — bản so sánh** | sau khi trả lời xong |

### 2.8 Thanh toán — 0 màn (đính chính 09/09 sau khi chạy thật)

| # | Màn | Trạng thái |
|---|-----|-----------|
| 26 | Thanh toán chuyển khoản (VietQR) | **Không còn dùng** |

Bản đầu tiên của tài liệu này xếp màn VietQR vào nhóm "đang dùng trên Android".
**Sai.** Chạy thật mới lộ ra: `/wr/payment` bị chặn ngay ở tầng đường dẫn trên
**mọi** bản build — `WrStorePolicy.allowsVietQrCheckout` mặc định false, chỉ mở
khi build kèm `--dart-define=FORCE_STORE_POLICY=open`. Mở đường dẫn đó thì bị đá
về màn Premium. Cả hai kho ứng dụng đều cấm bán hàng số bằng cổng riêng, nên đây
là chủ đích chứ không phải lỗi.

**Kết luận: 25 màn thiếu, không phải 26.** Trong đó 24 màn có ảnh chụp; màn chờ
(Splash) không có chữ nào nên bỏ qua.

---

## 3. Ba mươi màn còn trong bản dựng nhưng KHÔNG còn lối vào

Đây là phần còn lại từ giai đoạn app bám theo bản web, trước lần chuyển hướng
sang "bạn đồng hành mỗi ngày". Không tab nào, không nút nào dẫn tới chúng nữa —
chỉ gõ thẳng đường dẫn mới vào được.

- Khảo sát Career Compass cũ: 10 màn (`/survey…`)
- Workshop: 6 màn (`/workshops…`, `/my-workshops`)
- Coaching: 3 màn (`/coaching…`)
- Voucher, Lời mời: 2 màn
- Bốn tab của bản cũ: Hiểu mình cũ, Phát triển cũ, Hành trình cũ, Insights,
  Lộ trình: 5 màn
- Của WorkReflection nhưng đã ngắt lối vào: Story, Story flow, Career setup,
  Hành trình phát triển: 4 màn

**Không cần gửi chị quản lý phần này** — không ai đọc được chữ trên đó.

**Nhưng nên xử lý về mặt kỹ thuật.** Ba lý do: chúng vẫn làm nặng bản cài; chúng
vẫn gọi tới các bảng dữ liệu cũ; và nếu người của Apple gõ đúng một đường dẫn thì
sẽ thấy một phần app không khớp với phần mô tả. Đề nghị: gỡ hẳn sau khi bản App
Store được duyệt, không gỡ ngay bây giờ (đang giữa đợt nộp lại).

---

## 4. Đề nghị gửi khách

Gửi chị quản lý **mục 2** (26 màn), chia đúng 8 nhóm như trên, kèm ảnh chụp từng
màn. Ưu tiên xin câu chữ trước cho 5 màn người dùng gặp nhiều nhất và chưa được
duyệt lần nào:

1. Trò chuyện với trợ lý (số 9)
2. Chi tiết một chủ đề thực hành (số 15)
3. Đăng nhập / Đăng ký (số 3)
4. Giới thiệu 3 trang (số 2)
5. Tài khoản (số 5)

Bước tiếp theo phía mình: chạy app, chụp đủ 26 màn, đánh số theo đúng bảng này
rồi gửi kèm.

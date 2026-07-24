# Design: Nút lùi về trang trước (back navigation)

**Ngày**: 2026-07-24 · **Phạm vi duyệt**: Fullscreen `/wr/story` + tab điều hướng chéo · **Phương án duyệt**: Query param `?from=`

## Vấn đề

- `/wr/story` (fullscreen) không có nút lùi — ngõ cụt, đặc biệt trên web (không có back cứng).
- Khi bấm link chéo giữa tab (ví dụ Hành trình → "Xem trong Hiểu mình"), trang đích không có đường quay lại trang xuất phát; tab bar dùng `context.go` nên không có back stack.

## Giải pháp

### 1. Widget dùng chung `WrTabBackLink` — `lib/core/widgets/tab_back_link.dart`

- Đọc `GoRouterState.of(context).uri.queryParameters['from']`.
- Map hợp lệ: `home → /home`, `discover → /wr/discover`, `growth → /wr/growth`, `journey → /wr/journey`.
- Chỉ render khi `from` hợp lệ và khác tab hiện tại; ngược lại `SizedBox.shrink()`.
- UI: `GestureDetector` → Row [`Icons.arrow_back_ios_new` 14px muted, 6px gap, Text 'Quay lại' 13px w500 muted]; padding dọc nhỏ để vùng chạm đủ lớn.
- Tap → `context.go(targetPath)` — path sạch không query nên nút tự biến mất ở trang đích.
- Đặt ở đầu body 4 tab WR (trên tiêu đề, trong padding ngang hiện có của từng màn). Tab Tôi không cần (không có link chéo trỏ tới).

### 2. Gắn `?from=` vào 6 link chéo hiện có

| Link | File | from |
|---|---|---|
| 'Tìm hiểu thêm' → Discover | wr_home_screen.dart | `home` |
| 'Xem trong Hiểu mình' → Discover | wr_journey_screen.dart | `journey` |
| 'Tạo Memory đầu tiên' → Home | wr_journey_screen.dart | `journey` |
| 'Bắt đầu thực hành' → Growth | wr_discover_screen.dart | `discover` |
| 'Xem toàn bộ hành trình' → Journey | wr_discover_screen.dart | `discover` |
| 'Xem trong Hiểu mình' → Discover | wr_growth_screen.dart | `growth` |

KHÔNG gắn cho CTA hoàn tất flow (self-check → growth/journey, story-flow → home, profile-edit → home): đó là "đi tiếp", không phải "rẽ ngang tạm".

### 3. `/wr/story` — nút lùi fullscreen

Thêm hàng header đầu màn: IconButton `arrow_back_ios_new` → `context.pop()` nếu `context.canPop()`, fallback `context.go('/home')` (mở thẳng bằng URL trên web).

## Hành vi biên

- Bấm tab bar trực tiếp → URL sạch → không hiện nút (đúng chuẩn mobile tab).
- `from` rác (`?from=abc`) hoặc trùng tab hiện tại → không hiện nút.
- Refresh web giữ query → nút lùi còn nguyên (ưu điểm phương án 1).
- Chỉ nhớ 1 bước — đúng yêu cầu "lùi về trang trước đó".

## Test

- Widget test `WrTabBackLink`: hiện đúng khi from hợp lệ; ẩn khi thiếu/rác/trùng tab; tap điều hướng đúng path sạch.
- Mỗi tab: pump router với `?from=` → thấy 'Quay lại'; không query → không thấy.
- Tap link chéo từ trang nguồn → trang đích hiện 'Quay lại' → tap → về đúng trang nguồn, nút biến mất.
- `/wr/story`: có nút lùi; canPop pop về trang trước; không canPop → về /home.
- Gates: `flutter analyze` (1 warning pre-existing), full `flutter test` xanh (baseline 1268).

# Phase 4 — Web parity cho tính năng end-user (mobile)

**Ngày:** 2026-07-18
**Nguồn đối chiếu:**
- Biên bản nghiệm thu: `~/Desktop/FileTam/workreflection/BIEN_BAN_NGHIEM_THU_WorkReflection.docx` (59 hạng mục / 10 nhóm)
- Web codebase (source of truth cho schema + hành vi): `/home/duythong/Documents/DuyThong/workreflection`
- Mobile codebase: `/home/duythong/Documents/DuyThong/appmobileworkreflection`

## Kết luận gap-analysis

Mobile đã có đủ: auth (login/signup/Google), onboarding, khảo sát Free/Premium + TTS karaoke,
báo cáo SCA/ESI/eNPS + narratives + bottleneck, action plan có tick tiến độ, workshop
(browse/detail/đăng ký free/QR check-in/khảo sát sau workshop/tài nguyên), coaching
(gói/coach/claim free/lịch của tôi), profile (stats/reminder/ngôn ngữ/export/logout).

**NGOÀI PHẠM VI mobile (không làm, có lý do):**
- Nhóm G (Enterprise), H (Admin), I (trang công khai/blog/pháp lý), khu vực Coach-role — web-only theo thiết kế.
- Nhóm D (Thanh toán SePay/hoá đơn/voucher) — đã chốt: luồng trả phí chuyển hướng lên web.
- Video report, PDF export, nhập liệu giọng nói (STT) — hạng mục nặng, không cam kết trong phase này.
- Đặt lịch coaching (chọn slot) — đã chốt Phase 3: đặt lịch trên web, mobile chỉ xem.

## Task list (mỗi task: Sonnet implementer → Fable review → sửa tới khi đạt)

### Task 1 — Quên mật khẩu + Đổi mật khẩu (nghiệm thu mục A2)
- AuthScreen: link "Quên mật khẩu?" → nhập email → `supabase.auth.resetPasswordForEmail(email, redirectTo: <web reset URL — lấy đúng URL từ web codebase ForgotPassword.tsx/ResetPassword.tsx>)`.
- ProfileScreen: mục "Đổi mật khẩu" → màn hình/dialog nhập mật khẩu mới + xác nhận → `supabase.auth.updateUser(UserAttributes(password: ...))`. Xử lý lỗi (yếu, mạng, session hết hạn).
- l10n VI/EN đầy đủ; test logic validate + widget test cơ bản.

### Task 2 — Sửa hồ sơ cá nhân (nghiệm thu mục A3)
- Màn hình `/profile/edit`: sửa display_name (wr_mobile_profiles) + các trường cc_profiles
  đúng theo web `pages/user/Profile.tsx` (full_name, phone, position, company/department,
  work experience, tenure, company size — XÁC MINH tên cột từ web code, không đoán).
- Avatar: chỉ làm nếu web dùng Supabase Storage bucket công khai xác định được từ code web;
  nếu phức tạp (crop, bucket riêng) → ghi rõ defer, không làm nửa vời.
- Entry point từ ProfileScreen. l10n VI/EN. Tests.

### Task 3 — Lịch sử khảo sát & báo cáo (web `/user/survey-history`)
- Màn `/survey/history`: list cc_reports của user (ngày, điểm tổng, level, loại free/premium)
  → tap mở `/survey/report/:id` (màn có sẵn).
- Entry: ProfileScreen + Understand tab. l10n. Tests (repo logic + provider).

### Task 4 — Hộp thông báo in-app — **KHÔNG ÁP DỤNG (đã xác minh 2026-07-18)**
- Bằng chứng: `cc_notifications` KHÔNG có cột user_id; `target_type` chỉ nhận `"admin" | "enterprise"`
  (web `src/lib/notifications.ts`); web chỉ đọc bảng này ở `components/admin/NotificationPopover.tsx`,
  `pages/admin/Notifications.tsx`, `pages/enterprise/Notifications.tsx`.
- Kết luận: web KHÔNG có inbox in-app cho end-user — mục J5 nghiệm thu "thông báo cho người dùng"
  được đáp ứng qua email tự động (send-email/reminder-cron). Mobile làm inbox sẽ vĩnh viễn rỗng.
- Đã implement thử (commit ee40495) rồi REVERT (64a0b9b) sau khi Fable review bác vì là tính năng giả.

### Task 5 — Nổi UI cho data đã có + sửa stub
- Danh sách insights đầy đủ (repo `getInsights()` đã có, chưa có màn) — entry từ Understand.
- Lịch sử check-in (repo `getCheckinDates()` đã có) — dải 30 ngày gần nhất ở Profile hoặc Home.
- Sửa stub Home "Xem thêm" (`onTap: {}`) → điều hướng có nghĩa (Understand tab).
- l10n. Tests.

### Task 6 — Final gates
- `flutter analyze` = 0; toàn bộ test xanh; `flutter build apk --debug` OK.
- `gitnexus_detect_changes` scope đúng; re-index bằng GLOBAL `gitnexus analyze` (KHÔNG dùng npx).
- Fable adversarial review toàn phase.

## Quy tắc bắt buộc cho implementer (Sonnet)
1. Schema Supabase: đọc từ web codebase, không bịa cột. Backend dùng chung project `sukpcxevcjnhiuyaoqxi`.
2. Trước khi sửa symbol có sẵn: `gitnexus_impact({target, direction: "upstream"})`.
3. TDD: viết test trước khi/ngay cùng code; `flutter analyze` + `flutter test` phải xanh TRƯỚC khi báo hoàn thành, dán output thật.
4. Chỉ commit file thuộc task của mình; chạy `gitnexus_detect_changes` trước commit.
5. l10n: mọi string user-facing vào .arb VI + EN, không hardcode tiếng Việt.
6. Style theo code hiện có (Riverpod autoDispose, repository layer, WrCard widgets).

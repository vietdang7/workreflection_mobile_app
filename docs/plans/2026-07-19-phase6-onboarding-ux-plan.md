# Phase 6 — UX: nhập hồ sơ 1 lần, CTA khảo sát nổi bật, kiểm chứng auth

**Ngày:** 2026-07-19 (chỉ đạo owner tối 18/07). Nguồn chân lý: web `/home/duythong/Documents/DuyThong/workreflection`.

## Bằng chứng phân tích
- Web `src/pages/survey/Info.tsx`: prefill form từ cc_profiles (dòng 204-215), **auto-redirect bỏ qua form khi profile đầy đủ** (187-202), submit thì `UPDATE cc_profiles` (398). Mobile chưa mirror — đây là gốc phàn nàn "nhập lại mỗi lần".
- Mobile `survey_intro_screen.dart`: 5 TextEditingController tự do, không prefill, không lưu profile.
- Mobile auth: signUp → ensureSeeded → /home thẳng, không có bước hoàn thiện hồ sơ.
- Mobile đã có sẵn ProfileEditScreen (Phase 4) với đúng 5 dropdown enum chuẩn DB (staff/less_6m/…).

## Task (Sonnet implement → Fable duyệt độc lập → rework tới khi đạt)

### T1 — Bước "Hoàn thiện hồ sơ" sau đăng ký
- Sau SIGNUP thành công (không áp dụng login thường): điều hướng `/profile/setup` — tái dùng ProfileEditScreen ở chế độ setup (title "Hoàn thiện hồ sơ", CTA "Hoàn tất" → /home, link "Bỏ qua" → /home). Google OAuth lần đầu (user mới) cũng vào setup nếu xác định được là mới (nếu không phân biệt được thì chỉ áp dụng email signup — ghi rõ).
- Router: cho phép /profile/setup với session (kiểm computeRedirect không chặn).

### T2 — Survey intro: prefill + skip như web
- Đổi 5 ô text tự do thành 5 dropdown ĐÚNG enum như ProfileEditScreen (đồng bộ dữ liệu 2 nền tảng).
- Prefill từ cc_profiles; nếu đủ cả 5 trường → **bỏ qua màn intro**, vào thẳng /survey/guide (mirror web redirect; vẫn gửi thông tin từ profile vào submitSurvey).
- Khi user sửa/điền ở intro → UPDATE cc_profiles (mirror web dòng 398) rồi tiếp tục.

### T3 — Nút "Bắt đầu phản chiếu" đàng hoàng trên Home
- Thay card CTA hiện tại bằng NÚT full-width nổi bật (coral, icon, cao ≥52px) đặt NGAY DƯỚI lời chào (vị trí đầu tiên), label "Bắt đầu phản chiếu"; khi đã có báo cáo: nút chính "Xem báo cáo mới nhất" + link phụ "Làm lại bài phản chiếu".

### T4 — Kiểm chứng đăng ký/đăng nhập
- Audit + bổ sung widget test: signup (validation, lỗi trùng email, thành công → /profile/setup), login (sai mật khẩu, thành công → /home), Google OAuth callback, logout → /auth, guard redirect các route mới.

### T5 — Final gates
- analyze 0 · test xanh · APK OK · detect_changes · re-index · flutter run cho owner test.

## Quy tắc: như Phase 5 (schema từ web, gates dán output thật — Fable chạy lại độc lập, l10n VI/EN, commit riêng từng task `feat(p6): ...`).

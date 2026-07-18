# Phương án 2 (DỰ TRỮ — chưa thực thi) — Thêm trải nghiệm Enterprise-MEMBER vào mobile

**Trạng thái:** đã được duyệt LẬP PLAN 2026-07-18, chưa duyệt triển khai. Tiền đề: Phase 5 (parity người dùng) hoàn tất.

## Phạm vi
Nhân viên thuộc tổ chức (role enterprise member — KHÔNG gồm bảng điều khiển quản trị của org admin/manager):

1. **Khảo sát chiến dịch** — mirror `enterprise/survey/CampaignSurvey.tsx` + `CampaignSurveyResults.tsx`: nhận link/deep-link chiến dịch, làm khảo sát (bộ câu hỏi campaign 15/40 câu), xem kết quả cá nhân trong chiến dịch. Bảng: `cc_campaigns`, `cc_campaign_question_sets`, chế độ ẩn danh (anonymous flag) phải tôn trọng tuyệt đối.
2. **Workshop công ty** — mirror `user/CompanyWorkshops.tsx`: list workshop `org_id = tổ chức của tôi` (mobile hiện lọc `org_id IS NULL` — cần nhánh mới), đăng ký nội bộ, check-in QR dùng lại màn hiện có.
3. **Tài nguyên công ty** — mirror `user/CompanyResources.tsx`: `cc_workshop_resources`/L&D resources được chia sẻ cho nhân viên; xem + mở link/tải.
4. **L&D của nhân viên** — chương trình được ghi danh (`cc_lnd_enrollments`), tiến độ module (`cc_lnd_module_progress`), xem tài nguyên chương trình.
5. **Thông báo nội bộ doanh nghiệp** — phần `target_type='enterprise'` của `cc_notifications` CÓ áp dụng cho member? XÁC MINH RLS + web `enterprise/Notifications.tsx` trước (Phase 4 đã chứng minh phần end-user thường là N/A; enterprise member có thể khác).
6. **Ngữ cảnh tổ chức trong Profile** — tên org, phòng ban, vai trò (đọc `cc_org_members`/`cc_organizations`).

## Điều kiện kỹ thuật cần xác minh trước khi thực thi
- RLS các bảng campaign/L&D cho role member (test bằng user member thật trên staging).
- Cách web xác định org hiện tại của user (hook/context nào) → mobile cần provider tương đương.
- Deep-link mời chiến dịch (`/survey/campaign/:campaignId`) → cấu hình app links Android.

## Ước lượng
6 task lớn, cỡ ~60–70% khối lượng Phase 5. Điều kiện: có tài khoản enterprise-member test.

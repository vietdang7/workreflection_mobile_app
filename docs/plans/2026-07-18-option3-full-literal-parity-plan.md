# Phương án 3 (DỰ TRỮ — chưa thực thi) — Parity 100% nghĩa đen: Admin + Enterprise console + Coach + trang công khai

**Trạng thái:** đã được duyệt LẬP PLAN 2026-07-18, chưa duyệt triển khai. Tiền đề: Phase 5 + Phương án 2 hoàn tất. **Khuyến cáo của Fable: KHÔNG nên làm nguyên khối** — UX quản trị (bảng dữ liệu lớn, editor nội dung, phân tích) không phù hợp màn hình điện thoại; nếu cần, làm bản "companion" rút gọn thay vì port 1:1.

## Khối A — Coach console (giá trị cao nhất trong Phương án 3, nên làm trước)
Mirror `pages/coach/*`: lịch trống (`Availability.tsx` — CRUD `cc_coach_availability`), quản lý booking (`Bookings.tsx` — accept/complete/cancel), lịch sử buổi (`History.tsx`), roadmap khách hàng được cấp quyền (`ClientRoadmaps.tsx`). Coach là người di chuyển nhiều → mobile có giá trị thật. ~4 task.

## Khối B — Enterprise admin/manager console
Mirror `pages/enterprise/*`: Dashboard tổng quan điểm S-C-A theo team, Members (mời/role), Departments, Settings, Diagnostic Campaigns (tạo/launch/theo dõi/báo cáo 7 tab), L&D quản trị (programs/resources CRUD), Workshop doanh nghiệp (tạo/sửa/đăng ký/duyệt yêu cầu). Khối lượng RẤT lớn (~12–15 task), nhiều chart/table/form phức tạp. Đề xuất nếu làm: chỉ Dashboard xem số liệu + duyệt yêu cầu (read-mostly companion), phần tạo/sửa để web.

## Khối C — Platform Admin console
Mirror `pages/admin/*` (25+ trang: users, orders, invoices, questions/question-sets, narratives, vouchers, workshops, coaching, campaigns, enterprises, blogs, contact, email logs, analytics, settings). Đây là công cụ vận hành nội bộ của Cloud & Coral — người dùng cuối không bao giờ thấy. Đề xuất mạnh: GIỮ TRÊN WEB. Nếu vẫn muốn: ~20 task, cần thiết kế lại toàn bộ table-UX cho mobile.

## Khối D — Trang công khai/nội dung
Blog list + detail (`blog/*`), About, Services marketing pages, Coaching principles, Sample report, trang pháp lý (Terms/Privacy/Payment policy — bắt buộc nếu phát hành store: có thể nhúng WebView), Contact form. ~4 task, đa phần content tĩnh → cân nhắc WebView cho nhanh và luôn đồng bộ nội dung.

## Điểm không thể parity trên mobile (ghi nhận trước)
- SePay checkout (đã loại trừ vĩnh viễn theo chỉ đạo).
- Xuất Excel các bảng quản trị; Remotion video generation; email editor.
- Một số thao tác bulk (mời hàng loạt qua CSV…) cần thiết kế lại.

## Thứ tự đề xuất nếu triển khai: A → D (WebView) → B (companion rút gọn) → C (không khuyến nghị).

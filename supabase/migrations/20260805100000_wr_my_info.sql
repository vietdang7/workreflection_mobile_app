-- "Thông tin của bạn" — mockup Sprint 2 bản (4), `screenMyInfo`.
--
-- Màn này GỘP lại thông tin người dùng đã rải ra ba chỗ (Sửa hồ sơ, Khảo sát
-- tổ chức, Thông tin công việc) để xem và sửa ở đúng một chỗ. Bốn trong bảy
-- trường đã có sẵn cột bên `cc_profiles` — dùng chung với web, KHÔNG chép sang
-- đây:
--
--   experienceYears  → cc_profiles.total_work_experience
--   orgCompanySize   → cc_profiles.company_size
--   functionArea     → cc_profiles.department
--   seniority        → cc_profiles.position
--
-- Ba trường còn lại chưa có chỗ nào. Chúng nằm ở `wr_mobile_profiles` chứ không
-- thêm cột vào `cc_profiles`: bảng kia do web sở hữu và app chỉ đọc/ghi những
-- cột web đã định nghĩa. Thêm cột của riêng app vào bảng của web là mở đường
-- cho hai bên hiểu khác nhau về cùng một hàng.

alter table public.wr_mobile_profiles
  add column if not exists city text,
  add column if not exists org_industry text,
  add column if not exists org_company_type text;

comment on column public.wr_mobile_profiles.city is
  'Thành phố đang làm việc. Tuỳ chọn, người dùng tự khai ở màn "Thông tin của bạn".';
comment on column public.wr_mobile_profiles.org_industry is
  'Ngành của công ty. Tuỳ chọn. Không dùng để chấm điểm, chỉ để trợ lý AI hiểu bối cảnh.';
comment on column public.wr_mobile_profiles.org_company_type is
  'Loại hình công ty (Việt Nam / FDI / Startup / Nhà nước). Tuỳ chọn.';

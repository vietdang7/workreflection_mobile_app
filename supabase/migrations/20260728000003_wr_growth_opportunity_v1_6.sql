-- WorkReflection: Cơ hội phát triển + lịch sử tình huống đã xem + role_text.
-- Kiến trúc Dữ liệu Hai Lớp v1.6 §IV, §X, §XI.

-- ---------------------------------------------------------------------------
-- 1. recent_situation_ids — §IV.1 + §XII.2.
--
-- "recentSituationIds nên lưu theo Person, không chỉ theo phiên, để xoay vòng
-- hoạt động đúng qua nhiều ngày."
--
-- Đây là lý do nó nằm trên wr_mobile_profiles chứ không phải state trong app:
-- xoay vòng chống lặp chỉ có ý nghĩa khi nhớ được qua nhiều ngày và nhiều thiết
-- bị. Lưu theo phiên thì mở lại app là quên sạch, và người dùng gặp lại đúng
-- năm tình huống cũ.
--
-- Tối đa 30 mục, mới nhất đứng đầu — cắt ở tầng ứng dụng, vì Postgres không có
-- ràng buộc độ dài mảng gọn gàng và giới hạn này thuộc về luật nghiệp vụ.
-- ---------------------------------------------------------------------------

alter table public.wr_mobile_profiles
  add column if not exists recent_situation_ids text[] not null default '{}';

comment on column public.wr_mobile_profiles.recent_situation_ids is
  'Mã tình huống đã chọn gần đây, mới nhất đứng đầu, tối đa 30 '
  '(Hai Lớp v1.6 §4.1). Dùng cho cơ chế xoay vòng chống lặp lại.';

-- ---------------------------------------------------------------------------
-- 2. role_text trên Context Document — §11.3.
--
-- Màn "Thông tin công việc hiện tại" có hai phần: ô nhập tự do mô tả vai trò,
-- và tải lên JD/CV. App đã có phần tải lên (wr_context_documents + bucket
-- context-docs); đây là phần còn thiếu.
--
-- Vì sao là ô nhập tự do chứ không phải danh sách chọn: §11.3 cần "mô tả ngắn
-- về vị trí, phạm vi công việc, quy mô đội nhóm". Sáu lựa chọn cứng trong
-- kCareerRoleOptions không chứa nổi "phụ trách mảng B2C, quản lý một nhóm 4
-- người" — mà chính chi tiết đó mới làm gợi ý bám sát công việc thật.
--
-- Giữ nguyên current_role (danh sách chọn, dùng cho Career Snapshot); role_text
-- là lớp bổ sung, hoàn toàn tùy chọn.
-- ---------------------------------------------------------------------------

alter table public.wr_mobile_profiles
  add column if not exists role_text text;

comment on column public.wr_mobile_profiles.role_text is
  'Mô tả tự do về vai trò hiện tại (Hai Lớp v1.6 §11.3). Tùy chọn, '
  'chỉ ảnh hưởng độ chính xác của Cơ hội phát triển.';

-- ---------------------------------------------------------------------------
-- 3. wr_growth_opportunities — §11.5.
--
-- Lớp truy cập: Paid (§11.4) — đây là tổng hợp sâu trên toàn bộ hành trình,
-- không phải một phép đếm đơn giản như Pattern Cơ bản.
--
-- ⚠ §11.2 + §XII.7: suggestion_text và confidence_note KHÔNG được tách rời ở
--   tầng hiển thị. Ràng buộc NOT NULL dưới đây khiến không thể tạo một gợi ý
--   thiếu ghi chú độ chính xác ngay từ tầng dữ liệu.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_growth_opportunities (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  -- §11.1: luôn ở thể điều kiện, không phát biểu như một kết luận chắc chắn.
  suggestion_text text not null check (length(btrim(suggestion_text)) > 0),
  -- §11.5: tham chiếu Pattern/Story đã dùng để tổng hợp, phục vụ minh bạch và
  -- gỡ lỗi. Rỗng nghĩa là gợi ý không dựa trên gì — không nên hiển thị.
  based_on   text[] not null default '{}',
  -- §11.2: câu ghi chú cố định, KHÔNG đổi theo từng gợi ý. NOT NULL là có chủ ý.
  confidence_note text not null check (length(btrim(confidence_note)) > 0),
  -- §11.5: "gợi ý nên tính lại định kỳ, không phải mỗi lần mở app."
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists wr_growth_opportunities_user_idx
  on public.wr_growth_opportunities (user_id, generated_at desc);

alter table public.wr_growth_opportunities enable row level security;

drop policy if exists "wr_growth_opportunities_owner_select"
  on public.wr_growth_opportunities;
drop policy if exists "wr_growth_opportunities_owner_insert"
  on public.wr_growth_opportunities;
drop policy if exists "wr_growth_opportunities_owner_update"
  on public.wr_growth_opportunities;
drop policy if exists "wr_growth_opportunities_owner_delete"
  on public.wr_growth_opportunities;

create policy "wr_growth_opportunities_owner_select"
  on public.wr_growth_opportunities
  for select
  using (auth.uid() = user_id);

create policy "wr_growth_opportunities_owner_insert"
  on public.wr_growth_opportunities
  for insert
  with check (auth.uid() = user_id);

create policy "wr_growth_opportunities_owner_update"
  on public.wr_growth_opportunities
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_growth_opportunities_owner_delete"
  on public.wr_growth_opportunities
  for delete
  using (auth.uid() = user_id);

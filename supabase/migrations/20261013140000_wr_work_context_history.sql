-- 20261013140000_wr_work_context_history.sql
--
-- "Bối cảnh công việc" (script Sprint 2 `screenJobContext` + `ROLE_FIELDS`).
--
-- Khối VAI TRÒ có ba trường: Vị trí công việc · Kiến thức chuyên môn · Kỹ năng
-- chuyên môn. Script: "Mỗi lần sửa là một bản ghi mới, không đè lên bản cũ.
-- Người dùng xem lại được cả đường đi của vai trò theo thời gian." — nên mỗi
-- lần lưu là một dòng mới ở đây; giá trị hiện tại của một trường là dòng mới
-- nhất của trường đó. Không có thao tác sửa hay xoá dòng cũ (không policy
-- update/delete); xoá tài khoản thì dòng theo `auth.users` mà đi.
--
-- `field`:
--   position  — Vị trí công việc
--   knowledge — Kiến thức chuyên môn
--   skill     — Kỹ năng chuyên môn
--
-- ĐỒNG BỘ VỚI `wr_mobile_profiles.role_text`. Trợ lý trò chuyện, gợi ý chủ đề,
-- Cơ hội phát triển, đối chiếu kỹ năng và `wr-doc-analyze` đều đọc `role_text`.
-- App ghi giá trị mới nhất của `position` về `role_text` mỗi lần lưu, nên mọi
-- nơi đọc cũ vẫn chạy y nguyên; bảng này chỉ thêm phần lịch sử.

create table if not exists public.wr_work_context_history (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  field      text not null check (field in ('position','knowledge','skill')),
  value      text not null check (char_length(btrim(value)) between 1 and 4000),
  created_at timestamptz not null default now()
);

comment on table public.wr_work_context_history is
  'Lịch sử ba trường VAI TRÒ của màn Bối cảnh công việc. Mỗi lần lưu là một '
  'dòng mới (không đè). Dòng mới nhất của field position được app đồng bộ về '
  'wr_mobile_profiles.role_text.';

create index if not exists wr_work_context_history_user_field_idx
  on public.wr_work_context_history (user_id, field, created_at desc);

-- ============================================================
-- RLS: chỉ chủ sở hữu đọc và ghi thêm. Không update/delete — lịch sử không bị
-- sửa lại.
-- ============================================================

alter table public.wr_work_context_history enable row level security;

drop policy if exists "wr_work_context_history_owner_select"
  on public.wr_work_context_history;
drop policy if exists "wr_work_context_history_owner_insert"
  on public.wr_work_context_history;

create policy "wr_work_context_history_owner_select"
  on public.wr_work_context_history
  for select
  using (auth.uid() = user_id);

create policy "wr_work_context_history_owner_insert"
  on public.wr_work_context_history
  for insert
  with check (auth.uid() = user_id);

-- ============================================================
-- Backfill: `role_text` đang có trở thành bản đầu tiên của "Vị trí công việc".
--
-- Màn cũ đặt nhãn ô này là "VỊ TRÍ / CHỨC DANH HIỆN TẠI", nên đúng nghĩa trường
-- `position`. Lấy `updated_at` của hồ sơ làm mốc (gần nhất với lúc viết mà dữ
-- liệu còn giữ). Chạy lại migration không nhân đôi: bỏ qua người đã có dòng
-- `position`.
-- ============================================================

insert into public.wr_work_context_history (user_id, field, value, created_at)
select p.user_id,
       'position',
       left(btrim(p.role_text), 4000),
       coalesce(p.updated_at, p.created_at, now())
from public.wr_mobile_profiles p
where p.role_text is not null
  and char_length(btrim(p.role_text)) > 0
  and not exists (
    select 1
    from public.wr_work_context_history h
    where h.user_id = p.user_id
      and h.field = 'position'
  );

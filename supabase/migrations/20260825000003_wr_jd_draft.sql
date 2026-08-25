-- "Viết JD cùng app" — bản mô tả công việc do chính người dùng viết, chia 5
-- buổi ngắn.
--
-- Nguồn: WorkReflection_Changelog_20260824.docx §6, mockup v16 `screenJdBuilder`.
--
-- Dành cho người mà công ty chưa có JD sẵn. Thay vì đưa nguyên form tư vấn 8
-- trường vào app trong một lần, chia thành 5 buổi 2–3 phút, làm rải rác trong
-- tuần.
--
-- ---------------------------------------------------------------------------
-- Vì sao là một BẢNG RIÊNG, không phải thêm cột vào wr_mobile_profiles
-- ---------------------------------------------------------------------------
--
-- §6, ghi chú cho dev: "Dữ liệu JD cần một cấu trúc lưu trữ thống nhất (không
-- chỉ local state như trong mockup) để tái sử dụng cho Career Memory, gợi ý
-- Reflection sát với công việc thật, và Cơ hội phát triển."
--
-- Mười một trường nội dung cộng phần theo dõi tiến độ là một THỰC THỂ, không
-- phải mấy cột lẻ của hồ sơ: nó có vòng đời riêng (viết dở qua nhiều ngày, hoàn
-- tất, viết lại), và nó là nguồn cho ba tính năng khác. Nhét vào
-- `wr_mobile_profiles` thì mỗi lần đọc tên hiển thị lại kéo theo cả bản JD.
--
-- Một hàng cho mỗi người dùng: JD là mô tả công việc HIỆN TẠI, không phải lịch
-- sử nghề nghiệp. Đổi việc thì viết đè lên.
--
-- ---------------------------------------------------------------------------
-- Vì sao có cột `completed_days`
-- ---------------------------------------------------------------------------
--
-- §6, ghi chú cho dev: "Thanh nút Buổi 1–5 ở cuối màn hình chỉ phục vụ xem
-- trước cho demo — bản thật nên khoá buổi sau cho đến khi hoàn thành buổi
-- trước, không cho nhảy cóc tự do."
--
-- Việc khoá đó cần biết buổi nào ĐÃ XONG, và điều đó không suy được từ nội dung
-- các trường: một buổi có thể hoàn thành mà người dùng bỏ trống mọi ô (mọi
-- trường đều tuỳ chọn, đúng tinh thần cả app). Suy từ "có chữ hay không" sẽ
-- khoá ngược lại chính những người viết ít nhất.

create table if not exists public.wr_jd_drafts (
  user_id uuid primary key references auth.users(id) on delete cascade,

  -- Buổi 1 — Khởi động: 3 câu hỏi làm nóng trí nhớ, trả lời tự do. Đây là
  -- nguyên liệu cho các buổi sau, không phải trường của JD thành phẩm.
  warmup_repeated    text,  -- việc lặp đi lặp lại mỗi ngày, mỗi tuần
  warmup_blocked     text,  -- nghỉ phép một tuần thì việc gì ùn lại
  warmup_asked_about text,  -- đồng nghiệp/sếp hay nhờ, hay hỏi về việc gì

  -- Buổi 2 — Vị trí & mục tiêu.
  job_title   text,
  department  text,
  reports_to  text,
  seniority   text,
  purpose     text,  -- vì sao vị trí này tồn tại

  -- Buổi 3 — Nhiệm vụ chính. Mỗi dòng một nhiệm vụ.
  --
  -- §6: đã BỎ việc chia % theo mảng ra khỏi luồng chính, để riêng thành tính
  -- năng nâng cao. Không tạo sẵn cột cho nó ở đây.
  main_tasks text,

  -- Buổi 4 — Kết quả & kỹ năng.
  outcomes    text,  -- kết quả, KPI
  skills      text,  -- kiến thức, kỹ năng, công cụ

  -- Buổi 5 — Mối quan hệ & điều kiện làm việc.
  collaborators   text,
  work_conditions text,

  -- Tiến độ. `current_day` là buổi người dùng đang dở, `completed_days` là
  -- những buổi đã bấm "Lưu và tiếp tục".
  current_day    smallint not null default 1 check (current_day between 1 and 5),
  completed_days smallint[] not null default '{}',

  -- Đã đi hết buổi 5. Tách khỏi completed_days để câu truy vấn "ai đã có JD"
  -- không phải đụng vào mảng.
  completed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.wr_jd_drafts is
  'Bản JD người dùng tự viết qua 5 buổi ngắn (changelog 24/08/2026 §6). '
  'Nguồn cho gợi ý Reflection, Cơ hội phát triển và đối chiếu kỹ năng.';

-- ---------------------------------------------------------------------------
-- RLS — dữ liệu riêng tư, chỉ chủ sở hữu đọc/ghi.
--
-- Cùng khuôn với mọi bảng wr_* khác. Đây là mô tả công việc thật của người
-- dùng, có tên phòng ban và tên người quản lý — rò ra là rò chỗ làm của họ.
-- ---------------------------------------------------------------------------

alter table public.wr_jd_drafts enable row level security;

drop policy if exists "wr_jd_drafts_owner_select" on public.wr_jd_drafts;
drop policy if exists "wr_jd_drafts_owner_insert" on public.wr_jd_drafts;
drop policy if exists "wr_jd_drafts_owner_update" on public.wr_jd_drafts;
drop policy if exists "wr_jd_drafts_owner_delete" on public.wr_jd_drafts;

create policy "wr_jd_drafts_owner_select"
  on public.wr_jd_drafts for select
  using (auth.uid() = user_id);

create policy "wr_jd_drafts_owner_insert"
  on public.wr_jd_drafts for insert
  with check (auth.uid() = user_id);

create policy "wr_jd_drafts_owner_update"
  on public.wr_jd_drafts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_jd_drafts_owner_delete"
  on public.wr_jd_drafts for delete
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- updated_at tự cập nhật.
-- ---------------------------------------------------------------------------

create or replace function public.wr_jd_drafts_touch()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists wr_jd_drafts_touch on public.wr_jd_drafts;

create trigger wr_jd_drafts_touch
  before update on public.wr_jd_drafts
  for each row execute function public.wr_jd_drafts_touch();

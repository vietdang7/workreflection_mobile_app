-- Khảo sát tổ chức (ESI + eNPS) — mockup Sprint 2, màn Hồ sơ.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO TÁCH KHỎI BỘ KHẢO SÁT CŨ
--
-- Trong app đã có một tầng tên "ESI" rồi: `cc_questions.layer = 'ESI'`, một
-- trong bốn tầng của bộ khảo sát SCA bên web. Đó KHÔNG phải thứ này.
--
--   • Bộ cũ: ESI là một tầng nằm bên trong một bài khảo sát dài, kết quả chảy
--     vào báo cáo cá nhân và bản PDF.
--   • Bộ này: một bài riêng, 12 câu hài lòng + 1 câu eNPS, mockup ghi rõ
--     "Tuỳ chọn, tách riêng khỏi Reflection" và "Hoàn toàn không ảnh hưởng đến
--     Reflection, Insight hay Career Memory cá nhân của bạn".
--
-- Nhét chung vào `cc_responses` là phá đúng lời hứa vừa in ra màn hình cho
-- người dùng đọc, vì điểm sẽ chảy vào báo cáo cá nhân của họ.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1 · Câu hỏi
--
-- Để trong bảng chứ không ghi cứng trong app, giống `wr_sca_self_check_questions`:
-- câu chữ khảo sát là thứ người vận hành sẽ chỉnh, và mỗi lần chỉnh mà phải phát
-- hành lại app thì trên thực tế là không chỉnh được.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_org_survey_questions (
  id         text primary key,
  area       text not null
             check (area in ('compensation', 'growth', 'fairness', 'support')),
  text       text not null check (length(btrim(text)) > 0),
  sort_order integer not null,
  active     boolean not null default true
);

comment on table public.wr_org_survey_questions is
  'Câu hỏi Khảo sát tổ chức (ESI). Thang 5 mức hài lòng, lưu 0..4. '
  'KHÔNG liên quan tới cc_questions.layer = ''ESI'' của bộ khảo sát SCA.';

create index if not exists wr_org_survey_questions_order_idx
  on public.wr_org_survey_questions (sort_order)
  where active;

alter table public.wr_org_survey_questions enable row level security;

drop policy if exists "wr_org_survey_questions_select_all"
  on public.wr_org_survey_questions;

-- Bảng tĩnh, không có dữ liệu riêng của ai: mọi người đăng nhập đều đọc được.
create policy "wr_org_survey_questions_select_all"
  on public.wr_org_survey_questions
  for select
  to authenticated
  using (true);

grant select on public.wr_org_survey_questions to authenticated;

insert into public.wr_org_survey_questions (id, area, text, sort_order) values
  ('OS-01', 'compensation', 'Mức độ hài lòng của bạn với thu nhập hiện tại, so với khối lượng và tính chất công việc bạn đang làm.', 1),
  ('OS-02', 'compensation', 'Mức độ hài lòng của bạn với các phúc lợi hiện có, như bảo hiểm, thưởng, nghỉ phép.', 2),
  ('OS-03', 'compensation', 'Mức độ hài lòng của bạn khi so sánh đãi ngộ hiện tại với mặt bằng chung ngành.', 3),
  ('OS-04', 'growth', 'Mức độ hài lòng của bạn với cơ hội học hỏi kỹ năng mới trong công việc hiện tại.', 4),
  ('OS-05', 'growth', 'Mức độ hài lòng của bạn với lộ trình hoặc định hướng phát triển cho vị trí hiện tại.', 5),
  ('OS-06', 'growth', 'Mức độ hài lòng của bạn với mức đầu tư thời gian và ngân sách của tổ chức cho việc phát triển năng lực của bạn.', 6),
  ('OS-07', 'fairness', 'Mức độ hài lòng của bạn với cách các quyết định thăng tiến, khen thưởng được đưa ra trong đội.', 7),
  ('OS-08', 'fairness', 'Mức độ hài lòng của bạn với sự công bằng trong cách bạn được đối xử so với đồng nghiệp cùng vị trí.', 8),
  ('OS-09', 'fairness', 'Mức độ hài lòng của bạn với cách các vấn đề hoặc khiếu nại được xử lý.', 9),
  ('OS-10', 'support', 'Mức độ hài lòng của bạn với sự hỗ trợ nhận được khi gặp khó khăn trong công việc.', 10),
  ('OS-11', 'support', 'Mức độ hài lòng của bạn với sự quan tâm của cấp quản lý trực tiếp đến khối lượng và sức khỏe tinh thần của bạn.', 11),
  ('OS-12', 'support', 'Mức độ hài lòng của bạn với công cụ và nguồn lực được cung cấp để hoàn thành công việc.', 12)
on conflict (id) do update
  set area = excluded.area,
      text = excluded.text,
      sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- 2 · Câu trả lời
--
-- `answers` là nguồn sự thật; bốn cột trung bình do TRIGGER tính, không do app
-- gửi lên. Nếu app tự tính rồi gửi kèm, hàm benchmark ở mục 3 sẽ cộng những con
-- số mà không gì bảo đảm là khớp với `answers` — và sai lệch đó thì không ai
-- nhìn thấy cho tới lúc bản so sánh nói một điều vô lý.
--
-- Bỏ trống câu nào cũng được (mockup cho thoát giữa chừng, và ô "Chưa trả lời"
-- có mặt trong màn kết quả): trung bình chỉ tính trên số câu đã trả lời, cả bốn
-- mảng đều để null được.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_org_survey_responses (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  answers          jsonb not null default '{}'::jsonb,
  enps             smallint check (enps between 0 and 10),
  avg_compensation numeric(4, 2),
  avg_growth       numeric(4, 2),
  avg_fairness     numeric(4, 2),
  avg_support      numeric(4, 2),
  created_at       timestamptz not null default now()
);

comment on table public.wr_org_survey_responses is
  'Một lần làm Khảo sát tổ chức. answers = {question_id: 0..4}. '
  'Bốn cột avg_* do trigger tính từ answers, app không ghi.';

create index if not exists wr_org_survey_responses_user_created_idx
  on public.wr_org_survey_responses (user_id, created_at desc);

create or replace function public.wr_org_survey_compute_avgs()
returns trigger
language plpgsql
as $$
declare
  v record;
begin
  select
    avg(a.val::numeric) filter (where q.area = 'compensation') as c,
    avg(a.val::numeric) filter (where q.area = 'growth')       as g,
    avg(a.val::numeric) filter (where q.area = 'fairness')     as f,
    avg(a.val::numeric) filter (where q.area = 'support')      as s
  into v
  from jsonb_each_text(new.answers) as a(key, val)
  join public.wr_org_survey_questions q on q.id = a.key
  -- Câu ngoài thang 0..4 bị loại thay vì làm hỏng cả trung bình. Một giá trị
  -- rác lọt vào sẽ kéo lệch bản so sánh của mọi người, không chỉ của người gửi.
  where a.val ~ '^[0-4]$';

  new.avg_compensation := round(v.c, 2);
  new.avg_growth       := round(v.g, 2);
  new.avg_fairness     := round(v.f, 2);
  new.avg_support      := round(v.s, 2);
  return new;
end;
$$;

drop trigger if exists wr_org_survey_responses_avgs
  on public.wr_org_survey_responses;

create trigger wr_org_survey_responses_avgs
  before insert or update of answers
  on public.wr_org_survey_responses
  for each row execute function public.wr_org_survey_compute_avgs();

alter table public.wr_org_survey_responses enable row level security;

drop policy if exists "wr_org_survey_responses_select_own"
  on public.wr_org_survey_responses;
drop policy if exists "wr_org_survey_responses_insert_own"
  on public.wr_org_survey_responses;
drop policy if exists "wr_org_survey_responses_delete_own"
  on public.wr_org_survey_responses;

create policy "wr_org_survey_responses_select_own"
  on public.wr_org_survey_responses
  for select
  using (auth.uid() = user_id);

create policy "wr_org_survey_responses_insert_own"
  on public.wr_org_survey_responses
  for insert
  with check (auth.uid() = user_id);

-- CÓ policy delete, khác với `wr_career_questions`. Màn giới thiệu hứa thẳng
-- "Có thể ngừng tham gia bất kỳ lúc nào" — không có quyền xoá thì đó là một lời
-- hứa app không giữ được.
create policy "wr_org_survey_responses_delete_own"
  on public.wr_org_survey_responses
  for delete
  using (auth.uid() = user_id);

-- Cố tình KHÔNG có policy update: một lần làm là một bản ghi tại một thời điểm.
-- Sửa lại câu trả lời cũ sẽ làm chuỗi theo thời gian nói sai về quá khứ.
grant select, insert, delete on public.wr_org_survey_responses to authenticated;

-- ---------------------------------------------------------------------------
-- 3 · Mặt bằng chung
--
-- Mockup ghi cứng {compensation:2.1, growth:2.6, fairness:2.4, support:2.8,
-- enps:6.4}. Đó là số minh hoạ cho bản demo. Đem nguyên vào sản phẩm rồi dán
-- nhãn "mặt bằng chung ẩn danh" là nói với người dùng một điều không có thật.
--
-- Thay vào đó:
--   • đủ [min_sample] người trả lời  → tính thật từ dữ liệu, source = 'live'
--   • chưa đủ nhưng người vận hành đã nhập số tham chiếu ngành → 'reference'
--   • chưa có gì                     → 'none', và màn kết quả chỉ hiện điểm của
--                                       chính người dùng, không vẽ vạch so sánh
--
-- Ngưỡng mẫu tối thiểu vừa để con số có nghĩa, vừa để tránh chuyện với 2 người
-- trả lời thì "mặt bằng chung" gần như là điểm của chính người còn lại.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_org_survey_reference (
  area       text primary key
             check (area in ('compensation', 'growth', 'fairness', 'support', 'enps')),
  avg_value  numeric(4, 2) not null,
  note       text,
  updated_at timestamptz not null default now()
);

comment on table public.wr_org_survey_reference is
  'Số tham chiếu ngành do người vận hành nhập, dùng khi chưa đủ mẫu thật. '
  'Để TRỐNG cho tới khi có nguồn thật — bảng rỗng thì app không vẽ vạch so sánh.';

alter table public.wr_org_survey_reference enable row level security;
-- Không policy nào cho `authenticated`: app chỉ đọc bảng này gián tiếp qua hàm
-- bên dưới. Người vận hành ghi bằng service role.

create or replace function public.wr_org_survey_benchmark(min_sample integer default 30)
returns table (area text, avg_value numeric, sample_size integer, source text)
language sql
stable
security definer
set search_path = public
as $$
  with live as (
    select
      count(avg_compensation)::int as n_compensation,
      count(avg_growth)::int       as n_growth,
      count(avg_fairness)::int     as n_fairness,
      count(avg_support)::int      as n_support,
      count(enps)::int             as n_enps,
      round(avg(avg_compensation), 2) as a_compensation,
      round(avg(avg_growth), 2)       as a_growth,
      round(avg(avg_fairness), 2)     as a_fairness,
      round(avg(avg_support), 2)      as a_support,
      round(avg(enps), 2)             as a_enps
    from public.wr_org_survey_responses
  ),
  unpivoted as (
    select 'compensation' as area, a_compensation as v, n_compensation as n from live
    union all select 'growth',     a_growth,     n_growth     from live
    union all select 'fairness',   a_fairness,   n_fairness   from live
    union all select 'support',    a_support,    n_support    from live
    union all select 'enps',       a_enps,       n_enps       from live
  )
  select
    u.area,
    case when u.n >= min_sample then u.v else r.avg_value end,
    u.n,
    case
      when u.n >= min_sample then 'live'
      when r.avg_value is not null then 'reference'
      else 'none'
    end
  from unpivoted u
  left join public.wr_org_survey_reference r on r.area = u.area;
$$;

comment on function public.wr_org_survey_benchmark(integer) is
  'Mặt bằng chung để so sánh. SECURITY DEFINER vì phải đọc câu trả lời của mọi '
  'người — chỉ trả về SỐ TỔNG HỢP, không dòng nào truy ngược được về cá nhân.';

revoke all on function public.wr_org_survey_benchmark(integer) from public;
grant execute on function public.wr_org_survey_benchmark(integer) to authenticated;

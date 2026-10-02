-- Khách 01/10: ngưỡng so sánh 10 người, thêm "Lĩnh vực làm việc", đếm theo người.

alter table public.wr_org_survey_responses
  add column if not exists industry text
  check (industry in ('tech','finance','manufacturing','retail','education',
                      'healthcare','construction','other'));

comment on column public.wr_org_survey_responses.industry is
  'Lĩnh vực lúc làm khảo sát (chụp lại, không đọc từ hồ sơ) — mã giống wr_mobile_profiles.org_industry.';

create or replace function public.wr_org_survey_benchmark_v2(p_industry text default null)
returns table (scope text, area text, avg_value numeric, sample_size integer, source text)
language sql
stable
security definer
set search_path = public
as $$
  -- Ngưỡng nằm CỨNG ở đây, không nhận từ app: ai gọi cũng không hạ được.
  with cfg as (select 10 as min_sample),
  latest as (
    -- Một người một phiếu: phiếu mới nhất. Làm lại 10 lần không mở khoá so sánh.
    select distinct on (user_id) *
    from public.wr_org_survey_responses
    order by user_id, created_at desc
  ),
  scoped as (
    select 'all'::text as scope, l.* from latest l
    union all
    select 'industry', l.* from latest l
    where p_industry is not null and l.industry = p_industry
  ),
  agg as (
    select scope,
      count(avg_compensation)::int n_c, round(avg(avg_compensation),2) a_c,
      count(avg_growth)::int       n_g, round(avg(avg_growth),2)       a_g,
      count(avg_fairness)::int     n_f, round(avg(avg_fairness),2)     a_f,
      count(avg_support)::int      n_s, round(avg(avg_support),2)      a_s,
      count(enps)::int             n_e, round(avg(enps),2)             a_e
    from scoped group by scope
  ),
  scopes as (
    select 'all'::text as scope
    union all select 'industry' where p_industry is not null
  ),
  unpivoted as (
    select s.scope, x.area, x.v, coalesce(x.n, 0) as n
    from scopes s
    left join agg a on a.scope = s.scope
    cross join lateral (values
      ('compensation', a.a_c, a.n_c), ('growth', a.a_g, a.n_g),
      ('fairness', a.a_f, a.n_f), ('support', a.a_s, a.n_s), ('enps', a.a_e, a.n_e)
    ) as x(area, v, n)
  )
  select u.scope, u.area,
    case when u.n >= c.min_sample then u.v
         when u.scope = 'all' then r.avg_value end,
    u.n,
    case when u.n >= c.min_sample then 'live'
         when u.scope = 'all' and r.avg_value is not null then 'reference'
         else 'none' end
  from unpivoted u cross join cfg c
  left join public.wr_org_survey_reference r on r.area = u.area;
$$;

comment on function public.wr_org_survey_benchmark_v2(text) is
  'Mặt bằng chung v2: một người một phiếu (phiếu mới nhất), ngưỡng 10 cứng phía server. '
  'SECURITY DEFINER vì phải đọc câu trả lời của mọi người, chỉ trả SỐ TỔNG HỢP.';

revoke all on function public.wr_org_survey_benchmark_v2(text) from public;
revoke all on function public.wr_org_survey_benchmark_v2(text) from anon;
grant execute on function public.wr_org_survey_benchmark_v2(text) to authenticated;

-- Bản cũ: app đang chạy ngoài thị trường vẫn gọi tên này kèm min_sample.
-- Giữ chữ ký, BỎ QUA tham số (vá lỗ hổng min_sample => 1), trả đúng cột cũ.
create or replace function public.wr_org_survey_benchmark(min_sample integer default 30)
returns table (area text, avg_value numeric, sample_size integer, source text)
language sql stable security definer set search_path = public
as $$
  select area, avg_value, sample_size, source
  from public.wr_org_survey_benchmark_v2(null) where scope = 'all';
$$;

revoke all on function public.wr_org_survey_benchmark(integer) from public;
revoke all on function public.wr_org_survey_benchmark(integer) from anon;
grant execute on function public.wr_org_survey_benchmark(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Câu kiểm, chạy tay SAU KHI push (không có supabase/tests):
--
--   select * from wr_org_survey_benchmark_v2(null);    -- 5 dòng scope='all'
--   select * from wr_org_survey_benchmark_v2('tech');  -- 10 dòng
--   select * from wr_org_survey_benchmark(1);          -- source vẫn 'none' nếu < 10 người
--
--   -- Một người làm lại nhiều lần chỉ tính 1:
--   --   select area, sample_size from wr_org_survey_benchmark_v2(null) where area='enps';
--   --   so với: select count(distinct user_id) from wr_org_survey_responses where enps is not null;
--   --   (hai con số phải bằng nhau nếu mỗi người có phiếu mới nhất có enps)
--
--   -- Anon không gọi được:
--   --   select has_function_privilege('anon','public.wr_org_survey_benchmark_v2(text)','execute'); -- false
-- ---------------------------------------------------------------------------

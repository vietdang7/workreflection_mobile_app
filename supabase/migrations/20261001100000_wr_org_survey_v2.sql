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
      count(avg_compensation)::int n_c, round(avg(avg_compensation),1) a_c,
      count(avg_growth)::int       n_g, round(avg(avg_growth),1)       a_g,
      count(avg_fairness)::int     n_f, round(avg(avg_fairness),1)     a_f,
      count(avg_support)::int      n_s, round(avg(avg_support),1)      a_s,
      count(enps)::int             n_e, round(avg(enps),1)             a_e
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
  counted as (
    -- n_all: số người của phạm vi 'all' cho cùng mảng, để tính phần bù bên dưới.
    select u.*, max(case when u.scope = 'all' then u.n end) over (partition by u.area) as n_all
    from unpivoted u
  ),
  judged as (
    select d.*, c.min_sample,
      -- Phạm vi 'industry' chỉ được trả số khi:
      --   (1) đủ ngưỡng cùng ngành, VÀ
      --   (2) phần bù (n_all - n_industry) bằng 0 hoặc cũng đủ ngưỡng.
      -- Một lần gọi trả cả hai dòng: nếu phần bù chỉ còn 1-9 người thì
      -- n_all*avg_all - n_ind*avg_ind = tổng điểm của đúng những người đó,
      -- tức suy ngược được điểm cá nhân. Phần bù 0 thì không còn ai để suy.
      case when d.scope = 'industry'
           then d.n >= c.min_sample
                and (d.n_all - d.n = 0 or d.n_all - d.n >= c.min_sample)
           else d.n >= c.min_sample end as is_live
    from counted d cross join cfg c
  )
  select j.scope, j.area,
    case when j.is_live then j.v
         when j.scope = 'all' then r.avg_value end,
    -- Industry không live: trả 0, không lộ số đếm thật (số nhỏ cũng là thông tin).
    case when j.scope = 'industry' and not j.is_live then 0 else j.n end,
    case when j.is_live then 'live'
         when j.scope = 'all' and r.avg_value is not null then 'reference'
         else 'none' end
  from judged j
  left join public.wr_org_survey_reference r on r.area = j.area;
$$;

comment on function public.wr_org_survey_benchmark_v2(text) is
  'Mặt bằng chung v2: một người một phiếu (phiếu mới nhất), ngưỡng 10 cứng phía server. '
  'Dòng industry chỉ live khi đủ ngưỡng VÀ phần bù (all - industry) bằng 0 hoặc đủ ngưỡng, '
  'để không suy ngược điểm cá nhân bằng phép trừ giữa hai phạm vi; không live thì sample_size = 0. '
  'Trung bình làm tròn 1 chữ số. '
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

comment on function public.wr_org_survey_benchmark(integer) is
  'Bản cũ cho các build đã lên store: tham số min_sample được BỎ QUA, ngưỡng nằm cứng trong wr_org_survey_benchmark_v2.';

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
--   -- Một người làm lại nhiều lần chỉ tính 1 (so với số người có PHIẾU MỚI NHẤT có enps):
--   --   select area, sample_size from wr_org_survey_benchmark_v2(null) where area='enps';
--   --   select count(*) from (
--   --     select distinct on (user_id) user_id, enps
--   --     from wr_org_survey_responses order by user_id, created_at desc
--   --   ) t where enps is not null;
--   --   (hai con số phải bằng nhau)
--
--   -- Làm lại không mở khoá được (CHỈ CHẠY TRONG GIAO DỊCH, rồi rollback):
--   --   begin;
--   --   -- chèn 10 phiếu mới cho cùng MỘT user_id có sẵn (điền các cột bắt buộc còn lại theo bảng):
--   --   insert into wr_org_survey_responses (user_id, enps, created_at)
--   --     select (select user_id from wr_org_survey_responses limit 1), 8, now() + g * interval '1 second'
--   --     from generate_series(1,10) g;
--   --   select area, sample_size from wr_org_survey_benchmark_v2(null) where area='enps';
--   --   -- sample_size tăng tối đa 1 so với trước khi chèn
--   --   rollback;
--
--   -- Phép trừ giữa hai phạm vi bị chặn: với n_all - n_industry trong 1..9 thì
--   -- dòng scope='industry' phải có source='none', sample_size=0.
--   --   select scope, area, sample_size, source from wr_org_survey_benchmark_v2('tech') where scope='industry';
--
--   -- Anon không gọi được:
--   --   select has_function_privilege('anon','public.wr_org_survey_benchmark_v2(text)','execute'); -- false
-- ---------------------------------------------------------------------------

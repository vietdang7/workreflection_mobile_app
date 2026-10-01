# Kế hoạch triển khai: các việc chốt trong buổi họp khách (01/10/2026)

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyên dùng) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`) để theo dõi.

**Mục tiêu:** làm 5 trong 6 hạng mục khách chốt: Onboarding, Câu chữ & ngắt dòng, trang Phát triển, Khảo sát tổ chức, Web App. **Hạng mục 2 (Âm thanh & Voice AI) bỏ ra theo yêu cầu.**

**Kiến trúc:** đây là 6 phân hệ độc lập, chia thành 6 đợt (A–F). Mỗi đợt là một nhánh và một PR riêng, tự kiểm thử được, không đợt nào chặn đợt nào. Đợt A–E làm ở repo mobile Flutter (`appmobileworkreflection`), đợt F làm ở repo web (`workreflection`, GitHub `vietdang7/workreflection-app`). Hai repo dùng chung Supabase `sukpcxevcjnhiuyaoqxi`.

**Công nghệ:**
- Mobile: Flutter 3.41, Riverpod, go_router, supabase_flutter, `tr()` cho song ngữ (lớp ARB chỉ còn ở màn cũ).
- Web: Vite 5, React 18, TypeScript, Tailwind/shadcn, recharts, `qrcode.react`.
- Backend: Supabase Postgres + Edge Functions (Deno).

**Nguồn yêu cầu:** biên bản họp khách người dùng dán vào phiên 01/10/2026 (bản tổng hợp 6 hạng mục). Hiện trạng code ghi trong kế hoạch được 5 agent đọc trực tiếp ngày 01/10 trên `main` @ `4cd3433`, index GitNexus dựng lại cùng ngày.

## Ràng buộc chung

- **Supabase:** MCP `supabase` của phiên trỏ sang project KHÁC (`zsvisvrmfssxkytuiuun`), tuyệt đối không ghi qua đó.
  - Migration viết thành file `supabase/migrations/YYYYMMDDHHMMSS_wr_<chủ_đề>.sql`.
  - Đẩy bằng `supabase db push --include-all`, luôn `--dry-run` trước.
  - Giữ nguyên các file `*_remote_stub.sql`. Không dùng `migration repair`.
- **Trước khi sửa một hàm/class:** chạy `node .gitnexus/run.cjs impact "<symbol>" --direction upstream --repo .` và báo rủi ro. HIGH/CRITICAL phải báo người dùng. UNKNOWN phải dò thêm bằng grep.
- **Trước mỗi commit:** chạy `node .gitnexus/run.cjs detect-changes --scope all --repo .`.
- **Chữ hiển thị:**
  - Mọi câu mới viết `tr('vi', 'en')`.
  - Hằng chở `tr()` phải là **getter**, không phải `const`/`final` cấp file.
  - Route mới phải bọc `wrRoute(...)` với builder không-const.
- **Chính tả nội dung:**
  - Không dùng dấu "—" trong chữ hiển thị.
  - Nút Coral chữ Navy, nền xám `#F4F4F6`.
  - Tên sản phẩm viết liền **"WorkReflection"** cho tới khi khách xác nhận khác (xem Q2).
- **Bảng mới (`wr_*`):**
  - 4 policy owner-only `<bảng>_owner_select/insert/update/delete` với `auth.uid() = user_id`.
  - Thêm bảng vào `exportUserData` (`lib/core/data/wr_repository.dart:730-737`).
  - Fake repo phải **chép lại mọi CHECK** của bảng, kèm một contract test như `test/core/wr_memory_event_db_contract_test.dart`. Lý do: đã hai lần dính lỗi 400 vì fake không có CHECK.
- **Cổng mỗi đợt:**
  - `flutter analyze` = 0.
  - `flutter test` đủ bộ, so với baseline `git stash`, 0 hồi quy.
  - `deno test` nếu đụng Edge Function.
  - `flutter build apk --debug` OK.
- **Git:**
  - Mỗi đợt một nhánh `feat/<đợt>-20261001`, tạo PR rồi **dừng**. Sếp (`vietdang7`) tự merge, không tự merge.
  - Commit kết bằng dòng `Co-Authored-By` theo quy định phiên.
- **Phát hành:** mọi thay đổi mobile cần một bản build iOS mới qua Codemagic và nộp duyệt lại. Gom đợt A–E vào **một** lần nộp.

## Trọng tâm khi review

1. **Người dùng làm lại khảo sát nhiều lần.** Mặt bằng chung phải tính **một người một phiếu** (phiếu mới nhất). Không được để một người làm 10 lần là mở khoá so sánh. Test ở Task A1 (SQL) và A2 (fake repo).
2. **Ai cũng gọi được RPC mặt bằng chung với tham số tuỳ ý.** Hiện ai gọi `min_sample => 1` cũng đọc được trung bình thật. Ngưỡng phải nằm cứng phía server. Test ở Task A1.
3. **Câu tiêu đề ngắn lại bị nối cứng thành khối không ngắt được.** Đây là lỗi "feeling goo" ngày 11/09. Helper chống rớt chữ mới chỉ được nối khi đuôi đủ ngắn. Test ở Task B1 (cả tiếng Anh).
4. **Việc tự đặt của người dùng bị tính như chủ đề thư viện.** Nếu vậy nó sẽ chiếm quota Free 2 chủ đề, chặn auto-enroll và lọt vào chat. Task D1 phải chứng minh `practiceEnrollmentsProvider` không đổi.
5. **Video giới thiệu không tải được** (mạng yếu, web chặn autoplay có tiếng). Màn chào phải vẫn bấm "Bắt đầu" được và không treo. Test ở Task E2.

---

## Câu hỏi cần khách trả lời (chặn một số task)

| # | Câu hỏi | Chặn task | Mặc định nếu khách chưa trả lời |
|---|---|---|---|
| Q1 | Ai làm video Mascot? Khách cần gửi file mascot gốc và video hoàn chỉnh (mp4 H.264, ≤ 60 giây, ≤ 15 MB). Có cần bản tiếng Anh không? | E2 (nội dung), không chặn code | Làm code với video tạm. Đổi URL khi có file thật |
| Q2 | Viết "Work Reflection" (tách) hay "WorkReflection" (liền như khắp app)? | E1 | "WorkReflection" |
| Q3 | Viết lại câu hỏi Reflection gồm những bộ nào? Bộ Self-check 15 câu có nằm trong phạm vi không (header file ghi "KHÔNG tự biên tập lại", nguồn là mockup)? | C1 | Luồng 5 bước + 72 câu `reflection_question` của story. KHÔNG đụng Self-check và Khảo sát tổ chức |
| Q4 | "Vết AI" cụ thể là gì? Xin ảnh chụp 2–3 chỗ | B3 | Dấu "—", emoji, `**`, `#`, gạch đầu dòng do AI sinh |
| Q5 | Khai chứng chỉ/kỹ năng có mở cho Free không? AI đọc file chứng chỉ có phải Premium như JD/CV không? | D2 | Khai tay: mọi gói. AI đọc file: Premium |
| Q6 | "Tự lên kế hoạch": Free được mấy việc? Làm đủ 5 lần có tính là "Kỹ năng đã hình thành" không? Có hiện ở tab Hành trình không? Khách đã từng bác "mời thêm chủ đề" ở tab này; ô này là việc **của người dùng**, không phải chủ đề thư viện. Khách xác nhận giúp | D1 | Không giới hạn. Không tính vào Kỹ năng đã hình thành. Không lên Hành trình |
| Q7 | "Lĩnh vực làm việc" là **ngành** (8 lựa chọn có sẵn ở "Thông tin của bạn") hay **phòng ban/chức năng**? Ngưỡng 10 người có chấp nhận về mặt ẩn danh không? Có so theo từng ngành không? | A1–A3 | Ngành (8 mã `myInfoIndustryOptions`). Ngưỡng 10. So theo ngành khi ngành đó đủ 10 người |
| Q8 | Web: sếp vừa merge PR #53 sáng nay (khung điện thoại dựng bằng HTML). Khách muốn thay bằng ảnh chụp thật trong khung đó, hay thêm một dải ảnh chụp riêng? | F2 | Thay ruột khung bằng ảnh chụp thật, giữ 4 tab bấm được |
| Q9 | Analytics: cần **Vendor Number** (App Store Connect → Payments and Financial Reports). File khoá `AuthKey_DLFUYXK3QT.p8` còn trên máy không? | F3 | Chặn F3 tới khi có đủ |

---

## Thứ tự và ước lượng

| Đợt | Hạng mục khách | Ngày công | Phụ thuộc |
|---|---|---|---|
| A | 5. Khảo sát tổ chức (lỗi "chưa có kết quả" + Lĩnh vực + ngưỡng 10) | 1.5 | Q7 (có mặc định) |
| B | 3. Ngắt dòng + làm sạch vết AI | 1.5 | Q4 (có mặc định) |
| C | 3. Viết lại câu hỏi Reflection | 1 soạn + 1 áp | **Khách duyệt bảng câu** |
| D | 4. Kế hoạch tự đặt (D1) + Chứng chỉ/kỹ năng đã có (D2) | 2 + 2.5 | Q5, Q6 (có mặc định) |
| E | 1. Màn chào + video một lần | 1.5 | Q1 (video thật), Q2 |
| F | 6. Web: logo Apple + ô Google Play (F1), ảnh chụp thật (F2), lượt tải (F3) | 0.5 + 1 + 2 | Q8, **Q9 chặn F3** |
| | **Tổng** | **≈ 15.5** | |

**Lịch đề xuất:**
- **Tuần 1 (02–08/10):** gửi khách bảng Q1–Q9. Làm A, B, F1. Soạn bảng câu hỏi C1 gửi khách duyệt.
- **Tuần 2 (09–15/10):** D1, D2.
- **Tuần 3 (16–22/10):** E (khi có video), C2 (khi khách duyệt), F2, F3 (khi có Vendor Number). Build iOS, nộp duyệt.

---

## ĐỢT A: Khảo sát tổ chức

**Hiện trạng đã kiểm chứng (01/10):**
- Migration `20260805000000_wr_org_survey.sql` **đã có trên remote**.
- Lỗi khách gặp gần như chắc chắn là hành vi đúng thiết kế: RPC `wr_org_survey_benchmark` chỉ trả so sánh khi **≥ 30 dòng**, mà bảng `wr_org_survey_reference` cố ý để trống. Vì vậy ngay sau khi làm xong, cả 4 mảng và eNPS đều hiện "Chưa đủ dữ liệu để so sánh", và khách đọc thành "chưa có kết quả".
- Có thêm hai lỗi thật:
  - RPC đếm **dòng**, không đếm người.
  - `min_sample` do app tự truyền lên.
- Lỗi đọc mặt bằng chung bị nuốt thành map rỗng (`org_survey_providers.dart:36-46`), nên "RPC hỏng" trông y hệt "chưa đủ người".

### Task A0: Đo dữ liệu thật trên remote (không sửa gì)

- [ ] **Bước 1:** nhờ người dùng chạy trong SQL Editor của dashboard `sukpcxevcjnhiuyaoqxi`, rồi ghi kết quả vào PR:

```sql
select count(*) as rows, count(distinct user_id) as users from public.wr_org_survey_responses;
select * from public.wr_org_survey_benchmark(30);
```

Kỳ vọng: `users < 30`, mọi dòng `source = 'none'`. Như vậy là xác nhận giả thuyết số 1. Nếu RPC lỗi thì ghi lại mã lỗi; Task A2 sẽ làm lỗi đó hiện ra màn hình.

### Task A1: Migration mặt bằng chung v2 + cột lĩnh vực

**Files:**
- Tạo: `supabase/migrations/20261001100000_wr_org_survey_v2.sql`
- Test: `supabase/tests/wr_org_survey_v2_test.sql`. Nếu thư mục `supabase/tests` chưa có thì ghi các câu kiểm vào cuối file migration dạng comment, và chạy tay sau khi push.

**Interfaces:**
- Produces: cột `wr_org_survey_responses.industry text null`. RPC `wr_org_survey_benchmark_v2(p_industry text default null)` trả về `(scope text, area text, avg_value numeric, sample_size integer, source text)`, trong đó `scope ∈ {'all','industry'}`.

- [ ] **Bước 1: viết migration**

```sql
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
```

- [ ] **Bước 2:** chạy `supabase db push --include-all --dry-run`. Kỳ vọng: chỉ có `20261001100000_wr_org_survey_v2.sql`.
- [ ] **Bước 3:** nhờ người dùng xác nhận rồi mới push thật. Sau đó chạy các câu kiểm:

```sql
select * from wr_org_survey_benchmark_v2(null);       -- 5 dòng scope='all'
select * from wr_org_survey_benchmark_v2('tech');     -- 10 dòng
select * from wr_org_survey_benchmark(1);             -- source vẫn 'none' nếu < 10 người
```

- [ ] **Bước 4:** commit `feat(khảo sát tổ chức): mặt bằng chung đếm theo người, ngưỡng 10 cứng phía server, thêm cột lĩnh vực`.

### Task A2: Repository, model và provider (Dart)

**Files:**
- Sửa: `lib/core/models/wr_org_survey.dart` (`OrgSurveyBenchmark` :153 thêm `scope`; `OrgSurveyResponse` thêm `industry`)
- Sửa: `lib/core/logic/wr_org_survey_scoring.dart:22` (`kOrgSurveyMinSample = 10`, giờ chỉ dùng để hiển thị)
- Sửa: `lib/core/data/wr_org_survey_repository.dart:18-40,93-125`
- Sửa: `lib/features/wr/org_survey_providers.dart:21-46`
- Sửa: `test/support/fake_wr_org_survey_repository.dart`
- Test: `test/logic/wr_org_survey_scoring_test.dart:145-149` (đổi 30 → 10), `test/features/wr_org_survey_test.dart`

**Interfaces:**
- Produces:
  - `enum BenchmarkScope { all, industry }`
  - `OrgSurveyBenchmark.scope`
  - `Future<OrgSurveyResponse> submit({required Map<String,int> answers, int? enps, String? industry})`
  - `Future<List<OrgSurveyBenchmark>> fetchBenchmark({String? industry})`
  - `wrOrgSurveyBenchmarkProvider` đổi thành `FutureProvider.family<OrgSurveyBenchmarks, String?>`, với `class OrgSurveyBenchmarks { Map<OrgSurveyArea?, OrgSurveyBenchmark> all; Map<OrgSurveyArea?, OrgSurveyBenchmark> industry; }`
  - **Không nuốt lỗi nữa**: lỗi đi thẳng ra `AsyncError`.

- [ ] **Bước 1: viết test hỏng** trong `wr_org_survey_test.dart`:
  - `'fake: một người nộp 10 lần vẫn chỉ tính 1 mẫu'`: fake chứa 10 phiếu cùng `user_id` → `fetchBenchmark()` trả `sampleSize == 1`, `source == none`.
  - `'fake: 10 người khác nhau → live'`.
  - `'industry: chỉ đếm phiếu cùng lĩnh vực'`.
  - `'submit gửi industry'`.
  - `'lỗi đọc mặt bằng chung → provider báo lỗi, không trả map rỗng'`: thêm cờ `failBenchmark` vào fake.

  Fake phải chép đúng luật của SQL ở Task A1: `distinct on user_id` lấy phiếu mới nhất, ngưỡng 10, CHECK `industry` thuộc 8 mã (sai mã thì `throw PostgrestException(code: '23514')`).
- [ ] **Bước 2:** `flutter test test/features/wr_org_survey_test.dart` → các bài mới FAIL.
- [ ] **Bước 3: sửa code:**
  - Repository gọi `rpc('wr_org_survey_benchmark_v2', params: {'p_industry': industry})`.
  - `submit` thêm `if (industry != null) 'industry': industry`.
  - `fetchLatestResponse` đọc thêm cột `industry`.
  - Provider bỏ `try/catch` ở benchmark. **Giữ** `try/catch` ở `wrOrgSurveyLatestProvider`, vì màn Hồ sơ dựa vào nó, nhưng màn kết quả sẽ không dùng nhánh nuốt lỗi đó nữa (Task A4).
- [ ] **Bước 4:** chạy lại test → PASS. Chạy `flutter test test/logic/wr_org_survey_scoring_test.dart` → PASS sau khi đổi 30 → 10.
- [ ] **Bước 5:** commit.

### Task A3: Câu "Lĩnh vực làm việc" ở đầu bài

**Files:**
- Sửa: `lib/features/wr/presentation/wr_org_survey_flow_screen.dart` (`:51-92` state + submit; `:150` chỉ số bước eNPS)
- Sửa: `lib/features/wr/presentation/wr_org_survey_intro_screen.dart` (số câu hiển thị thành `questions.length + 2`)
- Test: `test/features/wr_org_survey_test.dart`

**Interfaces:**
- Consumes: `myInfoIndustryOptions()` (`lib/core/logic/wr_my_info.dart:47`), `wr_mobile_profiles.org_industry`, `saveMyInfo` (`wr_repository.dart:459`), `submit(industry:)` từ Task A2.

**Luật:**
- Bước 0 là `DropdownButtonFormField<String>` 8 mã, tiêu đề `tr('Bạn đang làm việc trong lĩnh vực nào?', 'Which field do you work in?')`.
- Nếu hồ sơ đã có `org_industry` thì chọn sẵn mã đó.
- Phải chọn mới bấm "Tiếp tục" được. Không auto-advance, vì dropdown cần xác nhận.
- Khi nộp: nếu hồ sơ **chưa** có `org_industry` thì ghi mã vừa chọn vào hồ sơ. Đã có thì **không ghi đè**, vì hồ sơ là chỗ người dùng tự khai.

- [ ] **Bước 1: test hỏng:**
  - `'bước đầu là Lĩnh vực, chưa chọn thì nút Tiếp tục tắt'`
  - `'hồ sơ có org_industry=finance → chọn sẵn Tài chính, ngân hàng'`
  - `'nộp xong gửi industry=finance'`
  - `'hồ sơ trống → nộp xong ghi org_industry'`
  - `'hồ sơ đã có → không ghi đè'`
  - Sửa bài `"8 / 10"` hiện có cho đúng tổng bước mới.
- [ ] **Bước 2:** chạy → FAIL.
- [ ] **Bước 3:** cài đặt. Key: `Key('wr_org_survey_industry')`, `Key('wr_org_survey_industry_next')`.
- [ ] **Bước 4:** chạy → PASS.
- [ ] **Bước 5:** commit.

### Task A4: Màn kết quả nói rõ đang ở đâu

**Files:**
- Sửa: `lib/features/wr/presentation/wr_org_survey_result_screen.dart` (`:43-75`, `:90-93`, `:192-230`)
- Test: `test/features/wr_org_survey_test.dart`

**Luật hiển thị:**
- `source == none`: thay ba câu "Chưa đủ dữ liệu…" lặp lại bằng **một** khối:
  - `tr('Mặt bằng chung sẽ hiện khi có đủ 10 người tham gia. Hiện đã có $n người.', 'The overall comparison appears once 10 people have taken part. So far: $n.')`
  - Nhãn từng mảng chỉ còn điểm của người dùng, không lặp câu "chưa đủ".
- Lỗi đọc (AsyncError): `tr('Chưa tải được phần so sánh.', 'Could not load the comparison.')` kèm nút "Thử lại" (`ref.invalidate`). Không còn trông giống "chưa đủ người".
- Có `scope industry` và `live`: thêm dòng so sánh thứ hai `tr('Cùng lĩnh vực', 'Same field')` dưới mỗi thanh.
- Không có `extra` (mở từ Hồ sơ, hoặc tải lại trang web): đọc `wrOrgSurveyLatestProvider`. Đang tải thì hiện vòng chờ. Lỗi thì hiện nút thử lại, **không** hiện `_Empty`.

- [ ] **Bước 1: test hỏng:**
  - `'9 người → một khối "Hiện đã có 9 người", không còn chữ "Chưa đủ dữ liệu để so sánh"'`
  - `'benchmark lỗi → "Chưa tải được phần so sánh" + Thử lại'`
  - `'10 người cùng ngành → hiện dòng Cùng lĩnh vực'`
  - `'không extra + latest lỗi → không hiện _Empty'`
- [ ] **Bước 2:** chạy → FAIL.
- [ ] **Bước 3:** cài đặt.
- [ ] **Bước 4:** chạy → PASS. Chạy `flutter test test/features/wr_english_build_test.dart` → PASS.
- [ ] **Bước 5:** cổng đợt A, rồi PR `feat/khao-sat-to-chuc-v2-20261001`.

---

## ĐỢT B: Ngắt dòng và làm sạch vết AI

**Hiện trạng:**
- "Ngày hôm nay của bạn như thế nào?" là một `Text` thường ở `lib/features/wr/presentation/wr_home_screen.dart:352-361` (17px, w700). Bề rộng còn khoảng 291–306px, nên "nào?" rớt một mình.
- `WrParagraph` có nối U+00A0 nhưng **cấm** dùng cho tiêu đề (bài học "feeling goo" 11/09).
- Hiện chưa có helper nào cho tiêu đề.

### Task B1: Helper chống rớt chữ cho tiêu đề

**Files:**
- Tạo: `lib/core/widgets/wr_title_text.dart`
- Test: `test/core/wr_title_text_test.dart`

**Interfaces:**
- Produces:
  - `String wrKeepTitleTail(String text, {int maxTailChars = 14})`
  - `class WrTitleText extends StatelessWidget { const WrTitleText(this.text, {super.key, this.style, this.textAlign, this.maxLines}); }`

**Luật:** chỉ nối hai tiếng **cuối** bằng U+00A0 khi đủ ba điều kiện:
1. Câu có ≥ 3 tiếng.
2. Độ dài `tiếng_áp_chót + 1 + tiếng_cuối` ≤ `maxTailChars`.
3. Câu chưa có U+00A0.

Nhờ vậy "như thế nào?" (11 ký tự) được nối, còn "feeling good" ở ô hẹp, hay câu có 2 tiếng, thì không. Không đổi `textAlign`, mặc định là `start`.

- [ ] **Bước 1: test hỏng:**

```dart
test('nối đuôi ngắn', () {
  expect(wrKeepTitleTail('Ngày hôm nay của bạn như thế nào?'),
      'Ngày hôm nay của bạn như thế nào?');
});
test('không nối câu 2 tiếng', () {
  expect(wrKeepTitleTail('Tạm ổn'), 'Tạm ổn');
});
test('không nối đuôi dài (bài học feeling goo)', () {
  expect(wrKeepTitleTail('I am feeling wonderful'), 'I am feeling wonderful');
});
test('idempotent', () {
  final once = wrKeepTitleTail('How was your day today?');
  expect(wrKeepTitleTail(once), once);
});
testWidgets('WrTitleText không dùng justify', (t) async {
  await t.pumpWidget(const MaterialApp(home: WrTitleText('A b c')));
  expect(t.widget<Text>(find.byType(Text)).textAlign, isNot(TextAlign.justify));
});
```

- [ ] **Bước 2:** chạy → FAIL.
- [ ] **Bước 3:** cài đặt.
- [ ] **Bước 4:** chạy → PASS.
- [ ] **Bước 5:** commit.

### Task B2: Áp vào các tiêu đề và rà màn hình

**Files:**
- Sửa: `wr_home_screen.dart:352-361`, sau đó là danh sách tiêu đề ≥ 16px đậm do agent quét được. Bắt đầu từ các file:
  - `wr_self_check_screen`
  - `wr_paywall`
  - `wr_payment`
  - `wr_ask`
  - `wr_org_survey_intro`
  - `wr_sca_deep_dive`
  - `profile_screen`
  - các widget `_*Header`
- Test: `test/core/wr_title_text_usage_test.dart` (quét mã nguồn)

- [ ] **Bước 1:** liệt kê ứng viên:

```bash
grep -rn "fontSize: \(1[6-9]\|2[0-9]\)" lib --include=*.dart -B4 | grep -n "Text(" > <scratchpad>/title_candidates.txt
```

Chỉ giữ chữ là **câu** (có ≥ 3 tiếng). Bỏ số, nhãn nút, nhãn ô trong lưới.
- [ ] **Bước 2:** test quét nguồn hỏng. Lớp `_TodayQuestion` (hoặc tên thật của khối câu hỏi Home) phải chứa `WrTitleText` và không chứa `WrParagraph`. Mẫu lấy từ `_classBody(...)` trong `test/features/wr_i18n_journey_and_checkin_test.dart`.
- [ ] **Bước 3:** thay `Text(` bằng `WrTitleText(` ở từng chỗ. Chạy `impact` trước mỗi widget.
- [ ] **Bước 4:** rà mắt. Chạy bộ chụp `test/screenshots/app_store_test.dart` ở khổ **375×812** (thêm một biến thể kích thước) cho cả VI và EN, mở ảnh xem từng màn đã liệt kê. Ghi ảnh trước/sau vào PR.
- [ ] **Bước 5:** chạy đủ bộ `flutter test` (nhiều bài `find.text` khớp chuỗi nguyên văn; U+00A0 sẽ làm hỏng chúng). Bài nào đỏ vì U+00A0 thì sửa bằng `find.text(wrKeepTitleTail('...'))`, **không** tắt helper trong test.
- [ ] **Bước 6:** commit.

### Task B3: Làm sạch vết AI

**Hiện trạng:**
- Bộ lọc `supabase/functions/_shared/strip_markdown.ts` và `lib/core/logic/wr_plain_text.dart` đã bỏ `**`, `#`, gạch đầu dòng, link.
- Còn hở:
  - `ai-personalize` không lọc phía server.
  - Prompt `wr-narrative/prompt.ts` không cấm "—" và tự chứa "—" (:110, :123).
  - `wr-chat/system_prompt.ts:46-60` tự dùng `**đậm**`.
  - Khoảng 23 dòng EN của bài đọc cảm xúc (migration `20260910200000`) còn "—".
  - `wr_paywall_screen.dart:730` còn emoji 📈.

**Files:**
- Sửa: `strip_markdown.ts`, `wr_plain_text.dart`, cùng test của chúng (`reply_shaping_test.ts`, `test/core/logic/wr_plain_text_test.dart`)
- Sửa: `supabase/functions/ai-personalize/index.ts` (gọi `stripMarkdown` trước khi trả về)
- Sửa: `supabase/functions/wr-narrative/prompt.ts`, `supabase/functions/wr-chat/system_prompt.ts`
- Tạo: `supabase/migrations/20261001110000_wr_mood_content_en_no_em_dash.sql`
- Sửa: `lib/features/wr/presentation/wr_paywall_screen.dart:730`

**Luật thêm cho bộ lọc (giống hệt ở cả TS và Dart):**
- `" — "` và `" – "` giữa hai chữ → `", "`.
- "—" ở đầu dòng → bỏ.
- Bỏ emoji (`\p{Extended_Pictographic}` và `️`).
- Bỏ khoảng trắng thừa trước dấu câu.
- **Không** lọc lượt chat của người dùng và `raw_text` (luật đã có).

- [ ] **Bước 1: test hỏng:**
  - Deno: `stripMarkdown('Bạn đã làm tốt — rất tốt 🎉')` → `'Bạn đã làm tốt, rất tốt'`.
  - Dart: cùng ca đó.
  - Thêm một ca "5 – 3" giữ nguyên (gạch giữa hai **số** không phải dấu câu).
- [ ] **Bước 2:** `deno test supabase/functions` và `flutter test test/core/logic/wr_plain_text_test.dart` → FAIL.
- [ ] **Bước 3:** cài đặt bộ lọc ở cả hai nơi. Gắn vào `ai-personalize`. Sửa hai prompt: bỏ `**` trong prompt chat, thêm câu cấm "—" và emoji vào prompt narrative.
- [ ] **Bước 4:** migration dữ liệu. Chỉ UPDATE các cột `_en` của bảng nội dung cảm xúc, dùng đúng tên cột trong `20260910200000`:

```sql
update public.wr_mood_content
set reading_en = regexp_replace(reading_en, '\s+[—–]\s+', ', ', 'g')
where reading_en ~ '[—–]';
```

Cột thực tế phải đọc lại từ migration gốc trước khi viết.
- [ ] **Bước 5:** `rg "—" lib supabase/functions -g '!*test*'` → không còn chữ hiển thị nào chứa dấu này. Chạy bài canh em dash hiện có (`test/core/wr_self_check_questions_test.dart`).
- [ ] **Bước 6:** cổng đợt B. Deploy `ai-personalize`, `wr-chat`, `wr-narrative` sau khi PR được merge. PR `fix/ngat-dong-va-vet-ai-20261001`.

---

## ĐỢT C: Viết lại câu hỏi Reflection (cần khách duyệt chữ)

**Nguồn chữ hiện tại (theo Q3, mặc định):**
- **Luồng 5 bước** (`lib/core/logic/wr_reflect_flow.dart`):
  - `kNoticePrompt` :125, `noticeSubtitle` :167, `kDetailPrompt` :191, `kFamiliarStoryIntro` :215, `kStoryDetailInvite` :238, `kCustomDetailNote` :249, gợi ý :259/:266
  - tiêu đề và gợi ý ở `wr_meaning_screen.dart:242-443`, `kDefaultAha` :284
  - `wr_commit_screen.dart:199`
  - 8 dòng `wr_choice_pool`
- **Luồng cũ còn chạy:** `lib/core/logic/wr_experience_state.dart` (6 + 22 câu hỏi, 6 + 18 gợi ý), `wr_episode.dart:53-77` (6 câu), `wr_energy_screen.dart:31`, `wr_moment_screen.dart:70`.
- **Story:** `reflection_question` của 72 story trong `assets/seed/wr_stories.json`, sinh SQL bằng `tool/gen_wr_seed_sql.py`.

### Task C1: Soạn bảng câu mới để khách duyệt

**Files:**
- Tạo: `docs/cau_hoi_reflection_2026-10.md`

- [ ] **Bước 1:** dựng bảng `Mã | Nơi (file:dòng) | Câu cũ VI | Câu mới VI | Câu mới EN`, đủ mọi câu trong phạm vi.
- [ ] **Bước 2:** viết câu mới theo 6 luật giọng, ghi ở đầu tài liệu:
  1. Gọi "bạn", hỏi về **một khoảnh khắc cụ thể** ("Lúc đó…", "Điều gì khiến bạn…").
  2. ≤ 18 tiếng.
  3. Không thuật ngữ (SCA, ESI, "chiều", "trụ").
  4. Không "—".
  5. Kết bằng "?".
  6. Không hỏi dồn hai ý trong một câu.
- [ ] **Bước 3:** gửi khách (docx hoặc Claude Doc). **Dừng tới khi khách duyệt.**

### Task C2: Áp câu đã duyệt

**Files:**
- Sửa: các file Dart ở phần "Nguồn chữ", `assets/seed/wr_stories.json`
- Tạo: `supabase/migrations/20261015000000_wr_reflection_questions_v2.sql`, sinh bằng `python3 tool/gen_wr_seed_sql.py`. Chỉ `UPDATE reflection_question, reflection_question_en`, không chèn lại.
- Test: các bài ghim chuỗi ở `wr_reflection_flow_test.dart`, `wr_screens_test.dart`, `wr_home_surface_test.dart`, `wr_meeting_2026_07_29_test.dart`, `wr_english_build_test.dart`

- [ ] **Bước 1:** thêm test `test/data/wr_reflection_questions_v2_test.dart`. Đọc `docs/cau_hoi_reflection_2026-10.md` (cột "Câu mới"), đối chiếu với các getter và JSON: mọi câu mới phải có mặt, mọi câu cũ phải vắng mặt. Grep **chuỗi cũ**, không grep tên hằng (bài học 5.3 ngày 10/09).
- [ ] **Bước 2:** chạy → FAIL.
- [ ] **Bước 3:** thay chữ. Sinh SQL. Dry-run.
- [ ] **Bước 4:** chạy đủ bộ test. Sửa các bài ghim chuỗi cũ bằng cách tham chiếu getter, không chép lại chuỗi.
- [ ] **Bước 5:** cổng. Push migration (sau khi người dùng xác nhận). PR `feat/cau-hoi-reflection-v2-20261001`.

---

## ĐỢT D: Trang Phát triển

### Task D1: "Việc bạn tự đặt" (Add Action Hub)

**Quyết định kiến trúc:** dùng **bảng riêng**, không dùng `wr_practice_enrollments`. Bảng đó có FK sang `wr_practice_themes`, người dùng không có quyền insert chủ đề, và nếu dùng chung thì sẽ chiếm quota Free 2, chặn `_maybeAutoEnroll` (`wr_growth_screen.dart:92-140`) và lọt vào `wr-chat/user_context.ts:636`.

**Files:**
- Tạo: `supabase/migrations/20261001120000_wr_user_practice_actions.sql`
- Tạo: `lib/core/models/wr_user_action.dart`, `lib/core/data/wr_user_action_repository.dart`, `lib/features/wr/user_action_providers.dart`
- Tạo: `lib/features/wr/presentation/widgets/wr_user_actions_section.dart`
- Sửa: `lib/features/wr/presentation/wr_growth_screen.dart` (chèn sliver sau danh sách "CHỦ ĐỀ CỦA BẠN" và "Xem thêm", trước `_QuotaCard`, khoảng `:376-388`; cập nhật comment ⚠ ở `:376-384`)
- Sửa: `lib/core/data/wr_repository.dart:730-737` (`exportUserData`), `lib/core/data/user_session_scope.dart:141` (đăng ký provider)
- Tạo: `test/support/fake_wr_user_action_repository.dart`, `test/core/wr_user_action_db_contract_test.dart`, `test/features/wr_user_actions_test.dart`

**Interfaces:**
- Produces:
  - `class WrUserAction { String id; String title; int targetCount; DateTime createdAt; DateTime? completedAt; List<DateTime> doneDays; int get doneCount; bool get doneToday; }`
  - `abstract class WrUserActionRepository { Future<List<WrUserAction>> list(); Future<WrUserAction> add(String title); Future<void> logToday(String actionId); Future<void> complete(String actionId); Future<void> delete(String actionId); }`
  - `final wrUserActionsProvider = FutureProvider<List<WrUserAction>>`

- [ ] **Bước 1: migration**

```sql
create table if not exists public.wr_user_practice_actions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  title        text not null check (char_length(btrim(title)) between 1 and 120),
  target_count smallint not null default 5 check (target_count between 1 and 100),
  created_at   timestamptz not null default now(),
  completed_at timestamptz
);
create table if not exists public.wr_user_practice_action_logs (
  action_id uuid not null references public.wr_user_practice_actions(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  done_on   date not null default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  primary key (action_id, done_on)          -- một lần mỗi ngày, như nút "duy trì"
);
create index on public.wr_user_practice_actions (user_id, created_at desc);
alter table public.wr_user_practice_actions enable row level security;
alter table public.wr_user_practice_action_logs enable row level security;
-- 4 policy owner-only cho mỗi bảng, đúng mẫu 20260722000000:373-429
```

- [ ] **Bước 2:** fake chép CHECK (`title` 1..120 sau `trim`, khoá chính `action_id` + `done_on` trùng thì `throw` mã `23505`). Contract test so tập CHECK trong fake với chuỗi trong file migration.
- [ ] **Bước 3: test hỏng** `wr_user_actions_test.dart`:
  - `'nhập "Hỏi ý kiến 1 đồng nghiệp mỗi ngày" + Thêm → hiện trong VIỆC BẠN TỰ ĐẶT, 0/5'`
  - `'bấm Hôm nay tôi đã làm → 1/5, nút đổi sang Đã ghi hôm nay, bấm lại không tăng'`
  - `'đủ 5 lần → hiện Hoàn thành, có nút đánh dấu xong'`
  - `'ô trống hoặc toàn khoảng trắng → nút Thêm tắt'`
  - `'thêm việc KHÔNG đổi practiceEnrollmentsProvider và không đổi quota'`
  - `'tab vẫn không có CHỦ ĐỀ TIẾP THEO CHO BẠN / wr_growth_add_theme_row / Thực hành khác'`: các bài cũ ở `wr_growth_link_test.dart:528-555`, `wr_practice_theme_test.dart:384-428`, `wr_meeting_2026_07_29_test.dart:1332` phải **giữ xanh, không sửa**.
  - `'chưa theo chủ đề nào vẫn thấy ô Việc bạn tự đặt'`: sliver riêng, không nằm trong cột "CHỦ ĐỀ CỦA BẠN".
- [ ] **Bước 4:** chạy → FAIL.
- [ ] **Bước 5:** cài đặt.
  - Chữ: eyebrow `tr('VIỆC BẠN TỰ ĐẶT', 'YOUR OWN ACTIONS')`, gợi ý ô nhập `tr('Thêm một việc bạn muốn tự thực hành', 'Add something you want to practise')`, nút `tr('Hôm nay tôi đã làm', 'Done today')`.
  - Key: `wr_growth_user_action_input`, `wr_growth_user_action_add`, `wr_growth_user_action_<id>`.
  - Tránh mọi chuỗi đã bị khoá ở bước 3.
- [ ] **Bước 6:** chạy → PASS. Chạy đủ bộ.
- [ ] **Bước 7:** dry-run, push migration (sau khi người dùng xác nhận), commit.

### Task D2: Chứng chỉ, khoá học, kỹ năng đã có

**Quyết định kiến trúc:**
- Dùng bảng riêng `wr_owned_skills`. Tài liệu đính kèm (nếu có) dùng lại bucket `context-docs` theo đường `{uid}/cert-{ms}.{ext}`, **không** chiếm suất 1 tài liệu của Free.
- Mỗi mục được ánh xạ sang `theme_ids` trong 10 chủ đề thư viện:
  - Máy **đề xuất** bằng từ khoá (`kPillarKeywords` và tên/mô tả chủ đề).
  - **Người dùng xác nhận** bằng ô tích, nên không có ánh xạ nào do máy tự quyết.
- AI dùng dữ liệu này ở ba chỗ (bước 6).

**Files:**
- Tạo: `supabase/migrations/20261001130000_wr_owned_skills.sql`
- Tạo: `lib/core/models/wr_owned_skill.dart`, `lib/core/logic/wr_owned_skill_match.dart`, `lib/core/data/wr_owned_skill_repository.dart`, `lib/features/wr/owned_skill_providers.dart`
- Tạo: `lib/features/wr/presentation/widgets/wr_owned_skills_section.dart`, `lib/features/wr/presentation/wr_owned_skill_sheet.dart`
- Sửa: `lib/features/wr/presentation/wr_work_info_screen.dart` (thêm khối dưới dòng "Tài liệu", khoảng `:211-225`)
- Sửa: `lib/features/wr/growth_providers.dart:251-254` (`wrPracticeSuggestionProvider`: bỏ chủ đề đã có)
- Sửa: `lib/core/logic/wr_skill_jd_match.dart:165,227-233` (`matchSkillsToContext` thêm `Set<String> ownedThemeIds = const {}`, bỏ khỏi `gaps`), và nơi gọi nó (`wrSkillJdMatchProvider`)
- Sửa: `supabase/functions/wr-chat/user_context.ts` (khối mới cạnh khối kỹ năng `:422-467`)
- Sửa: `exportUserData`, `user_session_scope.dart`
- Test: `test/core/logic/wr_owned_skill_match_test.dart`, `test/core/wr_owned_skill_db_contract_test.dart`, `test/features/wr_owned_skills_test.dart`, `supabase/functions/wr-chat/user_context_test.ts`

**Interfaces:**
- Produces:
  - `enum OwnedSkillKind { certificate, course, skill }`
  - `class WrOwnedSkill { String id; OwnedSkillKind kind; String title; String? issuer; DateTime? completedOn; String? filePath; List<String> themeIds; }`
  - `List<String> suggestThemesForOwnedSkill(String title, List<PracticeTheme> themes)`, trả tối đa 3 `themeId`
  - `final wrOwnedThemeIdsProvider = Provider<Set<String>>`

- [ ] **Bước 1: migration**

```sql
create table if not exists public.wr_owned_skills (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  kind         text not null check (kind in ('certificate','course','skill')),
  title        text not null check (char_length(btrim(title)) between 1 and 160),
  issuer       text check (issuer is null or char_length(issuer) <= 160),
  completed_on date,
  file_path    text,
  theme_ids    text[] not null default '{}',
  created_at   timestamptz not null default now()
);
alter table public.wr_owned_skills enable row level security;
-- 4 policy owner-only
```

- [ ] **Bước 2: test hỏng cho logic thuần:**

```dart
test('"Chứng chỉ Quản lý dự án PMP" gợi ý chủ đề có từ khoá kế hoạch/ưu tiên', () {
  final ids = suggestThemesForOwnedSkill('Chứng chỉ Quản lý dự án PMP', kTestThemes);
  expect(ids, isNotEmpty);
  expect(ids.length, lessThanOrEqualTo(3));
});
test('tên không khớp gì → rỗng (không đoán bừa)', () {
  expect(suggestThemesForOwnedSkill('Bằng lái xe B2', kTestThemes), isEmpty);
});
test('matchSkillsToContext bỏ chủ đề đã có khỏi gaps', () {
  final m = matchSkillsToContext(contextText: 'quản lý đội nhóm', formations: const [],
      allThemes: kTestThemes, ownedThemeIds: {'pt-c1'});
  expect(m!.gaps.map((t) => t.themeId), isNot(contains('pt-c1')));
});
```

`kTestThemes` lấy từ fixture 10 chủ đề đang dùng trong `test/support/`.
- [ ] **Bước 3: test hỏng cho provider và UI:**
  - `'đã khai chủ đề pt-s1 → wrPracticeSuggestionProvider không bao giờ đề xuất pt-s1, auto-enroll bỏ qua pt-s1'`
  - `'màn Thông tin công việc: thêm Chứng chỉ → sheet hiện gợi ý chủ đề có ô tích, bỏ tích thì lưu theme_ids rỗng'`
  - `'Free thêm chứng chỉ không chiếm suất tài liệu (canUploadContextDocument không đổi)'`
- [ ] **Bước 4:** chạy → FAIL.
- [ ] **Bước 5:** cài đặt. Chạy `impact` trước khi sửa `wrPracticeSuggestionProvider` và `matchSkillsToContext`; dự kiến HIGH vì chúng nuôi auto-enroll, màn Kỹ năng và Cơ hội phát triển, nên phải báo người dùng.
  - Lọc chủ đề **trước** `suggestPracticeTheme`, vì hàm đó lùi về `candidates.first` (`wr_practice_match.dart:208`).
  - Lưu ý: dòng `wr_growth_opportunities` đã lưu sẵn sẽ được dùng trước, không qua logic mới (`wr_providers.dart:655`). Ghi chú điều này trong PR, không xử lý ở task này.
- [ ] **Bước 6: AI ghi nhận.** Trong `user_context.ts`, thêm khối:

```ts
// Người dùng tự khai đã có — KHÔNG đề xuất lại các kỹ năng/chủ đề này.
lines.push('Người dùng đã có sẵn (chứng chỉ/khoá học/kỹ năng tự khai), đừng gợi ý lại:');
for (const s of owned) lines.push(`- ${s.title}${s.issuer ? ` (${s.issuer})` : ''}`);
```

Deno test: có 2 mục → prompt chứa cả hai tên. 0 mục → không có khối.
- [ ] **Bước 7:** chạy toàn bộ test (Flutter và Deno) → PASS.
- [ ] **Bước 8:** cổng đợt D. Dry-run, push hai migration D1 + D2 (sau khi người dùng xác nhận), deploy `wr-chat`. PR `feat/phat-trien-tu-dat-va-chung-chi-20261001`.

**Ngoài phạm vi (ghi lại, không làm):** AI đọc nội dung file chứng chỉ để tự điền tên/đơn vị cấp. Có thể làm sau bằng cách mở rộng `wr-doc-analyze` với `doc_type = 'certificate'`. Việc này phải sửa CHECK `doc_type` và `buildExtractionPrompt`.

---

## ĐỢT E: Màn chào và video một lần

**Hiện trạng:**
- 3 slide nằm ở `lib/features/onboarding/presentation/onboarding_screen.dart` (`_Step1/2/3`), chữ lấy từ ARB `onb1*–onb3*`.
- Cờ `'seen_onboarding'` (SharedPreferences, `app_router.dart:165-178`). Logic `computeRedirect` giữ nguyên.
- Slide 2 ghi `onboarding_situation`, nhưng **không có nơi nào đọc** (đã grep `lib` và `supabase/functions` ngày 01/10), nên bỏ đi an toàn. `ensureSeeded` nhận `null` được.
- **Chưa có** gói video, chưa có tài sản mascot nào.

### Task E1: Một màn chào thay 3 slide

**Files:**
- Sửa: `lib/features/onboarding/presentation/onboarding_screen.dart` (viết lại thành một màn)
- Sửa: `lib/features/onboarding/onboarding_state.dart` (bỏ step; giữ `selectedSituation` = null để `seedServiceProvider` không đổi chữ ký)
- Sửa: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb` (xoá `onb1*–onb3*`, chạy `flutter gen-l10n`)
- Test: `test/features/onboarding_test.dart` (viết lại). `test/core/onboarding_once_only_test.dart`, `onboarding_cta_regression_test.dart`, `router_test.dart` phải **giữ xanh, không sửa**.

**Luật:**
- Màn chỉ gồm: `WrLogo`, tiêu đề `tr('Chào mừng bạn đến với WorkReflection', 'Welcome to WorkReflection')`, thẻ video (ảnh bìa + nút phát), nút "Bắt đầu".
- Nút "Bắt đầu" giữ đúng mẫu cũ: `setSeenOnboarding()`, rồi `ref.invalidate(seenOnboardingProvider)`, rồi `await .future`.

- [ ] **Bước 1: test hỏng:**
  - `'chỉ một màn: có tiêu đề chào mừng, không có Reflect/Understand/Grow, không có chấm tiến độ'`
  - `'Bắt đầu → seen_onboarding = true'`
  - `'tiêu đề không rớt chữ'`: dùng `WrTitleText` từ Task B1. Nếu đợt B chưa merge thì làm E sau B.
- [ ] **Bước 2:** chạy → FAIL.
- [ ] **Bước 3:** cài đặt. Xoá `_Step1/2/3`, `_StepDot`, `_SituationCard`, `_PromiseCard` (chạy `impact` trước).
- [ ] **Bước 4:** chạy đủ bộ → PASS.
- [ ] **Bước 5:** commit.

### Task E2: Video hướng dẫn bật tự động một lần

**Files:**
- Sửa: `pubspec.yaml` (thêm `video_player: ^2.9.0`)
- Tạo: `lib/features/onboarding/presentation/wr_intro_video_sheet.dart`
- Tạo: `lib/features/onboarding/intro_video_providers.dart`
- Tạo: `supabase/migrations/20261001140000_wr_media_bucket.sql` (bucket public `wr-media`)
- Sửa: màn Hướng dẫn (HDSD in-app, route tìm bằng `node .gitnexus/run.cjs query "huong dan su dung screen"`) để thêm dòng "Xem lại video hướng dẫn"
- Test: `test/features/wr_intro_video_test.dart`

**Interfaces:**
- Produces:
  - `const kIntroVideoUrl = String.fromEnvironment('WR_INTRO_VIDEO_URL', defaultValue: 'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/wr-media/intro/intro_vi.mp4')`
  - `final introVideoShownProvider = StateNotifierProvider<IntroVideoShownNotifier, bool?>`: key `'wr_intro_video_shown'`, theo thiết bị, viết theo mẫu `ProfileNudgeDismissedNotifier` (`lib/features/profile/profile_providers.dart:220-252`)
  - `Future<void> showIntroVideo(BuildContext context, {bool autoplay = true})`
  - `typedef IntroVideoControllerFactory = VideoPlayerController Function(Uri)`, dùng để test thay thế được

**Luật:**
- Màn chào mở lần đầu (`introVideoShownProvider == false`): sau frame đầu thì bật sheet video toàn màn, rồi đánh dấu `true` **ngay lúc mở**. Nhờ vậy dù người dùng tắt app giữa chừng cũng không bật lại.
- Trên web: `setVolume(0)` trước `play()`, vì trình duyệt chặn autoplay có tiếng. Hiện nút "Bật tiếng".
- Lỗi tải hoặc quá 8 giây chưa sẵn sàng: hiện `tr('Chưa tải được video. Bạn có thể xem lại trong phần Hướng dẫn.', 'The video could not load. You can watch it later in the Guide.')` kèm nút đóng.
- Nút "Bắt đầu" ở màn chào luôn bấm được, kể cả khi video đang mở hoặc lỗi.

- [ ] **Bước 1: test hỏng** (dùng factory giả, không mạng):
  - `'lần đầu mở màn chào → sheet video tự bật, cờ = true'`
  - `'cờ = true → không tự bật'`
  - `'controller lỗi → hiện câu chưa tải được + nút đóng; đóng xong vẫn bấm Bắt đầu được'`
  - `'màn Hướng dẫn có dòng Xem lại video hướng dẫn'`
- [ ] **Bước 2:** chạy → FAIL.
- [ ] **Bước 3:** cài đặt. Chạy `flutter pub get`. iOS: `cd ios && pod install` để chắc build Codemagic không vỡ (sàn iOS 15, `video_player` dùng AVPlayer, không cần thêm quyền).
- [ ] **Bước 4:** migration bucket:

```sql
insert into storage.buckets (id, name, public) values ('wr-media','wr-media', true)
on conflict (id) do nothing;
-- Không policy insert cho authenticated: chỉ người vận hành tải lên bằng service role/dashboard.
```

- [ ] **Bước 5:** chạy đủ bộ → PASS. `flutter build apk --debug` OK. `flutter build web --release` OK.
- [ ] **Bước 6:** khi khách gửi video (Q1): tải lên `wr-media/intro/intro_vi.mp4` (và `intro_en.mp4` nếu có) qua dashboard, rồi mở thử bằng `flutter run` trên máy thật.
- [ ] **Bước 7:** cổng đợt E. PR `feat/man-chao-video-20261001`.

---

## ĐỢT F: Web App (repo `/home/duythong/Documents/DuyThong/workreflection`)

**Trước khi làm:** chạy `git fetch`. Bản local đang cũ: `origin/main` local là `55f8d89`, remote đã ở `f6cd3ab` sau khi PR #52 và #53 được merge sáng 01/10. Tạo nhánh từ `origin/main`.

**Đã xong hôm nay (không làm lại):**
- File QR `public/qr-app-store.svg` trỏ `https://apps.apple.com/app/id6805322970`.
- Đã bỏ nút Google Play.
- Khung điện thoại HTML `src/components/landing/PhoneDemo.tsx`.

### Task F1: Logo Apple chính thức + ô chờ Google Play

**Files:**
- Sửa: `src/pages/Index.tsx` (khối `#download` `:394-441`, ký tự Apple vẽ tay ở `:421-423`)
- Tạo: `public/badges/app-store-vi.svg`, `public/badges/app-store-en.svg`. Huy hiệu "Tải về trên App Store / Download on the App Store" tải từ trang Apple Marketing Resources; người dùng tải giúp, không tự vẽ.
- Sửa: `src/i18n/translations/vi.ts`, `en.ts` (khoảng `:4126-4138`, dùng lại `googlePlaySmall/Strong`)
- Test: `src/pages/__tests__/IndexDownload.test.tsx` (nếu repo có Vitest; nếu không thì kiểm bằng `npm run build` và mở thử)

**Luật:**
- Đặt hằng `GOOGLE_PLAY_URL: string | null = null`.
- Khi `null`: ô bên cạnh QR App Store hiện viền đứt + `t('landingV2.download.googlePlaySoon')` ("Sắp có trên Google Play"), không có link.
- Khi có URL: hiện `<QRCodeSVG value={GOOGLE_PLAY_URL} />` cùng cỡ với QR App Store.

- [ ] **Bước 1:** kiểm tra repo có test runner không (`grep vitest package.json`). Có thì viết test hỏng: `'GOOGLE_PLAY_URL null → có chữ Sắp có trên Google Play, không có thẻ a'`.
- [ ] **Bước 2:** cài đặt, chạy `npm run build`, `npm run lint`.
- [ ] **Bước 3:** PR `fix/logo-apple-o-google-play-20261001`. Dừng, để sếp merge.

### Task F2: Ảnh chụp thật thay mockup (sau Q8)

**Files:**
- Tạo: `public/screens/{vi,en}/0{1..5}.webp` (rộng 600px)
- Sửa: `src/components/landing/PhoneDemo.tsx` (thay ruột HTML từng tab bằng `<img loading="lazy">`, giữ khung và 4 tab)

- [ ] **Bước 1:** ở repo mobile, chụp lại bộ mới cho cả VI và EN:

```bash
WR_SCREENSHOTS=1 flutter test test/screenshots/app_store_test.dart --update-goldens
```

Bản EN cần thêm biến thể locale vào bài test chụp nếu chưa có. Nguồn là `screenshots/app_store/iphone_6_9/01_home…05_tro_ly_ai` (1290×2796).
- [ ] **Bước 2:** nén sang WebP:

```bash
for f in screenshots/app_store/iphone_6_9/*.png; do cwebp -q 80 -resize 600 0 "$f" -o "<web>/public/screens/vi/$(basename "${f%.png}").webp"; done
```

- [ ] **Bước 3:** sửa `PhoneDemo.tsx`, chạy `npm run build`. Mở thử ở khổ 390px và 1440px. Không có thanh cuộn ngang.
- [ ] **Bước 4:** PR. Dừng.

### Task F3: Lượt tải App Store + người dùng mới trong trang quản trị (sau Q9)

**Hiện trạng:**
- `src/pages/admin/Analytics.tsx` có ô "User Growth" đang là placeholder (`:135-141`), dùng được ngay.
- Web không có server runtime (Vercel chỉ phục vụ SPA). Khoá `VITE_*` lọt ra trình duyệt.
- Vì vậy việc gọi App Store Connect **phải** chạy trong Edge Function Supabase.
- Đã có khoá Admin `DLFUYXK3QT` (issuer `31833d86-…`, ghi trong `docs/app_store_release_log_2026-08-26.md:21-28` ở repo mobile).

**Files (repo web):**
- Tạo: `supabase/migrations/20261001150000_asc_daily_units.sql`
- Tạo: `supabase/functions/asc-sales-sync/index.ts`, `supabase/functions/asc-sales-sync/parse.ts`, `supabase/functions/asc-sales-sync/parse_test.ts`
- Sửa: `src/pages/admin/Analytics.tsx`

**Interfaces:**
- Produces:
  - Bảng `asc_daily_units(report_date date, country text, product_type text, units int, primary key(report_date, country, product_type))`. RLS chỉ admin được select: dùng đúng hàm hoặc điều kiện kiểm admin mà các bảng `cc_*` đang dùng; đọc policy của `cc_orders` để chép lại.
  - Edge Function `asc-sales-sync`: cron hằng ngày, kéo báo cáo `SALES/SUMMARY/DAILY` của ngày hôm qua (và bù 30 ngày ở lần chạy đầu), rồi upsert.

- [ ] **Bước 1: test hỏng cho `parse.ts`** với một file TSV mẫu (bỏ thông tin thật):
  - Tổng `Units` theo ngày.
  - Chỉ tính lượt tải lần đầu: `Product Type Identifier ∈ {'1','1F','1T'}`. Bỏ `7*` (cập nhật), `3*` (tải lại), `IA*` (mua trong app).
- [ ] **Bước 2:** `deno test supabase/functions/asc-sales-sync` → FAIL.
- [ ] **Bước 3:** cài đặt.
  - Ký JWT ES256 bằng `jose` (`iss` = issuer, `kid` = key id, `aud` = `appstoreconnect-v1`, hết hạn sau 20 phút).
  - Gọi `GET https://api.appstoreconnect.apple.com/v1/salesReports?filter[frequency]=DAILY&filter[reportType]=SALES&filter[reportSubType]=SUMMARY&filter[vendorNumber]=$ASC_VENDOR&filter[reportDate]=YYYY-MM-DD`, giải nén gzip, parse.
  - Secret: `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_P8`, `ASC_VENDOR`, đặt bằng `supabase secrets set`, **không** đặt vào `.env` của web.
- [ ] **Bước 4:** chạy cron bằng `pg_cron` + `net.http_post` lúc 10:00 giờ VN (báo cáo của Apple trễ khoảng 1 ngày).
- [ ] **Bước 5:** `Analytics.tsx`:
  - Ô "User Growth" thành `LineChart` của recharts, hai đường: "Lượt tải App Store" (`asc_daily_units`) và "Tài khoản mới" (`cc_profiles.created_at` theo ngày).
  - Có công tắc 30/90 ngày.
  - Bảng rỗng thì hiện "Chưa có dữ liệu từ App Store Connect".
  - Thêm `/admin/analytics` vào sidebar (`Sidebar.tsx:57-107`), vì hiện chưa có lối vào.
- [ ] **Bước 6:** `npm run build`. Deploy function. Chạy tay một lần, đối chiếu tổng 7 ngày với App Store Connect → Analytics.
- [ ] **Bước 7:** PR. Dừng.

**Phát hiện phụ (ngoài phạm vi, cần báo sếp):** `.env` của web có `VITE_GEMINI_API_KEY`. Mọi biến `VITE_*` bị nhúng vào bundle trình duyệt, nên khoá này đang công khai. Nên xoay khoá và chuyển lời gọi Gemini vào Edge Function.

---

## Tự rà kế hoạch

- **Đủ yêu cầu khách:**

| Mục khách | Task |
|---|---|
| 1 video | E2 |
| 1 màn chào | E1 |
| 1 bỏ 3 slide | E1 |
| 3 câu hỏi | C1, C2 |
| 3 rớt chữ | B1, B2 |
| 3 vết AI | B3 |
| 4 chứng chỉ | D2 |
| 4 lọc trùng | D2 bước 5–6 |
| 4 tự lên kế hoạch | D1 |
| 5 dropdown | A1, A3 |
| 5 lỗi "chưa có kết quả" | A1, A2, A4 |
| 5 mốc 10 lượt | A1 |
| 6 QR | F1 (đã có QR, còn logo + ô Play) |
| 6 ảnh thật | F2 |
| 6 analytics | F3 |

  Hạng mục 2 bỏ theo yêu cầu.
- **Tên hàm và kiểu dùng nhất quán:**
  - `fetchBenchmark({String? industry})` khớp giữa A2 và A4.
  - `wrKeepTitleTail` / `WrTitleText` dùng ở B1, B2, E1.
  - `ownedThemeIds` có ở D2 bước 2 và bước 5.
- **Phụ thuộc giữa các đợt:** E1 dùng `WrTitleText` nên làm sau B. Các đợt còn lại độc lập.

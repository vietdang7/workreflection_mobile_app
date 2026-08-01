# WR Data Foundation (Pivot Sprint 0) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Use superpowers:test-driven-development for all Dart code.

**Goal:** Build the data foundation for the mobile pivot (daily-companion): extract the client's Career Situation Library (100 stories) + DataSpec v3 mapping table into structured seeds, create `wr_situations` / `wr_stories` / `wr_career_memory_events` tables, and Dart models + repository with tests.

**Architecture:** One-time Python extraction from the two client docx files → committed JSON seeds in `assets/seed/` → a generated SQL migration seeding content tables (read-only content, RLS authenticated-read) + user event table (owner-only RLS) → plain immutable Dart models mirroring existing `lib/core/models/` style → repository in `lib/core/data/` following existing patterns.

**Tech Stack:** Flutter 3.41 (Riverpod, supabase_flutter), Supabase (project `sukpcxevcjnhiuyaoqxi`, shared with web), python-docx for extraction.

---

## Nguồn dữ liệu (đọc trước khi làm)

- `/home/duythong/Desktop/FileTam/workreflection/Career Situation Library.docx` — 100 stories (S1..S3, C1..C3, A1..A4 × 10). Mỗi story: id (`C2-03`), title, situation, story_content, reflection_question, self_reflection, aha_message, practice_action, emotion/behavior/career-stage tags nếu có.
- `/home/duythong/Desktop/FileTam/workreflection/WorkReflection_DataSpec_v3.docx` — bảng ánh xạ: Tình huống → Mong đợi kết quả → Nhu cầu cốt lõi → Góc nhìn SCA, nhóm theo chiều SCA; enum hợp lệ; 3 đợt triển khai (wave).
- Bản trích text sẵn (nhanh hơn): `/tmp/Career_Situation_Library.txt`, `/tmp/WorkReflection_DataSpec_v3.txt` (nếu không còn, tự trích lại bằng python-docx, gồm cả tables).

## Quyết định thiết kế đã chốt (Fable — KHÔNG tự thay đổi)

1. **4 nhu cầu cốt lõi** (không phải 3): `ro_rang` (Rõ ràng), `ket_noi` (Kết nối), `thich_nghi` (Thích nghi), `phat_trien` (Phát triển). Dòng "chỉ 3 nhu cầu Clarity/Connection/Adaptability" trong DataSpec là artifact cũ — bỏ qua, đã ghi vào danh sách feedback gửi khách.
2. **Chiều SCA**: enum 10 giá trị `S1 S2 S3 C1 C2 C3 A1 A2 A3 A4` + wave triển khai: wave1 = C2,A1,A3,C1; wave2 = A4,A2,S1; wave3 = C3,S2,S3.
3. Tình huống nào có trong Library nhưng **không có dòng ánh xạ** trong DataSpec: vẫn seed vào `wr_situations` với `expected_outcome`/`sca_perspective` NULL, suy `human_need` từ story cùng mã nếu rõ, nếu không thì NULL — và LIỆT KÊ chúng trong báo cáo cuối (feedback cho khách).
4. Không đụng các bảng `wr_*` hiện có (`wr_checkins`, `wr_insights`, …). Không xóa feature nào của app trong sprint này.
5. Migration mới: `supabase/migrations/20260721000000_create_wr_reflection_content.sql`. **Chỉ chạy `supabase db push --include-all --dry-run`** — KHÔNG push thật; Fable duyệt rồi mới push.
6. MCP supabase trỏ sai project — tuyệt đối không dùng MCP supabase để apply. Chỉ dùng file migration + CLI dry-run.

---

### Task 1: Extraction script → JSON seeds

**Files:**
- Create: `tool/extract_wr_content.py`
- Create (output, commit): `assets/seed/wr_situations.json`, `assets/seed/wr_stories.json`

**Steps:**
1. Viết script python-docx đọc 2 file docx (đường dẫn hardcode ở trên, có `--src` override), parse:
   - stories: nhận diện block bắt đầu bằng `^[SCA]\d-\d\d` (mỗi id xuất hiện 2 lần trong text — kiểm tra và khử trùng lặp), tách các trường theo heading trong block (Situation / Story / Reflection question / Self-reflection / Aha / Practice…; heading có thể là tiếng Việt — inspect thực tế trước khi viết regex).
   - situations: từ các bảng DataSpec (`Tình huống | Mong đợi kết quả | Nhu cầu cốt lõi | Góc nhìn SCA`) + danh sách situation theo chiều trong Library phần đầu.
2. Output schema:
   - `wr_situations.json`: `[{code, text, sca_dimension, human_need, expected_outcome, sca_perspective, wave}]` (code dạng `S1-sit-01` tự đánh số theo chiều).
   - `wr_stories.json`: `[{story_id, title, sca_dimension, human_need, situation, emotion_tags, behavior_tags, career_stages, difficulty_level, story_content, reflection_question, self_reflection, aha_message, practice_action}]` — trường thiếu để `null`/`[]`.
3. Script tự validate và in báo cáo: đúng 100 story id duy nhất, đủ 10 chiều × 10, đếm situation có/không có mapping, liệt kê field null. Exit non-zero nếu <100 stories.
4. Chạy script, xem báo cáo, commit script + JSON.

### Task 2: Migration SQL

**Files:**
- Create: `supabase/migrations/20260721000000_create_wr_reflection_content.sql`
- Create: `tool/gen_wr_seed_sql.py` (đọc 2 JSON → sinh phần INSERT, escape chuẩn SQL `$$`-quoting hoặc quote thủ công)

**Nội dung migration (theo style file `20260717000000_create_wr_mobile_tables.sql`):**
```sql
create table if not exists public.wr_situations (
  code text primary key,
  text text not null,
  sca_dimension text not null check (sca_dimension in ('S1','S2','S3','C1','C2','C3','A1','A2','A3','A4')),
  human_need text check (human_need in ('ro_rang','ket_noi','thich_nghi','phat_trien')),
  expected_outcome text,
  sca_perspective text,
  wave smallint not null default 3 check (wave between 1 and 3),
  created_at timestamptz not null default now()
);
create table if not exists public.wr_stories (
  story_id text primary key,          -- 'C2-03'
  title text not null,
  sca_dimension text not null check (sca_dimension in ('S1','S2','S3','C1','C2','C3','A1','A2','A3','A4')),
  human_need text check (human_need in ('ro_rang','ket_noi','thich_nghi','phat_trien')),
  situation text,
  emotion_tags text[] not null default '{}',
  behavior_tags text[] not null default '{}',
  career_stages text[] not null default '{}',
  difficulty_level smallint check (difficulty_level between 1 and 3),
  story_content text not null,
  reflection_question text,
  self_reflection text,
  aha_message text,
  practice_action text,
  created_at timestamptz not null default now()
);
create table if not exists public.wr_career_memory_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  story_id text references public.wr_stories(story_id),
  situation_code text references public.wr_situations(code),
  human_need text check (human_need in ('ro_rang','ket_noi','thich_nghi','phat_trien')),
  sca_dimension text check (sca_dimension in ('S1','S2','S3','C1','C2','C3','A1','A2','A3','A4')),
  emotion text,
  behavior text,
  intensity smallint check (intensity between 1 and 5),
  reflection_text text,
  career_stage text,
  created_at timestamptz not null default now()
);
```
- RLS: content tables → enable RLS, policy `select` cho `authenticated` (read-only, không insert/update policy); events → owner-only 4 policies giống pattern `wr_checkins`.
- Index: `wr_career_memory_events (user_id, created_at desc)`, `wr_stories (sca_dimension)`, `wr_situations (sca_dimension)`.
- Cuối file: các INSERT sinh từ `gen_wr_seed_sql.py` (idempotent: `on conflict do nothing`).
- Verify: `supabase db push --include-all --dry-run` chỉ liệt kê migration mới. Bắt buộc chạy và dán output vào báo cáo.

### Task 3: Dart models (TDD)

**Files:**
- Create: `lib/core/models/wr_content.dart` (WrSituation, WrStory, CareerMemoryEvent + enums `HumanNeed`, `ScaDimension`)
- Test: `test/core/models/wr_content_test.dart`

Style: plain immutable class + `fromJson`/`toInsert` giống `lib/core/models/checkin.dart` & `ai_personalization_models.dart`. Enum có `dbValue` + `fromDb`. Test: round-trip fromJson với sample JSON thật lấy từ seed (ít nhất 1 story đầy đủ + 1 story field null), enum parse sai → throw/`unknown` theo pattern hiện có trong repo (xem cách `Mood` xử lý). Viết test trước → fail → implement → pass → commit.

### Task 4: Repository (TDD)

**Files:**
- Create: `lib/core/data/wr_content_repository.dart`
- Test: `test/core/data/wr_content_repository_test.dart`

API: `fetchSituations({ScaDimension? dimension})`, `fetchStories({ScaDimension? dimension, int? wave})`, `fetchStory(String id)`, `insertMemoryEvent(CareerMemoryEvent e)`, `fetchMemoryEvents({int limit})`. Bắt chước pattern repository + test hiện có trong `lib/core/data/` (xem cách các repo khác mock SupabaseClient/PostgrestFilterBuilder — dùng đúng cùng kỹ thuật, đừng chế mới). Provider Riverpod đặt cạnh repository giống các feature khác.

### Task 5: Gates + báo cáo

1. `flutter analyze` → 0 issues.
2. `flutter test` → toàn bộ green (hiện ~779 test, không được làm hỏng test cũ).
3. `gitnexus_detect_changes` (hoặc `npx gitnexus analyze` + kiểm tra scope) trước commit cuối.
4. Commit từng task riêng, message `feat(wr-data): …`.
5. Báo cáo cuối gửi Fable: số situation/story seed được, danh sách situation thiếu mapping (feedback khách), field null đáng chú ý, output dry-run, kết quả analyze/test.

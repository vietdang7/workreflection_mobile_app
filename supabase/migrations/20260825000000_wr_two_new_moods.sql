-- WorkReflection: hai cảm xúc check-in mới — "Tôi thấy mơ hồ" và "Tôi thấy mọi
-- thứ lệch nhau".
--
-- Nguồn: WorkReflection_Changelog_20260824.docx §3, mockup
-- WorkReflection_Sprint2_Mockup_v16.html (`MOODS`, `MOOD_LABELS`).
--
--   foggy     dims S1  — rõ ràng vai trò & trách nhiệm
--   outofsync dims S2  — luồng thông tin & phối hợp
--
-- Hai cảm xúc này chèn GIỮA `tired` và `okay` ở lưới Home: nhóm khó khăn đứng
-- trước, nhóm tích cực đứng sau. Thứ tự nằm ở `kCheckinOptions` phía app; ở đây
-- chỉ cần bảng chấp nhận thêm hai chuỗi.
--
-- ⚠ VÌ SAO MIGRATION NÀY LÀ BẮT BUỘC, KHÔNG PHẢI DỌN DẸP CHO ĐẸP
--
-- `wr_checkins.mood` và `wr_mood_content.mood` đều có CHECK constraint liệt kê
-- cứng bốn chuỗi cũ. Thêm giá trị vào enum `Mood` phía Dart mà không chạy
-- migration này thì:
--
--   · mọi lần chạm hai ô mới ở Home → INSERT wr_checkins trả 400,
--   · toàn bộ 10 bài đọc của hai nhóm mới không seed được.
--
-- Và cả hai lỗi đó KHÔNG lộ ra trong test: fake repository trong `test/` không
-- có check constraint nào, nên bộ test vẫn xanh. Đây đúng bài học đã ghi lại ở
-- Hai Lớp v1.6 (28/07) — hai lỗi 400 chỉ lộ khi chạy thật.

-- ---------------------------------------------------------------------------
-- 1 · wr_checkins.mood
-- ---------------------------------------------------------------------------

alter table public.wr_checkins
  drop constraint if exists wr_checkins_mood_check;

alter table public.wr_checkins
  add constraint wr_checkins_mood_check
  check (mood in ('stressed', 'tired', 'foggy', 'outofsync', 'okay', 'happy'));

comment on column public.wr_checkins.mood is
  'Sáu cảm xúc của lưới check-in Home (changelog mockup 24/08/2026 §3). '
  'Khớp enum Mood ở lib/core/models/checkin.dart — sửa một bên phải sửa bên kia.';

-- ---------------------------------------------------------------------------
-- 2 · wr_mood_content.mood
--
-- Bảng này dùng khoá NGẮN ('stress', 'ok') còn wr_checkins dùng khoá dài
-- ('stressed', 'okay') — lệch có từ trước, ánh xạ nằm ở `MoodContentKey` phía
-- app. Hai khoá mới cố ý GIỐNG NHAU ở cả hai bảng để không nới thêm chỗ lệch.
-- ---------------------------------------------------------------------------

alter table public.wr_mood_content
  drop constraint if exists wr_mood_content_mood_check;

alter table public.wr_mood_content
  add constraint wr_mood_content_mood_check
  check (mood in ('stress', 'tired', 'foggy', 'outofsync', 'ok', 'happy'));

comment on column public.wr_mood_content.mood is
  'Sáu nhóm cảm xúc. Khoá ngắn (stress/ok) là di sản, hai khoá mới '
  '(foggy/outofsync) dùng chung chuỗi với wr_checkins.';

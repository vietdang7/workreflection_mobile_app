-- Script Sprint 2 (13/10/2026) — chữ của bộ 4 bước thực hành.
--
-- Chỉ đổi CHỮ trên hàng có sẵn, không đổi cấu trúc bảng, giữ nguyên `step_id`
-- để `completed_steps` của người đang thực hành vẫn trỏ đúng. Chạy lại bao
-- nhiêu lần cũng vậy: mỗi câu lệnh chỉ chạm hàng còn mang chữ cũ.
--
-- 1. Bước 4: nhãn "Mang về" đổi thành "Câu hỏi cho lần sau", việc là "Điều
--    bạn muốn hỏi lần tới" (script `buildPracticeSteps`). Mô tả giữ nguyên, vì
--    đã đúng script. Áp cho cả chủ đề thư viện lẫn chủ đề người dùng tự thêm.
--    Tên cũ vẫn tra được sang tiếng Anh trên Hành trình nhờ
--    `kLegacyPracticeStepTitles` (Career Memory đã đóng băng tên cũ).
-- 2. Bước 3: mô tả mở đầu bằng "Mở phần gợi ý, chọn một cách, rồi thử…" vì ba
--    cách không còn xổ ngay trên màn chủ đề mà nằm ở màn riêng.
--
-- Không thêm cột cho phần "Đang duy trì": `wr_practice_enrollments.completed_at`
-- là mốc người dùng bấm "Đưa vào phần duy trì", còn mỗi lần "Ghi nhận" là một
-- mảnh `practice_maintained` trong `wr_career_memory_events` (đã có).

-- ── 1. Bước 4 ────────────────────────────────────────────────────────────────
update public.wr_practice_steps set
  title = 'Câu hỏi cho lần sau: Điều bạn muốn hỏi lần tới',
  title_en = 'A question for next time: What you want to ask next time'
where step_order = 4
  and title = 'Mang về: Giữ lại một câu hỏi';

-- ── 2. Bước 3, chủ đề thư viện ───────────────────────────────────────────────
update public.wr_practice_steps set
  content = 'Mở phần gợi ý, chọn một cách, rồi thử trong một cuộc họp thật.',
  content_en = 'Open the suggestions, pick one way, then try it in a real meeting.'
where step_order = 3
  and content = 'Chọn một trong các cách ở trên và thử trong một cuộc họp thật.';

update public.wr_practice_steps set
  content = 'Mở phần gợi ý, chọn một cách, rồi thử trong một tình huống thật.',
  content_en = 'Open the suggestions, pick one way, then try it in a real situation.'
where step_order = 3
  and content = 'Chọn một trong các cách ở trên và thử trong một tình huống thật.';

-- ── 3. Bước 3, chủ đề người dùng tự thêm ─────────────────────────────────────
-- Bản cũ: "Chọn một trong các cách ở trên và thử trong một tình huống thật,
-- liên quan tới ‹điều muốn khác đi›.[ Lần này đừng lặp lại điều bạn đã thử:
-- "…".]" Bỏ câu "đừng lặp lại": ba cách gợi ý của chủ đề đã tránh điều đó.
update public.wr_practice_steps set
  content = regexp_replace(
    content,
    '^Chọn một trong các cách ở trên và thử trong một tình huống thật, liên quan tới (.*?)\.( Lần này đừng lặp lại điều bạn đã thử: ".*"\.)?$',
    'Mở phần gợi ý, chọn một cách, rồi thử trong một tình huống thật liên quan tới \1.'
  ),
  content_en = case when content_en is null then null else regexp_replace(
    content_en,
    '^Pick one of the ways above and try it in a real situation, related to (.*?)\.( This time, do not repeat what you already tried: ".*"\.)?$',
    'Open the suggestions, pick one way, then try it in a real situation related to \1.'
  ) end
where step_order = 3
  and theme_id like 'u-%'
  and content like 'Chọn một trong các cách ở trên và thử trong một tình huống thật, liên quan tới %';

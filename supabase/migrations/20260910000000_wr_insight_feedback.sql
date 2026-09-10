-- Đồng ý / Không đồng ý ở bước "Góc nhìn khác".
--
-- Nguồn: WorkReflection_Changelog_CareerSnapshot.docx §10 (khách gửi 10/09/2026).
--
-- §10 đổi nút "Tiếp tục" ở bước Góc nhìn khác thành hai nút "Đồng ý" và "Không
-- đồng ý". Tài liệu tự ghi: "Đây không phải thay đổi copy mà là thay đổi luồng
-- dữ liệu."
--
-- ---------------------------------------------------------------------------
-- Vì sao cần một bảng RIÊNG, không suy ra từ bảng Insight
-- ---------------------------------------------------------------------------
--
-- §10.3: "Tỷ lệ Không đồng ý là tín hiệu quý về chất lượng nội dung. Nếu một
-- đúc kết bị từ chối nhiều lần, đó là dấu hiệu cần viết lại câu đó."
--
-- Không suy ra được từ `wr_insights`: khi người dùng bấm Không đồng ý thì
-- KHÔNG có hàng nào được ghi vào đó cả. Vắng mặt không phân biệt được với "chưa
-- đi tới bước ấy", "thoát app giữa chừng", hay "chưa từng gặp tình huống này".
-- Muốn đếm tỷ lệ thì phải ghi cả hai vế thành sự kiện.
--
-- Một HÀNG cho mỗi lần bấm, không phải một hàng cho mỗi tình huống với hai cột
-- đếm: đội nội dung cần biết tỷ lệ ĐỔI THEO THỜI GIAN sau khi viết lại một đúc
-- kết. Bộ đếm cộng dồn thì viết lại câu xong vẫn mang theo vết của bản cũ mãi.
--
-- ---------------------------------------------------------------------------
-- Vì sao KHÔNG khoá ngoại sang wr_situations
-- ---------------------------------------------------------------------------
--
-- Nhánh "Điều khác" không có mã tình huống nào, mà lần bấm đó vẫn cần được đếm.
-- Cột để null, và thư viện tình huống vẫn sửa/xoá được mà không kéo theo lịch
-- sử phản hồi.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_insight_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  -- Mã tình huống của lần nhìn lại đó. Null = nhánh "Điều khác".
  situation_code text,

  -- true = Đồng ý (đúc kết được ghi vào Insight), false = Không đồng ý.
  agreed boolean not null,

  created_at timestamptz not null default now()
);

-- Truy vấn duy nhất đội nội dung cần: "tình huống X bị từ chối bao nhiêu phần
-- trăm trong khoảng thời gian nào".
create index if not exists wr_insight_feedback_situation_idx
  on public.wr_insight_feedback (situation_code, created_at desc);

create index if not exists wr_insight_feedback_user_idx
  on public.wr_insight_feedback (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- RLS — chỉ chủ sở hữu ghi và đọc.
--
-- Không có policy update hay delete: đây là NHẬT KÝ SỰ KIỆN. Sửa lại một lần
-- bấm đã xảy ra thì con số tỷ lệ mất ý nghĩa. Người dùng đổi ý thì lần nhìn lại
-- sau ghi một hàng mới.
--
-- Đội nội dung đọc số tổng hợp bằng service role ở phía quản trị, không qua
-- app — nên không mở policy đọc chéo người dùng nào ở đây.
-- ---------------------------------------------------------------------------

alter table public.wr_insight_feedback enable row level security;

drop policy if exists "wr_insight_feedback_owner_select" on public.wr_insight_feedback;
drop policy if exists "wr_insight_feedback_owner_insert" on public.wr_insight_feedback;

create policy "wr_insight_feedback_owner_select"
  on public.wr_insight_feedback for select
  using (auth.uid() = user_id);

create policy "wr_insight_feedback_owner_insert"
  on public.wr_insight_feedback for insert
  with check (auth.uid() = user_id);

-- Bộ nhớ đệm cho lớp 3 "AI diễn đạt lại" của Diễn giải sâu.
--
-- Nguồn: WorkReflection_DienGiaiSau_NoiDung.docx §7.3.
--
-- §7.3: "Không gọi mỗi lần mở màn hình. Chỉ gọi một lần khi nội dung diễn giải
-- được tạo mới, rồi lưu lại kết quả. Người dùng mở lại màn hình sẽ đọc bản đã
-- lưu."
--
-- ---------------------------------------------------------------------------
-- Vì sao khoá là BĂM CỦA CÂU GỐC, không phải một cột thời gian
-- ---------------------------------------------------------------------------
--
-- Câu diễn giải là hàm thuần của dữ liệu nền: cùng số lần nhìn lại, cùng điểm
-- Self-Check thì ra cùng một câu. Băm chính câu đó rồi làm khoá nghĩa là bộ đệm
-- TỰ hết hạn đúng lúc cần hết hạn — dữ liệu đổi thì câu đổi, câu đổi thì khoá
-- đổi, và bản cũ không bao giờ được đọc lại nữa.
--
-- Cách khác là lưu một hàng cho mỗi người kèm `expires_at`. Cách đó vừa cần một
-- công việc dọn dẹp định kỳ, vừa có cửa sổ sai: trong lúc chưa hết hạn mà người
-- dùng vừa nhìn lại thêm 5 lần, họ đọc một câu nói về dữ liệu cũ.
--
-- Bản cũ ở lại trong bảng sau khi câu đổi — cố ý. Người dùng có thể quay lại
-- đúng con số cũ (bỏ bớt một lần nhìn lại, sửa lại Self-Check), và khi đó bản
-- đã viết lại vẫn còn dùng được. Mỗi hàng vài trăm byte, vài lần một tháng.
--
-- ---------------------------------------------------------------------------
-- Vì sao có user_id khi khoá đã là băm nội dung
-- ---------------------------------------------------------------------------
--
-- Không phải để phân biệt nội dung — hai người ra cùng một câu thì bản viết lại
-- dùng chung được. Là để RLS có chỗ neo. Bảng chia sẻ chéo người dùng thì một
-- người dò băm là biết người khác đang ở tình trạng nào, mà câu diễn giải nói
-- về đời sống công việc của họ.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_polished_text (
  user_id uuid not null references auth.users(id) on delete cascade,

  -- SHA-256 của câu gốc đã trim, viết hex thường (64 ký tự).
  source_hash text not null,

  -- Bản model viết lại, ĐÃ qua cả ba rào chắn của §7.2. Không bao giờ lưu bản
  -- chưa soi: đọc từ bảng này ra là dùng thẳng.
  polished text not null,

  created_at timestamptz not null default now(),

  primary key (user_id, source_hash)
);

-- ---------------------------------------------------------------------------
-- RLS — chỉ chủ sở hữu.
--
-- Không có policy insert/update cho người dùng: chỉ Edge Function `wr-polish`
-- (service role) được ghi, vì nó là chỗ duy nhất đã chạy ba rào chắn. Mở cửa
-- ghi cho app nghĩa là mở cửa cho bất kỳ chuỗi nào vào đúng ô mà màn hình đọc
-- ra không kiểm lại lần nữa.
-- ---------------------------------------------------------------------------

alter table public.wr_polished_text enable row level security;

drop policy if exists "wr_polished_text_owner_select" on public.wr_polished_text;

create policy "wr_polished_text_owner_select"
  on public.wr_polished_text for select
  using (auth.uid() = user_id);

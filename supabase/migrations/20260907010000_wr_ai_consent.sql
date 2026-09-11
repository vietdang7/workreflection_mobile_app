-- Sự đồng ý cho phép gửi dữ liệu sang dịch vụ AI bên thứ ba.
--
-- Vì sao có bảng này: App Store từ chối bản 1.0 (6) ngày 06/09/2026 theo
-- Guideline 5.1.1(i) và 5.1.2(i). Nguyên văn phần cốt lõi:
--
--   The app appears to share the user's personal data with a third-party AI
--   service but the app does not clearly explain what data is sent, identify
--   who the data is sent to, and ask the user's permission before sharing the
--   data.
--
-- Apple nói thẳng rằng ghi trong Terms hoặc Privacy Policy là CHƯA ĐỦ — phải
-- hỏi ngay trong app, trước khi gửi. Bảng này là nơi câu trả lời đó được lưu.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO LƯU Ở MÁY CHỦ CHỨ KHÔNG PHẢI SharedPreferences
--
-- Hai lý do, lý do thứ hai mới là lý do chính:
--
--   1. Đồng ý đi theo TÀI KHOẢN, không theo máy. Người dùng đổi điện thoại thì
--      không phải trả lời lại, mà quan trọng hơn: người đã TỪ CHỐI thì cài lại
--      app cũng vẫn là từ chối.
--
--   2. Để máy chủ CƯỠNG CHẾ được. `wr-chat`, `wr-doc-analyze` và `wr-narrative`
--      đọc bảng này trước khi gửi bất cứ thứ gì sang OpenRouter. Chặn ở phía
--      app thì một lỗi lập trình, một màn hình quên chặn, hay một bản build cũ
--      còn trên máy ai đó là dữ liệu vẫn chảy đi. Chặn ở chỗ thật sự gọi ra
--      ngoài thì không có đường vòng nào.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO CLIENT ĐƯỢC GHI VÀO ĐÂY
--
-- Khác `wr_entitlements` và `wr_iap_transactions` — hai bảng đó cấm client ghi
-- vì ghi được là tự cấp quyền cho mình. Bảng này thì ngược lại: nó ghi lại lựa
-- chọn của chính người dùng về chính dữ liệu của họ. Người dùng tự "gian lận"
-- để được đồng ý gửi dữ liệu của chính mình thì không có ai bị thiệt.

create table if not exists public.wr_ai_consent (
  user_id     uuid primary key references auth.users(id) on delete cascade,

  -- Phiên bản bản công bố mà người dùng đã đọc khi bấm đồng ý.
  --
  -- Có cột này để khi nào nội dung công bố đổi về BẢN CHẤT — thêm một bên nhận
  -- dữ liệu, gửi thêm một loại dữ liệu — thì nâng số lên là cả app hỏi lại.
  -- Sửa câu chữ cho dễ đọc thì KHÔNG nâng: hỏi lại vì một dấu phẩy là dạy người
  -- dùng bấm đồng ý mà không đọc.
  version     integer not null default 1,

  -- Mốc đồng ý gần nhất. NULL nghĩa là chưa từng đồng ý.
  granted_at  timestamptz,

  -- Mốc rút lại. Có giá trị và mới hơn `granted_at` nghĩa là đang TỪ CHỐI.
  --
  -- Giữ lại cả hai mốc chứ không xoá hàng khi rút lại: cần trả lời được câu
  -- "lúc dữ liệu này được gửi đi thì người ta đã đồng ý chưa".
  revoked_at  timestamptz,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.wr_ai_consent enable row level security;

drop policy if exists "wr_ai_consent_owner_select" on public.wr_ai_consent;
drop policy if exists "wr_ai_consent_owner_insert" on public.wr_ai_consent;
drop policy if exists "wr_ai_consent_owner_update" on public.wr_ai_consent;

create policy "wr_ai_consent_owner_select"
  on public.wr_ai_consent
  for select
  using (auth.uid() = user_id);

create policy "wr_ai_consent_owner_insert"
  on public.wr_ai_consent
  for insert
  with check (auth.uid() = user_id);

create policy "wr_ai_consent_owner_update"
  on public.wr_ai_consent
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Cố ý KHÔNG có policy DELETE. Xoá hàng là xoá luôn dấu vết đã từng đồng ý hay
-- từ chối; rút lại thì đặt `revoked_at`, đó mới là thao tác đúng.

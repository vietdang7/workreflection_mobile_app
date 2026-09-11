-- Nhật ký giao dịch In-App Purchase.
--
-- Vì sao có bảng này: App Store từ chối bản 1.0 (6) ngày 06/09/2026 theo
-- Guideline 3.1.1, nên app phải bán Premium bằng IAP. Edge Function
-- `wr-verify-iap` kiểm biên lai Apple rồi ghi quyền vào `wr_entitlements`;
-- bảng này là sổ ghi từng giao dịch đứng sau quyền đó.
--
-- Ba việc bảng này làm, không việc nào thay thế được bằng chỗ khác:
--
--   1. CHỐNG DÙNG CHUNG. Một biên lai Apple hợp lệ có thể bị gửi lên từ nhiều
--      tài khoản WorkReflection khác nhau — biên lai là thật, chữ ký là thật,
--      mọi lớp kiểm mật mã đều qua. Chỉ có sổ này mới biết giao dịch đó đã
--      thuộc về ai. Khoá theo `original_transaction_id` vì mỗi kỳ gia hạn sinh
--      ra `transaction_id` mới.
--
--   2. TRUY NGƯỢC KHI CÓ KHIẾU NẠI. Người dùng nói "tôi đã trả tiền mà không
--      thấy mở khoá" thì đây là chỗ duy nhất trả lời được, vì `wr_entitlements`
--      chỉ giữ trạng thái cuối chứ không giữ lịch sử.
--
--   3. ĐỐI CHIẾU VỚI BÁO CÁO CỦA APPLE. Doanh thu Apple trả về theo tháng;
--      không có sổ phía mình thì không đối chiếu được.
--
-- Bảng KHÔNG cho client ghi. Cùng lý do với `wr_entitlements`: client ghi được
-- vào đây thì tự khai một giao dịch rồi tự cấp Premium.

create table if not exists public.wr_iap_transactions (
  -- Mã thuê bao, giữ nguyên qua mọi kỳ gia hạn. Đây là khoá chính chứ không
  -- phải `transaction_id`: khoá theo mã từng kỳ thì cùng một thuê bao vẫn cấp
  -- được cho nhiều tài khoản qua các kỳ khác nhau.
  original_transaction_id  text primary key,

  -- Mã của kỳ gần nhất đã xác minh.
  transaction_id           text not null,

  user_id                  uuid not null references auth.users(id) on delete cascade,

  -- 'ios' | 'android'. Android chưa bật, để sẵn cho khi mở Play Billing.
  platform                 text not null default 'ios' check (platform in ('ios','android')),

  -- Product id bên App Store Connect, không phải `cc_products.id`.
  product_id               text not null,

  purchased_at             timestamptz,
  expires_at               timestamptz,

  -- Có giá trị nghĩa là Apple đã hoàn tiền / thu hồi. Quyền phải bị cắt.
  revoked_at               timestamptz,

  -- 'Production' | 'Sandbox'. Giữ lại để không nhầm giao dịch chạy thử của
  -- TestFlight với giao dịch thật lúc đối chiếu doanh thu.
  environment              text,

  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- Tra theo người dùng khi xử lý khiếu nại.
create index if not exists wr_iap_transactions_user_idx
  on public.wr_iap_transactions (user_id);

alter table public.wr_iap_transactions enable row level security;

-- Chỉ SELECT của chính mình. GHI LÀ VIỆC CỦA `wr-verify-iap` bằng service role
-- — service role đi vòng qua RLS nên không cần policy insert/update nào cả.
--
-- ⚠️ Đừng thêm policy cho client ghi vào bảng này. Ghi được vào đây là tự cấp
-- được Premium.
drop policy if exists "wr_iap_transactions_owner_select" on public.wr_iap_transactions;

create policy "wr_iap_transactions_owner_select"
  on public.wr_iap_transactions
  for select
  using (auth.uid() = user_id);

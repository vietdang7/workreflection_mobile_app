-- Đổ dữ liệu gói từ `cc_profiles` sang `wr_entitlements`.
--
-- ---------------------------------------------------------------------------
-- Vấn đề đang chữa
-- ---------------------------------------------------------------------------
--
-- App có HAI nguồn sự thật về gói, và chúng đang mâu thuẫn trên production
-- (đo ngày 2026-07-31):
--
--   cc_profiles.subscription_expires_at   9/169 hàng còn hạn
--   wr_entitlements                       0 hàng — bảng rỗng hoàn toàn
--
-- Màn Tài khoản đọc nguồn thứ nhất nên ghi "PREMIUM MEMBER"; còn MỌI cổng tính
-- năng của WorkReflection (`wrEntitlementProvider` → `WrEntitlement`) đọc nguồn
-- thứ hai, nên toàn bộ người dùng đang bị coi là miễn phí — kể cả 9 người có
-- thuê bao còn hiệu lực. Người trả tiền thấy nhãn Premium mà không mở được
-- tính năng Premium nào.
--
-- ---------------------------------------------------------------------------
-- Quyết định
-- ---------------------------------------------------------------------------
--
-- `plan = 'premium'` cho mọi hàng có `subscription_expires_at`, kể cả mốc đã
-- qua: `valid_until` giữ nguyên mốc thật và `WrEntitlement.isPremium` đã tự coi
-- premium-quá-hạn là miễn phí. Ghi thành 'free' là làm mất thông tin "người này
-- từng trả tiền tới ngày nào".
--
-- Người có `subscription_expires_at = NULL` KHÔNG được ghi hàng nào. Không có
-- hàng thì `wrEntitlementProvider` trả về miễn phí — cùng kết quả, mà không
-- dựng ra 160 hàng vô nghĩa.
--
-- `on conflict do nothing`, KHÔNG phải `do update`: hôm nay bảng rỗng nên không
-- khác gì, nhưng nếu sau này webhook thanh toán đã ghi một hàng thật thì dữ
-- liệu suy ra từ `cc_profiles` tuyệt đối không được đè lên nó.
--
-- `source` đánh dấu để còn phân biệt hàng suy ra với hàng do thanh toán ghi, và
-- để lùi lại được:  delete from public.wr_entitlements
--                    where source = 'cc_profiles_backfill';
--
-- ---------------------------------------------------------------------------
-- ⚠ ĐÂY LÀ BẢN VÁ MỘT LẦN, KHÔNG PHẢI CÁCH CHỮA GỐC
-- ---------------------------------------------------------------------------
--
-- Không có gì ghi vào `wr_entitlements` khi ai đó thanh toán — đó chính là lý
-- do bảng rỗng. Nên lần thanh toán kế tiếp, hai nguồn lại lệch. Muốn hết lệch
-- thì phải chọn một trong hai: trigger đồng bộ từ `cc_profiles`, hoặc cho
-- đường thanh toán ghi thẳng vào đây.

insert into public.wr_entitlements (user_id, plan, valid_until, source, updated_at)
select p.id,
       'premium',
       p.subscription_expires_at,
       'cc_profiles_backfill',
       now()
  from public.cc_profiles p
 where p.subscription_expires_at is not null
   -- wr_entitlements.user_id có khoá ngoại tới auth.users. Một hàng
   -- cc_profiles mồ côi sẽ làm hỏng cả migration, nên lọc trước.
   and exists (select 1 from auth.users u where u.id = p.id)
on conflict (user_id) do nothing;

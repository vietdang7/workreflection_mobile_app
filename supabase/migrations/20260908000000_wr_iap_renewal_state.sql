-- Trạng thái gia hạn của thuê bao App Store.
--
-- Vì sao có migration này: khách chốt 08/09/2026 bán gói **tự động gia hạn**, và
-- kèm yêu cầu "phải thông báo nếu gần hết hạn". Muốn nhắc cho đúng thì phải
-- phân biệt được hai người có cùng một ngày trên lịch:
--
--   • người vẫn đang bật gia hạn  → ngày đó là ngày BỊ TRỪ TIỀN kỳ tiếp
--   • người đã tắt gia hạn        → ngày đó là ngày MẤT QUYỀN
--
-- Nói "sắp hết hạn" với người thứ nhất là nói sai, mà nói "sẽ tự động gia hạn"
-- với người thứ hai cũng sai. Biên lai giao dịch KHÔNG chứa thông tin này —
-- nó chỉ nói kỳ vừa mua kết thúc lúc nào. Chỗ duy nhất mang nó tới là App Store
-- Server Notifications V2 (`signedRenewalInfo`), do Edge Function
-- `wr-apple-notifications` nhận.
--
-- Không thêm cột "ngày gia hạn" riêng: `expires_at` đã là mốc kết thúc kỳ hiện
-- tại, và với gói tự động gia hạn thì đó cũng chính là mốc trừ tiền kỳ sau. Hai
-- cột gần giống nhau là hai cột sẽ lệch nhau, rồi không ai biết cột nào đúng.

alter table public.wr_iap_transactions
  -- null = CHƯA BIẾT (mới mua xong, Apple chưa gửi thông báo nào). Cố ý cho
  -- phép null chứ không default false: "chưa biết" và "đã tắt gia hạn" là hai
  -- chuyện khác nhau, và thẻ nhắc phải im lặng ở trường hợp đầu chứ không được
  -- doạ người ta rằng gói sắp mất.
  add column if not exists auto_renew boolean,

  -- Product id của kỳ tiếp. Khác `product_id` khi người dùng vừa đổi gói
  -- (tháng ↔ năm): kỳ đang chạy vẫn theo gói cũ, kỳ sau mới đổi.
  add column if not exists auto_renew_product_id text,

  -- Vì sao thuê bao sẽ dừng, theo mã của Apple: 1 người dùng tự huỷ ·
  -- 2 lỗi thanh toán · 3 không đồng ý giá mới · 4 sản phẩm không còn bán.
  -- Giữ lại vì mã 2 đáng nói khác hẳn: đó là thẻ hỏng chứ không phải người ta
  -- muốn thôi dùng.
  add column if not exists expiration_intent smallint,

  -- Thông báo gần nhất Apple gửi. Để trả lời được câu "hàm có chạy không" mà
  -- không phải đi lục log — bài học `wr_pattern_narratives`: một bảng ghi chú
  -- "backend ghi" nhưng suốt một tháng không có backend nào ghi thật.
  add column if not exists last_notification_type text,
  add column if not exists last_notification_at timestamptz;

comment on column public.wr_iap_transactions.auto_renew is
  'null = chưa nhận được thông báo nào từ Apple. true = Apple sẽ trừ tiền kỳ tiếp vào expires_at. false = tới expires_at là mất quyền.';

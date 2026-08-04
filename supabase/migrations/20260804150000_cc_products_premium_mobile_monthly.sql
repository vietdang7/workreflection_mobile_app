-- Gói Premium theo tháng cho app mobile.
--
-- Khách chốt 2026-08-04: thêm gói 70.000đ/tháng bên cạnh gói 499.000đ/năm để hạ
-- rào cản tài chính cho người dùng mới trong giai đoạn đầu. Gói năm vẫn là gói
-- chọn sẵn trên Paywall (display_order nhỏ hơn).
--
-- Cùng `product_type = 'premium_mobile'` với gói năm — hai gói chỉ khác
-- `duration_days`. App đọc CẢ NHÓM rồi dựng bộ chọn gói theo `display_order`,
-- nên sau này thêm gói 6 tháng chỉ là thêm một dòng ở trang quản trị, không
-- phải build lại app.
--
-- Không đụng RPC `complete_payment`: nó lấy `duration_days` từ `cc_products`
-- theo `product_id`, nên đơn mua gói này tự cấp Premium 30 ngày và vẫn ghi
-- `cc_profiles.role = 'premium'` như gói năm. Không có tự động gia hạn — hạ
-- tầng là chuyển khoản VietQR thủ công, hết hạn thì rơi về Free và mua lại.

-- Chèn một lần. Chạy lại migration thì không nhân bản, và cũng không ghi đè giá
-- mà quản trị đã chỉnh tay sau đó.
INSERT INTO cc_products (
  name,
  description,
  product_type,
  current_price,
  original_price,
  currency,
  duration_days,
  is_active,
  display_order
)
SELECT
  'Cloud & Coral Premium (App · theo tháng)',
  'Gói Premium theo tháng mua trong ứng dụng di động. Mở khoá AI Insight, báo '
    'cáo chuyên sâu 49 câu, Career Pattern và toàn bộ Career Memory trong 30 '
    'ngày.',
  'premium_mobile',
  70000,
  -- Để trống giá gốc: 70.000đ là giá gốc, không hiện gạch ngang. Chỗ so sánh
  -- với gói năm do app tự tính (nhãn "TIẾT KIỆM …%" trên gói năm).
  NULL,
  'VND',
  30,
  true,
  -- Lớn hơn 90 của gói năm → gói năm đứng trước và là gói chọn sẵn.
  91
WHERE NOT EXISTS (
  SELECT 1 FROM cc_products
  WHERE product_type = 'premium_mobile' AND duration_days = 30
);

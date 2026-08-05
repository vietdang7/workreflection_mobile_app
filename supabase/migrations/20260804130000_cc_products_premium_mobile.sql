-- Gói Premium riêng cho app mobile.
--
-- Khách chốt 2026-08-04: web và app bán hai gói khác nhau, khác giá — web
-- 249.000đ, app 499.000đ — nhưng thanh toán xong thì cả hai cùng cấp một
-- `cc_profiles.role = 'premium'`. Khác gói, khác tiền, KHÔNG khác quyền.
--
-- Bảng `cc_products` không có cột nào chỉ nền tảng, mà cả web lẫn app đều tra
-- giá bằng `product_type` (web: `useProductPrice(productType)`), nên tách bằng
-- đúng cột đó:
--
--   product_type = 'premium'         → gói web   (dòng đã có, không đụng tới)
--   product_type = 'premium_mobile'  → gói app   (dòng thêm ở đây)
--
-- Không đụng RPC `complete_payment`: đơn hàng vẫn ghi
-- `cc_orders.product_type = 'premium_survey'` (điều kiện `right(...,7) =
-- '_survey'` để cấp role premium), chỉ `cc_orders.product_id` là trỏ sang dòng
-- mới — RPC tra `duration_days` theo id nên hạn gói vẫn đúng.
--
-- Sau khi chạy, sửa giá gói app ngay tại trang quản trị Gói dịch vụ của web
-- (ô "Loại sản phẩm" nhập tự do), app đổi theo mà không cần build lại.

-- Chèn một lần. Chạy lại migration thì không nhân bản, và cũng không ghi đè
-- giá mà quản trị đã chỉnh tay sau đó.
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
  'Cloud & Coral Premium (App)',
  'Gói Premium mua trong ứng dụng di động. Mở khoá AI Insight, báo cáo chuyên '
    'sâu 49 câu, Career Pattern và toàn bộ Career Memory trong một năm.',
  'premium_mobile',
  499000,
  -- Để trống giá gốc: 499.000đ chính là giá gốc, app không hiện gạch ngang.
  NULL,
  'VND',
  365,
  true,
  90
WHERE NOT EXISTS (
  SELECT 1 FROM cc_products WHERE product_type = 'premium_mobile'
);

-- ============================================================================
-- Migration: sửa lỗi complete_payment không bao giờ cấp được Premium
-- Date: 2026-08-01
-- ----------------------------------------------------------------------------
-- TRIỆU CHỨNG: mua Premium bằng voucher giảm 100% trên app báo
-- "Không hoàn tất được đơn". Đơn CNCB2DE90DF: 0đ, pending, đúng chủ.
--
-- NGUYÊN NHÂN: nhánh cấp Premium so `cc_profiles.id` (uuid) với
-- `cc_orders.user_id` (text) mà không ép kiểu. Kiểm chứng bằng một đơn thử:
--
--   POST /rest/v1/rpc/complete_payment
--   -> 42883  operator does not exist: uuid = text
--
-- Lỗi này ném ra giữa hàm nên TOÀN BỘ giao dịch rollback: đơn không được đánh
-- 'paid', voucher không tăng lượt dùng, Premium không được cấp.
--
-- PHẠM VI: có từ migration 20260520000000 (2026-05-20), tức nhánh cấp Premium
-- CHƯA TỪNG chạy được — trên web cũng vậy, không riêng mobile. Chỉ nhánh
-- '_survey' dính; workshop và coaching không sao vì các bảng đó đều dùng text.
--
-- Nhân tiện sửa một lỗi nữa cùng chỗ: hàm gán thẳng role = 'premium', nên
-- admin mua gói để thử sẽ bị hạ xuống 'premium' và mất quyền quản trị.
-- ============================================================================

CREATE OR REPLACE FUNCTION complete_payment(p_order_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_voucher_id uuid;
  v_user_id text;
  v_org_id uuid;
  v_product_type text;
  v_product_id uuid;
  v_final_amount numeric;
  v_already_paid boolean;
  v_should_invoice boolean;
  v_supabase_url text;
  v_service_key text;
  v_sessions_count integer;
  v_duration_days integer;
  v_rows_inserted integer := 0;
  v_claims text;
  v_jwt_role text;
  v_privileged boolean;
  v_result json;
BEGIN
  SELECT (status = 'paid'), user_id, voucher_id, final_amount, product_type, product_id
    INTO v_already_paid, v_user_id, v_voucher_id, v_final_amount, v_product_type, v_product_id
  FROM cc_orders
  WHERE id = p_order_id;

  IF v_already_paid THEN
    SELECT json_build_object('success', true, 'order_id', p_order_id, 'already_paid', true)
      INTO v_result;
    RETURN v_result;
  END IF;

  -- ── CHỐT CHẶN NGƯỜI GỌI ───────────────────────────────────────────────
  -- Người gọi được coi là tin cậy khi:
  --   • JWT mang role 'service_role' (webhook bank-webhook, sepay-invoice), hoặc
  --   • không có JWT nào cả -> gọi thẳng bằng SQL (psql, pg_cron, admin).
  -- Anon và authenticated đều KHÔNG tin cậy.
  v_claims := current_setting('request.jwt.claims', true);
  v_jwt_role := COALESCE((NULLIF(v_claims, '')::jsonb) ->> 'role', '');
  v_privileged := (v_jwt_role = 'service_role') OR (COALESCE(v_claims, '') = '');

  IF NOT v_privileged THEN
    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'Order not found'
        USING ERRCODE = 'no_data_found';
    END IF;

    IF auth.uid() IS NULL OR v_user_id IS DISTINCT FROM auth.uid()::text THEN
      RAISE EXCEPTION 'Not your order'
        USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Đây là chốt quan trọng nhất: đơn có tiền chỉ được xác nhận bởi ngân
    -- hàng qua webhook. Client chỉ tự hoàn tất được đơn 0đ.
    IF COALESCE(v_final_amount, 0) > 0 THEN
      RAISE EXCEPTION 'Paid orders must be confirmed by the bank webhook'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  -- ── HẾT CHỐT CHẶN ─────────────────────────────────────────────────────

  -- Snapshot org_id CHỈ cho workshop_enterprise (B2B thật sự).
  IF v_product_type = 'workshop_enterprise' THEN
    SELECT org_id INTO v_org_id
    FROM cc_org_members
    WHERE user_id = v_user_id
    ORDER BY CASE role
      WHEN 'owner' THEN 0
      WHEN 'admin' THEN 1
      ELSE 2
    END
    LIMIT 1;
  END IF;

  v_should_invoice := (COALESCE(v_final_amount, 0) > 0);

  UPDATE cc_orders
  SET status = 'paid',
      org_id = COALESCE(org_id, v_org_id),
      invoice_status = CASE WHEN v_should_invoice THEN 'pending' ELSE 'not_required' END,
      paid_at = COALESCE(paid_at, now()),
      updated_at = now()
  WHERE id = p_order_id;

  IF v_voucher_id IS NOT NULL THEN
    UPDATE cc_vouchers
    SET used_count = COALESCE(used_count, 0) + 1
    WHERE id = v_voucher_id;
  END IF;

  -- ────────────────────────────────────────────────────────────────────────
  -- Server-side fulfillment (giữ nguyên từ 20260520000000)
  -- ────────────────────────────────────────────────────────────────────────

  IF v_product_type = 'workshop' THEN
    INSERT INTO cc_workshop_registrations (user_id, workshop_id, order_id, status, payment_status)
    SELECT v_user_id, v_product_id, p_order_id, 'registered', 'paid'
    WHERE NOT EXISTS (
      SELECT 1 FROM cc_workshop_registrations WHERE order_id = p_order_id
    );
    GET DIAGNOSTICS v_rows_inserted = ROW_COUNT;

    IF v_rows_inserted > 0 THEN
      UPDATE cc_workshops
      SET current_participants = COALESCE(current_participants, 0) + 1
      WHERE id = v_product_id;
    END IF;
  END IF;

  IF v_product_type = 'coaching' THEN
    SELECT sessions_count INTO v_sessions_count
    FROM cc_coaching_packages
    WHERE id = v_product_id;

    INSERT INTO cc_coaching_bookings (user_id, package_id, order_id, status, session_number)
    SELECT v_user_id, v_product_id, p_order_id, 'pending', gs
    FROM generate_series(1, COALESCE(v_sessions_count, 1)) AS gs
    WHERE NOT EXISTS (
      SELECT 1 FROM cc_coaching_bookings WHERE order_id = p_order_id
    );
  END IF;

  IF right(v_product_type, 7) = '_survey' THEN
    SELECT duration_days INTO v_duration_days
    FROM cc_products
    WHERE id = v_product_id;

    -- cc_profiles.id là uuid, cc_orders.user_id là text -> BẮT BUỘC ép kiểu.
    -- Thiếu ::uuid thì Postgres ném 42883 "operator does not exist: uuid = text"
    -- và cả RPC rollback: đơn không được đánh dấu đã trả, Premium không cấp.
    --
    -- role: KHÔNG hạ cấp admin/coordinator xuống 'premium'. Người quản trị mua
    -- gói để thử là mất quyền quản trị. Họ vốn đã có mọi quyền của Premium
    -- (isWebPremiumRole coi admin là Premium), chỉ cần gia hạn là đủ.
    UPDATE cc_profiles
    SET role = CASE
                 WHEN role IN ('admin', 'coordinator') THEN role
                 ELSE 'premium'
               END,
        subscription_expires_at = now() + (COALESCE(v_duration_days, 365) || ' days')::interval,
        updated_at = now()
    WHERE id = v_user_id::uuid;
  END IF;

  -- ────────────────────────────────────────────────────────────────────────
  -- Trigger eInvoice
  -- ────────────────────────────────────────────────────────────────────────

  IF v_should_invoice THEN
    SELECT value INTO v_supabase_url FROM cc_app_config WHERE key = 'supabase_url';
    SELECT value INTO v_service_key FROM cc_app_config WHERE key = 'service_role_key';

    IF v_supabase_url IS NOT NULL AND v_service_key IS NOT NULL THEN
      PERFORM net.http_post(
        url := v_supabase_url || '/functions/v1/sepay-invoice',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_service_key
        ),
        body := jsonb_build_object('orderId', p_order_id)
      );
    END IF;
  END IF;

  SELECT json_build_object(
    'success', true,
    'order_id', p_order_id,
    'org_id', v_org_id,
    'product_type', v_product_type,
    'final_amount', v_final_amount,
    'invoice_triggered', v_should_invoice,
    'config_loaded', v_supabase_url IS NOT NULL AND v_service_key IS NOT NULL,
    'fulfilled', v_rows_inserted > 0 OR v_product_type IN ('workshop_enterprise','coaching') OR right(v_product_type, 7) = '_survey'
  ) INTO v_result;
  RETURN v_result;
END;
$$;

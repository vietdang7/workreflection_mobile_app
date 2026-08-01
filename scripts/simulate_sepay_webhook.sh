#!/usr/bin/env bash
#
# Giả lập một cú gọi webhook của SePay để test luồng thanh toán mà không cần
# chuyển khoản thật.
#
# Vì sao không cần sandbox của SePay: webhook chỉ là một endpoint HTTP nhận
# JSON. Gửi đúng gói tin là đủ — phần còn lại (dò mã CNC, gọi complete_payment,
# cấp Premium, gửi mail) chạy y hệt như khi tiền vào thật.
#
# Cách dùng:
#   export SEPAY_WEBHOOK_SECRET=<khoá đã đặt trong SePay và Supabase>
#   ./scripts/simulate_sepay_webhook.sh CNCABC12345 249000
#
# Đối số:
#   $1  mã đơn, dạng CNC + 8 ký tự (lấy trên màn thanh toán của app)
#   $2  số tiền, mặc định 249000
#
# CẢNH BÁO: script này chạy vào DB thật. Nó sẽ đánh đơn là đã trả và cấp
# Premium thật cho chủ đơn. Chỉ dùng với đơn test của chính bạn.

set -euo pipefail

ORDER_CODE="${1:-}"
AMOUNT="${2:-249000}"
PROJECT_URL="${SUPABASE_URL:-https://sukpcxevcjnhiuyaoqxi.supabase.co}"
ENDPOINT="$PROJECT_URL/functions/v1/bank-webhook"

if [[ -z "$ORDER_CODE" ]]; then
  echo "Thiếu mã đơn." >&2
  echo "Dùng: $0 CNCABC12345 [số tiền]" >&2
  exit 1
fi

if [[ ! "$ORDER_CODE" =~ ^CNC[A-Za-z0-9]{6,8}$ ]]; then
  echo "Mã đơn '$ORDER_CODE' không đúng dạng CNC + 6..8 ký tự." >&2
  echo "Webhook dò bằng /CNC([A-Z0-9]{6,8})/i nên sai dạng là không khớp đơn." >&2
  exit 1
fi

if [[ -z "${SEPAY_WEBHOOK_SECRET:-}" ]]; then
  echo "Chưa đặt SEPAY_WEBHOOK_SECRET." >&2
  echo "Webhook đang bật cổng xác thực; thiếu khoá sẽ nhận 401." >&2
  exit 1
fi

# id giao dịch phải khác nhau mỗi lần: webhook chống trùng bằng
# sepay_transaction_id, gửi lại cùng id sẽ bị bỏ qua.
TX_ID="$(date +%s)$RANDOM"

echo "→ $ENDPOINT"
echo "  đơn      : $ORDER_CODE"
echo "  số tiền  : $AMOUNT"
echo "  giao dịch: $TX_ID"
echo

HTTP_CODE=$(curl -s -o /tmp/sepay_sim_response.json -w '%{http_code}' \
  -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: Apikey $SEPAY_WEBHOOK_SECRET" \
  -d @- <<JSON
{
  "id": $TX_ID,
  "gateway": "MBBank",
  "transactionDate": "$(date '+%Y-%m-%d %H:%M:%S')",
  "accountNumber": "2610130979",
  "transferType": "in",
  "transferAmount": $AMOUNT,
  "content": "CHUYEN TIEN $ORDER_CODE"
}
JSON
)

echo "HTTP $HTTP_CODE"
cat /tmp/sepay_sim_response.json
echo

case "$HTTP_CODE" in
  200) echo "✓ Webhook đã nhận. Mở lại app xem đơn đã chuyển sang đã trả chưa." ;;
  401) echo "✗ Sai khoá, hoặc SEPAY_WEBHOOK_SECRET trên Supabase khác khoá ở đây." ;;
  *)   echo "✗ Xem log: $PROJECT_URL/../functions/bank-webhook/logs" ;;
esac

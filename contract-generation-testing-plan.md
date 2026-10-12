# Kế hoạch xây dựng hệ thống kiểm thử xuất hợp đồng

## 1. Mục tiêu

Tự động kiểm thử toàn bộ quy trình:

```text
Tạo dữ liệu → Tạo báo giá → Gom báo giá thành hợp đồng → Tạo hợp đồng
→ Chọn template → Render → Đọc file đầu ra → Đối chiếu dữ liệu nguồn
→ Kiểm tra không lấy nhầm dữ liệu từ template → Sinh báo cáo
```

Hệ thống phải kiểm tra ba lớp:

1. Đúng quy trình nghiệp vụ.
2. Đúng nội dung dữ liệu.
3. Đúng nguồn dữ liệu; nội dung phải đến từ phần mềm, không phải giá trị có sẵn trong mẫu.

## 2. UIlicious và môi trường local

UIlicious phù hợp để kiểm thử web application qua trình duyệt. Nếu phần báo giá/hợp đồng là Flutter mobile/native app thì UIlicious không nên là công cụ duy nhất để điều khiển ứng dụng.

UIlicious Cloud không truy cập trực tiếp được `localhost`; ứng dụng local cần được expose qua tunnel tạm thời như ngrok hoặc chạy trên staging. UIlicious có thể chạy bằng CLI để tích hợp vào script/CI:

- [UIlicious CLI](https://docs.uilicious.com/v3/how-to-guides/run-test/run-test-using-cli)
- [Testing localhost/private network](https://uilicious.com/cloud-testing-grid/)

Kiến trúc nên dùng:

```text
Test launcher local
  ├── Khởi động app/backend
  ├── Tạo dữ liệu test
  ├── Mở tunnel hoặc xác định staging URL
  ├── Gọi UIlicious CLI
  ├── Chạy contract verifier local
  └── Sinh báo cáo

UIlicious = điều khiển UI, user journey, screenshot, cross-browser
Verifier = đọc PDF/DOCX/HTML, so sánh field và kiểm tra provenance
```

Nếu yêu cầu bắt buộc là chạy 100% local, dùng Playwright hoặc Selenium cho local regression; dùng UIlicious cho cross-browser hoặc các lần chạy trên staging.

## 3. Mô hình dữ liệu kiểm thử

Mỗi lần chạy phải có một `testRunId` duy nhất:

```text
TEST-20261003-AB12
```

Mọi dữ liệu đều chứa mã này:

```json
{
  "customerName": "CUSTOMER_SRC_7F31",
  "quotationCode": "QUOTE_TEST-AB12",
  "contractCode": "CONTRACT_TEST-AB12",
  "productName": "PRODUCT_SRC_12AB",
  "price": 1234567,
  "effectiveDate": "2026-10-03",
  "term": "TERM_SRC_5512"
}
```

Không dùng dữ liệu phổ biến như `Nguyễn Văn A` hoặc `100.000`, vì template có thể đã chứa sẵn các giá trị này.

### Sentinel value và dữ liệu bẫy

Dùng các giá trị duy nhất cho từng run:

```text
CUSTOMER_SRC_7F31
PRICE_SRC_9284
ADDRESS_SRC_AA19
TERM_SRC_5512
```

Trong template đặt các giá trị bẫy:

```text
TEMPLATE_ONLY_CUSTOMER
TEMPLATE_ONLY_PRICE
TEMPLATE_DEFAULT_TERM
```

Các giá trị bẫy không được xuất hiện trong hợp đồng cuối cùng. Đây là assertion trực tiếp để phát hiện việc lấy nhầm dữ liệu từ mẫu.

## 4. Thành phần cần xây dựng

### 4.1. Test Orchestrator

Chịu trách nhiệm:

1. Kiểm tra môi trường.
2. Khởi động frontend/backend và database test.
3. Tạo `testRunId`.
4. Seed dữ liệu.
5. Mở tunnel hoặc xác định staging URL.
6. Gọi UIlicious CLI.
7. Lấy file hợp đồng.
8. Chạy semantic verifier.
9. Sinh báo cáo.
10. Cleanup dữ liệu và trả exit code.

### 4.2. Test Data Factory

Sinh khách hàng, sản phẩm, báo giá, điều khoản và hợp đồng. Mỗi run phải độc lập và lưu snapshot dữ liệu nguồn trước khi render.

Ví dụ:

```json
{
  "runId": "TEST-20261003-AB12",
  "source": {
    "customerName": "CUSTOMER_SRC_7F31",
    "address": "ADDRESS_SRC_AA19",
    "price": 1234567,
    "discount": 5,
    "tax": 10,
    "term": "TERM_SRC_5512"
  },
  "template": {
    "name": "template-standard-v2",
    "templateOnlyMarkers": [
      "TEMPLATE_ONLY_CUSTOMER",
      "TEMPLATE_ONLY_PRICE"
    ]
  }
}
```

### 4.3. UIlicious Test Suite

```text
uilicious/
├── config/                 # environment, selectors
├── data/                   # test input
├── flows/                  # login, quotation, contract, render
├── assertions/             # UI assertions
└── suites/                 # các suite nghiệp vụ
```

Nên tách các flow dùng chung như login, tạo báo giá và render. UIlicious hỗ trợ tái sử dụng flow bằng `TEST.run()` ([tài liệu](https://docs.uilicious.com/scripting/reference/test/test-run)).

### 4.4. Contract Verifier

Đây là thành phần quan trọng nhất. `I.see()` chỉ chứng minh text hiển thị trên UI, không chứng minh text đến từ nguồn dữ liệu đúng.

Verifier cần:

- Đọc text từ PDF.
- Đọc XML/text từ DOCX.
- Đọc DOM/text từ HTML.
- Có OCR fallback nếu PDF là ảnh.
- Chuẩn hóa Unicode tiếng Việt, khoảng trắng, xuống dòng.
- Chuẩn hóa tiền tệ và ngày tháng.
- So sánh từng field với snapshot nguồn.
- Phát hiện placeholder chưa được thay thế.
- Phát hiện các giá trị chỉ có trong template.
- Tính lại tổng tiền, thuế và chiết khấu.

## 5. Luồng kiểm thử

### Bước 1: Chuẩn bị

- Kiểm tra frontend/backend, database test, tài khoản test và template.
- Dọn dữ liệu cũ của automation.
- Tạo `testRunId`.
- Tạo tunnel nếu dùng UIlicious Cloud.

### Bước 2: Tạo dữ liệu nguồn

Khuyến nghị dùng API hoặc seed script để tạo dữ liệu nền; dùng UIlicious để kiểm tra các nghiệp vụ chính. Không cần dùng UI cho mọi thao tác vì sẽ làm test chậm và khó chẩn đoán.

Dữ liệu cần có: khách hàng, người liên hệ, sản phẩm/dịch vụ, đơn giá, thuế, chiết khấu, điều khoản, người phụ trách, ngày hiệu lực, địa chỉ và template.

### Bước 3: Tạo báo giá

Kiểm tra mã báo giá, khách hàng, sản phẩm, đơn giá, chiết khấu, thuế, tổng tiền và trạng thái.

### Bước 4: Gom báo giá thành hợp đồng

Kiểm tra:

```text
contract.quotationIds == expectedQuotationIds
contract.total == sum(quotationTotals)
contract.itemCount == expectedItemCount
```

Phải phát hiện được báo giá bị gom nhầm, dòng bị mất hoặc dòng bị trùng.

### Bước 5: Tạo hợp đồng

Kiểm tra mã hợp đồng, khách hàng, người đại diện, số tiền, ngày hiệu lực, điều khoản, trạng thái, báo giá liên kết và phiên bản template. Lưu snapshot hợp đồng trước khi render.

### Bước 6: Chọn template

Tối thiểu kiểm tra template tiêu chuẩn, nhiều dòng sản phẩm, điều khoản dài, field tùy chọn, template song ngữ nếu có, phiên bản cũ/mới và template có giá trị mặc định làm bẫy.

```text
selectedTemplate == expectedTemplate
selectedTemplateVersion == expectedVersion
unresolvedPlaceholders.length == 0
```

### Bước 7: Render và đối chiếu

Lập field mapping riêng:

| Field | Nguồn | Giá trị kỳ vọng | Bắt buộc |
|---|---|---|---|
| Tên khách hàng | Customer | `CUSTOMER_SRC_7F31` | Có |
| Địa chỉ | Customer | `ADDRESS_SRC_AA19` | Có |
| Mã hợp đồng | Contract | `CONTRACT_TEST-AB12` | Có |
| Sản phẩm | Quotation item | `PRODUCT_SRC_12AB` | Có |
| Đơn giá | Quotation item | `1.234.567` | Có |
| Thuế | Quotation | `10%` | Có |
| Điều khoản | Contract | `TERM_SRC_5512` | Có |

Kết quả từng field:

```json
{
  "field": "customerName",
  "expected": "CUSTOMER_SRC_7F31",
  "actual": "CUSTOMER_SRC_7F31",
  "status": "PASS",
  "source": "customer.name",
  "location": "page 1"
}
```

## 6. Kiểm tra tính toán

Verifier phải tính lại:

```text
subtotal = sum(quantity × unitPrice)
discountAmount = subtotal × discountRate
taxAmount = (subtotal - discountAmount) × taxRate
total = subtotal - discountAmount + taxAmount
```

Sau đó kiểm tra:

```text
renderedTotal == calculatedTotal
contractTotal == quotationTotal
```

Trước khi triển khai phải thống nhất quy tắc làm tròn, số chữ số thập phân và định dạng tiền tệ.

## 7. Bộ test MVP

| Nhóm | Nội dung |
|---|---|
| Happy path | Một báo giá → một hợp đồng → render thành công |
| Multiple quotations | Nhiều báo giá → một hợp đồng |
| Data provenance | Dữ liệu render đúng từ báo giá/hợp đồng |
| Template contamination | Không xuất hiện dữ liệu mẫu |
| Missing optional field | Field tùy chọn bị bỏ trống |
| Missing required field | Hệ thống báo lỗi đúng |
| Calculation | Tổng tiền, thuế, chiết khấu đúng |
| Rendering | PDF/DOCX không mất chữ, không tràn bảng |

Sau MVP mới mở rộng sang đa ngôn ngữ, đa tiền tệ, nhiều template, ký số, gửi email, phân quyền và chạy đồng thời.

## 8. Báo cáo đầu ra

```text
artifacts/
└── TEST-20261003-AB12/
    ├── input-data.json
    ├── quotation-snapshot.json
    ├── contract-snapshot.json
    ├── rendered-contract.pdf
    ├── extracted-text.txt
    ├── field-comparison.json
    ├── visual-screenshots/
    ├── ui-licious-report-url.txt
    └── summary.html
```

Ví dụ kết quả:

```text
Run ID: TEST-20261003-AB12
Status: FAILED

UI flow: PASS
Quotation creation: PASS
Contract creation: PASS
Template selection: PASS
PDF rendering: PASS
Field mapping: FAIL

Failed fields:
- customerName: expected CUSTOMER_SRC_7F31, actual TEMPLATE_ONLY_CUSTOMER
- total: expected 1,234,567, actual 999,999

Template contamination:
- TEMPLATE_ONLY_PRICE found on page 2
```

UIlicious tự động chụp screenshot; có thể dùng `I.see()`, `I.dontSee()` và `TEST.assert()` cho assertion UI ([screenshots](https://docs.uilicious.com/scripting/guides/screeenshots), [page validation](https://docs.uilicious.com/scripting/guides/validating-page-content), [TEST.assert](https://docs.uilicious.com/scripting/reference/logging/test-assert)).

## 9. Chạy bằng một lệnh

Nên có script:

```bash
./scripts/test-contract-flow.sh
```

Script thực hiện:

1. Kiểm tra dependency.
2. Khởi động hệ thống local.
3. Khởi động database test.
4. Khởi động tunnel.
5. Tạo `testRunId`.
6. Seed dữ liệu.
7. Chạy UIlicious CLI.
8. Chạy contract verifier.
9. Sinh report.
10. Cleanup và đóng tunnel.

Exit code:

```text
0 = toàn bộ pass
1 = test nghiệp vụ fail
2 = semantic verification fail
3 = môi trường không sẵn sàng
4 = lỗi cấu hình
```

## 10. Lộ trình triển khai

### Phase 0 — Khảo sát, 1–2 ngày

- Xác định hệ thống chứa báo giá/hợp đồng.
- Xác định API, database và môi trường test.
- Xác định định dạng output.
- Liệt kê template và field.
- Lập bảng quotation-to-contract mapping.

### Phase 1 — Proof of Concept, 2–4 ngày

Chỉ làm một flow: tạo báo giá → tạo hợp đồng → chọn một template → render PDF → verify 5–10 field. Mục tiêu là chứng minh có thể truy cập hệ thống, đọc file và phát hiện dữ liệu template giả.

### Phase 2 — MVP, 1–2 tuần

Xây test data factory, UIlicious flows, local orchestrator, PDF/DOCX extractor, field mapping, contamination check, report và cleanup.

### Phase 3 — Regression suite, 1–2 tuần

Mở rộng tất cả template, nhiều báo giá, case thiếu field, thuế/chiết khấu, render nhiều trang, visual regression và phân quyền.

### Phase 4 — CI/CD, 3–5 ngày

```text
Pull request: smoke test + template chính
Nightly: toàn bộ template + nhiều browser + semantic verification
```

## 11. Tiêu chí nghiệm thu

- Tạo được dữ liệu test độc lập ở mỗi lần chạy.
- Tự tạo được báo giá và hợp đồng.
- Tự gom đúng báo giá.
- Tự chọn đúng template và version.
- Tự render được hợp đồng.
- Đọc được PDF/DOCX/HTML.
- Xác minh được toàn bộ field bắt buộc.
- Phát hiện dữ liệu lấy từ template.
- Phát hiện placeholder chưa thay thế.
- Kiểm tra được tổng tiền, thuế và chiết khấu.
- Lưu được screenshot, file đầu ra và snapshot nguồn.
- Có log đủ để tái hiện lỗi.
- Có exit code cho CI/CD.
- Có cleanup sau khi chạy.

## 12. Rủi ro và cách xử lý

| Rủi ro | Cách xử lý |
|---|---|
| UIlicious không truy cập localhost | Dùng tunnel, staging hoặc Playwright/Selenium local |
| Text assertion cho kết quả sai | Bắt buộc có snapshot nguồn và verifier riêng |
| Test data trùng template | Dùng sentinel value và template-only markers |
| PDF không extract được text | PDF extractor, kiểm tra font, OCR fallback và visual comparison |
| Dữ liệu automation làm bẩn môi trường | Database test riêng, `runId`, `createdBy=automation` và cleanup |

## 13. Kiến trúc kết luận

```text
UIlicious
  = thao tác UI, user journey, screenshot, cross-browser

Local test orchestrator
  = khởi động hệ thống, seed data, gọi UIlicious, cleanup

Contract verifier
  = đọc PDF/DOCX, kiểm tra field và provenance

Database/API snapshot
  = bằng chứng dữ liệu nguồn trước khi render

HTML/JSON report
  = kết quả cho QA và developer
```

Nên bắt đầu bằng một template và khoảng 10 field quan trọng. Sau khi chứng minh được hệ thống phát hiện lỗi “hợp đồng lấy dữ liệu mẫu thay vì dữ liệu phần mềm”, mới mở rộng sang toàn bộ template, browser và các luồng phức tạp hơn.

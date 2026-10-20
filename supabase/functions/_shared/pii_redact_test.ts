// Test khử PII trước khi gửi chữ sang DeepSeek.
//
// Chạy: deno test supabase/functions/_shared/pii_redact_test.ts
//
// Hai chiều đều phải kiểm: thông tin cá nhân KHÔNG được lọt, và nội dung nghề
// nghiệp (năm, doanh số, tên công ty, kỹ năng) KHÔNG được bị xoá nhầm — xoá nhầm
// thì bản phân tích JD/CV hỏng mà chẳng ai thấy lỗi.

import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { loadPiiIdentity, PII_TAGS, redactPii, redactPiiDetailed } from './pii_redact.ts';

const CV_VI = `NGUYỄN VĂN AN
Chuyên viên Marketing
SĐT: 0912 345 678 | Email: nguyenvanan.mkt@gmail.com
Địa chỉ: 123 Nguyễn Trãi, Phường 2, Quận 5, TP.HCM
Ngày sinh: 12/03/1995
CCCD: 079095001234
LinkedIn: https://www.linkedin.com/in/nguyen-van-an-123
Facebook: fb.com/an.nguyen.95

MỤC TIÊU NGHỀ NGHIỆP
Phát triển thương hiệu cho doanh nghiệp FMCG.

KINH NGHIỆM LÀM VIỆC
2019 - 2023: Công ty TNHH ABC Việt Nam, Quận 1, TP.HCM
- Quản lý ngân sách 2.500.000.000 VNĐ/năm, tăng doanh số 35%.
- Phối hợp 12 đối tác, liên hệ qua hotline công ty 1900 6789.

Tôi, Nguyễn Văn An, xin cam đoan các thông tin trên là đúng sự thật.`;

Deno.test('CV tiếng Việt: xoá đủ 7 loại thông tin cá nhân', () => {
  const { text, counts } = redactPiiDetailed(CV_VI, { isCv: true });
  for (const leak of [
    'NGUYỄN VĂN AN',
    'Nguyễn Văn An',
    '0912 345 678',
    'nguyenvanan.mkt@gmail.com',
    '123 Nguyễn Trãi',
    '12/03/1995',
    '079095001234',
    'linkedin.com/in',
    'fb.com/an.nguyen.95',
  ]) {
    assert(!text.includes(leak), `còn lọt: ${leak}`);
  }
  assert(counts.name >= 2, 'cả dòng đầu lẫn câu cam đoan');
  assertEquals(counts.email, 1);
  assertEquals(counts.phone, 1);
  assertEquals(counts.id, 1);
  assertEquals(counts.dob, 1);
  assertEquals(counts.address, 1);
  assertEquals(counts.link, 2);
});

Deno.test('CV tiếng Việt: nội dung nghề nghiệp giữ nguyên', () => {
  const text = redactPii(CV_VI, { isCv: true });
  for (const keep of [
    'Chuyên viên Marketing',
    'MỤC TIÊU NGHỀ NGHIỆP',
    '2019 - 2023',
    'Công ty TNHH ABC Việt Nam, Quận 1, TP.HCM',
    '2.500.000.000 VNĐ/năm',
    '35%',
    '1900 6789',
    'Ngày sinh: ',
    'Địa chỉ: ',
  ]) {
    assertStringIncludes(text, keep);
  }
});

Deno.test('CV tiếng Anh, tên ghi nhãn, số +84 và quốc tế', () => {
  const cv = `Full name: Tran Thi Bich Ngoc
Phone: (+84) 98-765-4321
Mobile (SG): +65 9123 4567
Date of birth: March 5, 1998
Address: 45 Le Loi Street, Ben Nghe Ward, District 1
Passport No: C1234567
GitHub: github.com/ngoctran

Summary: Data analyst with 4 years of experience in Python and SQL.
Reference: available upon request. Signed, Tran Thi Bich Ngoc.`;
  const text = redactPii(cv, { isCv: true });
  for (const leak of [
    'Tran Thi Bich Ngoc',
    '98-765-4321',
    '9123 4567',
    'March 5, 1998',
    '45 Le Loi',
    'C1234567',
    'github.com/ngoctran',
  ]) {
    assert(!text.includes(leak), `còn lọt: ${leak}`);
  }
  assertStringIncludes(text, 'Data analyst with 4 years of experience in Python and SQL.');
});

Deno.test('lớp danh tính thật: xoá tên/email/SĐT của người dùng ở mọi dạng viết', () => {
  const text = redactPii(
    'Liên hệ Le Hoang Minh (le.hoang.minh@corp.vn), số +84 903.111.222. ' +
      'Anh LÊ HOÀNG MINH phụ trách. Gọi 0903111222.',
    {
      identity: {
        fullName: 'Lê Hoàng Minh',
        email: 'Le.Hoang.Minh@corp.vn',
        phone: '0903 111 222',
      },
    },
  );
  assert(!/minh/i.test(text), text);
  assert(!text.includes('903'), text);
  assert(!text.includes('@'), text);
});

Deno.test('tên một chữ trong hồ sơ không làm xoá nhầm chữ thường', () => {
  const text = redactPii('Đảm bảo an toàn lao động.', { identity: { fullName: 'An' } });
  assertEquals(text, 'Đảm bảo an toàn lao động.');
});

Deno.test('JD: chức danh dòng đầu và địa chỉ làm việc KHÔNG bị xoá', () => {
  const jd = `Trưởng Nhóm Kinh Doanh
Công ty Cổ phần XYZ
Địa chỉ làm việc: Tầng 5, 18 Lý Thường Kiệt, Quận Hoàn Kiếm, Hà Nội
Mức lương: 25 - 35 triệu
Yêu cầu: 3 năm kinh nghiệm B2B, thành thạo CRM.
Nộp hồ sơ: tuyendung@xyz.vn hoặc 024 3826 1234`;
  const text = redactPii(jd, { isCv: false });
  assertStringIncludes(text, 'Trưởng Nhóm Kinh Doanh');
  assertStringIncludes(text, 'Địa chỉ làm việc: Tầng 5, 18 Lý Thường Kiệt');
  assertStringIncludes(text, '25 - 35 triệu');
  assertStringIncludes(text, '3 năm kinh nghiệm B2B');
  assert(!text.includes('tuyendung@xyz.vn'));
  assert(!text.includes('3826 1234'));
});

Deno.test('không cắn nhầm năm, khoảng năm, số tiền, mã sản phẩm', () => {
  const s = 'Giai đoạn 2018-2021, doanh thu 120.000.000.000 đồng, mã SKU 4006381333931, ' +
    'tăng trưởng 12,5%, đội 15 người, ISO 9001:2015.';
  assertEquals(redactPii(s, { isCv: true }), s);
});

Deno.test('chữ dạng tổ hợp (NFD) từ PDF vẫn bị nhận ra', () => {
  const nfd = 'Họ và tên: Phạm Thị Thu\nEmail: thu@x.vn'.normalize('NFD');
  const text = redactPii(nfd);
  assertStringIncludes(text, PII_TAGS.name);
  assert(!text.includes('Thu\n'));
});

Deno.test('chuỗi rỗng đi qua yên ổn', () => {
  assertEquals(redactPii(''), '');
});

Deno.test('loadPiiIdentity: đọc hỏng thì trả rỗng, không ném', async () => {
  const broken = { from: () => { throw new Error('db down'); } };
  assertEquals(await loadPiiIdentity(broken, 'u1'), {});
  const ok = {
    from: () => ({
      select: () => ({
        eq: () => ({
          limit: () => Promise.resolve({ data: [{ full_name: 'A B', email: 'a@b.c', phone: null }] }),
        }),
      }),
    }),
  };
  assertEquals(await loadPiiIdentity(ok, 'u1'), { fullName: 'A B', email: 'a@b.c', phone: null });
});

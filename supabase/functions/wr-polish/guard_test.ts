// Ba rào chắn của §7.2 — bản Deno.
//
// Bản Dart cùng luật có test riêng ở `test/core/logic/wr_polish_guard_test.dart`.
// Nhóm này khoá cùng bộ ca, để hai bản không lệch nhau: lệch thì cùng một câu
// được máy chủ nhận mà app từ chối, hoặc ngược lại — và không ai hiểu vì sao.
//
// Run: deno test supabase/functions/wr-polish/guard_test.ts

import { assertEquals } from 'jsr:@std/assert@1';
import {
  BANNED_WORDS,
  extractNumbers,
  numberUnitPairs,
  inspectPolished,
  POLISH_SYSTEM_PROMPT,
  sourceHash,
} from './guard.ts';

const original =
  'Bạn đã nhìn lại 21 lần trong 30 ngày qua, tăng so với 12 lần của tháng trước. Điều gì đang khiến bạn quay lại thường xuyên hơn?';

Deno.test('giữ nguyên số thì qua', () => {
  assertEquals(
    inspectPolished(
      original,
      'Trong 30 ngày qua bạn nhìn lại 21 lần, nhiều hơn 12 lần của tháng trước. Điều gì khiến bạn quay lại đều hơn vậy?',
    ),
    null,
  );
});

Deno.test('đổi một con số là huỷ', () => {
  assertEquals(
    inspectPolished(
      original,
      'Bạn đã nhìn lại 20 lần trong 30 ngày qua, tăng so với 12 lần của tháng trước. Điều gì khiến bạn quay lại đều hơn?',
    ),
    'numbers_changed',
  );
});

Deno.test('TRÁO số giữa hai đơn vị là huỷ', () => {
  // So tập hợp trần thì ca này lọt, mà "3 lần trong 14 ngày" và "14 lần trong
  // 3 ngày" nói hai điều khác hẳn.
  assertEquals(
    inspectPolished('3 lần trong 14 ngày.', '14 lần trong 3 ngày.'),
    'numbers_changed',
  );
});

Deno.test('ĐẢO MỆNH ĐỀ thì qua — đó là việc model được giao', () => {
  assertEquals(
    inspectPolished(
      'Bạn đã nhìn lại 21 lần trong 30 ngày qua.',
      'Trong 30 ngày qua, bạn đã nhìn lại 21 lần.',
    ),
    null,
  );
});

Deno.test('numberUnitPairs ghép số với đơn vị và sắp xếp', () => {
  assertEquals(numberUnitPairs('21 lần trong 30 ngày'), ['21|lần', '30|ngày']);
  assertEquals(numberUnitPairs('30 ngày, 21 lần'), ['21|lần', '30|ngày']);
});

Deno.test('đổi dấu thập phân KHÔNG phải đổi số', () => {
  assertEquals(
    inspectPolished('Bạn tự chấm 3.8 điểm.', 'Bạn tự chấm 3,8 điểm.'),
    null,
  );
});

Deno.test('extractNumbers giữ thứ tự và chuẩn hoá dấu', () => {
  assertEquals(extractNumbers('21 lần, 3,8 điểm, 30 ngày'), [
    '21',
    '3.8',
    '30',
  ]);
});

Deno.test('mỗi từ cấm đều bị bắt, kể cả viết hoa', () => {
  for (const w of BANNED_WORDS) {
    assertEquals(
      inspectPolished('Bạn ổn.', `Bạn ${w}.`),
      'banned_word',
      `từ cấm "${w}" lọt lưới`,
    );
  }
  assertEquals(inspectPolished('Bạn ổn.', 'Bạn Burnout.'), 'banned_word');
});

Deno.test('lệch độ dài quá 20% là huỷ', () => {
  assertEquals(
    inspectPolished(
      'Bạn đã nhìn lại đều hơn.',
      'Bạn đã nhìn lại đều hơn, và đó là một điều rất đáng ghi nhận trong quãng vừa rồi của bạn.',
    ),
    'length_drift',
  );
});

Deno.test('rỗng là huỷ', () => {
  assertEquals(inspectPolished(original, '   '), 'empty');
});

Deno.test('prompt chở đủ tám quy tắc của §7.1', () => {
  // Không kiểm câu chữ — kiểm rằng không quy tắc nào bị rơi khi ai đó sửa
  // prompt. §7.1 có đúng tám mục được đánh số.
  for (let i = 1; i <= 8; i++) {
    assertEquals(
      POLISH_SYSTEM_PROMPT.includes(`\n${i}. `),
      true,
      `thiếu quy tắc ${i}`,
    );
  }
});

Deno.test('băm ổn định và bỏ khoảng trắng hai đầu', async () => {
  // Khoá đệm phải KHÔNG đổi khi chỉ khác khoảng trắng, không thì cùng một câu
  // sinh hai hàng đệm và lượt gọi model thứ hai là tiền đổ đi.
  assertEquals(await sourceHash('  Một câu.  '), await sourceHash('Một câu.'));
});

Deno.test('câu khác thì băm khác', async () => {
  const a = await sourceHash('Bạn nhìn lại 21 lần.');
  const b = await sourceHash('Bạn nhìn lại 22 lần.');
  assertEquals(a === b, false);
});

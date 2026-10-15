// Run: deno test --allow-read supabase/functions/wr-experience-read/

import { assert, assertEquals } from 'jsr:@std/assert@1';
import {
  dropTrailingAlternative,
  fingerprint,
  parsePillars,
  repairMessage,
  reviewAll,
  validateAll,
  validateReading,
} from './reading.ts';

const GOOD_VI = {
  shape:
    'Hai chuyện quay lại nhiều nhất trong nhóm này đều nằm ở cùng một chỗ: lúc cần lên tiếng.',
  detail:
    'Điều bạn ghi lại không phải việc thiếu ý. Bạn có ý và đã chuẩn bị. Phần khó là ý nói ra mà không đến nơi, hoặc chưa kịp nói ra.',
  hard_part: 'Việc nói ra mà không đến nơi.',
};

Deno.test('ví dụ "Đạt" của tài liệu qua phép thử, mảnh rút gọn được chuẩn hoá', () => {
  const r = validateReading(GOOD_VI, 'vi');
  assert(r);
  assertEquals(r.hard_part, 'việc nói ra mà không đến nơi');
});

Deno.test('ví dụ "Không đạt" của tài liệu bị loại: sai khung, có câu rút lại', () => {
  assertEquals(
    validateReading(
      {
        shape: 'Mối quan hệ là nhóm bạn quay lại nhiều nhất.',
        detail:
          'Điều này cho thấy bạn đang gặp khó khăn trong giao tiếp. Tuy nhiên nó chưa nói nhóm đó đang tốt hay đang khó.',
      },
      'vi',
    ),
    null,
  );
});

Deno.test('đủ bốn khung câu hình dạng', () => {
  const detail = 'Đây không phải chuyện thiếu cố gắng. Phần khó là việc tới tay muộn.';
  for (const shape of [
    'Ba chuyện quay lại trong nhóm này đều xuất hiện ở cùng một lúc: khi vừa nhận việc.',
    'Hai chuyện quay lại trong nhóm này đều xảy ra với cùng một phía: nhóm khác.',
    'Chuyện quay lại trong nhóm này không phải việc nhiều, mà là cảm giác cạn sức.',
  ]) {
    assert(validateReading({ shape, detail }, 'vi'), shape);
  }
});

Deno.test('thiếu "Phần khó là", xưng tôi, khuyên, từ đã bỏ: đều bị loại', () => {
  const base = { ...GOOD_VI };
  assertEquals(validateReading({ ...base, detail: 'Bạn có ý và đã chuẩn bị.' }, 'vi'), null);
  assertEquals(
    validateReading({ ...base, detail: base.detail + ' Tôi thấy vậy.' }, 'vi'),
    null,
  );
  assertEquals(
    validateReading({ ...base, detail: base.detail + ' Bạn nên nói sớm hơn.' }, 'vi'),
    null,
  );
  assertEquals(
    validateReading({ ...base, detail: base.detail.replace('ghi lại', 'Reflection') }, 'vi'),
    null,
  );
});

Deno.test('quá dài thì loại', () => {
  const long = GOOD_VI.detail + ' ' + 'rất '.repeat(10).trim() + '.';
  assertEquals(validateReading({ ...GOOD_VI, detail: long }, 'vi'), null);
});

Deno.test('mảnh rút gọn hỏng chỉ bỏ mảnh đó, giữ hai câu', () => {
  const r = validateReading({ ...GOOD_VI, hard_part: 'a b c d e f g h i j k l m n' }, 'vi');
  assert(r);
  assertEquals(r.hard_part, null);
});

Deno.test('bản tiếng Anh', () => {
  const r = validateReading(
    {
      shape:
        'Two of the situations that come back most in this group sit in the same place: when you need to speak up.',
      detail:
        'This is not a lack of ideas. You had them and you prepared. The hard part is that what you say does not land.',
      hard_part: 'ideas that are said but do not land',
    },
    'en',
  );
  assert(r);
  assertEquals(
    validateReading({ shape: 'We think you avoid conflict.', detail: 'The hard part is x.' }, 'en'),
    null,
  );
});

Deno.test('chỉ giữ nhóm đủ ngưỡng §2 và nhóm đã hỏi', () => {
  const pillars = parsePillars({
    pillars: [
      // Một chuyện hai lần: chưa đủ.
      { pillar: 's', stories: [{ title: 'A', count: 2, lines: [] }] },
      // Một chuyện ba lần: đủ.
      { pillar: 'c', stories: [{ title: 'B', count: 3, lines: [{ text: 'x', date: '01/10/2026' }] }] },
      // Hai chuyện: đủ.
      {
        pillar: 'a',
        stories: [
          { title: 'C', count: 2, lines: [] },
          { title: 'D', count: 2, lines: [] },
        ],
      },
      { pillar: 'z', stories: [] },
    ],
  });
  assertEquals(pillars.map((p) => p.pillar), ['c', 'a']);
  const out = validateAll({ pillars: { c: GOOD_VI, s: GOOD_VI } }, pillars, 'vi');
  assertEquals(Object.keys(out), ['c']);
});

Deno.test('khoá nhớ đệm đổi theo nguyên liệu và ngôn ngữ', async () => {
  const p = parsePillars({
    pillars: [{ pillar: 'c', stories: [{ title: 'B', count: 3, lines: [] }] }],
  });
  const q = parsePillars({
    pillars: [{ pillar: 'c', stories: [{ title: 'B', count: 4, lines: [] }] }],
  });
  assertEquals(await fingerprint(p, 'vi'), await fingerprint(p, 'vi'));
  assert((await fingerprint(p, 'vi')) !== (await fingerprint(q, 'vi')));
  assert((await fingerprint(p, 'vi')) !== (await fingerprint(p, 'en')));
});

Deno.test('câu trả lời thật 15/10 dài 54 chữ: cắt vế "hoặc" ở đuôi thì qua', () => {
  const asked = parsePillars({
    pillars: [{ pillar: 'c', stories: [{ title: 'B', count: 3, lines: [] }] }],
  });
  const review = reviewAll(
    {
      pillars: {
        c: {
          shape:
            'Hai chuyện quay lại nhiều nhất trong nhóm này đều nằm ở cùng một chỗ: lúc cần lên tiếng.',
          detail:
            'Điều bạn ghi lại không phải việc thiếu ý. Bạn có kế hoạch và đã nói ra. Phần khó là nói ra rồi bị ngắt lời, hoặc đồng ý dù trong lòng không đồng ý.',
          hard_part: 'việc nói ra mà không đến nơi',
        },
      },
    },
    asked,
    'vi',
  );
  assertEquals(Object.keys(review.failures), []);
  assertEquals(
    review.ok.c?.detail,
    'Điều bạn ghi lại không phải việc thiếu ý. Bạn có kế hoạch và đã nói ra. Phần khó là nói ra rồi bị ngắt lời.',
  );
});

Deno.test('câu trả lời thật 15/10 lượt sửa 51 chữ (nhóm a): cắt vế "hoặc" thì qua', () => {
  const r = validateReading(
    {
      shape:
        'Năm chuyện quay lại trong nhóm này đều xuất hiện ở cùng một lúc: lúc làm xong việc mà chưa thấy kết quả.',
      detail:
        'Không phải việc lười. Bạn làm cả tuần và có báo cáo. Phần khó là làm xong mà sếp chưa đọc, hoặc ngắt lời đồng nghiệp trong họp.',
      hard_part: 'việc làm xong mà chưa được ghi nhận',
    },
    'vi',
  );
  assert(r);
  assert(r.detail.endsWith('Phần khó là làm xong mà sếp chưa đọc.'), r.detail);
});

Deno.test('cắt vế "hoặc": chỉ ở đuôi câu cuối, không cắt trơ nhịp 3', () => {
  const m = 'Phần khó là';
  assertEquals(dropTrailingAlternative('A. Phần khó là x, hoặc y. Câu khác.', m, false), null);
  assertEquals(dropTrailingAlternative('A. Phần khó là x, hoặc y.', m, false), null);
  assertEquals(dropTrailingAlternative('A. Phần khó là x y z.', m, false), null);
  assertEquals(
    dropTrailingAlternative('A. The hard part is x y, or z.', 'The hard part is', true),
    'A. The hard part is x y.',
  );
});

Deno.test('dài mà không cắt được: loại, nói rõ phải cắt bao nhiêu để xin sửa', () => {
  const asked = parsePillars({
    pillars: [{ pillar: 'c', stories: [{ title: 'B', count: 3, lines: [] }] }],
  });
  const review = reviewAll(
    {
      pillars: {
        c: {
          ...GOOD_VI,
          detail:
            'Điều bạn ghi lại không phải việc thiếu ý. Bạn có kế hoạch rất rõ và đã nói ra trong buổi họp. Phần khó là nói ra rồi bị ngắt lời giữa chừng khi chưa kịp nói xong.',
        },
      },
    },
    asked,
    'vi',
  );
  assertEquals(Object.keys(review.ok), []);
  assert(review.failures.c?.includes('chữ'), review.failures.c);
  assert(review.failures.c?.includes('cắt bớt ít nhất'), review.failures.c);
  const msg = repairMessage(review.failures, 'vi');
  assert(msg.includes('- c:'), msg);
  assert(msg.includes('cùng dạng JSON'), msg);
});

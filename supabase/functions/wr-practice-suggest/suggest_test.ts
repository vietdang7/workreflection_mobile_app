// Test lời dặn + phép thử gợi ý thực hành.
//
// Chạy: deno test supabase/functions/wr-practice-suggest/suggest_test.ts

import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { buildMessages, mergeFragments, parseIntake, parseJsonLoose, review } from './suggest.ts';

const good = {
  options: [
    { title: 'Nói ý chính trong câu đầu tiên', fit: 'Phù hợp khi bạn hay bị ngắt lời giữa chừng.', tradeoff: 'Bạn bỏ phần dẫn dắt quen thuộc.' },
    { title: 'Xin hai phút cuối buổi họp', fit: 'Phù hợp khi cuộc họp luôn kín lịch.', tradeoff: 'Bạn phải hẹn trước với người chủ trì.' },
    { title: 'Gửi ghi chú trước buổi họp', fit: 'Phù hợp khi bạn nghĩ rõ hơn khi viết.', tradeoff: 'Tốn thêm mười phút chuẩn bị.' },
  ],
  question: 'Lần này điều gì giúp bạn nói được trọn ý?',
};

Deno.test('parseIntake: thiếu ô bắt buộc thì null, ô "đã thử" trống thì null', () => {
  assertEquals(parseIntake({ title: 'A', situation: '', goal: 'C' }), null);
  assertEquals(parseIntake({ title: 'A', situation: 'B', goal: 'C', tried: '  ' })?.tried, null);
  assertEquals(parseIntake({ title: 'A', situation: 'x'.repeat(900), goal: 'C' })?.situation.length, 400);
});

Deno.test('buildMessages: có điều đã thử và luật không lặp lại, đúng ngôn ngữ', () => {
  const intake = { title: 'Lên tiếng', situation: 'Họp', goal: 'Nói rõ', tried: 'Im lặng chờ' };
  const vi = JSON.stringify(buildMessages(intake, 'vi'));
  assertStringIncludes(vi, 'Im lặng chờ');
  assertStringIncludes(vi, 'không gợi ý lại điều họ đã thử');
  assertStringIncludes(vi, 'json');
  const en = JSON.stringify(buildMessages(intake, 'en'));
  assertStringIncludes(en, 'Never suggest again');
  assertStringIncludes(en, 'json');
});

Deno.test('review: bản tốt đi qua, gạch dài và markdown bị lột', () => {
  const r = review({
    ...good,
    options: [{ ...good.options[0], title: '**Nói ý chính** — ngay câu đầu' }, ...good.options.slice(1)],
  });
  assert(r.ok);
  assertEquals(r.ok.options.length, 3);
  assertEquals(r.ok.options[0].title, 'Nói ý chính, ngay câu đầu');
  assertEquals(r.ok.question, good.question);
});

Deno.test('review: thiếu thẻ, trùng thẻ, sót PII thì không đủ ba → loại', () => {
  assertEquals(review({ options: good.options.slice(0, 2), question: 'x?' }).ok, null);
  assertEquals(review({ options: [good.options[0], good.options[0], good.options[1]] }).ok, null);
  const leak = { ...good.options[2], fit: 'Phù hợp khi bạn gọi 0912345678.' };
  assertEquals(review({ options: [good.options[0], good.options[1], leak] }).ok, null);
});

Deno.test('review: câu hỏi hỏng không kéo cả bản xuống', () => {
  const r = review({ ...good, question: 'Không phải câu hỏi.' });
  assert(r.ok);
  assertEquals(r.ok.question, '');
});

Deno.test('parseJsonLoose: bọc ``` hoặc có lời dẫn vẫn đọc được', () => {
  assertEquals((parseJsonLoose('```json\n{"a":1}\n```') as { a: number }).a, 1);
  assertEquals((parseJsonLoose('Đây: {"a":2} nhé') as { a: number }).a, 2);
  assertEquals(parseJsonLoose('không có json'), null);
});

Deno.test('review: mỗi cách bị tách làm hai object (DeepSeek 20/10) vẫn gộp lại được', () => {
  // Nguyên văn khuôn sai của lần chạy thật 20/10/2026.
  const r = review({
    options: [
      { title: 'Đặt câu hỏi làm rõ rủi ro', fit: 'Phù hợp khi bạn muốn nêu lo ngại mà không đối đầu trực diện.' },
      { tradeoff: 'Bạn phải chấp nhận cuộc họp kéo dài thêm vài phút.' },
      { title: 'Chuẩn bị sẵn một câu phản biện', fit: 'Phù hợp khi bạn biết trước kế hoạch sẽ được chốt trong họp.' },
      { tradeoff: 'Bạn phải dành thời gian chuẩn bị trước mỗi cuộc họp.' },
      { title: 'Xin một phút trao đổi cuối họp', fit: 'Phù hợp khi bạn cần thời gian ngắn để sắp xếp ý.' },
      { tradeoff: 'Bạn có thể bị xem là người làm chậm tiến độ cuộc họp.' },
    ],
    question: 'Điều gì khiến bạn im lặng lúc đó?',
  });
  assert(r.ok);
  assertEquals(r.ok.options.map((o) => o.title), [
    'Đặt câu hỏi làm rõ rủi ro',
    'Chuẩn bị sẵn một câu phản biện',
    'Xin một phút trao đổi cuối họp',
  ]);
  assertEquals(r.ok.options[2].tradeoff, 'Bạn có thể bị xem là người làm chậm tiến độ cuộc họp.');
});

Deno.test('mergeFragments: không gộp hai cách khác nhau vào một', () => {
  const m = mergeFragments([
    { title: 'A', fit: 'f' },
    { title: 'B', fit: 'g', tradeoff: 't' },
  ]);
  assertEquals(m.length, 2);
  assertEquals(m[0].tradeoff, undefined);
});

Deno.test('lời dặn có mẫu CÓ CHỮ đủ ba khoá; phép thử nói rõ khoá nào thiếu', () => {
  const vi = (buildMessages({ title: 'a', situation: 'b', goal: 'c', tried: null }, 'vi') as {
    content: string;
  }[])[0].content;
  assertStringIncludes(vi, '"tradeoff":"Bạn mất thêm một phút');
  const r = review({
    options: [{ title: 'A', fit: 'f' }, { title: 'B', fit: 'g' }, { title: 'C', fit: 'h' }],
  });
  assertEquals(r.ok, null);
  assertStringIncludes(r.reason ?? '', 'thiếu tradeoff');
});

// Test lời dặn + phép thử gợi ý thực hành.
//
// Chạy: deno test supabase/functions/wr-practice-suggest/suggest_test.ts

import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { buildMessages, parseIntake, parseJsonLoose, review } from './suggest.ts';

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

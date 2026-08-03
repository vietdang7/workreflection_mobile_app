// Test cho lớp nắn câu trả lời.
//
// Chạy: deno test supabase/functions/wr-chat/reply_shaping_test.ts
//
// Đây là lớp phòng thủ cuối trước khi chữ tới mắt người dùng. Một lỗi ở đây
// không làm sập gì cả, nó chỉ lặng lẽ đẩy `[[ACTION:calm]]` hoặc `**đậm**` lên
// màn hình. Nên phải có test.

import { assertEquals } from 'jsr:@std/assert@1';
import {
  conversationTitle,
  shapeReply,
  stripMarkdown,
} from './reply_shaping.ts';

// ---------------------------------------------------------------------------
// Thẻ hành động
// ---------------------------------------------------------------------------

Deno.test('bắt thẻ reflect và gỡ khỏi câu chữ', () => {
  const r = shapeReply(
    'Muốn ghi lại thành một Reflection không?\n[[ACTION:reflect]]',
  );

  assertEquals(r.action, 'reflect');
  assertEquals(r.text, 'Muốn ghi lại thành một Reflection không?');
});

Deno.test('bắt thẻ calm', () => {
  const r = shapeReply('Mình có một bài ngắn giúp bạn dịu lại.\n[[ACTION:calm]]');

  assertEquals(r.action, 'calm');
  assertEquals(r.text.includes('ACTION'), false);
});

Deno.test('thẻ đặt GIỮA bài vẫn bị gỡ sạch', () => {
  // Prompt bảo đặt ở dòng cuối, nhưng model không phải lúc nào cũng nghe. Neo
  // vào cuối chuỗi thì một lần đặt sai chỗ là người dùng đọc thấy nguyên thẻ.
  const r = shapeReply('Câu đầu. [[ACTION:reflect]] Câu sau.');

  assertEquals(r.action, 'reflect');
  assertEquals(r.text.includes('[['), false);
});

Deno.test('hai thẻ thì lấy cái đầu, không hiện hai nút mâu thuẫn', () => {
  const r = shapeReply('Abc [[ACTION:reflect]] def [[ACTION:calm]]');

  assertEquals(r.action, 'reflect');
  assertEquals(r.text.includes('ACTION'), false);
});

Deno.test('không có thẻ thì không có nút', () => {
  assertEquals(shapeReply('Bạn kể thêm được không?').action, null);
});

// ---------------------------------------------------------------------------
// Luật an toàn — mục 8
// ---------------------------------------------------------------------------

Deno.test('nhánh đáng lo ngại QUÊN thẻ thì tự ép nút dịu lại', () => {
  // Bước 3 của mục 8 buộc phải đề nghị Thư viện Nội dung Cảm xúc. Lượt này xảy
  // ra đúng lúc người dùng đang tệ nhất; đề nghị giúp rồi không mở được gì là
  // điều tệ nhất ta có thể làm.
  const r = shapeReply(
    'Cảm ơn bạn đã nói điều này. Mình là trợ lý đồng hành về công việc, '
      + 'không phải chuyên gia tâm lý, nên mình không phải nơi tốt nhất. '
      + 'Nếu có người bạn tin tưởng, hãy tìm đến họ ngay bây giờ.',
  );

  assertEquals(r.action, 'calm');
});

Deno.test('trò chuyện thường không bị ép nút', () => {
  const r = shapeReply('Nghe quen thuộc đấy. Điều gì khiến bạn chọn im lặng?');

  assertEquals(r.action, null);
});

Deno.test('nhánh đáng lo ngại CÓ thẻ rồi thì giữ nguyên thẻ đó', () => {
  const r = shapeReply(
    'Mình không phải chuyên gia tâm lý. [[ACTION:calm]]',
  );

  assertEquals(r.action, 'calm');
});

// ---------------------------------------------------------------------------
// Markdown
// ---------------------------------------------------------------------------

Deno.test('lột in đậm', () => {
  assertEquals(
    stripMarkdown('quanh nhu cầu **Rõ ràng**, đặc biệt'),
    'quanh nhu cầu Rõ ràng, đặc biệt',
  );
});

Deno.test('lột in nghiêng mà không đụng dấu sao lẻ', () => {
  assertEquals(stripMarkdown('một *chút* thôi'), 'một chút thôi');
  // Dấu sao đứng một mình giữa câu không phải cú pháp Markdown.
  assertEquals(stripMarkdown('2 * 3 = 6'), '2 * 3 = 6');
});

Deno.test('đậm-nghiêng ba sao không rơi lại thành một lớp sao', () => {
  assertEquals(stripMarkdown('***rất*** quan trọng'), 'rất quan trọng');
});

Deno.test('lột tiêu đề và gạch đầu dòng, giữ nguyên chữ', () => {
  assertEquals(
    stripMarkdown('## Nhận xét\n- điều một\n- điều hai'),
    'Nhận xét\nđiều một\nđiều hai',
  );
});

Deno.test('lột liên kết, giữ chữ và bỏ đường dẫn', () => {
  assertEquals(
    stripMarkdown('xem [Thư viện](https://example.com) nhé'),
    'xem Thư viện nhé',
  );
});

Deno.test('gạch dưới trong tên biến KHÔNG bị đụng vào', () => {
  // Chữ người dùng dán vào phải nguyên vẹn. Đánh đổi có chủ đích: `__đậm__` sẽ
  // lọt, nhưng model viết đậm bằng `**` chứ không dùng `__`. Xem chú thích
  // trong `stripMarkdown`.
  assertEquals(stripMarkdown('cột __init__ của tôi'), 'cột __init__ của tôi');
});

Deno.test('chữ thuần đi qua nguyên vẹn', () => {
  const s = 'Nghe quen thuộc đấy. Bạn có nhớ điều gì khiến bạn chọn im lặng không?';
  assertEquals(stripMarkdown(s), s);
});

// ---------------------------------------------------------------------------
// Tiêu đề cuộc trò chuyện
// ---------------------------------------------------------------------------

Deno.test('câu ngắn thì giữ nguyên làm tiêu đề', () => {
  assertEquals(conversationTitle('Hôm nay mình mệt'), 'Hôm nay mình mệt');
});

Deno.test('câu dài cắt ở ranh giới TỪ, không cắt giữa chữ', () => {
  const t = conversationTitle(
    'Hôm nay mình bị sếp nhắc trước cả phòng và mình thấy rất tệ về chuyện đó',
    40,
  );

  assertEquals(t.endsWith('…'), true);
  assertEquals(t.length <= 41, true);
  // Cắt giữa chữ sẽ để lại một từ tiếng Việt cụt ngay trước dấu ba chấm.
  assertEquals(t.slice(0, -1).trim().split(' ').pop()!.length > 1, true);
});

Deno.test('gộp khoảng trắng thừa và xuống dòng trong tiêu đề', () => {
  assertEquals(conversationTitle('  Hôm  nay\n\nmình mệt  '), 'Hôm nay mình mệt');
});

// ---------------------------------------------------------------------------
// Lời mời dịu lại ở những lượt nhẹ hơn mục 8
// ---------------------------------------------------------------------------

Deno.test('mời đọc gì đó cho dịu lại mà quên thẻ thì vẫn có nút', () => {
  const r = shapeReply(
    'Mình nghe bạn nói vậy cũng thấy nặng lòng. Bạn có muốn thử một bài đọc '
      + 'ngắn để dịu lại một chút không?',
  );
  assertEquals(r.action, 'calm');
});

Deno.test('nhắc ngang qua một bài đọc thì KHÔNG ép nút', () => {
  // Ép nhầm hại hơn thiếu: nút hiện sai chỗ dạy người dùng rằng nút là vô nghĩa.
  const r = shapeReply(
    'Hôm trước bạn có kể là đã nghe một bài đọc và thấy đỡ hơn. Điều gì trong '
      + 'đó khiến bạn thấy nhẹ đi vậy?',
  );
  assertEquals(r.action, null);
});

Deno.test('nhánh mục 8 vẫn thắng, không bị luật nhẹ hơn ghi đè', () => {
  const r = shapeReply(
    'Mình là trợ lý đồng hành sự nghiệp, không phải chuyên gia tâm lý. Nếu có '
      + 'người bạn tin tưởng, hãy tìm đến họ ngay bây giờ nhé.',
  );
  assertEquals(r.action, 'calm');
});

Deno.test('thẻ model tự đặt luôn thắng luật đoán', () => {
  const r = shapeReply(
    'Bạn có muốn thử một bài đọc ngắn không? [[ACTION:reflect]]',
  );
  assertEquals(r.action, 'reflect');
});

Deno.test('mời dạng trần thuật, gọi tên thư viện, cũng phải có nút', () => {
  const r = shapeReply(
    'Mình nghe rồi, cảm giác đó nặng thật. Có một bài đọc hoặc audio ngắn '
      + 'trong Thư viện Nội dung Cảm xúc có thể giúp bạn dịu lại một chút.',
  );
  assertEquals(r.action, 'calm');
});

Deno.test('từ chối jailbreak có câu minh bạch KHÔNG bị ép nút dịu lại', () => {
  // Mục 4.9 cho phép nhắc "mình không phải chuyên gia tâm lý" ở bất kỳ lượt nào.
  // Chỉ riêng câu đó không phải nhánh mục 8, và hiện nút dịu lại ngay sau một
  // lượt từ chối nghịch prompt làm nút mất nghĩa.
  const r = shapeReply(
    'Mình là trợ lý phản chiếu của WorkReflection. Mình không phải chuyên gia '
      + 'tâm lý hay tư vấn nghề nghiệp, chỉ là một người bạn đồng hành biết lắng '
      + 'nghe. Hôm nay có điều gì bạn muốn nhìn lại không?',
  );
  assertEquals(r.action, null);
});

Deno.test('nhánh mục 8 thật có đủ hai dấu hiệu thì vẫn được ép nút', () => {
  const r = shapeReply(
    'Cảm ơn bạn đã nói điều này với mình. Mình là trợ lý đồng hành sự nghiệp, '
      + 'không phải chuyên gia tâm lý, nên mình không phải nơi tốt nhất để bạn '
      + 'đi qua cảm giác này. Nếu có người thân hay bạn bè bạn tin tưởng, hãy '
      + 'tìm đến họ ngay bây giờ nhé.',
  );
  assertEquals(r.action, 'calm');
});

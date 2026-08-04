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
// Luật an toàn — nhánh tín hiệu đáng lo ngại
// ---------------------------------------------------------------------------

Deno.test('nhánh đáng lo ngại QUÊN thẻ thì tự ép nút dịu lại', () => {
  // Bước 3 của phần "Xử lý tín hiệu đáng lo ngại" buộc phải đề nghị Thư viện Nội dung Cảm xúc. Lượt này xảy
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
// Lời mời dịu lại ở những lượt nhẹ hơn nhánh tín hiệu đáng lo ngại
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

Deno.test('nhánh tín hiệu đáng lo ngại vẫn thắng, không bị luật nhẹ hơn ghi đè', () => {
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
  // Nguyên tắc 11 "minh bạch về bản thân" cho phép nhắc "mình không phải chuyên gia tâm lý" ở bất kỳ lượt nào.
  // Chỉ riêng câu đó không phải nhánh tín hiệu đáng lo ngại, và hiện nút dịu lại ngay sau một
  // lượt từ chối nghịch prompt làm nút mất nghĩa.
  const r = shapeReply(
    'Mình là trợ lý phản chiếu của WorkReflection. Mình không phải chuyên gia '
      + 'tâm lý hay tư vấn nghề nghiệp, chỉ là một người bạn đồng hành biết lắng '
      + 'nghe. Hôm nay có điều gì bạn muốn nhìn lại không?',
  );
  assertEquals(r.action, null);
});

Deno.test('nhánh tín hiệu đáng lo ngại thật có đủ hai dấu hiệu thì vẫn được ép nút', () => {
  const r = shapeReply(
    'Cảm ơn bạn đã nói điều này với mình. Mình là trợ lý đồng hành sự nghiệp, '
      + 'không phải chuyên gia tâm lý, nên mình không phải nơi tốt nhất để bạn '
      + 'đi qua cảm giác này. Nếu có người thân hay bạn bè bạn tin tưởng, hãy '
      + 'tìm đến họ ngay bây giờ nhé.',
  );
  assertEquals(r.action, 'calm');
});

// ---------------------------------------------------------------------------
// Chỉ vào nút thì nút phải có thật
// ---------------------------------------------------------------------------

Deno.test('nhắc tới nút mở luồng mà quên thẻ thì vẫn hiện nút', () => {
  // Khách gặp 2026-08-03: trợ lý bảo "bấm vào đó" mà dưới bong bóng trống trơn.
  const r = shapeReply(
    'Nút mở luồng Reflection đang hiện ngay dưới đây, bạn bấm vào đó để bắt đầu nhé.',
  );
  assertEquals(r.action, 'reflect');
});

Deno.test('gỡ thẻ giữa câu không để lại khoảng trắng đôi', () => {
  const r = shapeReply('Bạn bấm vào nút [[ACTION:reflect]] ở ngay dưới nhé.');
  assertEquals(r.text.includes('  '), false);
  assertEquals(r.text, 'Bạn bấm vào nút ở ngay dưới nhé.');
  assertEquals(r.action, 'reflect');
});

Deno.test('câu thường không nhắc nút thì KHÔNG ép nút reflect', () => {
  const r = shapeReply(
    'Nghe quen thuộc đấy. Bạn có nhớ điều gì khiến bạn chọn im lặng lúc đó không?',
  );
  assertEquals(r.action, null);
});

Deno.test('nhánh tín hiệu đáng lo ngại vẫn thắng luật chỉ-vào-nút', () => {
  const r = shapeReply(
    'Mình không phải chuyên gia tâm lý. Hãy tìm đến một người thân bạn tin '
      + 'tưởng ngay bây giờ nhé. Bạn bấm vào đó nếu muốn đọc một chút.',
  );
  assertEquals(r.action, 'calm');
});

// ---------------------------------------------------------------------------
// Đối chiếu từng mẫu của tài liệu Conversation Examples
//
// VÌ SAO CÓ NHÓM NÀY: bộ ví dụ mẫu là thứ đội nội dung sửa thường xuyên nhất, và
// nó cũng là thứ được nạp thẳng vào prompt làm few-shot. Nếu một mẫu ở đó viết
// lệch khỏi các cụm mà lưới an toàn dưới đây dò, thì mô hình sẽ học đúng cách
// viết lọt lưới, và lượt đó ra màn hình không có nút nào.
//
// Rà tay ngày 2026-08-04 phát hiện ba mẫu như vậy, đều nằm ở nhóm nhạy cảm
// nhất. Các test dưới đây chép NGUYÊN VĂN câu chữ của tài liệu sau khi sửa, để
// lần sau ai đổi chữ mà làm thủng lưới thì test đỏ ngay, không phải chờ người
// dùng thật gặp.
// ---------------------------------------------------------------------------

Deno.test('mẫu 6.1 tín hiệu rõ ràng: tự bật nút calm dù thiếu thẻ', () => {
  const r = shapeReply(
    'Cảm ơn bạn đã nói điều này với mình. Nghe có vẻ bạn đang mang một điều khá '
      + 'nặng. Mình là trợ lý đồng hành về công việc và sự nghiệp, không phải '
      + 'chuyên gia tâm lý, nên mình không phải là nơi tốt nhất để cùng bạn đi '
      + 'qua cảm giác này một mình. Nếu có một người bạn tin tưởng, người thân, '
      + 'hoặc một chuyên gia tâm lý bạn có thể tìm đến ngay bây giờ, đó sẽ là '
      + 'điều tốt nhất lúc này. Trong lúc đó, nếu muốn, mình có một bài đọc ngắn '
      + 'có thể giúp bạn dịu lại một chút.',
  );
  assertEquals(r.action, 'calm');
});

Deno.test('mẫu 6.2 ẩn dụ: bản CŨ lọt lưới, bản MỚI thì không', () => {
  // Bản cũ của tài liệu. Hai chỗ lệch cộng lại làm nó trượt: viết "ngay lúc
  // này" thay vì "ngay bây giờ", và mệnh đề phụ đẩy khoảng cách vượt cửa sổ cũ.
  // Giữ lại đây làm bằng chứng vì sao regex phải nới, chứ không phải để ai đó
  // dùng lại câu này.
  const cu = 'Cảm ơn bạn đã chia sẻ điều này. Nghe như bạn đang rất mệt và muốn '
    + 'thoát khỏi tất cả. Mình là trợ lý đồng hành về công việc, không phải '
    + 'chuyên gia tâm lý, nên nếu có ai đó bạn tin tưởng có thể nói chuyện ngay '
    + 'lúc này, mình mong bạn tìm đến họ. Mình vẫn ở đây nếu bạn muốn nói tiếp.';
  assertEquals(shapeReply(cu).action, 'calm');

  // Bản đã sửa: đủ ba phần, gọi tên bài đọc, dùng đúng cụm "ngay bây giờ".
  const moi = 'Cảm ơn bạn đã chia sẻ điều này. Nghe như bạn đang rất mệt và muốn '
    + 'thoát khỏi tất cả. Mình là trợ lý đồng hành về công việc, không phải '
    + 'chuyên gia tâm lý, nên nếu có người thân hay một người bạn tin tưởng mà '
    + 'bạn tìm đến được ngay bây giờ, mình mong bạn làm điều đó. Trong lúc đó '
    + 'mình có một bài đọc ngắn có thể giúp bạn dịu lại, và mình vẫn ở đây nếu '
    + 'bạn muốn nói tiếp.';
  assertEquals(shapeReply(moi).action, 'calm');
});

Deno.test('mẫu 6.3 mệt mỏi thường: lời mời mơ hồ vẫn phải mở được nút', () => {
  // Bản cũ nói "vài điều nhẹ nhàng", không có danh từ nội dung nào cụ thể.
  const cu = 'Nghe như dạo này khá nặng nề với bạn. Mình có vài điều nhẹ nhàng '
    + 'có thể giúp bạn dịu lại một chút, muốn xem không?';
  assertEquals(shapeReply(cu).action, 'calm');

  const moi = 'Nghe như dạo này khá nặng nề với bạn. Mình có một bài đọc ngắn '
    + 'có thể giúp bạn dịu lại một chút, muốn thử không?';
  assertEquals(shapeReply(moi).action, 'calm');
});

Deno.test('mẫu 4.5 chủ động muốn ghi: cả hai lối diễn đạt đều mở được nút', () => {
  // Bản cũ: trợ lý nói như thể tự mở được màn hình. Sai về bản chất, và không
  // chứa chữ "nút" nên bản regex cũ cũng không đỡ được.
  const cu = 'Được, mình mở luồng Reflection cho bạn ngay. Chỉ khoảng một phút thôi.';
  assertEquals(shapeReply(cu).action, 'reflect');

  const moi = 'Được. Nút mở luồng Reflection đang ở ngay dưới câu này, bạn bấm '
    + 'vào đó nhé, chỉ khoảng một phút thôi.';
  assertEquals(shapeReply(moi).action, 'reflect');
});

Deno.test('mẫu 4.6 họ đồng ý: chỉ vào nút, không tự chạy luồng', () => {
  const r = shapeReply('Được, nút mở luồng đang ở ngay dưới đây nhé.\n[[ACTION:reflect]]');
  assertEquals(r.action, 'reflect');
  assertEquals(r.text, 'Được, nút mở luồng đang ở ngay dưới đây nhé.');
});

Deno.test('nới regex KHÔNG làm lượt từ chối jailbreak bật nút nhầm', () => {
  // Đây là lý do bản đầu phải đòi HAI dấu hiệu. Nới cửa sổ lên 90 ký tự và nhận
  // thêm "lúc này" có nguy cơ kéo lại đúng lỗi cũ, nên khoá nó bằng test.
  const r = shapeReply(
    'Mình không phải chuyên gia tâm lý hay tư vấn nghề nghiệp, mình chỉ là một '
      + 'người bạn đồng hành biết lắng nghe thôi. Hôm nay có điều gì bạn muốn '
      + 'nhìn lại không?',
  );
  assertEquals(r.action, null);
});

Deno.test('nhắc ngang qua một bài đọc thì KHÔNG bật nút', () => {
  const r = shapeReply(
    'Hôm trước bạn có nghe một bài rồi đúng không. Hôm nay thì sao?',
  );
  assertEquals(r.action, null);
});

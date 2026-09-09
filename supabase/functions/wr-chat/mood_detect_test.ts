// Test cho `mood_detect.ts`.
//
// Chạy: deno test --allow-none supabase/functions/wr-chat/mood_detect_test.ts

import { assertEquals } from 'jsr:@std/assert';
import { detectMood } from './mood_detect.ts';

// ── Ca khách gặp 2026-09-09 ───────────────────────────────────────────────

Deno.test('câu khách gõ thật: "khá là căng thẳng"', () => {
  assertEquals(detectMood(['khá là căng thẳng']), 'stressed');
});

Deno.test('nhận ra cảm xúc từ lượt TRƯỚC, không chỉ lượt vừa gõ', () => {
  // Đúng hình dạng cuộc trò chuyện trong ảnh khách gửi: họ nói cảm xúc ở một
  // lượt, trợ lý an ủi, rồi họ mới gõ tiếp một câu trung tính và bấm nút.
  assertEquals(
    detectMood(['ừ', 'khá là căng thẳng', 'hi']),
    'stressed',
  );
});

Deno.test('lượt GẦN NHẤT thắng lượt cũ', () => {
  // Cảm giác đổi trong một cuộc trò chuyện. Câu mới là câu đúng lúc này.
  assertEquals(
    detectMood(['giờ thì mình mệt rã rời', 'lúc nãy mình khá căng thẳng']),
    'tired',
  );
});

// ── Sáu nhóm ──────────────────────────────────────────────────────────────

Deno.test('đủ sáu cảm xúc', () => {
  assertEquals(detectMood(['deadline dí quá trời']), 'stressed');
  assertEquals(detectMood(['mình kiệt sức rồi']), 'tired');
  assertEquals(detectMood(['mọi thứ còn mông lung lắm']), 'foggy');
  assertEquals(detectMood(['team mình lệch nhau hoài']), 'outofsync');
  assertEquals(detectMood(['hôm nay cũng bình thường thôi']), 'okay');
  assertEquals(detectMood(['hôm nay mình vui lắm']), 'happy');
});

// ── Không đoán bừa ────────────────────────────────────────────────────────

Deno.test('không có tín hiệu nào thì trả null', () => {
  // Trả null để app quay về bày cả sáu nhóm. Đoán bừa một nhóm là giấu mất năm
  // nhóm còn lại của một người mà ta không hiểu đang thế nào.
  assertEquals(detectMood(['hi']), null);
  assertEquals(detectMood(['báo cáo quý này nộp ngày nào vậy?']), null);
  assertEquals(detectMood([]), null);
  assertEquals(detectMood(['']), null);
});

Deno.test('phủ định không tính là có cảm xúc đó', () => {
  assertEquals(detectMood(['mình không căng thẳng đâu']), null);
  assertEquals(detectMood(['hôm nay đỡ mệt rồi']), null);
  assertEquals(detectMood(['chưa thấy mệt gì cả']), null);
  assertEquals(detectMood(['mình không còn vui như trước']), null);
});

Deno.test('phủ định NẰM TRONG từ khoá vẫn tính', () => {
  // "không rõ" là chính từ khoá của `foggy`, không phải một cái phủ định.
  assertEquals(detectMood(['mình không rõ nên làm gì tiếp']), 'foggy');
  assertEquals(detectMood(['tụi mình không ăn khớp gì cả']), 'outofsync');
});

// ── Luật phân định ────────────────────────────────────────────────────────

Deno.test('nhóm khó thắng nhóm tích cực khi cùng điểm', () => {
  // Mở thư viện ở nhóm "Khá ổn" cho người vừa nói mình căng thẳng là đọc sai họ.
  assertEquals(
    detectMood(['công việc vẫn ổn nhưng mình khá căng thẳng']),
    'stressed',
  );
});

Deno.test('nhiều từ khoá cùng nhóm thì nhóm đó thắng', () => {
  assertEquals(
    detectMood(['mình mệt rã rời, uể oải, mà việc thì vẫn ổn']),
    'tired',
  );
});

// ── Lời trợ lý chỉ là phương án dự phòng ──────────────────────────────────

Deno.test('đọc lời trợ lý khi người dùng không nói ra cảm xúc', () => {
  assertEquals(
    detectMood(
      ['ừ'],
      'Nghe có vẻ bạn đang trải qua những ngày khá áp lực.',
    ),
    'stressed',
  );
});

Deno.test('lời NGƯỜI DÙNG luôn thắng lời trợ lý', () => {
  assertEquals(
    detectMood(
      ['mình mệt quá'],
      'Nghe có vẻ bạn đang trải qua những ngày khá áp lực.',
    ),
    'tired',
  );
});

Deno.test('KHÔNG lấy nhóm tích cực từ lời trợ lý', () => {
  // Trợ lý viết "để bạn thoải mái hơn" là điều nó CHÚC, không phải điều người
  // dùng đang thấy. Mở thư viện ở nhóm "Đang vui" cho một người vừa kể chuyện
  // tệ là hiểu ngược hẳn.
  assertEquals(
    detectMood(
      ['ừ'],
      'Mình có vài điều nhẹ nhàng, mong bạn thấy thoải mái hơn một chút.',
    ),
    null,
  );
});

Deno.test('chữ hoa chữ thường không ảnh hưởng', () => {
  assertEquals(detectMood(['MÌNH ĐANG RẤT CĂNG THẲNG']), 'stressed');
});

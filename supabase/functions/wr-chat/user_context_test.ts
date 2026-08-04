// Test cho mốc thời gian trong ngữ cảnh trò chuyện.
//
// Chạy: deno test supabase/functions/wr-chat/user_context_test.ts
//
// File này KHÔNG được index.ts import nên nó không đi vào bản deploy.
//
// Vì sao đáng test riêng: `monthlyBuckets` chia theo giờ Việt Nam, và ranh giới
// múi giờ là loại lỗi không kêu. Một lần nhìn lại lúc 0 giờ 30 ngày mùng 1 tính
// theo UTC sẽ rơi vào tháng trước, con số lệch đi một, và không ai nhận ra cho
// tới khi người dùng nói "tháng này tôi ghi 5 lần mà sao nó bảo 4".

import { assertEquals } from 'jsr:@std/assert@1';
import { monthlyBuckets } from './user_context.ts';

/// Dựng một Episode ở đúng thời điểm cho trước.
function ep(iso: string, need: string | null = null) {
  return { situation_code: null, human_need: need, opened_at: iso };
}

/// ISO của "n tháng trước, ngày 15, 12 giờ trưa giờ VN" — xa mọi ranh giới.
function monthsAgo(n: number): string {
  const d = new Date();
  d.setMonth(d.getMonth() - n);
  d.setDate(15);
  d.setHours(12, 0, 0, 0);
  return d.toISOString();
}

Deno.test('gom đúng số lần theo từng tháng, mới nhất trước', () => {
  const buckets = monthlyBuckets([
    ep(monthsAgo(0)),
    ep(monthsAgo(0)),
    ep(monthsAgo(1)),
  ]);

  assertEquals(buckets.length, 2);
  assertEquals(buckets[0].count, 2);
  assertEquals(buckets[1].count, 1);
});

Deno.test('tháng không có lần nào thì BỎ HẲN, không hiện 0 lần', () => {
  // Một tháng trống thường là tháng người ta bận hoặc đang ổn. Bày ra thành số
  // 0 là mời model diễn giải một khoảng lặng thành thất bại.
  const buckets = monthlyBuckets([ep(monthsAgo(0)), ep(monthsAgo(2))]);

  assertEquals(buckets.length, 2);
  assertEquals(buckets.every((b) => b.count > 0), true);
});

Deno.test('bỏ qua dữ liệu cũ hơn cửa sổ sáu tháng', () => {
  const buckets = monthlyBuckets([ep(monthsAgo(0)), ep(monthsAgo(11))]);

  assertEquals(buckets.length, 1);
});

Deno.test('nửa đêm mùng 1 giờ VN thuộc về tháng MỚI, không phải tháng trước', () => {
  // 00:30 ngày 01/08 giờ VN = 17:30 ngày 31/07 UTC. Tính theo UTC thì lần này
  // rơi nhầm sang tháng 7.
  const buckets = monthlyBuckets([ep('2026-07-31T17:30:00Z')]);

  assertEquals(buckets.length, 1);
  assertEquals(buckets[0].label, 'Tháng 08/2026');
});

Deno.test('nhu cầu chủ đạo tính riêng cho từng tháng', () => {
  const buckets = monthlyBuckets([
    ep(monthsAgo(0), 'ro_rang'),
    ep(monthsAgo(0), 'ro_rang'),
    ep(monthsAgo(0), 'ket_noi'),
    ep(monthsAgo(1), 'thich_nghi'),
  ]);

  assertEquals(buckets[0].topNeed, 'Rõ ràng');
  assertEquals(buckets[1].topNeed, 'Thích nghi');
});

Deno.test('không có nhu cầu nào thì để trống, không bịa', () => {
  const buckets = monthlyBuckets([ep(monthsAgo(0))]);

  assertEquals(buckets[0].topNeed, null);
});

Deno.test('opened_at rỗng hoặc hỏng thì bỏ qua, không làm sập', () => {
  const buckets = monthlyBuckets([
    ep(monthsAgo(0)),
    { situation_code: null, human_need: null, opened_at: null },
    ep('không phải ngày tháng gì cả'),
  ]);

  assertEquals(buckets.length, 1);
  assertEquals(buckets[0].count, 1);
});

Deno.test('không có Episode nào thì trả về danh sách rỗng', () => {
  assertEquals(monthlyBuckets([]).length, 0);
});

// ---------------------------------------------------------------------------
// Ranh giới Free / Premium trong chính khối ngữ cảnh
//
// VÌ SAO CÓ NHÓM NÀY: chạy A/B thật 2026-08-03 phát hiện người dùng Free nhận
// được trọn bản phân tích xu hướng theo thời gian, thứ mục 7 xếp vào trục trí
// tuệ. Lúc đó cả hai gói cùng nhận một khối dữ liệu và ranh giới chỉ là một dòng
// dặn dò trong prompt; model đọc thấy số liệu thì nó đọc ra.
//
// Đây là loại lỗi KHÔNG kêu: không có ngoại lệ, không có test đỏ, chỉ có phần
// đang bán bị phát không. Nên phải khoá bằng test, không thể tin vào việc đọc lại
// prompt mỗi lần sửa.
// ---------------------------------------------------------------------------

/// Fake Supabase client tối thiểu: mọi phương thức lọc đều trả về chính nó, và
/// bản thân đối tượng `await` được, trả `{ data }` theo tên bảng.
function fakeDb(rows: Record<string, unknown[]>) {
  const builder = (table: string) => {
    const self: Record<string, unknown> = {};
    for (const m of ['select', 'eq', 'in', 'is', 'order', 'limit']) {
      self[m] = () => self;
    }
    self.then = (
      resolve: (v: { data: unknown[] }) => unknown,
    ) => resolve({ data: rows[table] ?? [] });
    return self;
  };
  // deno-lint-ignore no-explicit-any
  return { from: (t: string) => builder(t) } as any;
}

const ISO_NOW = new Date().toISOString();

const ROWS = {
  wr_reflection_episodes: [
    { situation_code: 'S1', human_need: 'ket_noi', opened_at: ISO_NOW },
    { situation_code: 'S1', human_need: 'ket_noi', opened_at: ISO_NOW },
  ],
  wr_situations: [{ code: 'S1', text: 'Im lặng trong cuộc họp' }],
};

Deno.test('gói miễn phí KHÔNG thấy mốc thời gian theo tháng', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(ROWS), 'u1', false);

  assertEquals(ctx.includes('theo tháng'), false);
  // Nhãn tháng cũng không được lọt qua đường nào khác.
  assertEquals(/Tháng \d{2}\/\d{4}/.test(ctx), false);
});

Deno.test('gói Premium CÓ mốc thời gian theo tháng', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(ROWS), 'u1', true);

  assertEquals(ctx.includes('theo tháng'), true);
  assertEquals(/Tháng \d{2}\/\d{4}/.test(ctx), true);
});

Deno.test('gói miễn phí vẫn thấy tình huống lặp lại, chỉ mất phần diễn giải', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(ROWS), 'u1', false);

  // Mục 3: đếm đơn giản là phần MIỄN PHÍ, ai cũng thấy. Gác quá tay ở đây sẽ
  // biến trợ lý thành người không biết gì về người đang nói chuyện với nó.
  assertEquals(ctx.includes('Im lặng trong cuộc họp'), true);
  assertEquals(ctx.includes('gói MIỄN PHÍ'), true);
});

Deno.test('chưa có dữ liệu thì cả hai gói đều rơi về luật cấm suy diễn', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  for (const premium of [false, true]) {
    const ctx = await buildUserContext(fakeDb({}), 'u1', premium);
    assertEquals(ctx.includes('CHƯA có dữ liệu nào'), true);
  }
});

// ---------------------------------------------------------------------------
// Bài tự đánh giá — ranh giới đi ngay GIỮA một bảng điểm
//
// Mục 7 xếp "kết quả tổng quan (không diễn giải sâu)" vào trục hành động (Free
// có quyền) nhưng "diễn giải sâu kết quả Self-Check" vào trục trí tuệ (Premium).
// Nên ở đây CẢ HAI gói đều thấy điểm, khác nhau ở luật kèm theo — không giống
// mốc tháng vốn cắt hẳn khỏi khối của Free.
// ---------------------------------------------------------------------------

const SELF_CHECK_ROWS = {
  wr_reflection_episodes: [
    { situation_code: 'S1', human_need: 'ket_noi', opened_at: ISO_NOW },
  ],
  wr_situations: [{ code: 'S1', text: 'Im lặng trong cuộc họp' }],
  wr_sca_self_check_responses: [
    {
      structure_score: 4.4,
      culture_score: 2.6,
      activity_score: 3.6,
      taken_at: ISO_NOW,
    },
  ],
};

Deno.test('cả hai gói đều thấy điểm ba trục, bằng tên tiếng Việt', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  for (const premium of [false, true]) {
    const ctx = await buildUserContext(fakeDb(SELF_CHECK_ROWS), 'u1', premium);
    assertEquals(ctx.includes('Sự rõ ràng: 4.4'), true);
    assertEquals(ctx.includes('Mối quan hệ: 2.6'), true);
    assertEquals(ctx.includes('Cách làm việc: 3.6'), true);
    // Trục thấp nhất phải tính đúng, không phải trục đứng đầu danh sách.
    assertEquals(ctx.includes('Trục thấp nhất của họ hiện là "Mối quan hệ"'), true);
  }
});

Deno.test('TUYỆT ĐỐI không lộ tên cột — ghép lại là cụm mục 6 cấm', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  for (const premium of [false, true]) {
    const ctx = await buildUserContext(fakeDb(SELF_CHECK_ROWS), 'u1', premium);
    assertEquals(/structure|culture|activity|SCA/i.test(ctx), false);
  }
});

Deno.test('nhãn mức khớp đúng ngưỡng của app', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(SELF_CHECK_ROWS), 'u1', true);
  // 4.4 ≥ 4.2 · 2.6 < 2.8 · 3.6 ≥ 3.5. Lệch ngưỡng thì người dùng thấy một nhãn
  // trên màn kết quả rồi nghe trợ lý gọi tên khác cho cùng con số.
  assertEquals(ctx.includes('4.4 trên 5 (đang khá thuận)'), true);
  assertEquals(ctx.includes('2.6 trên 5 (đang bị cản nhiều)'), true);
  assertEquals(ctx.includes('3.6 trên 5 (tạm ổn)'), true);
});

Deno.test('luật kèm theo khác nhau đúng theo gói', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const free = await buildUserContext(fakeDb(SELF_CHECK_ROWS), 'u1', false);
  const premium = await buildUserContext(fakeDb(SELF_CHECK_ROWS), 'u1', true);

  assertEquals(free.includes('KHÔNG được giải nghĩa sâu'), true);
  assertEquals(premium.includes('ĐƯỢC diễn giải sâu'), true);
  assertEquals(premium.includes('KHÔNG được giải nghĩa sâu'), false);
});

Deno.test('có bản ghi nhưng chưa có điểm thì NÓI RA là không có', async () => {
  // Bỏ trống là mời model tự điền, đúng lỗi đã bắt được ngày 2026-08-03.
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(
    fakeDb({
      ...SELF_CHECK_ROWS,
      wr_sca_self_check_responses: [
        {
          structure_score: null,
          culture_score: null,
          activity_score: null,
          taken_at: ISO_NOW,
        },
      ],
    }),
    'u1',
    true,
  );
  assertEquals(ctx.includes('KHÔNG có kết quả của bài đó'), true);
});

Deno.test('luật so sánh thời gian CHỈ dành cho Premium', async () => {
  // Nằm chung cho cả hai gói thì nó đánh nhau với FREE_GATE_RULE và thắng, khiến
  // trợ lý nói "bạn chưa đủ dữ liệu" với người đang có dữ liệu.
  const { buildUserContext } = await import('./user_context.ts');
  const free = await buildUserContext(fakeDb(ROWS), 'u1', false);
  const premium = await buildUserContext(fakeDb(ROWS), 'u1', true);

  assertEquals(premium.includes('nói thẳng là bạn chưa đủ dữ liệu'), true);
  assertEquals(free.includes('nói thẳng là bạn chưa đủ dữ liệu'), false);
  assertEquals(free.includes('TUYỆT ĐỐI KHÔNG nói "bạn chưa có đủ dữ liệu"'), true);
});

// ---------------------------------------------------------------------------
// Cơ hội phát triển và hồ sơ công việc — cả hai CHỈ Premium
// ---------------------------------------------------------------------------

const GROWTH_ROWS = {
  ...ROWS,
  wr_growth_opportunities: [
    {
      suggestion_text: 'Có thể đây là lúc thử vai trò dẫn dắt một nhóm nhỏ.',
      confidence_note: 'Gợi ý này dựa trên số lần nhìn lại còn ít, hãy xem như một hướng để cân nhắc.',
      generated_at: ISO_NOW,
    },
  ],
  wr_context_documents: [
    { doc_type: 'jd', uploaded_at: ISO_NOW },
    { doc_type: 'cv', uploaded_at: ISO_NOW },
  ],
};

Deno.test('gói miễn phí KHÔNG thấy cơ hội phát triển lẫn hồ sơ công việc', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(GROWTH_ROWS), 'u1', false);
  assertEquals(ctx.includes('dẫn dắt một nhóm nhỏ'), false);
  assertEquals(ctx.includes('mô tả công việc'), false);
});

Deno.test('Premium thấy cơ hội phát triển KÈM ghi chú độ chính xác', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(GROWTH_ROWS), 'u1', true);
  assertEquals(ctx.includes('dẫn dắt một nhóm nhỏ'), true);
  assertEquals(ctx.includes('hãy xem như một hướng để cân nhắc'), true);
  assertEquals(ctx.includes('không được tách rời'), true);
});

Deno.test('thiếu ghi chú độ chính xác thì BỎ HẲN cả gợi ý', async () => {
  // Ràng buộc NOT NULL ở migration 20260728000003 tồn tại để không thể có gợi ý
  // trần. Đọc trần ra ở tầng này là phá đúng ràng buộc đó ở chỗ cuối cùng.
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(
    fakeDb({
      ...GROWTH_ROWS,
      wr_growth_opportunities: [
        {
          suggestion_text: 'Có thể đây là lúc thử vai trò dẫn dắt một nhóm nhỏ.',
          confidence_note: '   ',
          generated_at: ISO_NOW,
        },
      ],
    }),
    'u1',
    true,
  );
  assertEquals(ctx.includes('dẫn dắt một nhóm nhỏ'), false);
});

Deno.test('hồ sơ công việc CHƯA phân tích: nói thẳng là không biết nội dung', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(GROWTH_ROWS), 'u1', true);
  assertEquals(ctx.includes('mô tả công việc và hồ sơ năng lực'), true);
  assertEquals(ctx.includes('KHÔNG biết nội dung'), true);
  // Không được lộ đường dẫn file — đó là tên trường dữ liệu, mục 6 cấm.
  assertEquals(/file_path|storage|\.pdf|\.docx/i.test(ctx), false);
});

// ---------------------------------------------------------------------------
// Hồ sơ công việc ĐÃ phân tích (từ 2026-08-04)
//
// `wr-doc-analyze` đọc JD/CV rồi lưu chữ vào `extracted_text` và bản phân tích
// vào `analysis`. Đây là chỗ nội dung thật đi vào ngữ cảnh của trợ lý.
// ---------------------------------------------------------------------------

const READY_JD_ROWS = {
  ...ROWS,
  wr_context_documents: [
    {
      doc_type: 'jd',
      uploaded_at: ISO_NOW,
      analyzed_at: ISO_NOW,
      analysis_status: 'ready',
      extracted_text:
        'Chuyên viên nhân sự. Phối hợp với trưởng bộ phận để tuyển dụng và '
        + 'đào tạo nhân sự mới. Yêu cầu 2 năm kinh nghiệm.',
      analysis: {
        title: 'Chuyên viên nhân sự',
        organization: 'Công ty ABC',
        summary: 'Vị trí phụ trách tuyển dụng và đào tạo nhân sự.',
        responsibilities: ['Tuyển dụng nhân sự mới', 'Đào tạo hội nhập'],
        requirements: ['2 năm kinh nghiệm nhân sự'],
        skills: ['Giao tiếp', 'Phỏng vấn'],
        pillars: { S: 2, C: 4, A: 1 },
      },
    },
  ],
};

Deno.test('hồ sơ ĐÃ phân tích: đưa nội dung thật vào ngữ cảnh', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(READY_JD_ROWS), 'u1', true);

  assertEquals(ctx.includes('Chuyên viên nhân sự'), true);
  assertEquals(ctx.includes('Tuyển dụng nhân sự mới'), true);
  assertEquals(ctx.includes('Trích nguyên văn'), true);
  // Đã đọc được rồi thì KHÔNG được kèm câu "bạn không biết nội dung" của nhánh
  // kia — hai câu ngược nhau trong cùng một prompt là chỗ model chọn bừa.
  assertEquals(ctx.includes('KHÔNG biết nội dung'), false);
});

Deno.test('hồ sơ đã phân tích vẫn bị cấm suy diễn ngoài phần đọc được', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(READY_JD_ROWS), 'u1', true);
  assertEquals(ctx.includes('CHỈ những gì có trong đoạn trên'), true);
});

Deno.test('gói miễn phí KHÔNG thấy nội dung hồ sơ dù đã phân tích', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(READY_JD_ROWS), 'u1', false);
  assertEquals(ctx.includes('Chuyên viên nhân sự'), false);
});

// ---------------------------------------------------------------------------
// Nội dung lần nhìn lại — chữ của chính người dùng
//
// VÌ SAO CÓ NHÓM NÀY: khách chụp màn 2026-08-03. Người dùng vừa đi hết một vòng
// Reflection, nói "bạn xem thử reflection tôi vừa làm để chia sẻ giúp tôi", và
// trợ lý trả lời "mình không có quyền truy cập vào nội dung cụ thể của từng
// Reflection".
//
// Câu đó đọc như một giới hạn về quyền, nhưng thật ra là khoảng trống trong
// ngữ cảnh: khối dữ liệu lúc ấy chỉ có NGÀY và SỐ ĐẾM, không có một chữ nào
// người dùng đã viết. Dữ liệu vẫn nằm nguyên trong database.
//
// Đây là loại lỗi tệ nhất với sản phẩm này, vì nó phủ nhận đúng lời hứa nền:
// những gì bạn ghi lại sẽ được nhìn thấy.
// ---------------------------------------------------------------------------

const ISO_YESTERDAY = new Date(Date.now() - 20 * 3_600_000).toISOString();
const ISO_LAST_WEEK = new Date(Date.now() - 8 * 86_400_000).toISOString();

/// Một Episode đã đi hết vòng, kèm đủ các trường người dùng tự viết.
function fullEpisode(openedAt: string, state = 'committed') {
  return {
    opened_at: openedAt,
    state,
    energy: 'low',
    situation_code: 'S1',
    human_need: 'ket_noi',
    intention: 'Muốn hiểu vì sao mình im lặng',
    notes: {
      notice: 'Mình thấy tim đập nhanh khi định giơ tay',
      explore: 'Có lẽ vì lần trước bị ngắt lời giữa chừng',
      commit: 'Lần sau sẽ nói ngay câu đầu tiên',
    },
    draft_meaning: 'Im lặng của mình là để tránh bị đánh giá, không phải vì không có ý kiến',
    tiny_action: 'Chuẩn bị sẵn một câu mở đầu trước cuộc họp',
    reflect_choice: null,
  };
}

const REFLECTION_ROWS = {
  wr_reflection_episodes: [fullEpisode(ISO_YESTERDAY)],
  wr_situations: [{ code: 'S1', text: 'Im lặng trong cuộc họp' }],
};

Deno.test('trợ lý ĐỌC ĐƯỢC chữ người dùng viết trong lần nhìn lại', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(REFLECTION_ROWS), 'u1', false);

  assertEquals(ctx.includes('tim đập nhanh khi định giơ tay'), true);
  assertEquals(ctx.includes('bị ngắt lời giữa chừng'), true);
  assertEquals(ctx.includes('để tránh bị đánh giá'), true);
  assertEquals(ctx.includes('Chuẩn bị sẵn một câu mở đầu'), true);
  assertEquals(ctx.includes('Muốn hiểu vì sao mình im lặng'), true);
});

Deno.test('gói MIỄN PHÍ cũng đọc được — mục 7 xếp vào trục hành động', async () => {
  // "Tự xem dữ liệu thô của chính mình" là quyền của cả người dùng miễn phí.
  // Gác chỗ này là gác quá tay: thứ thuộc Premium là phần TỔNG HỢP theo thời
  // gian, không phải chính chữ họ vừa viết ra.
  const { buildUserContext } = await import('./user_context.ts');
  const free = await buildUserContext(fakeDb(REFLECTION_ROWS), 'u1', false);
  const paid = await buildUserContext(fakeDb(REFLECTION_ROWS), 'u1', true);

  for (const ctx of [free, paid]) {
    assertEquals(ctx.includes('chính chữ họ tự viết'), true);
    assertEquals(ctx.includes('tim đập nhanh khi định giơ tay'), true);
  }
});

Deno.test('KHÔNG lộ mã tình huống lẫn tên bước nội bộ', async () => {
  // Mục 6 cấm mã chiều và tên mô hình nội bộ. Cách chắc chắn nhất để model
  // không nói ra là nó không bao giờ nhìn thấy.
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(REFLECTION_ROWS), 'u1', true);

  assertEquals(ctx.includes('S1-'), false);
  assertEquals(/"S1"|\bnotice\b|\breframe\b|\bpreserve\b|draft_meaning|tiny_action/.test(ctx), false);
  // Tiêu đề tiếng Việt thì phải có.
  assertEquals(ctx.includes('Im lặng trong cuộc họp'), true);
});

Deno.test('vừa nhìn lại xong thì CẤM mời ghi lại lần nữa', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(fakeDb(REFLECTION_ROWS), 'u1', false);

  assertEquals(ctx.includes('VỪA đi qua một lần nhìn lại'), true);
  assertEquals(ctx.includes('[[ACTION:reflect]]'), true);
  assertEquals(ctx.includes('không có quyền truy cập'), true);
});

Deno.test('lần nhìn lại đã lâu thì KHÔNG bật luật đó', async () => {
  // Người tuần trước mới ghi một lần thì mời họ ghi tiếp là đúng việc.
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(
    fakeDb({
      ...REFLECTION_ROWS,
      wr_reflection_episodes: [fullEpisode(ISO_LAST_WEEK)],
    }),
    'u1',
    false,
  );

  assertEquals(ctx.includes('VỪA đi qua một lần nhìn lại'), false);
  // Nội dung thì vẫn phải đọc được.
  assertEquals(ctx.includes('tim đập nhanh khi định giơ tay'), true);
});

Deno.test('phiên bỏ dở KHÔNG tính là vừa nhìn lại xong', async () => {
  // Mở luồng rồi thoát giữa chừng thì mời họ quay lại làm nốt mới là việc đúng.
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(
    fakeDb({
      ...REFLECTION_ROWS,
      wr_reflection_episodes: [fullEpisode(ISO_YESTERDAY, 'exploring')],
    }),
    'u1',
    false,
  );

  assertEquals(ctx.includes('VỪA đi qua một lần nhìn lại'), false);
  assertEquals(ctx.includes('còn dở, chưa đi hết vòng'), true);
});

Deno.test('mở luồng rồi thoát ngay, chưa viết chữ nào → BỎ HẲN mục đó', async () => {
  // Một mục chỉ có ngày tháng mà không có nội dung là mời model tự điền, đúng
  // cái bẫy đã sập ba lần trong file này.
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(
    fakeDb({
      wr_reflection_episodes: [{
        opened_at: ISO_YESTERDAY,
        state: 'captured',
        energy: null,
        situation_code: null,
        human_need: null,
        intention: null,
        notes: {},
        draft_meaning: null,
        tiny_action: null,
        reflect_choice: null,
      }],
    }),
    'u1',
    false,
  );

  assertEquals(ctx.includes('chính chữ họ tự viết'), false);
});

Deno.test('câu đã chọn trùng việc nhỏ thì không lặp lại hai lần', async () => {
  const { buildUserContext } = await import('./user_context.ts');
  const same = 'Chuẩn bị sẵn một câu mở đầu trước cuộc họp';
  const ctx = await buildUserContext(
    fakeDb({
      ...REFLECTION_ROWS,
      wr_reflection_episodes: [
        { ...fullEpisode(ISO_YESTERDAY), reflect_choice: same },
      ],
    }),
    'u1',
    false,
  );

  assertEquals(ctx.split(same).length - 1, 1);
});

Deno.test('điều tự rút ra đọc từ CẢ HAI bảng insight', async () => {
  // Luồng Reflection v2.0 ghi vào `wr_reflection_insights`; bản đầu của file này
  // chỉ đọc bảng cũ `wr_insights`, nên phần chắt lọc nhất của những lần nhìn lại
  // gần đây chưa bao giờ tới được trợ lý.
  const { buildUserContext } = await import('./user_context.ts');
  const ctx = await buildUserContext(
    fakeDb({
      ...REFLECTION_ROWS,
      wr_reflection_insights: [
        { content: 'Mình cần được nghe hết câu', created_at: ISO_YESTERDAY },
      ],
    }),
    'u1',
    false,
  );

  assertEquals(ctx.includes('Mình cần được nghe hết câu'), true);
});

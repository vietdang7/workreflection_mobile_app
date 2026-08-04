// Test bộ chuẩn hoá kết quả đọc tài liệu.
//
// Chạy: deno test supabase/functions/wr-doc-analyze/analysis_test.ts
//
// Vì sao đáng test: thứ model trả về không phải hợp đồng, nó là một lời hứa.
// Mọi trường ở đây đều đã có lần bị trả sai kiểu ở một model nào đó — số dạng
// chuỗi, mảng lẫn null, thiếu hẳn trường. Lưu thẳng vào database thì mỗi chỗ
// đọc lại phải tự phòng thân, và sẽ có chỗ quên.

import { assertEquals } from 'jsr:@std/assert@1';
import {
  buildExtractionPrompt,
  dominantPillar,
  normalizeAnalysis,
} from './analysis.ts';

Deno.test('bản trả về đầy đủ đi qua nguyên vẹn', () => {
  const { analysis, extractedText } = normalizeAnalysis({
    doc_type: 'jd',
    title: 'Chuyên viên nhân sự',
    organization: 'Công ty ABC',
    summary: 'Tuyển dụng và đào tạo.',
    responsibilities: ['Tuyển dụng', 'Đào tạo'],
    requirements: ['2 năm kinh nghiệm'],
    skills: ['Giao tiếp'],
    keywords: ['nhân sự', 'tuyển dụng'],
    pillars: { S: 2, C: 4, A: 1 },
    language: 'vi',
    raw_text: 'Chuyên viên nhân sự...',
  });

  assertEquals(analysis.title, 'Chuyên viên nhân sự');
  assertEquals(analysis.responsibilities.length, 2);
  assertEquals(analysis.pillars.C, 4);
  assertEquals(extractedText, 'Chuyên viên nhân sự...');
});

Deno.test('thiếu trường thì về rỗng, không văng', () => {
  const { analysis, extractedText } = normalizeAnalysis({});
  assertEquals(analysis.doc_type, 'other');
  assertEquals(analysis.title, null);
  assertEquals(analysis.summary, '');
  assertEquals(analysis.responsibilities, []);
  assertEquals(analysis.pillars, { S: 0, C: 0, A: 0 });
  assertEquals(extractedText, '');
});

Deno.test('trọng số trả về dạng chuỗi hoặc ngoài thang vẫn nắn được', () => {
  const { analysis } = normalizeAnalysis({
    pillars: { S: '3', C: 9, A: -2 },
  });
  assertEquals(analysis.pillars.S, 3);
  assertEquals(analysis.pillars.C, 5);
  assertEquals(analysis.pillars.A, 0);
});

Deno.test('trụ viết thường vẫn nhận', () => {
  const { analysis } = normalizeAnalysis({ pillars: { s: 4, c: 1, a: 0 } });
  assertEquals(analysis.pillars.S, 4);
});

Deno.test('mảng lẫn null, chuỗi rỗng và mục trùng đều bị loại', () => {
  const { analysis } = normalizeAnalysis({
    responsibilities: ['Tuyển dụng', null, '  ', 'Tuyển dụng', 'Đào tạo'],
  });
  assertEquals(analysis.responsibilities, ['Tuyển dụng', 'Đào tạo']);
});

Deno.test('raw_text KHÔNG nằm trong cột analysis', () => {
  // Nó là phần dài nhất và là thứ duy nhất mọi tính năng khác cần nguyên văn.
  // Để lẫn trong jsonb thì mỗi lần dựng ngữ cảnh phải kéo cả bản phân tích theo.
  const { analysis } = normalizeAnalysis({ raw_text: 'dài dòng…' });
  assertEquals('raw_text' in (analysis as unknown as Record<string, unknown>), false);
});

Deno.test('trụ nổi trội: hoà thì im, không chọn bừa', () => {
  assertEquals(dominantPillar({ S: 3, C: 3, A: 1 }), null);
  assertEquals(dominantPillar({ S: 0, C: 0, A: 0 }), null);
  assertEquals(dominantPillar({ S: 1, C: 4, A: 2 }), 'C');
});

Deno.test('lời dặn cấm suy đoán và nói rõ loại tài liệu', () => {
  const jd = buildExtractionPrompt('jd');
  assertEquals(jd.includes('mô tả công việc (JD)'), true);
  assertEquals(jd.includes('CHỈ ghi những gì thật sự có trong tài liệu'), true);
  assertEquals(buildExtractionPrompt('cv').includes('hồ sơ năng lực (CV)'), true);
});

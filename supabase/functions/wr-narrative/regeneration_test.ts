// Test cho lớp quyết định "có kể lại không".
//
// Chạy: deno test supabase/functions/wr-narrative/regeneration_test.ts
//
// Đây là lớp duy nhất trong hàm quyết định TIÊU TIỀN. Sai về phía rộng thì mỗi
// lần mở tab Hành trình là một lượt gọi model; sai về phía chặt thì thẻ đứng im
// và ta quay lại đúng lỗi khách báo 2026-08-24.

import { assertEquals } from 'jsr:@std/assert@1';
import {
  decideRegeneration,
  MIN_EPISODES,
  MIN_NEW_EPISODES,
  vnDate,
  type EpisodeRow,
  type NarrativeRow,
} from './regeneration.ts';

/// Episode với mốc mở là [daysAgo] ngày trước [now].
function ep(openedAt: string, code = 'C1-sit-01'): EpisodeRow {
  return {
    situation_code: code,
    human_need: null,
    energy: null,
    opened_at: openedAt,
    draft_meaning: null,
  };
}

/// Danh sách MỚI NHẤT TRƯỚC, mỗi mục cách nhau một ngày.
function series(count: number, fromIso: string): EpisodeRow[] {
  const base = new Date(fromIso).getTime();
  return Array.from({ length: count }, (_, i) =>
    ep(new Date(base - i * 86_400_000).toISOString()));
}

function narrative(createdAt: string): NarrativeRow {
  return {
    id: 'n1',
    narrative: 'Chuyện cũ.',
    period_start: null,
    period_end: null,
    created_at: createdAt,
  };
}

// ---------------------------------------------------------------------------
// Lần đầu
// ---------------------------------------------------------------------------

Deno.test('chưa đủ số lần thì không kể, và nói còn thiếu bao nhiêu', () => {
  const d = decideRegeneration(series(2, '2026-08-20T10:00:00Z'), null);

  assertEquals(d.regenerate, false);
  if (d.regenerate) return;
  assertEquals(d.reason, 'not_enough_data');
  assertEquals(d.needed, MIN_EPISODES - 2);
});

Deno.test('đủ số lần và chưa từng kể thì kể ngay', () => {
  const d = decideRegeneration(series(MIN_EPISODES, '2026-08-20T10:00:00Z'), null);

  assertEquals(d.regenerate, true);
});

Deno.test('mốc giai đoạn lấy từ chính dữ liệu, không lấy hôm nay', () => {
  // 5 lần, mới nhất 20/08, cũ nhất 16/08 (mỗi mục cách một ngày).
  const d = decideRegeneration(series(5, '2026-08-20T10:00:00Z'), null);

  assertEquals(d.regenerate, true);
  if (!d.regenerate) return;
  assertEquals(d.periodStart, '2026-08-16');
  assertEquals(d.periodEnd, '2026-08-20');
});

// ---------------------------------------------------------------------------
// Kể lại
// ---------------------------------------------------------------------------

Deno.test('chưa có đủ lần MỚI thì giữ nguyên bản cũ', () => {
  // Đã kể hôm 18/08. Sau đó chỉ thêm hai lần (19, 20).
  const episodes = series(6, '2026-08-20T10:00:00Z');
  const d = decideRegeneration(episodes, narrative('2026-08-18T23:59:00Z'));

  assertEquals(d.regenerate, false);
  if (d.regenerate) return;
  assertEquals(d.reason, 'up_to_date');
  assertEquals(d.needed, MIN_NEW_EPISODES - 2);
});

Deno.test('đủ lần mới thì kể lại', () => {
  // Đã kể hôm 17/08. Sau đó thêm ba lần (18, 19, 20).
  const episodes = series(6, '2026-08-20T10:00:00Z');
  const d = decideRegeneration(episodes, narrative('2026-08-17T23:59:00Z'));

  assertEquals(d.regenerate, true);
});

Deno.test('nhiều lần trong CÙNG một ngày vẫn được tính là mới', () => {
  // Vì sao test này tồn tại: nếu đếm theo `period_end` (ngày) thay vì
  // `created_at` (thời điểm), ba lần ghi thêm trong cùng ngày đã kể sẽ bị coi
  // là cũ và câu chuyện đứng im dù đã có thêm nguyên liệu.
  const sameDay = [
    ep('2026-08-20T21:00:00Z'),
    ep('2026-08-20T20:00:00Z'),
    ep('2026-08-20T19:00:00Z'),
    ...series(3, '2026-08-19T10:00:00Z'),
  ];
  const d = decideRegeneration(sameDay, narrative('2026-08-20T12:00:00Z'));

  assertEquals(d.regenerate, true);
});

// ---------------------------------------------------------------------------
// Dữ liệu lệch
// ---------------------------------------------------------------------------

Deno.test('Episode thiếu opened_at không làm hỏng mốc giai đoạn', () => {
  const episodes: EpisodeRow[] = [
    { ...ep('2026-08-20T10:00:00Z'), opened_at: null },
    ...series(4, '2026-08-19T10:00:00Z'),
  ];
  const d = decideRegeneration(episodes, null);

  assertEquals(d.regenerate, true);
  if (!d.regenerate) return;
  assertEquals(d.periodEnd, '2026-08-19');
});

Deno.test('vnDate trả null cho chuỗi rỗng hoặc hỏng', () => {
  assertEquals(vnDate(null), null);
  assertEquals(vnDate(''), null);
  assertEquals(vnDate('không phải ngày'), null);
});

Deno.test('vnDate đổi sang ngày theo giờ Việt Nam', () => {
  // 19/08 lúc 18:00 UTC là 20/08 lúc 01:00 giờ VN — mốc phải theo giờ người
  // dùng đang sống, không theo UTC.
  assertEquals(vnDate('2026-08-19T18:00:00Z'), '2026-08-20');
});

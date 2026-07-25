-- DO NOT push without Fable approval
-- Adds energy + direction columns to wr_checkins for Phase 2 Sprint 1.
-- Both nullable to preserve backward compatibility with existing rows.

alter table public.wr_checkins
  add column if not exists energy text
    check (energy in ('good', 'ok', 'low'));

alter table public.wr_checkins
  add column if not exists direction text
    check (direction in ('forward', 'steady', 'backward'));

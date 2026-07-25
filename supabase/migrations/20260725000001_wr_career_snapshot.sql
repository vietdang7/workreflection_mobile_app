-- WorkReflection: Career Snapshot trên wr_mobile_profiles.
-- Nguồn: mockup giao-dien-ho-tro.jsx — CareerSetupScreen ghi
-- {current_role, career_goal, current_challenge, last_updated}.
-- Ba cột đều nullable: người dùng được phép bỏ qua từng bước.
-- `updated_at` sẵn có đóng vai trò last_updated.

alter table public.wr_mobile_profiles
  add column if not exists current_role      text,
  add column if not exists career_goal       text,
  add column if not exists current_challenge text;

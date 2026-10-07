-- Mockup v47 (06/10/2026) — chủ đề thực hành 4 bước + chủ đề người dùng tự thêm.
--
-- 1. MỌI chủ đề dùng đúng bộ 4 bước: Nhận diện → Phần của tôi → Chọn một cách
--    → Mang về. Nhãn "Chuyển hoá" bỏ hẳn (chủ dự án chốt 06/10: chuyển cả thư
--    viện). Giữ nguyên step_id cũ để `completed_steps` của người đang thực hành
--    vẫn trỏ đúng:
--       <theme>-1    Nhận diện        (giữ nội dung)
--       <theme>-mine Phần của tôi     (MỚI, thứ tự 2)
--       <theme>-2    Chọn một cách    (bước "Thử nghiệm" cũ, thứ tự 3)
--       <theme>-3    Mang về          (bước "Chuyển hoá" cũ, thứ tự 4, vẫn Premium)
--    Việc nhỏ của bước "Thử nghiệm" cũ không mất: nó thành cách "Thử một bước
--    nhỏ" trong `mentor_options` của chủ đề.
-- 2. `mentor_options`: ba cách để chọn ở bước "Chọn một cách", mỗi cách có
--    "Phù hợp" và "Đánh đổi" (mockup `PRACTICE_MENTOR_OPTIONS`/`getMentorOptions`).
-- 3. Chủ đề người dùng tự thêm: `source='user'`, `owner_id`, `intake` (4 câu của
--    form "Bạn muốn tự thêm điều gì?"). RLS: chỉ chủ nhân thấy và ghi.
-- 4. `wr_practice_enrollments.pending_choice`: cách người dùng đã "Lưu cách tôi
--    muốn thử" mà chưa thử. `wr_practice_step_notes.choice`: cách đã dùng khi
--    đánh dấu một bước.

-- ── 1. Cột mới ───────────────────────────────────────────────────────────────
alter table public.wr_practice_themes
  add column if not exists source text not null default 'library',
  add column if not exists owner_id uuid references auth.users(id) on delete cascade,
  add column if not exists intake jsonb,
  add column if not exists mentor_options jsonb;

do $$ begin
  alter table public.wr_practice_themes
    add constraint wr_practice_themes_source_check
    check (source in ('library', 'user'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.wr_practice_themes
    add constraint wr_practice_themes_user_owner_check
    check ((source = 'user') = (owner_id is not null));
exception when duplicate_object then null; end $$;

create index if not exists wr_practice_themes_owner_idx
  on public.wr_practice_themes (owner_id) where owner_id is not null;

alter table public.wr_practice_enrollments
  add column if not exists pending_choice text;

alter table public.wr_practice_step_notes
  add column if not exists choice text;

-- ── 2. Thư viện sang 4 bước ──────────────────────────────────────────────────
-- Chỉ chủ đề đang dùng có đủ 3 bước cũ. Chủ đề đã ngưng (pt-voice, pt-rhythm,
-- pt-feedback) giữ nguyên: không ai được mời vào nữa.
do $$
declare
  t record;
  old_try text;
  old_try_en text;
begin
  for t in
    select th.theme_id
    from public.wr_practice_themes th
    where th.retired_at is null
      and th.source = 'library'
      and not exists (
        select 1 from public.wr_practice_steps s
        where s.theme_id = th.theme_id and s.step_id = th.theme_id || '-mine'
      )
      and exists (
        select 1 from public.wr_practice_steps s
        where s.step_id = th.theme_id || '-2'
      )
  loop
    select regexp_replace(title, '^[^:]*:\s*', ''),
           regexp_replace(coalesce(title_en, title), '^[^:]*:\s*', '')
      into old_try, old_try_en
      from public.wr_practice_steps where step_id = t.theme_id || '-2';

    -- Mang về (bước "Chuyển hoá" cũ). Đổi thứ tự trước để khỏi trùng.
    update public.wr_practice_steps set
      step_order = 4,
      title = 'Mang về: Giữ lại một câu hỏi',
      title_en = 'Take it with you: Keep one question',
      content = 'Sau khi thử, bạn muốn mang theo câu hỏi nào cho lần sau?',
      content_en = 'After trying, what question do you want to carry into next time?'
    where step_id = t.theme_id || '-3';

    -- Chọn một cách (bước "Thử nghiệm" cũ).
    update public.wr_practice_steps set
      step_order = 3,
      is_premium = false,
      title = 'Chọn một cách: Chọn một cách rồi thử',
      title_en = 'Pick one way: Pick one way and try it',
      content = case when t.theme_id = 'pt-c2'
        then 'Chọn một trong các cách ở trên và thử trong một cuộc họp thật.'
        else 'Chọn một trong các cách ở trên và thử trong một tình huống thật.' end,
      content_en = case when t.theme_id = 'pt-c2'
        then 'Pick one of the ways above and try it in a real meeting.'
        else 'Pick one of the ways above and try it in a real situation.' end
    where step_id = t.theme_id || '-2';

    insert into public.wr_practice_steps
      (step_id, theme_id, step_order, title, title_en, content, content_en, is_premium)
    values (
      t.theme_id || '-mine', t.theme_id, 2,
      'Phần của tôi: Tách phần mình và phần bối cảnh',
      'Your part: Separate your part from the context',
      case when t.theme_id = 'pt-c2'
        then 'Trong những lần đó, điều gì thuộc quyền quyết định của bạn, và điều gì thì chưa?'
        else 'Trong tình huống đó, điều gì thuộc quyền quyết định của bạn, và điều gì thì chưa?' end,
      case when t.theme_id = 'pt-c2'
        then 'In those moments, what was yours to decide, and what was not yet?'
        else 'In that situation, what is yours to decide, and what is not yet?' end,
      false
    );

    -- Ba cách. "Dám lên tiếng" và "Phản hồi thật" lấy nguyên bộ của mockup
    -- (t1, t2); các chủ đề còn lại dùng bộ chung `getMentorOptions`, với việc
    -- nhỏ của bước "Thử nghiệm" cũ làm cách đầu tiên.
    update public.wr_practice_themes set mentor_options = case theme_id
      when 'pt-c2' then jsonb_build_array(
        jsonb_build_object('id','ask','title','Hỏi để hiểu','title_en','Ask to understand',
          'fit','Bạn đang thiếu thông tin nhưng muốn mở cuộc trao đổi.',
          'fit_en','You are missing information but want to open the conversation.',
          'tradeoff','Bạn phải chấp nhận mình chưa có câu trả lời.',
          'tradeoff_en','You have to accept that you do not have the answer yet.'),
        jsonb_build_object('id','voice','title','Nói một góc nhìn','title_en','Offer one view',
          'fit','Bạn đã có quan sát và muốn góp tiếng ngay trong cuộc họp.',
          'fit_en','You already have an observation and want to speak up in the meeting.',
          'tradeoff','Ý kiến của bạn có thể bị phản biện hoặc chưa được dùng ngay.',
          'tradeoff_en','Your view may be challenged or not used right away.'),
        jsonb_build_object('id','observe','title','Quan sát thêm','title_en','Observe a bit more',
          'fit','Bối cảnh chưa đủ an toàn, hoặc bạn chưa hiểu vấn đề thật sự.',
          'fit_en','The setting does not feel safe enough yet, or you do not fully see the problem.',
          'tradeoff','Bạn chưa tạo ra thay đổi ở lần này.',
          'tradeoff_en','Nothing changes this time.'))
      when 'pt-c3' then jsonb_build_array(
        jsonb_build_object('id','small','title','Nói về sự việc và tác động','title_en','Talk about the event and its impact',
          'fit','Bạn có thể chỉ ra một hành vi cụ thể và điều nó ảnh hưởng đến.',
          'fit_en','You can point to one specific behaviour and what it affected.',
          'tradeoff','Cách nói trực tiếp hơn có thể khiến người kia phòng thủ.',
          'tradeoff_en','Being more direct may make the other person defensive.'),
        jsonb_build_object('id','ask','title','Hỏi trước, góp ý sau','title_en','Ask first, then give feedback',
          'fit','Bạn chưa chắc mình hiểu đúng ý định hoặc hoàn cảnh của người kia.',
          'fit_en','You are not sure you understand the other person''s intent or situation.',
          'tradeoff','Cuộc trò chuyện sẽ dài hơn và chưa chắc có câu trả lời ngay.',
          'tradeoff_en','The conversation takes longer and may not end with an answer.'),
        jsonb_build_object('id','oneone','title','Chọn một cuộc 1:1','title_en','Pick a 1:1',
          'fit','Chủ đề nhạy cảm hoặc cần không gian riêng để hai bên nói thật.',
          'fit_en','The topic is sensitive or needs a private space for both sides to be honest.',
          'tradeoff','Bạn phải chờ đúng người và đúng lúc để cuộc nói chuyện có chất lượng.',
          'tradeoff_en','You have to wait for the right person and moment.'))
      else jsonb_build_array(
        jsonb_build_object('id','try','title',old_try,'title_en',old_try_en,
          'fit','Hợp khi bạn đã biết điều nhỏ mình muốn thử.',
          'fit_en','Good when you already know the small thing you want to try.',
          'tradeoff','Bạn chấp nhận một chút khó chịu để có dữ liệu mới.',
          'tradeoff_en','You accept a little discomfort in exchange for new information.'),
        jsonb_build_object('id','observe','title','Quan sát thêm một lần','title_en','Observe one more time',
          'fit','Hợp khi bạn chưa chắc đây là một mẫu hình hay chỉ là một lần xảy ra.',
          'fit_en','Good when you are not sure whether this is a pattern or a one-off.',
          'tradeoff','Bạn có thêm thông tin, nhưng điều này có thể kéo dài thêm.',
          'tradeoff_en','You learn more, but the situation may go on a little longer.'),
        jsonb_build_object('id','talk','title','Đưa người khác vào cuộc','title_en','Bring someone else in',
          'fit','Hợp khi tình huống phụ thuộc vào ai đó hoặc cần thêm một góc nhìn.',
          'fit_en','Good when the situation depends on someone else or needs another view.',
          'tradeoff','Bạn phải mở lời và chấp nhận có thể nhận phản hồi không như mong đợi.',
          'tradeoff_en','You have to speak up and may hear something you did not expect.'))
      end
    where theme_id = t.theme_id;
  end loop;
end $$;

-- ── 3. RLS cho chủ đề người dùng ─────────────────────────────────────────────
drop policy if exists wr_practice_themes_public_read on public.wr_practice_themes;
create policy wr_practice_themes_public_read on public.wr_practice_themes
  for select using (
    auth.role() = 'authenticated'
    and (owner_id is null or owner_id = auth.uid())
  );

drop policy if exists wr_practice_themes_owner_insert on public.wr_practice_themes;
create policy wr_practice_themes_owner_insert on public.wr_practice_themes
  for insert with check (
    source = 'user' and owner_id = auth.uid() and theme_id like 'u-%'
  );

drop policy if exists wr_practice_themes_owner_update on public.wr_practice_themes;
create policy wr_practice_themes_owner_update on public.wr_practice_themes
  for update using (owner_id = auth.uid())
  with check (source = 'user' and owner_id = auth.uid());

drop policy if exists wr_practice_themes_owner_delete on public.wr_practice_themes;
create policy wr_practice_themes_owner_delete on public.wr_practice_themes
  for delete using (owner_id = auth.uid());

drop policy if exists wr_practice_steps_public_read on public.wr_practice_steps;
create policy wr_practice_steps_public_read on public.wr_practice_steps
  for select using (
    auth.role() = 'authenticated'
    and exists (
      select 1 from public.wr_practice_themes t
      where t.theme_id = wr_practice_steps.theme_id
        and (t.owner_id is null or t.owner_id = auth.uid())
    )
  );

drop policy if exists wr_practice_steps_owner_insert on public.wr_practice_steps;
create policy wr_practice_steps_owner_insert on public.wr_practice_steps
  for insert with check (
    exists (
      select 1 from public.wr_practice_themes t
      where t.theme_id = wr_practice_steps.theme_id
        and t.owner_id = auth.uid()
    )
  );

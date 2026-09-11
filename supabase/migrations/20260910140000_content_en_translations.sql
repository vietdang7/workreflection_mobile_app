-- Bản tiếng Anh cho nội dung nằm trong database.
--
-- Đi cùng `20260910120000_content_en_columns` — migration đó mở cột, migration
-- này đổ chữ vào.
--
-- ---------------------------------------------------------------------------
-- ĐÂY LÀ BẢN NHÁP CHỜ DUYỆT
--
-- Câu chữ do máy dịch, chưa qua người bản ngữ và chưa qua đội nội dung. Đưa vào
-- migration chứ không chạy tay CHÍNH VÌ THẾ: nằm trong Git thì khách rà được
-- trên diff của pull request, và sửa một câu là sửa một dòng có lịch sử, không
-- phải một lệnh UPDATE ai đó gõ lúc nửa đêm rồi không ai biết.
--
-- ---------------------------------------------------------------------------
-- BA QUY TẮC ĐÃ THEO KHI DỊCH
--
-- 1. GIỮ NGÔI. `wr_situations` viết ngôi thứ nhất ("Tôi im lặng"), phần lớn
--    `wr_stories` viết ngôi thứ hai ("Bạn im lặng"), riêng nhóm P-01..P-10 lại
--    quay về ngôi thứ nhất ở `story_content`. Bản tiếng Anh giữ đúng từng chỗ.
--    Đây là lý do 9 dòng nhóm C2 có bản dịch riêng cho `text` và cho `title`,
--    dù bản tiếng Việt của chúng chỉ khác nhau đúng một chữ.
--
-- 2. GIỮ XUỐNG DÒNG. `story_content` là những câu ngắn xếp thành khối, mỗi câu
--    một dòng. Gộp lại thành đoạn văn là đổi nhịp đọc của cả màn hình.
--
-- 3. TRÁNH TỪ NGỮ TƯ VẤN. Chính system prompt của trợ lý cấm "leverage",
--    "actionable", "unpack", "journey". Nội dung đọc cạnh câu trả lời của trợ
--    lý nên phải cùng một giọng.
--
-- ---------------------------------------------------------------------------
-- BỐN DÒNG DỮ LIỆU HỎNG SẴN, CHỈ DỊCH PHẦN THẬT
--
-- `wr_stories.practice_action` của A1-10, A3-10, S1-10, S2-10 bị dán thêm đuôi
-- tiêu đề mục kế tiếp lúc nhập liệu từ tài liệu gốc — ví dụ A1-10 kết thúc
-- bằng "A2 – Execution Rhythm / Human Need / Adaptability / SCA Dimension...".
-- Rác đó ĐANG HIỆN LÊN MÀN HÌNH ở bản tiếng Việt.
--
-- Bản tiếng Anh ở đây chỉ dịch câu thật và bỏ phần rác. CỐ Ý KHÔNG tự sửa bản
-- tiếng Việt: đó là dữ liệu của khách, sửa nội dung gốc phải là quyết định của
-- họ. Xem ghi chú cuối file.

begin;

-- -------------------------------------------------------------------------
-- wr_situations — chip ở bước đầu của Reflect (110 dòng)
-- -------------------------------------------------------------------------

update public.wr_situations set text_en = 'I''m moving fast, but where am I going?' where code = 'A1-01';
update public.wr_situations set text_en = 'I want to leave, but I don''t know what I want instead' where code = 'A1-02';
update public.wr_situations set text_en = 'I do a lot, but none of it feels meaningful' where code = 'A1-03';
update public.wr_situations set text_en = 'Is my success still what I want?' where code = 'A1-04';
update public.wr_situations set text_en = 'I don''t know what actually matters to me' where code = 'A1-05';
update public.wr_situations set text_en = 'Am I growing, or just busy?' where code = 'A1-06';
update public.wr_situations set text_en = 'I don''t feel like I belong here anymore' where code = 'A1-07';
update public.wr_situations set text_en = 'I want more, but I can''t name what' where code = 'A1-08';
update public.wr_situations set text_en = 'Whose definition of success am I living by?' where code = 'A1-09';
update public.wr_situations set text_en = 'What if I keep going like this for three more years?' where code = 'A1-10';
update public.wr_situations set text_en = 'I know what to do, but I still haven''t done it' where code = 'A2-01';
update public.wr_situations set text_en = 'I have too many plans' where code = 'A2-02';
update public.wr_situations set text_en = 'I start well but can''t keep it up' where code = 'A2-03';
update public.wr_situations set text_en = 'I''m always busy but never finish what matters' where code = 'A2-04';
update public.wr_situations set text_en = 'I keep changing direction' where code = 'A2-05';
update public.wr_situations set text_en = 'I keep waiting until I feel ready' where code = 'A2-06';
update public.wr_situations set text_en = 'I have too many things half-finished' where code = 'A2-07';
update public.wr_situations set text_en = 'I don''t see results, so I want to give up' where code = 'A2-08';
update public.wr_situations set text_en = 'I keep getting pulled away from what matters' where code = 'A2-09';
update public.wr_situations set text_en = 'What actually gets me to act?' where code = 'A2-10';
update public.wr_situations set text_en = 'Why is this happening again?' where code = 'A3-01';
update public.wr_situations set text_en = 'I know I''m tired, but I don''t know why' where code = 'A3-02';
update public.wr_situations set text_en = 'I reacted more strongly than the moment needed' where code = 'A3-03';
update public.wr_situations set text_en = 'I''m always busy but I don''t see progress' where code = 'A3-04';
update public.wr_situations set text_en = 'I keep deciding on feeling alone' where code = 'A3-05';
update public.wr_situations set text_en = 'I can''t remember what I''ve learned' where code = 'A3-06';
update public.wr_situations set text_en = 'I feel stuck' where code = 'A3-07';
update public.wr_situations set text_en = 'I always think I should be doing better' where code = 'A3-08';
update public.wr_situations set text_en = 'What am I avoiding looking at?' where code = 'A3-09';
update public.wr_situations set text_en = 'What if I stopped for ten minutes to look back?' where code = 'A3-10';
update public.wr_situations set text_en = 'I keep making the same mistake' where code = 'A4-01';
update public.wr_situations set text_en = 'How did I get through that?' where code = 'A4-02';
update public.wr_situations set text_en = 'What did this failure teach me?' where code = 'A4-03';
update public.wr_situations set text_en = 'In what way am I growing?' where code = 'A4-04';
update public.wr_situations set text_en = 'What signal did I miss?' where code = 'A4-05';
update public.wr_situations set text_en = 'Am I learning, or just going through it?' where code = 'A4-06';
update public.wr_situations set text_en = 'Am I repeating what works?' where code = 'A4-07';
update public.wr_situations set text_en = 'What is this teaching me about myself?' where code = 'A4-08';
update public.wr_situations set text_en = 'How did I come to change my mind?' where code = 'A4-09';
update public.wr_situations set text_en = 'If I read this year back as one chapter' where code = 'A4-10';
update public.wr_situations set text_en = 'I ended up doing it for them again' where code = 'C1-01';
update public.wr_situations set text_en = 'I always have to double-check' where code = 'C1-02';
update public.wr_situations set text_en = 'People say one thing and do another' where code = 'C1-03';
update public.wr_situations set text_en = 'I don''t know who I can ask' where code = 'C1-04';
update public.wr_situations set text_en = 'I hold back because I''m afraid of being let down' where code = 'C1-05';
update public.wr_situations set text_en = 'I''m not sure my manager will keep their word' where code = 'C1-06';
update public.wr_situations set text_en = 'I find it hard to ask for help' where code = 'C1-07';
update public.wr_situations set text_en = 'I don''t know what other people are thinking' where code = 'C1-08';
update public.wr_situations set text_en = 'I used to trust them, and now I don''t' where code = 'C1-09';
update public.wr_situations set text_en = 'I feel at ease working with them' where code = 'C1-10';
update public.wr_situations set text_en = 'My idea disappeared in the meeting' where code = 'C2-01';
update public.wr_situations set text_en = 'The meeting ended and the most important thing went unsaid' where code = 'C2-02';
update public.wr_situations set text_en = 'I agreed even though I didn''t' where code = 'C2-03';
update public.wr_situations set text_en = 'I got cut off mid-sentence' where code = 'C2-04';
update public.wr_situations set text_en = 'I wanted to say something but was afraid of upsetting people' where code = 'C2-05';
update public.wr_situations set text_en = 'I took the blame instead of explaining' where code = 'C2-06';
update public.wr_situations set text_en = 'I had a question and didn''t ask it' where code = 'C2-07';
update public.wr_situations set text_en = 'I was asked for input but didn''t believe it would change anything' where code = 'C2-08';
update public.wr_situations set text_en = 'I''m always the last one to speak' where code = 'C2-09';
update public.wr_situations set text_en = 'I used to speak up a lot, and now I don''t' where code = 'C2-10';
update public.wr_situations set text_en = 'I know there''s a problem and I don''t want to raise it' where code = 'C3-01';
update public.wr_situations set text_en = 'Every piece of feedback turns into an argument' where code = 'C3-02';
update public.wr_situations set text_en = 'We only talk about the work, never the problem' where code = 'C3-03';
update public.wr_situations set text_en = 'I don''t feel understood' where code = 'C3-04';
update public.wr_situations set text_en = 'We always read the same thing differently' where code = 'C3-05';
update public.wr_situations set text_en = 'I''m afraid of making other people uncomfortable' where code = 'C3-06';
update public.wr_situations set text_en = 'The meeting ended and the problem is still there' where code = 'C3-07';
update public.wr_situations set text_en = 'I always have to guess what people mean' where code = 'C3-08';
update public.wr_situations set text_en = 'We talk, but we don''t connect' where code = 'C3-09';
update public.wr_situations set text_en = 'Which conversation needs to happen?' where code = 'C3-10';
update public.wr_situations set text_en = 'I just finished something harder than I expected' where code = 'P-01';
update public.wr_situations set text_en = 'My manager recognised my work' where code = 'P-02';
update public.wr_situations set text_en = 'I helped a colleague untangle something hard' where code = 'P-03';
update public.wr_situations set text_en = 'I got a raise or a promotion' where code = 'P-04';
update public.wr_situations set text_en = 'Someone thanked me out of the blue' where code = 'P-05';
update public.wr_situations set text_en = 'Today went the way I hoped it would' where code = 'P-06';
update public.wr_situations set text_en = 'I felt in control of my own pace today' where code = 'P-07';
update public.wr_situations set text_en = 'I learned something small but useful' where code = 'P-08';
update public.wr_situations set text_en = 'I had a good conversation with a colleague' where code = 'P-09';
update public.wr_situations set text_en = 'Nothing special happened today, and I feel fine' where code = 'P-10';
update public.wr_situations set text_en = 'I don''t know what good looks like here' where code = 'S1-01';
update public.wr_situations set text_en = 'Everything ends up on my desk' where code = 'S1-02';
update public.wr_situations set text_en = 'I don''t know what to prioritise' where code = 'S1-03';
update public.wr_situations set text_en = 'I always feel like I''m not good enough' where code = 'S1-04';
update public.wr_situations set text_en = 'I get instructions that contradict each other' where code = 'S1-05';
update public.wr_situations set text_en = 'I don''t understand why this is mine to do' where code = 'S1-06';
update public.wr_situations set text_en = 'I don''t know how far my decisions can go' where code = 'S1-07';
update public.wr_situations set text_en = 'My role is shifting' where code = 'S1-08';
update public.wr_situations set text_en = 'I don''t know what counts as enough' where code = 'S1-09';
update public.wr_situations set text_en = 'What was I actually hired to do?' where code = 'S1-10';
update public.wr_situations set text_en = 'I don''t know who to go to for this' where code = 'S2-01';
update public.wr_situations set text_en = 'I''m always waiting on someone else' where code = 'S2-02';
update public.wr_situations set text_en = 'We did the same work without knowing' where code = 'S2-03';
update public.wr_situations set text_en = 'The work keeps getting passed back and forth' where code = 'S2-04';
update public.wr_situations set text_en = 'We read the same goal differently' where code = 'S2-05';
update public.wr_situations set text_en = 'I have to chase the same thing over and over' where code = 'S2-06';
update public.wr_situations set text_en = 'I don''t understand what other people actually do' where code = 'S2-07';
update public.wr_situations set text_en = 'Working together is exhausting every time' where code = 'S2-08';
update public.wr_situations set text_en = 'We depend far too much on one person' where code = 'S2-09';
update public.wr_situations set text_en = 'What makes us work well together?' where code = 'S2-10';
update public.wr_situations set text_en = 'I don''t know where to find things' where code = 'S3-01';
update public.wr_situations set text_en = 'I found out too late' where code = 'S3-02';
update public.wr_situations set text_en = 'Everyone tells me something different' where code = 'S3-03';
update public.wr_situations set text_en = 'I don''t know which version is current' where code = 'S3-04';
update public.wr_situations set text_en = 'I have to ask the same question again and again' where code = 'S3-05';
update public.wr_situations set text_en = 'I''m drowning in too much information' where code = 'S3-06';
update public.wr_situations set text_en = 'Some things only a few people know' where code = 'S3-07';
update public.wr_situations set text_en = 'I can''t see the whole picture' where code = 'S3-08';
update public.wr_situations set text_en = 'I don''t know what changed' where code = 'S3-09';
update public.wr_situations set text_en = 'What keeps me in the loop?' where code = 'S3-10';

-- -------------------------------------------------------------------------
-- wr_stories — sáu cột hiển thị trong luồng đọc truyện (110 dòng)
-- -------------------------------------------------------------------------

update public.wr_stories set
  title_en = 'I''m moving fast, but where am I going?',
  story_content_en = 'You still get the work done.
You still hit your targets.
You still get good reviews.
But whenever someone asks:
"Where do you want to be in three years?"
You don''t know what to say.',
  reflection_question_en = 'Are you busier than you are headed somewhere?',
  self_reflection_en = 'What makes you believe you''re heading the right way?',
  aha_message_en = 'Losing direction isn''t the same as standing still.
Sometimes it''s moving very fast without knowing why you''re running.',
  practice_action_en = 'Write down three things you want from your career in the next three years.'
where story_id = 'A1-01';

update public.wr_stories set
  title_en = 'I want to leave, but I don''t know what I want instead',
  story_content_en = 'You think about leaving often.
But when you ask yourself:
"If I left, what would I want?"
You don''t have a clear answer.',
  reflection_question_en = 'Are you moving away from something, or towards something?',
  self_reflection_en = 'What is making you want a change?',
  aha_message_en = 'Leaving a place doesn''t mean you know where you want to go.',
  practice_action_en = 'List what you want your next job to have.'
where story_id = 'A1-02';

update public.wr_stories set
  title_en = 'I do a lot, but none of it feels meaningful',
  story_content_en = 'You finish everything that needs finishing.
But looking back at the weekend.
You struggle to answer:
"What did I make this week that mattered?"',
  reflection_question_en = 'If you looked hard, what part of this week might have mattered without you noticing?',
  self_reflection_en = 'When did you last feel proud of your work?',
  aha_message_en = 'Lasting motivation usually comes from meaning, not only from results.',
  practice_action_en = 'Note down a moment when your work clearly created value.'
where story_id = 'A1-03';

update public.wr_stories set
  title_en = 'Is my success still what I want?',
  story_content_en = 'You once badly wanted the position you have now.
Now you have it.
But the excitement didn''t arrive the way you expected.',
  reflection_question_en = 'Is there a goal you''re chasing only because you used to want it?',
  self_reflection_en = 'How have you changed over the past few years?',
  aha_message_en = 'An old goal doesn''t always fit the person you are now.',
  practice_action_en = 'Look back at a career goal you set three years ago.'
where story_id = 'A1-04';

update public.wr_stories set
  title_en = 'I don''t know what actually matters to me',
  story_content_en = 'There are too many options.
Good pay.
Interesting work.
Room to learn.
A life outside work.
You want all of it.
Which is why deciding is so hard.',
  reflection_question_en = 'If you could keep only three things about your work, which three?',
  self_reflection_en = 'What are you willing to trade, and what aren''t you?',
  aha_message_en = 'Clarity usually arrives once we know what matters most.',
  practice_action_en = 'Rank the five things that matter most to you in your work.'
where story_id = 'A1-05';

update public.wr_stories set
  title_en = 'Am I growing, or just busy?',
  story_content_en = 'Your calendar is fuller than it has ever been.
But looking back at the last six months.
You''re not sure whether you''ve grown or just done more.',
  reflection_question_en = 'If you looked hard, what small sign might show you''ve grown, even if it isn''t obvious yet?',
  self_reflection_en = 'What have you learned in the last ninety days?',
  aha_message_en = 'How much work you do doesn''t always reflect how much you''ve grown.',
  practice_action_en = 'Note three skills you''ve improved this year.'
where story_id = 'A1-06';

update public.wr_stories set
  title_en = 'I don''t feel like I belong here anymore',
  story_content_en = 'You used to understand why the company existed.
You used to believe in what you were doing.
The work is still the same.
The sense of connection isn''t.',
  reflection_question_en = 'What changed?',
  self_reflection_en = 'Do you still feel part of something bigger?',
  aha_message_en = 'People usually leave the meaning before they leave the job.',
  practice_action_en = 'Write down what your current work gives to other people.'
where story_id = 'A1-07';

update public.wr_stories set
  title_en = 'I want more, but I can''t name what',
  story_content_en = 'You feel you could be doing more.
But you can''t say what "more" actually means.',
  reflection_question_en = 'If you weren''t afraid of failing, what would you try?',
  self_reflection_en = 'What is most missing from your work right now?',
  aha_message_en = 'Many people don''t lack ability.
They lack the words for what they actually want.',
  practice_action_en = 'Finish the sentence:
"I want my work to give me more ______."'
where story_id = 'A1-08';

update public.wr_stories set
  title_en = 'Whose definition of success am I living by?',
  story_content_en = 'You''ve reached the things that get called success.
And sometimes it still feels empty.',
  reflection_question_en = 'Is the goal you''re working towards yours, or someone else''s?',
  self_reflection_en = 'What are you trying to prove?',
  aha_message_en = 'Not every success is your own.',
  practice_action_en = 'Rewrite what success means to you, as of today.'
where story_id = 'A1-09';

update public.wr_stories set
  title_en = 'What if I keep going like this for three more years?',
  story_content_en = 'Picture nothing major changing.
You''re still doing this job.
Still in this place.
Still the same way.',
  reflection_question_en = 'Does that picture excite you or worry you?',
  self_reflection_en = 'What comes to mind first?',
  aha_message_en = 'The future usually isn''t made in one big decision.
It''s made from the choices you repeat every day.',
  practice_action_en = 'Write down one small change you want to make in the next thirty days.'
where story_id = 'A1-10';

update public.wr_stories set
  title_en = 'I know what to do, but I still haven''t done it',
  story_content_en = 'You''ve thought about this many times.
You know it matters.
You know you should start.
But week after week.
It stays on the list of things you mean to do.',
  reflection_question_en = 'What is keeping you from starting?',
  self_reflection_en = 'Are you short on motivation, time, or clarity?',
  aha_message_en = 'Sometimes what blocks action isn''t difficulty.
It''s how long the delay has gone on.',
  practice_action_en = 'Name the smallest step you could take in the next twenty-four hours.'
where story_id = 'A2-01';

update public.wr_stories set
  title_en = 'I have too many plans',
  story_content_en = 'The to-do list keeps getting longer.
The ideas keep coming.
The progress doesn''t match.',
  reflection_question_en = 'Are you short on resources, or short on focus?',
  self_reflection_en = 'What genuinely matters most right now?',
  aha_message_en = 'When everything is a priority, nothing is.',
  practice_action_en = 'Choose the single most important thing for this week.'
where story_id = 'A2-02';

update public.wr_stories set
  title_en = 'I start well but can''t keep it up',
  story_content_en = 'You were determined.
One week.
Two weeks.
Then everything went back to how it was.',
  reflection_question_en = 'What made you stop?',
  self_reflection_en = 'Are you pushing too hard, or missing the support to keep going?',
  aha_message_en = 'Lasting progress usually comes from a steady pace rather than short bursts.',
  practice_action_en = 'Shrink your current goal to a size you''re certain you can manage.'
where story_id = 'A2-03';

update public.wr_stories set
  title_en = 'I''m always busy but never finish what matters',
  story_content_en = 'Every day is full.
Every task has a good reason.
And the most important thing still hasn''t moved.',
  reflection_question_en = 'What is taking up your time?',
  self_reflection_en = 'Are you reacting to the work, or leading it?',
  aha_message_en = 'Being busy isn''t the same as making progress.',
  practice_action_en = 'Note the three things that took the most time this past week.'
where story_id = 'A2-04';

update public.wr_stories set
  title_en = 'I keep changing direction',
  story_content_en = 'You get excited about new things easily.
And move on to the next one just as fast.',
  reflection_question_en = 'Are you exploring, or avoiding commitment?',
  self_reflection_en = 'What makes it hard to stay with something?',
  aha_message_en = 'Not every new idea needs to be chased straight away.',
  practice_action_en = 'Finish one unfinished thing before you start anything new.'
where story_id = 'A2-05';

update public.wr_stories set
  title_en = 'I keep waiting until I feel ready',
  story_content_en = 'You want to prepare a bit more.
Learn a bit more.
Wait for a better moment.
And months have gone by.',
  reflection_question_en = 'What is stopping you from starting?',
  self_reflection_en = 'Are you preparing, or putting it off?',
  aha_message_en = 'Very few people feel completely ready before starting something new.',
  practice_action_en = 'Make the first version instead of the perfect one.'
where story_id = 'A2-06';

update public.wr_stories set
  title_en = 'I have too many things half-finished',
  story_content_en = 'Many things have been started.
Few have actually been finished.',
  reflection_question_en = 'What usually happens in the middle?',
  self_reflection_en = 'Did you lose interest, or run into something?',
  aha_message_en = 'Finishing usually creates more value than starting.',
  practice_action_en = 'Pick one unfinished thing and close it this week.'
where story_id = 'A2-07';

update public.wr_stories set
  title_en = 'I don''t see results, so I want to give up',
  story_content_en = 'You''ve been trying.
The results haven''t shown up.
And you''re starting to doubt it.',
  reflection_question_en = 'Are you judging the process, or only the outcome?',
  self_reflection_en = 'What has changed even though the results haven''t shown yet?',
  aha_message_en = 'Many important changes happen quietly before anything visible appears.',
  practice_action_en = 'Note the small signs of progress from this week.'
where story_id = 'A2-08';

update public.wr_stories set
  title_en = 'I keep getting pulled away from what matters',
  story_content_en = 'You start the day with a clear plan.
By the end of it.
You''ve done a great deal of something else.',
  reflection_question_en = 'What usually pulls your attention away?',
  self_reflection_en = 'Do those interruptions come from outside, or from you?',
  aha_message_en = 'The ability to focus is one of the most important skills in getting things done.',
  practice_action_en = 'Give thirty minutes a day to the thing that matters most.'
where story_id = 'A2-09';

update public.wr_stories set
  title_en = 'What actually gets me to act?',
  story_content_en = 'Some things you do without fail.
Some things never get started at all.',
  reflection_question_en = 'What makes the difference?',
  self_reflection_en = 'What conditions bring out your best?',
  aha_message_en = 'Everyone has their own rhythm for getting things done.
Knowing yours makes progress last.',
  practice_action_en = 'Notice when you work best this week.'
where story_id = 'A2-10';

update public.wr_stories set
  title_en = 'Why is this happening again?',
  story_content_en = 'This isn''t the first time.
Different people.
Different project.
Different circumstances.
But the feeling is oddly familiar.
You''re disappointed in the same old way.',
  reflection_question_en = 'Is something repeating in how work goes for you?',
  self_reflection_en = 'How many times have you been in a situation like this?',
  aha_message_en = 'When an experience keeps coming back, sometimes it''s trying to teach you something.',
  practice_action_en = 'Write down a problem that has come up at least three times this year.'
where story_id = 'A3-01';

update public.wr_stories set
  title_en = 'I know I''m tired, but I don''t know why',
  story_content_en = 'You''re sleeping enough.
The workload isn''t crushing.
From the outside everything looks fine.
And you still feel drained.',
  reflection_question_en = 'What is taking your energy?',
  self_reflection_en = 'When did you last genuinely feel full of energy?',
  aha_message_en = 'Exhaustion doesn''t only come from doing too much.
Sometimes it comes from doing something for too long after it stopped meaning anything.',
  practice_action_en = 'Note what gave you energy and what drained it this week.'
where story_id = 'A3-02';

update public.wr_stories set
  title_en = 'I reacted more strongly than the moment needed',
  story_content_en = 'A small piece of feedback.
A short email.
An ordinary meeting.
And you carried that uneasy feeling all day.',
  reflection_question_en = 'What about that moment made you react so strongly?',
  self_reflection_en = 'What other experience did it remind you of?',
  aha_message_en = 'Sometimes what hurts isn''t the thing that just happened.
It''s the meaning we attach to it.',
  practice_action_en = 'Next time a strong feeling arrives, ask:
"What is actually being touched here?"'
where story_id = 'A3-03';

update public.wr_stories set
  title_en = 'I''m always busy but I don''t see progress',
  story_content_en = 'You do a great deal.
But looking back at the last six months.
You don''t know what you changed.',
  reflection_question_en = 'If you tried to remember, what small change might you have overlooked?',
  self_reflection_en = 'What are you measuring growth by?',
  aha_message_en = 'What never gets written down is very hard to see.',
  practice_action_en = 'Note three things you do better than you did six months ago.'
where story_id = 'A3-04';

update public.wr_stories set
  title_en = 'I keep deciding on feeling alone',
  story_content_en = 'Under pressure.
You want to quit.
After praise.
Everything seems fine.
The mood shifts.
And the decision shifts with it.',
  reflection_question_en = 'What state are you usually in when you make big decisions?',
  self_reflection_en = 'When do your best decisions tend to appear?',
  aha_message_en = 'Feelings are data.
They shouldn''t be the driver.',
  practice_action_en = 'Before a big decision, write down what you''re feeling.'
where story_id = 'A3-05';

update public.wr_stories set
  title_en = 'I can''t remember what I''ve learned',
  story_content_en = 'You''ve been on many projects.
Solved many problems.
Got through many hard patches.
But if someone asked:
"What did you learn this past year?"
You''d struggle to answer.',
  reflection_question_en = 'Which lessons are you leaving behind?',
  self_reflection_en = 'What deserved to be written down?',
  aha_message_en = 'Experience only becomes wisdom once you look back at it.',
  practice_action_en = 'Write out one important lesson from the past month.'
where story_id = 'A3-06';

update public.wr_stories set
  title_en = 'I feel stuck',
  story_content_en = 'There''s no crisis.
But nothing is moving forward either.
Everything feels like it''s standing still.',
  reflection_question_en = 'Where exactly are you stuck?',
  self_reflection_en = 'What is keeping you from moving on?',
  aha_message_en = 'Feeling stuck often shows up right before something important shifts.',
  practice_action_en = 'Name one small step you could take this week.'
where story_id = 'A3-07';

update public.wr_stories set
  title_en = 'I always think I should be doing better',
  story_content_en = 'Even when the result is good.
All you see is the part that wasn''t good enough.',
  reflection_question_en = 'Are you harder on yourself than you''d be on anyone else?',
  self_reflection_en = 'If you were your own colleague, what would you say?',
  aha_message_en = 'Growth needs honest feedback.
It doesn''t need constant criticism.',
  practice_action_en = 'Write down one thing you did well today.'
where story_id = 'A3-08';

update public.wr_stories set
  title_en = 'What am I avoiding looking at?',
  story_content_en = 'There''s a problem you noticed a long time ago.
And you keep putting off facing it.',
  reflection_question_en = 'Is there something you know but aren''t ready to admit?',
  self_reflection_en = 'What makes it hard?',
  aha_message_en = 'The hardest thing to look at is usually the thing that most needs looking at.',
  practice_action_en = 'Write down one truth you''re avoiding.'
where story_id = 'A3-09';

update public.wr_stories set
  title_en = 'What if I stopped for ten minutes to look back?',
  story_content_en = 'You''re always busy.
There''s always a next task.
Always a next deadline.
And it''s been a long time since you asked yourself:
"How am I actually doing?"',
  reflection_question_en = 'When did you last take time to look at yourself?',
  self_reflection_en = 'What comes up if you stop for a few minutes?',
  aha_message_en = 'We don''t always need to do more.
Sometimes we need to notice more.',
  practice_action_en = 'Give the last ten minutes of the day to one question:
"What stayed with me today?"'
where story_id = 'A3-10';

update public.wr_stories set
  title_en = 'I keep making the same mistake',
  story_content_en = 'You''ve just run into a familiar problem again.
The hard part isn''t that it happened.
It''s that you once promised yourself it wouldn''t.',
  reflection_question_en = 'Is there a lesson you''ve seen but haven''t really used?',
  self_reflection_en = 'What keeps it coming back?',
  aha_message_en = 'Knowing a lesson isn''t the same as having learned it.',
  practice_action_en = 'Write down one concrete action to stop this repeating.'
where story_id = 'A4-01';

update public.wr_stories set
  title_en = 'How did I get through that?',
  story_content_en = 'Something used to weigh on you a great deal.
Today it doesn''t reach you the same way.',
  reflection_question_en = 'What did you change to get past it?',
  self_reflection_en = 'What made you more grown up about it?',
  aha_message_en = 'The things that were hardest usually hold the most to learn from.',
  practice_action_en = 'Write about something you managed that you once thought impossible.'
where story_id = 'A4-02';

update public.wr_stories set
  title_en = 'What did this failure teach me?',
  story_content_en = 'It didn''t go the way you hoped.
You can blame yourself for it.
Or you can learn from it.',
  reflection_question_en = 'If this failure were a teacher, what is it teaching you?',
  self_reflection_en = 'What will you do differently next time?',
  aha_message_en = 'A failure is only truly wasted when nothing is learned from it.',
  practice_action_en = 'Write down three lessons from this experience.'
where story_id = 'A4-03';

update public.wr_stories set
  title_en = 'In what way am I growing?',
  story_content_en = 'We tend to look at what isn''t there yet.
And forget to look at what has changed.',
  reflection_question_en = 'Where are you better than you were a year ago?',
  self_reflection_en = 'Which skills or perspectives have shifted?',
  aha_message_en = 'Progress is often so slow it''s hard to notice.',
  practice_action_en = 'List five things you do better than you used to.'
where story_id = 'A4-04';

update public.wr_stories set
  title_en = 'What signal did I miss?',
  story_content_en = 'Looking back.
You can see the signs were there early.
You just weren''t paying attention then.',
  reflection_question_en = 'Which signals did you let pass?',
  self_reflection_en = 'If you met the same situation again, what would you watch for?',
  aha_message_en = 'Experience lets us see what we used to walk past.',
  practice_action_en = 'Note the early warning signs you want to remember.'
where story_id = 'A4-05';

update public.wr_stories set
  title_en = 'Am I learning, or just going through it?',
  story_content_en = 'You''ve joined a lot of projects.
Taken a lot of courses.
Had a lot of chances.
And the sense of growth doesn''t match.',
  reflection_question_en = 'Are you collecting experiences, or collecting lessons?',
  self_reflection_en = 'What has changed in how you work?',
  aha_message_en = 'An experience only pays off once it turns into understanding or action.',
  practice_action_en = 'Pick a recent experience and write down what you learned.'
where story_id = 'A4-06';

update public.wr_stories set
  title_en = 'Am I repeating what works?',
  story_content_en = 'There was a stretch when work went really well.
Plenty of energy.
Plenty of progress.
And then it went away.',
  reflection_question_en = 'What was making it work back then?',
  self_reflection_en = 'Are you still doing those things?',
  aha_message_en = 'Learning isn''t only about avoiding mistakes.
It''s also about repeating what worked.',
  practice_action_en = 'Write down three things you''d like to recreate from your best stretch.'
where story_id = 'A4-07';

update public.wr_stories set
  title_en = 'What is this teaching me about myself?',
  story_content_en = 'Something just happened.
Good or bad.
But the more interesting question is:
What is it telling you about yourself?',
  reflection_question_en = 'What do you understand about yourself now that you didn''t before?',
  self_reflection_en = 'What surprised you most?',
  aha_message_en = 'Every experience is a mirror.',
  practice_action_en = 'Write one new thing you''ve just discovered about yourself.'
where story_id = 'A4-08';

update public.wr_stories set
  title_en = 'How did I come to change my mind?',
  story_content_en = 'There are decisions you wouldn''t make the same way you would have a few years ago.',
  reflection_question_en = 'What changed in how you think?',
  self_reflection_en = 'Which experience shaped that most?',
  aha_message_en = 'Growing up usually shows in how we decide.',
  practice_action_en = 'Compare how you''d handle a current problem with how you would have three years ago.'
where story_id = 'A4-09';

update public.wr_stories set
  title_en = 'If I read this year back as one chapter',
  story_content_en = 'Imagine this year as one chapter in the book of your working life.',
  reflection_question_en = 'What would that chapter be called?',
  self_reflection_en = 'What is the biggest lesson of this chapter?',
  aha_message_en = 'Growth isn''t measured in years worked.
It''s measured in the lessons collected from those years.',
  practice_action_en = 'Write the title of this year and its biggest lesson.'
where story_id = 'A4-10';

update public.wr_stories set
  title_en = 'I ended up doing it for them again',
  story_content_en = 'You handed the work over.
You agreed a deadline.
You checked in on it.
And at the last minute.
You still had to step in and fix it.',
  reflection_question_en = 'What made trust hard in this situation?',
  self_reflection_en = 'Is this a one-off, or something that keeps happening?',
  aha_message_en = 'Trust isn''t lost the first time a promise slips.
It''s lost when that becomes the pattern.',
  practice_action_en = 'Note a situation where you felt you had to carry someone else''s work.'
where story_id = 'C1-01';

update public.wr_stories set
  title_en = 'I always have to double-check',
  story_content_en = 'You hand the work over.
And then keep watching it.
Keep reminding.
Keep checking.',
  reflection_question_en = 'What makes it hard to let go of control?',
  self_reflection_en = 'Are you short on trust, or short on information?',
  aha_message_en = 'Not all control comes from responsibility.
Some of it comes from not trusting.',
  practice_action_en = 'Name one thing you could hand over more fully this week.'
where story_id = 'C1-02';

update public.wr_stories set
  title_en = 'People say one thing and do another',
  story_content_en = 'In the meeting.
Everyone agreed.
After the meeting.
It all went a completely different way.',
  reflection_question_en = 'How do you react when words and actions don''t match?',
  self_reflection_en = 'How does that affect the way you work with people?',
  aha_message_en = 'Trust is built through consistency, not through promises.',
  practice_action_en = 'Watch someone you find trustworthy and note what they do differently.'
where story_id = 'C1-03';

update public.wr_stories set
  title_en = 'I don''t know who I can ask',
  story_content_en = 'You hit a hard problem.
But you don''t know who could help.
Or you''re not sure who would be willing to.',
  reflection_question_en = 'Do you feel alone in your work?',
  self_reflection_en = 'Who can you go to when things get hard?',
  aha_message_en = 'Trust isn''t only believing others will do the work.
It''s believing you won''t have to face it alone.',
  practice_action_en = 'List three people you could turn to for support.'
where story_id = 'C1-04';

update public.wr_stories set
  title_en = 'I hold back because I''m afraid of being let down',
  story_content_en = 'You chose to do it yourself.
Not because it was faster.
But because you didn''t want to be let down again.',
  reflection_question_en = 'Are you protecting the work, or protecting yourself?',
  self_reflection_en = 'What made you stop expecting anything from others?',
  aha_message_en = 'Sometimes not trusting is what leaves us on our own.',
  practice_action_en = 'Name one small thing you could share with someone else.'
where story_id = 'C1-05';

update public.wr_stories set
  title_en = 'I''m not sure my manager will keep their word',
  story_content_en = 'Commitments were made.
And then they didn''t happen.
Once.
Then more than once.',
  reflection_question_en = 'What cost you the most trust?',
  self_reflection_en = 'Do you still believe those commitments?',
  aha_message_en = 'Trust in an organisation is usually built or lost in very small things.',
  practice_action_en = 'Note one commitment that was kept and one that wasn''t.'
where story_id = 'C1-06';

update public.wr_stories set
  title_en = 'I find it hard to ask for help',
  story_content_en = 'You''re overloaded.
And you still choose to manage alone.
Not because you don''t need help.
But because you don''t believe asking would help.',
  reflection_question_en = 'What makes you hesitate to look for support?',
  self_reflection_en = 'When did you last get help that actually helped?',
  aha_message_en = 'Trust doesn''t only show in what you give.
It shows in whether you can accept support.',
  practice_action_en = 'Ask someone for help with one specific thing this week.'
where story_id = 'C1-07';

update public.wr_stories set
  title_en = 'I don''t know what other people are thinking',
  story_content_en = 'Nobody says anything.
Everything carries on as normal.
And you always feel like you''re missing something.',
  reflection_question_en = 'Do you have enough information to feel at ease?',
  self_reflection_en = 'What is making you doubt?',
  aha_message_en = 'Trust grows best where things are in the open.',
  practice_action_en = 'Name one piece of information you need to work better.'
where story_id = 'C1-08';

update public.wr_stories set
  title_en = 'I used to trust them, and now I don''t',
  story_content_en = 'There was a time you trusted someone completely.
Then something happened that changed it.',
  reflection_question_en = 'What changed that trust?',
  self_reflection_en = 'Are you losing trust in a person, or in a kind of experience?',
  aha_message_en = 'One bad experience can colour how we see many other relationships.',
  practice_action_en = 'Separate the specific person from the specific experience.'
where story_id = 'C1-09';

update public.wr_stories set
  title_en = 'I feel at ease working with them',
  story_content_en = 'There are people whose names on a project.
Are enough to make you breathe out.
Not because they''re perfect.
But because you know they''ll do what they said.',
  reflection_question_en = 'Who do you feel most at ease working with?',
  self_reflection_en = 'What creates that feeling?',
  aha_message_en = 'Trust isn''t a vague feeling.
It''s built from very specific behaviour, repeated.',
  practice_action_en = 'Note three behaviours that make you trust someone.'
where story_id = 'C1-10';

update public.wr_stories set
  title_en = 'Your idea disappears in the meeting',
  story_content_en = 'You had prepared carefully.
When the meeting started, you shared your idea.
Nobody responded.
The conversation moved on as if it had never been said.
Ten minutes later, someone else made the same point.
This time everyone was interested.',
  reflection_question_en = 'How familiar does this feel?',
  self_reflection_en = 'When did you last feel your voice went unseen?',
  aha_message_en = 'Sometimes what keeps us quiet isn''t a shortage of ideas.
It''s having spoken up before and seen nothing change.',
  practice_action_en = 'This week, note one moment when you wanted to speak and chose not to.'
where story_id = 'C2-01';

update public.wr_stories set
  title_en = 'The meeting ended and the most important thing went unsaid',
  story_content_en = 'You spotted a serious risk in the plan.
You thought about saying it.
Then told yourself:
"They probably already know."
"I''m probably overthinking it."
The meeting ended.
Nobody mentioned it.',
  reflection_question_en = 'How many times have you held back what you really wanted to say?',
  self_reflection_en = 'What usually makes you hesitate to speak up?',
  aha_message_en = 'Many organisations aren''t short of ideas.
They''re short of people who feel safe enough to say what they see.',
  practice_action_en = 'Write down one thing you''re holding back that you think the team should know.'
where story_id = 'C2-02';

update public.wr_stories set
  title_en = 'You agree even though you don’t',
  story_content_en = 'You knew the chosen option wasn''t the best one.
But everyone else agreed.
You didn''t want to be the only one objecting.
You nodded.
The meeting moved on.',
  reflection_question_en = 'Do you often agree just to avoid an argument?',
  self_reflection_en = 'What makes it hard to voice a different view?',
  aha_message_en = 'Agreement isn''t always a sign that people agree.
Sometimes it''s just a sign that everyone went quiet.',
  practice_action_en = 'Next time you see it differently, try asking a question instead of objecting outright.'
where story_id = 'C2-03';

update public.wr_stories set
  title_en = 'You get cut off mid-sentence',
  story_content_en = 'You were mid-sentence.
Someone cut across you.
The conversation turned.
Nobody came back to what you were saying.
You stopped.',
  reflection_question_en = 'How did that leave you feeling?',
  self_reflection_en = 'After moments like that, do you change how you take part in meetings?',
  aha_message_en = 'A few small experiences, repeated, can pull people out of the room more than we realise.',
  practice_action_en = 'Notice whether anyone gets cut off in a meeting this week.'
where story_id = 'C2-04';

update public.wr_stories set
  title_en = 'You want to speak up but fear upsetting people',
  story_content_en = 'You could see a colleague struggling.
You knew one small piece of feedback could help.
But you worried they''d take it the wrong way.
In the end you said nothing.',
  reflection_question_en = 'Do you often hold back feedback to protect the relationship?',
  self_reflection_en = 'What did your earlier workplaces teach you about feedback?',
  aha_message_en = 'Many people don''t dodge feedback because they don''t care.
They dodge it because they care too much about the relationship.',
  practice_action_en = 'Try giving one specific, positive piece of feedback this week.'
where story_id = 'C2-05';

update public.wr_stories set
  title_en = 'You take the blame instead of explaining',
  story_content_en = 'Something went wrong.
There were several reasons.
But explaining felt like it would only make things messier.
You took the blame.
And closed the conversation quickly.',
  reflection_question_en = 'Do you often go quiet to avoid being judged?',
  self_reflection_en = 'What do you fear most when you get something wrong?',
  aha_message_en = 'When people are afraid of being judged, they tend to protect the image rather than share what happened.',
  practice_action_en = 'Note the last time you got something wrong and what you took from it.'
where story_id = 'C2-06';

update public.wr_stories set
  title_en = 'You have a question and don’t ask it',
  story_content_en = 'Everyone seems to have understood.
Only you feel unclear.
You want to ask.
But you''re afraid the question is too basic.
You stay quiet.',
  reflection_question_en = 'Do you often pretend to understand to avoid feeling awkward?',
  self_reflection_en = 'What makes it hard to ask?',
  aha_message_en = 'The questions that never get asked usually cost far more than the ones that do.',
  practice_action_en = 'This week, ask about one thing you genuinely don''t understand.'
where story_id = 'C2-07';

update public.wr_stories set
  title_en = 'You are asked for input but don’t believe it will change anything',
  story_content_en = 'Surveys.
Workshops.
Town halls.
Everyone is invited to share their view.
You joined in before.
And saw nothing change.
This time you skip it.',
  reflection_question_en = 'Do you still believe your voice can make a difference?',
  self_reflection_en = 'What wore that belief down?',
  aha_message_en = 'People don''t stop speaking up because they''ve run out of views.
They stop because nothing has shown them their views count.',
  practice_action_en = 'Write down the one small change you''d most like to see where you work.'
where story_id = 'C2-08';

update public.wr_stories set
  title_en = 'You are always the last one to speak',
  story_content_en = 'You have a view.
But you always wait for others to speak first.
You want to be sure your idea isn''t too far off.
Sometimes the meeting ends before your turn comes.',
  reflection_question_en = 'Do you usually speak to contribute, or to avoid being wrong?',
  self_reflection_en = 'What happens if you''re the one who speaks first?',
  aha_message_en = 'Confidence doesn''t always come before the act.
Sometimes it shows up after enough tries.',
  practice_action_en = 'In your next meeting, try speaking earlier than you normally would.'
where story_id = 'C2-09';

update public.wr_stories set
  title_en = 'You used to speak up a lot, and now you don’t',
  story_content_en = 'Your first day at the company.
You were full of ideas.
You wanted to contribute.
You wanted to change something.
You still work hard now.
But the eagerness to join in has gone.',
  reflection_question_en = 'What changed?',
  self_reflection_en = 'When did you start pulling back?',
  aha_message_en = 'People don''t disengage in a day.
It fades after enough moments of feeling your voice didn''t land.',
  practice_action_en = 'Think back to when you were fully engaged. What was different then?'
where story_id = 'C2-10';

update public.wr_stories set
  title_en = 'I know there''s a problem and I don''t want to raise it',
  story_content_en = 'There''s a problem sitting there.
You can see it.
But you decide to stay quiet.
Not because you don''t care.
But because you don''t know how to say it.',
  reflection_question_en = 'Is there something you''re avoiding bringing up?',
  self_reflection_en = 'What makes that conversation hard?',
  aha_message_en = 'What goes unsaid usually doesn''t go away on its own.',
  practice_action_en = 'Write down the thing you want to say but never have.'
where story_id = 'C3-01';

update public.wr_stories set
  title_en = 'Every piece of feedback turns into an argument',
  story_content_en = 'You want to give feedback.
But the other person explains or pushes back straight away.',
  reflection_question_en = 'What usually happens when you give feedback?',
  self_reflection_en = 'Are you trying to be right, or trying to understand each other?',
  aha_message_en = 'A good conversation starts with curiosity, not with who''s right.',
  practice_action_en = 'In your next conversation, ask one more question before giving your view.'
where story_id = 'C3-02';

update public.wr_stories set
  title_en = 'We only talk about the work, never the problem',
  story_content_en = 'The meetings happen on schedule.
The work gets updated.
And the things that actually matter never come up.',
  reflection_question_en = 'Is there a topic everyone always steers around?',
  self_reflection_en = 'What makes that topic sensitive?',
  aha_message_en = 'Not every exchange creates understanding.',
  practice_action_en = 'Name one important topic that rarely gets discussed.'
where story_id = 'C3-03';

update public.wr_stories set
  title_en = 'I don''t feel understood',
  story_content_en = 'You tried to explain.
But it felt like the other person was only waiting to reply.',
  reflection_question_en = 'When did you last feel genuinely heard?',
  self_reflection_en = 'What creates that feeling?',
  aha_message_en = 'Being heard usually matters more than being agreed with.',
  practice_action_en = 'Watch one conversation and count how often you actually listened.'
where story_id = 'C3-04';

update public.wr_stories set
  title_en = 'We always read the same thing differently',
  story_content_en = 'After the meeting.
Everyone walks away with a different version.',
  reflection_question_en = 'Do you often have to go back and clarify what was agreed?',
  self_reflection_en = 'What is getting missed in the exchange?',
  aha_message_en = 'A conversation isn''t only speaking.
It''s arriving at the same understanding.',
  practice_action_en = 'After an important conversation, try summarising what you understood.'
where story_id = 'C3-05';

update public.wr_stories set
  title_en = 'I''m afraid of making other people uncomfortable',
  story_content_en = 'You''ve noticed a problem.
But you don''t want to raise it in case it damages the relationship.',
  reflection_question_en = 'What do you usually hold back when you talk?',
  self_reflection_en = 'What are you trying to protect?',
  aha_message_en = 'Being kind doesn''t mean avoiding the truth.',
  practice_action_en = 'Choose one small, honest piece of feedback to give.'
where story_id = 'C3-06';

update public.wr_stories set
  title_en = 'The meeting ended and the problem is still there',
  story_content_en = 'There was plenty of discussion.
And afterwards nothing changed.',
  reflection_question_en = 'Do your discussions lead to action?',
  self_reflection_en = 'What is missing?',
  aha_message_en = 'A good conversation creates understanding.
An excellent one creates movement.',
  practice_action_en = 'Name the specific next action after a conversation.'
where story_id = 'C3-07';

update public.wr_stories set
  title_en = 'I always have to guess what people mean',
  story_content_en = 'Nobody says it straight.
Everyone uses very safe wording.',
  reflection_question_en = 'Do you often have to guess what people actually mean?',
  self_reflection_en = 'How does that affect the work?',
  aha_message_en = 'Clarity saves an enormous amount of emotional energy.',
  practice_action_en = 'Try saying what you need a little more plainly.'
where story_id = 'C3-08';

update public.wr_stories set
  title_en = 'We talk, but we don''t connect',
  story_content_en = 'People talk often enough.
And it still feels distant.',
  reflection_question_en = 'What is missing from the conversations you''re having?',
  self_reflection_en = 'Do you actually know what the other person is thinking?',
  aha_message_en = 'How often you communicate isn''t the same as how well.',
  practice_action_en = 'Ask one deeper question in your next conversation.'
where story_id = 'C3-09';

update public.wr_stories set
  title_en = 'Which conversation needs to happen?',
  story_content_en = 'There are conversations you know you need to have.
And still haven''t started.',
  reflection_question_en = 'Which conversation are you putting off?',
  self_reflection_en = 'What is making you not ready?',
  aha_message_en = 'Many important turning points start with one brave conversation.',
  practice_action_en = 'Write the opening line for that conversation.'
where story_id = 'C3-10';

update public.wr_stories set
  title_en = 'I just finished something harder than I expected',
  story_content_en = 'I was anxious before I started.
The deadline was tight.
The brief wasn''t clear at first.
But I got it done, and it turned out better than I thought.',
  reflection_question_en = 'What helped you get through this one?',
  self_reflection_en = 'Do you often stop to acknowledge the times you did well?',
  aha_message_en = 'Success slips out of memory faster than difficulty does. Stopping to hold onto it is a form of reflection too.',
  practice_action_en = 'Note the specific thing I got right here, so I can do it again.'
where story_id = 'P-01';

update public.wr_stories set
  title_en = 'My manager recognised my work',
  story_content_en = 'I wasn''t expecting it.
But in a short conversation, my manager said they valued how I''d handled things recently.',
  reflection_question_en = 'What did that recognition touch in you?',
  self_reflection_en = 'Do you believe it, or is part of you still doubting?',
  aha_message_en = 'Recognition from someone else counts, but it lands properly when I give it to myself as well.',
  practice_action_en = 'Write down their exact words, and one line I tell myself to keep this feeling.'
where story_id = 'P-02';

update public.wr_stories set
  title_en = 'I helped a colleague untangle something hard',
  story_content_en = 'They had been stuck for a while.
I didn''t have the perfect answer, but I asked a few questions and looked at the problem with them.
In the end they found their own way forward.',
  reflection_question_en = 'What made you willing to stop and help, even when you had your own work on?',
  self_reflection_en = 'How does helping someone feel different from finishing something yourself?',
  aha_message_en = 'Sometimes the most valuable thing I bring isn''t the answer, but staying present long enough for someone to find their own.',
  practice_action_en = 'Message them to ask whether that direction actually worked out.'
where story_id = 'P-03';

update public.wr_stories set
  title_en = 'I got a raise or a promotion',
  story_content_en = 'After a long stretch of work, it finally came through.
I''m glad, and also a little stunned, as if it hasn''t landed yet.',
  reflection_question_en = 'What in the journey so far led you here?',
  self_reflection_en = 'Are you letting yourself enjoy this, or already thinking about the next pressure?',
  aha_message_en = 'A good result brings new expectations very quickly. But letting myself stop and mark it is part of the journey, not a distraction from it.',
  practice_action_en = 'Do one small thing to mark it before thinking about the next step.'
where story_id = 'P-04';

update public.wr_stories set
  title_en = 'Someone thanked me out of the blue',
  story_content_en = 'I didn''t think what I''d done was worth mentioning.
But someone went out of their way to thank me, and it caught me off guard.',
  reflection_question_en = 'What have you done that felt small to you but mattered to someone else?',
  self_reflection_en = 'Do you tend to undervalue your own quiet contributions?',
  aha_message_en = 'The things I think of as ordinary are sometimes what other people remember longest.',
  practice_action_en = 'Write it down, as a reminder that small contributions carry real weight.'
where story_id = 'P-05';

update public.wr_stories set
  title_en = 'Today went the way I hoped it would',
  story_content_en = 'No surprises.
No emergencies.
Everything I planned happened the way I planned it.',
  reflection_question_en = 'How often do days like this come around for you?',
  self_reflection_en = 'Do you give steady days any weight, or only notice when something happens?',
  aha_message_en = 'Steadiness gets taken for granted, when it is really the result of a great deal done right behind the scenes.',
  practice_action_en = 'Note one thing that helped today go smoothly.'
where story_id = 'P-06';

update public.wr_stories set
  title_en = 'I felt in control of my own pace today',
  story_content_en = 'I wasn''t chasing a deadline.
I knew what had to come first and what could wait.
This feeling is fairly rare.',
  reflection_question_en = 'What was different today compared with the days you feel swept along?',
  self_reflection_en = 'How long could you hold this pace?',
  aha_message_en = 'Owning your pace doesn''t mean doing less. It means knowing what genuinely needs your attention right now.',
  practice_action_en = 'Note how I arranged today''s work, so I can try it again another day.'
where story_id = 'P-07';

update public.wr_stories set
  title_en = 'I learned something small but useful',
  story_content_en = 'Nothing dramatic.
But it helps me do a familiar task in a better way.',
  reflection_question_en = 'Could this small thing change how you work over time?',
  self_reflection_en = 'Do you skip small lessons because they don''t feel big enough to keep?',
  aha_message_en = 'Most progress doesn''t come from big turning points, but from a great many small things adding up.',
  practice_action_en = 'Write down what I just learned, in my own words.'
where story_id = 'P-08';

update public.wr_stories set
  title_en = 'I had a good conversation with a colleague',
  story_content_en = 'Not an important meeting.
Just a short conversation, but I came away feeling lighter.',
  reflection_question_en = 'What made that conversation different from the everyday ones?',
  self_reflection_en = 'Are you giving enough time to connections like this?',
  aha_message_en = 'Good working relationships usually aren''t built in big meetings, but in a great many small conversations like this one.',
  practice_action_en = 'Start one more conversation like it this week.'
where story_id = 'P-09';

update public.wr_stories set
  title_en = 'Nothing special happened today, and I feel fine',
  story_content_en = 'If I had to retell it, I wouldn''t remember much detail.
But the overall feeling was easy, nothing weighing on me.',
  reflection_question_en = 'Do you give these ordinary days any credit, or do you only remember the turbulent ones?',
  self_reflection_en = 'What is going well that you rarely notice?',
  aha_message_en = 'Not every experience worth keeping is dramatic. Sometimes calm is important data too.',
  practice_action_en = 'Write one line about how today felt, even with nothing to report.'
where story_id = 'P-10';

update public.wr_stories set
  title_en = 'I don''t know what good looks like here',
  story_content_en = 'You try to get the work done.
But there''s always the feeling:
"Am I doing what they actually expect?"',
  reflection_question_en = 'Do you know what a good result looks like in your current job?',
  self_reflection_en = 'Who defines success for your role?',
  aha_message_en = 'When expectations are unclear, confidence is hard to come by.',
  practice_action_en = 'Write down the three most important results your role has to produce.'
where story_id = 'S1-01';

update public.wr_stories set
  title_en = 'Everything ends up on my desk',
  story_content_en = 'You keep picking up extra work.
Not because it''s your responsibility.
But because nobody is clear on whose it is.',
  reflection_question_en = 'Are you carrying work that should belong to someone else?',
  self_reflection_en = 'What keeps that happening?',
  aha_message_en = 'A blurry role usually creates overload.',
  practice_action_en = 'Note one task you don''t think belongs to your role.'
where story_id = 'S1-02';

update public.wr_stories set
  title_en = 'I don''t know what to prioritise',
  story_content_en = 'There''s too much to do.
And everything gets called "important".',
  reflection_question_en = 'Do you know what matters most in your current role?',
  self_reflection_en = 'If you finished only one thing this week, what should it be?',
  aha_message_en = 'A clear role makes clear priorities possible.',
  practice_action_en = 'Name the single most important measure for your current role.'
where story_id = 'S1-03';

update public.wr_stories set
  title_en = 'I always feel like I''m not good enough',
  story_content_en = 'You work hard.
And you still aren''t sure whether you''re doing well.',
  reflection_question_en = 'What are you measuring yourself against?',
  self_reflection_en = 'Are those standards actually clear?',
  aha_message_en = 'Long stretches of uncertainty usually come from missing standards.',
  practice_action_en = 'List what success is judged on in your current role.'
where story_id = 'S1-04';

update public.wr_stories set
  title_en = 'I get instructions that contradict each other',
  story_content_en = 'One person wants it fast.
Another wants it thorough.
You try to do both.',
  reflection_question_en = 'How many different expectations are you trying to meet?',
  self_reflection_en = 'Which expectation actually matters?',
  aha_message_en = 'Not every expectation carries equal weight.',
  practice_action_en = 'Work out who the most important stakeholder in your role is.'
where story_id = 'S1-05';

update public.wr_stories set
  title_en = 'I don''t understand why this is mine to do',
  story_content_en = 'You finish the task.
But you can''t see the point of it.',
  reflection_question_en = 'Do you understand what this work contributes to?',
  self_reflection_en = 'Who benefits from the work you do?',
  aha_message_en = 'People connect more with work when they understand the purpose behind it.',
  practice_action_en = 'Write down who benefits from your work.'
where story_id = 'S1-06';

update public.wr_stories set
  title_en = 'I don''t know how far my decisions can go',
  story_content_en = 'You want to take the lead.
But you''re afraid of overstepping.',
  reflection_question_en = 'Do you know what you''re allowed to decide?',
  self_reflection_en = 'What makes you hesitate?',
  aha_message_en = 'Unclear authority makes people less willing to act.',
  practice_action_en = 'List three things you can decide without asking anyone.'
where story_id = 'S1-07';

update public.wr_stories set
  title_en = 'My role is shifting',
  story_content_en = 'The job isn''t what it was when you started.
But nobody has actually said so.',
  reflection_question_en = 'How has your role changed?',
  self_reflection_en = 'Are you being expected to do something different now?',
  aha_message_en = 'Roles always evolve, but expectations don''t always get updated.',
  practice_action_en = 'Compare your role now with a year ago.'
where story_id = 'S1-08';

update public.wr_stories set
  title_en = 'I don''t know what counts as enough',
  story_content_en = 'However much you get done.
There''s always more.',
  reflection_question_en = 'Do you know where a reasonable finishing point is?',
  self_reflection_en = 'Who is defining "enough"?',
  aha_message_en = 'Without a clear edge, people burn out.',
  practice_action_en = 'Decide what "good enough" means for one important task.'
where story_id = 'S1-09';

update public.wr_stories set
  title_en = 'What was I actually hired to do?',
  story_content_en = 'After years of working.
You notice you spend most of your time on things that weren''t the reason you were hired.',
  reflection_question_en = 'If you described your current role in one sentence, what would you write?',
  self_reflection_en = 'Are you doing the job you''re actually expected to do?',
  aha_message_en = 'Clarity starts with understanding what your role is really for.',
  practice_action_en = 'Rewrite your own job description in plain language.'
where story_id = 'S1-10';

update public.wr_stories set
  title_en = 'I don''t know who to go to for this',
  story_content_en = 'You hit a problem.
But you don''t know who the right person to help is.
You ask around.
And each person points you at someone else.',
  reflection_question_en = 'When you get stuck, do you know who to go to?',
  self_reflection_en = 'What makes finding the right person hard?',
  aha_message_en = 'Working well together starts with knowing who holds what.',
  practice_action_en = 'List three people you usually turn to for support.'
where story_id = 'S2-01';

update public.wr_stories set
  title_en = 'I''m always waiting on someone else',
  story_content_en = 'You''ve finished your part.
But the project isn''t moving.
Because it''s waiting on someone else.',
  reflection_question_en = 'What usually slows the work down?',
  self_reflection_en = 'Can you see the whole process?',
  aha_message_en = 'Bottlenecks usually sit where two roles meet.',
  practice_action_en = 'Work out which step in the process causes the most delay.'
where story_id = 'S2-02';

update public.wr_stories set
  title_en = 'We did the same work without knowing',
  story_content_en = 'After days of work.
You find out a colleague has been doing much the same thing.',
  reflection_question_en = 'Do you often run into duplicated work?',
  self_reflection_en = 'What made that happen?',
  aha_message_en = 'Weak coordination usually creates waste nobody can see.',
  practice_action_en = 'Watch one piece of work that several people are on.'
where story_id = 'S2-03';

update public.wr_stories set
  title_en = 'The work keeps getting passed back and forth',
  story_content_en = 'When something goes wrong.
Nobody is sure it''s theirs to handle.',
  reflection_question_en = 'When something breaks, how do people react?',
  self_reflection_en = 'Who is ultimately responsible?',
  aha_message_en = 'Work stalls easily when ownership isn''t clear.',
  practice_action_en = 'Work out who owns the final result of one important task.'
where story_id = 'S2-04';

update public.wr_stories set
  title_en = 'We read the same goal differently',
  story_content_en = 'Everyone is putting in the effort.
In different directions.',
  reflection_question_en = 'Is everyone looking at the same goal?',
  self_reflection_en = 'What tends to get read differently?',
  aha_message_en = 'Working together isn''t doing things side by side.
It''s heading the same way.',
  practice_action_en = 'Ask a colleague what they think the most important goal is right now.'
where story_id = 'S2-05';

update public.wr_stories set
  title_en = 'I have to chase the same thing over and over',
  story_content_en = 'You raised it.
And still had to raise it again.
And then once more.',
  reflection_question_en = 'What usually falls through the cracks when people work together?',
  self_reflection_en = 'Is the information held in a system, or in people''s heads?',
  aha_message_en = 'The problem isn''t that people forget.
It''s that nothing helps them remember.',
  practice_action_en = 'Find one thing that depends far too much on manual reminders.'
where story_id = 'S2-06';

update public.wr_stories set
  title_en = 'I don''t understand what other people actually do',
  story_content_en = 'You know your own work inside out.
But you don''t know what pressure other people are under.',
  reflection_question_en = 'How much do you understand about what other teams do?',
  self_reflection_en = 'What would change if you understood them better?',
  aha_message_en = 'Understanding usually comes before sympathy at work.',
  practice_action_en = 'Learn how one other team''s process works.'
where story_id = 'S2-07';

update public.wr_stories set
  title_en = 'Working together is exhausting every time',
  story_content_en = 'A simple task.
That somehow needs a great many meetings and messages.',
  reflection_question_en = 'What makes working together so draining?',
  self_reflection_en = 'Is the difficulty in the people or the process?',
  aha_message_en = 'When the structure is clear, working together gets lighter.',
  practice_action_en = 'Note the steps that eat the most time when you coordinate.'
where story_id = 'S2-08';

update public.wr_stories set
  title_en = 'We depend far too much on one person',
  story_content_en = 'One person knows everything.
When they''re busy or on leave.
Almost everything stops.',
  reflection_question_en = 'Is someone becoming a bottleneck in the system?',
  self_reflection_en = 'What makes the system depend on them?',
  aha_message_en = 'A healthy system doesn''t rest on one person.',
  practice_action_en = 'Work out which knowledge or process needs to be shared more widely.'
where story_id = 'S2-09';

update public.wr_stories set
  title_en = 'What makes us work well together?',
  story_content_en = 'There are times when everything runs smoothly.
People understand each other.
The work moves quickly.',
  reflection_question_en = 'What is present when you work well together?',
  self_reflection_en = 'Could that be made to happen more often?',
  aha_message_en = 'What works deserves as much attention as what doesn''t.',
  practice_action_en = 'Note a recent time when working together went well.'
where story_id = 'S2-10';

update public.wr_stories set
  title_en = 'I don''t know where to find things',
  story_content_en = 'You know the information exists.
But not where it lives.
You have to ask several people or search for a long time.',
  reflection_question_en = 'Do you often lose time looking for information?',
  self_reflection_en = 'Which information do you hunt for most?',
  aha_message_en = 'When information is hard to reach, the energy goes before the work even starts.',
  practice_action_en = 'Note one thing you spent a long time looking for this week.'
where story_id = 'S3-01';

update public.wr_stories set
  title_en = 'I found out too late',
  story_content_en = 'You''re working in one direction.
Then find out an important change was made a while ago.',
  reflection_question_en = 'Do you often hear things after everyone else?',
  self_reflection_en = 'How did that affect your work?',
  aha_message_en = 'It isn''t only the quality of information that matters.
When it reaches you matters too.',
  practice_action_en = 'Work out what kind of information you need to hear sooner.'
where story_id = 'S3-02';

update public.wr_stories set
  title_en = 'Everyone tells me something different',
  story_content_en = 'You ask three people.
And get three different answers.',
  reflection_question_en = 'How familiar does this feel?',
  self_reflection_en = 'What makes people read it differently?',
  aha_message_en = 'Inconsistency usually causes more confusion than a shortage of information.',
  practice_action_en = 'Watch one piece of information being interpreted differently across the organisation.'
where story_id = 'S3-03';

update public.wr_stories set
  title_en = 'I don''t know which version is current',
  story_content_en = 'There are many files.
Many documents.
Many sources.
And nobody is sure which one is official.',
  reflection_question_en = 'Have you ever worked from information that was out of date?',
  self_reflection_en = 'What makes keeping it current hard?',
  aha_message_en = 'Out-of-date information usually leads to the wrong decision.',
  practice_action_en = 'Check a document you use regularly.'
where story_id = 'S3-04';

update public.wr_stories set
  title_en = 'I have to ask the same question again and again',
  story_content_en = 'Every time you need something.
You have to ask from scratch again.',
  reflection_question_en = 'What has to be explained over and over?',
  self_reflection_en = 'Why hasn''t that knowledge been written down?',
  aha_message_en = 'A good system keeps information in place even when people move on.',
  practice_action_en = 'Note one thing that should be recorded instead of passed on by word of mouth.'
where story_id = 'S3-05';

update public.wr_stories set
  title_en = 'I''m drowning in too much information',
  story_content_en = 'Messages.
Emails.
Announcements.
Documents.
All of it marked important.',
  reflection_question_en = 'Do you find it hard to keep up with how much comes at you?',
  self_reflection_en = 'Which information is genuinely useful to you?',
  aha_message_en = 'More information doesn''t mean more clarity.',
  practice_action_en = 'Cut one source that no longer earns its place.'
where story_id = 'S3-06';

update public.wr_stories set
  title_en = 'Some things only a few people know',
  story_content_en = 'You notice some people always have an edge.
Not because they''re better.
But because they know more.',
  reflection_question_en = 'Is there information that isn''t equally easy for everyone to reach?',
  self_reflection_en = 'How does that affect fairness?',
  aha_message_en = 'Information is a form of power inside a system.',
  practice_action_en = 'Name one thing that should be shared more widely.'
where story_id = 'S3-07';

update public.wr_stories set
  title_en = 'I can''t see the whole picture',
  story_content_en = 'You know what you have to do.
But not why it matters.',
  reflection_question_en = 'Do you understand how your work connects to the bigger goal?',
  self_reflection_en = 'What is missing from the picture?',
  aha_message_en = 'Information only means something once it sits in the right context.',
  practice_action_en = 'Ask about the goal or the reasoning behind a task.'
where story_id = 'S3-08';

update public.wr_stories set
  title_en = 'I don''t know what changed',
  story_content_en = 'A new process appears.
A new decision is made.
And you had no idea.',
  reflection_question_en = 'Are you often caught off guard by changes?',
  self_reflection_en = 'How is news of change getting around?',
  aha_message_en = 'Change that isn''t explained usually meets resistance.',
  practice_action_en = 'Look at a recent change and how it was communicated.'
where story_id = 'S3-09';

update public.wr_stories set
  title_en = 'What keeps me in the loop?',
  story_content_en = 'There are times when everything feels clear.
You know what''s going on.
You know what you need to do.',
  reflection_question_en = 'What creates that feeling?',
  self_reflection_en = 'Where do you get your information?',
  aha_message_en = 'Clarity usually shows up when the right information reaches you at the right time.',
  practice_action_en = 'Note the source that is most useful to you right now.'
where story_id = 'S3-10';

-- -------------------------------------------------------------------------
-- cc_questions — câu hỏi Career Health Check (49 dòng)
-- -------------------------------------------------------------------------

update public.cc_questions set question_text_en = 'When you''re given new work, what''s expected is agreed clearly from the start, such as the deadline or the standard to reach.' where id = '093947cc-7e39-497f-a7be-768c7587f6db';
update public.cc_questions set question_text_en = 'You are satisfied with how much colleagues in your team or department cooperate, share information and support each other.' where id = '0ce2902f-ac5b-4723-bc07-a5d172bdb700';
update public.cc_questions set question_text_en = 'Your manager makes room for you and backs you up when you act on an improvement, whether by clearing blockers, finding resources or acknowledging the effort.' where id = '0f84469a-ab2f-431c-85e6-ae91bf14b24d';
update public.cc_questions set question_text_en = 'After each phase of work or project, your team sets aside proper time to look back and assess what was done.' where id = '130d3f43-5c4e-417e-b77f-adf2527b7bc0';
update public.cc_questions set question_text_en = 'While the work is under way, the requirements stay consistent; if they change, you are told and given the reason.' where id = '1eee413d-75fe-4db0-b161-f37227031285';
update public.cc_questions set question_text_en = 'When work spans several departments, you find responsibilities clearly divided, without overlap or confusion.' where id = '28c14aae-ff26-41a0-9ffe-2852f2258287';
update public.cc_questions set question_text_en = 'You are satisfied with how your immediate manager gives constructive feedback and recognises your effort promptly.' where id = '298d5594-504a-4d60-aff0-50602c741ac3';
update public.cc_questions set question_text_en = 'After a review, you can see clearly what to keep and what to change next time.' where id = '2bbde0b0-8c92-43b9-a343-c54da2a8b374';
update public.cc_questions set question_text_en = 'Suggested improvements usually have someone responsible for tracking, updating and assessing how they''re going.' where id = '2d32cfe4-8b74-45f9-8030-a3b278b91322';
update public.cc_questions set question_text_en = 'When something isn''t clear in a work conversation, you always follow up to clarify it.' where id = '30e34b8e-ba2b-42cc-a745-4fbdaa0db05c';
update public.cc_questions set question_text_en = 'After important conversations, you and your colleagues usually reach agreement and have a clear plan for the next step.' where id = '30ea0b98-b0c9-44ac-ba97-0003b52d3243';
update public.cc_questions set question_text_en = 'In meetings, when work is shared out, ideas are raised or decisions are made, everything is tied clearly to the shared goal.' where id = '338ce042-b8db-4003-80fd-66c4c2429361';
update public.cc_questions set question_text_en = 'Would you recommend this company as a great place to work to a friend or family member?' where id = '36305eaa-734a-4e26-80d1-138a614741bd';
update public.cc_questions set question_text_en = 'When work changes, you are told in good time.' where id = '3d572304-4dd7-44ec-832a-20582918dec1';
update public.cc_questions set question_text_en = 'The lessons that come out are written down well enough for you and the team to refer back to.' where id = '43f26453-0f22-4508-835c-889e0fdafe7d';
update public.cc_questions set question_text_en = 'You can still share your view openly, even with your manager in the room.' where id = '54982f4e-3f72-43e7-a0f0-96b1c07fa7d3';
update public.cc_questions set question_text_en = 'You regularly review and adjust your priorities to stay close to the team''s shared goal.' where id = '55df4560-0452-4843-b3d9-9e5553837265';
update public.cc_questions set question_text_en = 'You are satisfied with the resources and direction your immediate manager gives you to get the work done.' where id = '56d0de30-a5a5-4cdb-8ee5-bfa6dcc9c0d5';
update public.cc_questions set question_text_en = 'Your team is willing to try small adjustments and keep improving based on what actually happens.' where id = '595ea147-e863-4a03-b537-c24faed047ea';
update public.cc_questions set question_text_en = 'When you work with colleagues, you find that what people say and what they do line up.' where id = '59be09a6-68ee-48fa-bc24-c30b6f269656';
update public.cc_questions set question_text_en = 'When you give feedback, you find colleagues stay on the specific situation, with clear examples or suggestions for improving.' where id = '5e08d1ba-118c-4d07-a413-7cd7966f0b27';
update public.cc_questions set question_text_en = 'You are satisfied with how open and fair the current system is in assessing performance and rewarding it.' where id = '5e1b28ce-c7ff-41af-add7-73fd060fd83a';
update public.cc_questions set question_text_en = 'When working across departments, the pace between the sides stays steady even as the workload changes.' where id = '6079d18c-7f84-48f2-9621-93cb2695d4ac';
update public.cc_questions set question_text_en = 'You are satisfied with the benefits the company provides to support employees'' lives.' where id = '65ca99d1-7038-422b-aae7-4c5c1fbe78c8';
update public.cc_questions set question_text_en = 'Important information is stored according to clear rules that people follow, so you can find it again quickly.' where id = '6a81e777-f4a3-4dc1-92b5-b0df1565b03c';
update public.cc_questions set question_text_en = 'For work that matters, you are walked through a clear process before you begin.' where id = '7b5f16f5-26e6-460f-974e-2a8d472b5932';
update public.cc_questions set question_text_en = 'When the team''s work changes or something new comes up, everyone picks it up and moves on it together.' where id = '7e273010-f901-4f94-b156-bc63e9566e00';
update public.cc_questions set question_text_en = 'You are satisfied with the vision and cultural values the leadership is building for the organisation.' where id = '7ff80914-5fcd-40c2-8c10-9e50cf20cb5c';
update public.cc_questions set question_text_en = 'When something important or urgent comes up, you always know which channel to use and how quickly.' where id = '821dd815-cb83-471f-9c58-6f700a6a0913';
update public.cc_questions set question_text_en = 'When the shared goal changes, you adjust your own work to fit the new direction without being asked.' where id = '892b5395-7f91-4fc0-bc1c-4adcfb747168';
update public.cc_questions set question_text_en = 'Your team keeps a steady rhythm of working together, such as check-ins, progress updates or short regular meetings.' where id = '8c2baafb-a182-433d-8b6c-c6e84e9b2d8f';
update public.cc_questions set question_text_en = 'The company''s shared values and principles show clearly in how people work together and make decisions day to day.' where id = '915885fb-6b33-4532-a194-49b104cd51f0';
update public.cc_questions set question_text_en = 'Your manager does what they said they would; when something changes, it is always explained to you clearly.' where id = '9204b5d6-73bb-4782-8148-359059b9b3d9';
update public.cc_questions set question_text_en = 'Processes and guidance are specific enough to follow without having to guess or fill in the gaps yourself.' where id = 'b1f7a5d3-6cfc-4492-be3e-47262ea319ed';
update public.cc_questions set question_text_en = 'The things that need changing after a review turn into concrete actions in the work that follows.' where id = 'be0e8b61-cbb0-43c1-816c-d47ee3d8917e';
update public.cc_questions set question_text_en = 'How your team works together is agreed clearly, and everyone involved is kept up to date.' where id = 'bff783e7-61c6-4ac9-9b4e-541736ce7339';
update public.cc_questions set question_text_en = 'You are satisfied with your current pay, taking your overall workload and responsibilities into account.' where id = 'c99689d2-c849-48c4-a8e1-c0fb8043ad64';
update public.cc_questions set question_text_en = 'When you get something wrong, you can own it openly and learn from it without worrying about being judged or told off.' where id = 'cbe2c976-704d-48fc-901d-c24ed43c999f';
update public.cc_questions set question_text_en = 'When looking back at work, your team gets to the root cause rather than stopping at the surface.' where id = 'cf52b78e-f52c-4ba5-a78e-4662955691d8';
update public.cc_questions set question_text_en = 'In your team, people are willing to disagree with the majority when it helps, so the team gets more than one view.' where id = 'd111bf2a-ae98-478b-994c-c80613bcb00b';
update public.cc_questions set question_text_en = 'When you spot a risk or a possible problem while working, you''re willing to raise it, even without a complete solution.' where id = 'd5aa3ad2-4a92-44a2-9059-32f0ef00bf6a';
update public.cc_questions set question_text_en = 'You are satisfied with the career opportunities and progression available to you at the company in your role.' where id = 'd848c123-2862-4a52-9a77-6f8858287340';
update public.cc_questions set question_text_en = 'In your day-to-day work, you understand clearly how what you do contributes to the shared goal.' where id = 'e0ef0395-4205-4368-bad0-da139eddcc25';
update public.cc_questions set question_text_en = 'When people disagree about work, the conversation stays on the problem and its causes rather than turning personal.' where id = 'e4747457-b0ea-4aaf-932e-75828b625783';
update public.cc_questions set question_text_en = 'At your company, before you start a piece of work, it is always made clear who is responsible for it and who will work with you.' where id = 'e4c60f46-75ce-4e4d-91a4-9e778a4c8f7a';
update public.cc_questions set question_text_en = 'When work is assessed or contributions recognised, you find your manager open and fair about it.' where id = 'e5ea6586-d54b-4194-bde8-89cb78aa94bf';
update public.cc_questions set question_text_en = 'Work is handed out in your team at a steady, predictable rhythm, rather than being constantly reshuffled.' where id = 'e6cac1e1-422b-483c-800d-c1426534f578';
update public.cc_questions set question_text_en = 'You know which kind of work belongs on which channel, which keeps communication quick and easy.' where id = 'ed4c6b0e-d839-4885-bd51-fb19be0b17f8';
update public.cc_questions set question_text_en = 'In day-to-day work, people in your team understand and follow the process in much the same way.' where id = 'fe492793-74de-4bd2-95df-5337534d4aae';

-- -------------------------------------------------------------------------
-- wr_practice_themes — chủ đề Thực hành (10 dòng)
-- -------------------------------------------------------------------------

update public.wr_practice_themes set
  title_en = 'Seeing where you''re headed',
  description_en = 'Being busy isn''t the same as heading the right way. This practice builds the habit of stopping to ask, instead of just pushing on.',
  formed_line_en = 'You know where you''re headed, even when you''re busy.'
where theme_id = 'pt-a1';

update public.wr_practice_themes set
  title_en = 'Energy for the long run',
  description_en = 'Working sustainably isn''t about giving everything every day. It''s about knowing when to stop. Each round is practice at hearing your own limits.',
  formed_line_en = 'You stop before you''re empty, not after.'
where theme_id = 'pt-a2';

update public.wr_practice_themes set
  title_en = 'Out of the reaction loop',
  description_en = 'Sometimes your reaction is far bigger than what just happened. This practice builds a small pause, before the reaction takes over.',
  formed_line_en = 'You have a pause, before the reaction takes over.'
where theme_id = 'pt-a3';

update public.wr_practice_themes set
  title_en = 'Not learning the same lesson twice',
  description_en = 'Getting it wrong once is a lesson. Getting it wrong again for the same reason is a pattern worth a closer look. This practice builds the habit of looking back, so the lesson actually stays.',
  formed_line_en = 'The lesson has genuinely stayed with you now.'
where theme_id = 'pt-a4';

update public.wr_practice_themes set
  title_en = 'Trusting and being trusted',
  description_en = 'Trust is built by daring to let go, not by holding on tighter. Each round trains a new reflex in place of the urge to check again.',
  formed_line_en = 'You trust, and let people show they''ve earned it.'
where theme_id = 'pt-c1';

update public.wr_practice_themes set
  title_en = 'Speaking up',
  description_en = 'How many times have you had something to say and stayed quiet because it felt awkward? This practice doesn''t ask you to be bold straight away. Small moments are enough to start.',
  formed_line_en = 'Silence is no longer your default.'
where theme_id = 'pt-c2';

update public.wr_practice_themes set
  title_en = 'Honest feedback, not just polite',
  description_en = 'Politeness is sometimes how we avoid what needs saying. Giving honest feedback again and again, even in small ways, slowly makes it less frightening.',
  formed_line_en = 'You choose to say the true thing, not just the polite one.'
where theme_id = 'pt-c3';

update public.wr_practice_themes set
  title_en = 'Clear on what''s expected',
  description_en = 'A lot of stress doesn''t come from the work being hard. It comes from not being sure what''s expected of you. This practice builds the habit of asking first, instead of guessing and worrying.',
  formed_line_en = 'You don''t guess anymore, you ask.'
where theme_id = 'pt-s1';

update public.wr_practice_themes set
  title_en = 'Prioritising what''s actually yours',
  description_en = 'Taking on work that isn''t yours is the fastest way to lose energy for what matters. The small steps here help you see your own edges more clearly.',
  formed_line_en = 'You know what''s yours, and what isn''t.'
where theme_id = 'pt-s2';

update public.wr_practice_themes set
  title_en = 'Steady when things change',
  description_en = 'Change isn''t as unsettling as being left behind, not knowing what''s going on. This practice gets you used to asking, instead of waiting in the dark.',
  formed_line_en = 'Change doesn''t knock you off balance the way it used to.'
where theme_id = 'pt-s3';

-- -------------------------------------------------------------------------
-- wr_practice_steps — ba bước của mỗi chủ đề (39 dòng)
--
-- Tên ba giai đoạn dùng ĐÚNG bộ đã có trong mã (`practiceStageLabel`):
-- Notice / Try / Shift. Đặt tên khác ở đây là để nhãn trên thẻ và tiêu đề
-- bước gọi cùng một giai đoạn bằng hai cái tên.
-- -------------------------------------------------------------------------

update public.wr_practice_steps set
  title_en = 'Notice: Write one answer to the big question',
  content_en = 'Write one short line answering where this job is taking you.'
where step_id = 'pt-a1-1';

update public.wr_practice_steps set
  title_en = 'Try: Connect today''s work to something larger',
  content_en = 'Pick something you''re working on and write which larger goal of yours it serves.'
where step_id = 'pt-a1-2';

update public.wr_practice_steps set
  title_en = 'Shift: Revisit the goal on a rhythm',
  content_en = 'Set a regular rhythm for revisiting the goal, instead of running on autopilot.'
where step_id = 'pt-a1-3';

update public.wr_practice_steps set
  title_en = 'Notice: Track when your energy runs lowest',
  content_en = 'Notice the point in the week when your energy is lowest, and what led there.'
where step_id = 'pt-a2-1';

update public.wr_practice_steps set
  title_en = 'Try: Drop or move one thing that isn''t urgent',
  content_en = 'Pick something that isn''t genuinely urgent and try dropping it or moving it.'
where step_id = 'pt-a2-2';

update public.wr_practice_steps set
  title_en = 'Shift: Build a fixed rest rhythm',
  content_en = 'Set a fixed rest rhythm, rather than waiting until you''re empty.'
where step_id = 'pt-a2-3';

update public.wr_practice_steps set
  title_en = 'Notice: Record a moment you reacted too strongly',
  content_en = 'Notice a situation where you reacted more strongly than it needed.'
where step_id = 'pt-a3-1';

update public.wr_practice_steps set
  title_en = 'Try: Take a beat before responding',
  content_en = 'Before you respond, give yourself a breath or count to ten.'
where step_id = 'pt-a3-2';

update public.wr_practice_steps set
  title_en = 'Shift: Catch the reaction early',
  content_en = 'Learn to catch the signs of a reaction early, before it''s already out of your mouth.'
where step_id = 'pt-a3-3';

update public.wr_practice_steps set
  title_en = 'Notice: Record a mistake that repeated',
  content_en = 'Write down an old mistake, and a recent one that looks much like it.'
where step_id = 'pt-a4-1';

update public.wr_practice_steps set
  title_en = 'Try: Note what you''ll do differently, right after',
  content_en = 'Straight after a mistake, note specifically what you''ll do differently next time.'
where step_id = 'pt-a4-2';

update public.wr_practice_steps set
  title_en = 'Shift: Build a regular look back',
  content_en = 'Set a regular rhythm for looking back, a retro of your own, so learning isn''t left to chance.'
where step_id = 'pt-a4-3';

update public.wr_practice_steps set
  title_en = 'Notice: Record a time you checked again despite trusting',
  content_en = 'Notice a time you checked work you''d handed over, even though you trusted the person.'
where step_id = 'pt-c1-1';

update public.wr_practice_steps set
  title_en = 'Try: Hand something over fully, no mid-way checks',
  content_en = 'Pick one task, hand it over, and don''t ask about it until the deadline.'
where step_id = 'pt-c1-2';

update public.wr_practice_steps set
  title_en = 'Shift: Keep the trust you''ve given',
  content_en = 'Keep handing work over fully, without managing the detail, as a habit rather than an exception.'
where step_id = 'pt-c1-3';

update public.wr_practice_steps set
  title_en = 'Notice: Watch for the urge to stay quiet',
  content_en = 'Notice the moments when you have something to say and choose not to.'
where step_id = 'pt-c2-1';

update public.wr_practice_steps set
  title_en = 'Try: Ask one question in a meeting',
  content_en = 'In your next meeting, ask at least one question, however small.'
where step_id = 'pt-c2-2';

update public.wr_practice_steps set
  title_en = 'Shift: Share a view of your own',
  content_en = 'Offer a perspective of your own without being asked for it.'
where step_id = 'pt-c2-3';

update public.wr_practice_steps set
  title_en = 'Notice: Catch a time you stayed quiet instead of speaking',
  content_en = 'Notice a recent time you agreed on the surface without really agreeing.'
where step_id = 'pt-c3-1';

update public.wr_practice_steps set
  title_en = 'Try: Give one honest piece of feedback',
  content_en = 'Give one honest, prepared piece of feedback to someone you trust.'
where step_id = 'pt-c3-2';

update public.wr_practice_steps set
  title_en = 'Shift: Build the feedback habit',
  content_en = 'Make feedback a regular rhythm in the team, not only something for when there''s a problem.'
where step_id = 'pt-c3-3';

update public.wr_practice_steps set
  title_en = 'Notice',
  content_en = 'Take five minutes at the end of the day to note one thing you did well and one thing you''d like to improve. Just observe; no judging or fixing yet.'
where step_id = 'pt-feedback-1';

update public.wr_practice_steps set
  title_en = 'Try',
  content_en = 'Share one specific lesson in a meeting or a one-to-one this week, then ask the other person what was useful about it.'
where step_id = 'pt-feedback-2';

update public.wr_practice_steps set
  title_en = 'Shift',
  content_en = 'Keep a short weekly look back for four weeks: what to keep, what to change, and what the next small step is.'
where step_id = 'pt-feedback-3';

update public.wr_practice_steps set
  title_en = 'Notice',
  content_en = 'Track your calendar for three days. Note how many times you were interrupted, when, and why.'
where step_id = 'pt-rhythm-1';

update public.wr_practice_steps set
  title_en = 'Try',
  content_en = 'Try one block of deep work this week, at least ninety minutes uninterrupted. Then judge how it went.'
where step_id = 'pt-rhythm-2';

update public.wr_practice_steps set
  title_en = 'Shift',
  content_en = 'Keep at least two deep work blocks a week for four weeks running. Note briefly: what helped you hold the rhythm?'
where step_id = 'pt-rhythm-3';

update public.wr_practice_steps set
  title_en = 'Notice: Record a time the expectation wasn''t clear',
  content_en = 'Notice a situation this week where you weren''t sure what was expected of you.'
where step_id = 'pt-s1-1';

update public.wr_practice_steps set
  title_en = 'Try: Ask one direct question to make it clear',
  content_en = 'Before starting the next piece of work, ask whoever gave it to you one question to be sure of the result they want.'
where step_id = 'pt-s1-2';

update public.wr_practice_steps set
  title_en = 'Shift: Make asking a habit',
  content_en = 'For anything new, always establish what a good result looks like before you begin.'
where step_id = 'pt-s1-3';

update public.wr_practice_steps set
  title_en = 'Notice: Record work that isn''t yours',
  content_en = 'Notice something recent you took on even though it didn''t really need your decision.'
where step_id = 'pt-s2-1';

update public.wr_practice_steps set
  title_en = 'Try: Decline or hand over one task',
  content_en = 'Pick one task outside your remit to decline or hand back.'
where step_id = 'pt-s2-2';

update public.wr_practice_steps set
  title_en = 'Shift: Keep a clear way of prioritising',
  content_en = 'Build a way of sorting work by how much it genuinely needs your decision, and reuse it each week.'
where step_id = 'pt-s2-3';

update public.wr_practice_steps set
  title_en = 'Notice: Record a change that caught you out',
  content_en = 'Notice a time you were caught off guard because nobody told you about a change.'
where step_id = 'pt-s3-1';

update public.wr_practice_steps set
  title_en = 'Try: Ask why the change happened',
  content_en = 'Ask directly about the reasoning behind a change, instead of guessing.'
where step_id = 'pt-s3-2';

update public.wr_practice_steps set
  title_en = 'Shift: Confirm rather than assume',
  content_en = 'Build the habit of confirming important information before acting on it.'
where step_id = 'pt-s3-3';

update public.wr_practice_steps set
  title_en = 'Notice',
  content_en = 'Watch one meeting this week. Note the moments you wanted to speak and stayed quiet. No judging, just noticing.'
where step_id = 'pt-voice-1';

update public.wr_practice_steps set
  title_en = 'Try',
  content_en = 'Ask exactly one question in a meeting this week. It doesn''t need to be perfect. It just needs to be out loud.'
where step_id = 'pt-voice-2';

update public.wr_practice_steps set
  title_en = 'Shift',
  content_en = 'Share one view of your own each week for four weeks running. Note briefly how it felt each time.'
where step_id = 'pt-voice-3';

-- -------------------------------------------------------------------------
-- wr_choice_pool — lựa chọn ở cuối luồng (8 dòng)
-- -------------------------------------------------------------------------

update public.wr_choice_pool set text_en = 'Try a different approach next time' where id = 1;
update public.wr_choice_pool set text_en = 'Keep doing it this way and watch a bit longer' where id = 2;
update public.wr_choice_pool set text_en = 'Not sure yet, I need more time' where id = 3;
update public.wr_choice_pool set text_en = 'Talk to someone about this' where id = 4;
update public.wr_choice_pool set text_en = 'Keep this in mind to revisit later' where id = 5;
update public.wr_choice_pool set text_en = 'Set a reminder to come back to this in a week' where id = 6;
update public.wr_choice_pool set text_en = 'Share this with the person directly involved' where id = 7;
update public.wr_choice_pool set text_en = 'No action needed, noticing it is enough' where id = 8;

-- ---------------------------------------------------------------------------
-- CÒN CHỜ KHÁCH QUYẾT
--
-- Bốn dòng `practice_action` tiếng Việt nói ở đầu file vẫn đang chở đuôi rác.
-- Dọn được bằng đúng bốn lệnh dưới đây, nhưng CỐ Ý để lại dạng chú thích: đó
-- là nội dung tiếng Việt của khách, và im lặng sửa chữ trên màn hình của họ
-- không phải việc của một migration dịch thuật.
--
-- update public.wr_stories set practice_action = split_part(practice_action, E'\nA2 – Execution Rhythm', 1) where story_id = 'A1-10';
-- update public.wr_stories set practice_action = split_part(practice_action, E'\nA4 – Learning Loop', 1) where story_id = 'A3-10';
-- update public.wr_stories set practice_action = split_part(practice_action, E'\nS2 – Collaboration Capability', 1) where story_id = 'S1-10';
-- update public.wr_stories set practice_action = split_part(practice_action, E'\nS3 – Information Flow', 1) where story_id = 'S2-10';

commit;


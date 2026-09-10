-- Ghi lại NGÔN NGỮ của mỗi lần kể Diễn biến.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO CẦN
--
-- `wr_pattern_narratives` giữ văn xuôi do model sinh ra và app đọc thẳng lên
-- thẻ "Nhìn lại dòng thời gian". Trước đợt 10/09, `wr-narrative` không hề biết
-- người dùng đang chạy ngôn ngữ nào, nên mọi dòng trong bảng đều là tiếng Việt.
--
-- Sau khi thêm luật ngôn ngữ vào prompt, các lần kể MỚI đã ra tiếng Anh khi app
-- chạy tiếng Anh. Nhưng những dòng đã có thì không tự đổi, và luật kể lại chỉ
-- xét "có đủ lần nhìn lại mới chưa" — nên người bật tiếng Anh vẫn đọc lại đúng
-- đoạn tiếng Việt cũ cho tới khi họ ghi thêm ba lần nữa.
--
-- Không có cột này thì không có cách nào phân biệt "đoạn này viết bằng tiếng
-- Việt" với "đoạn này viết bằng tiếng Anh", vì cả hai đều chỉ là `text`.
--
-- ---------------------------------------------------------------------------
-- DÒNG CŨ LÀ 'vi', KHÔNG PHẢI NULL
--
-- Mọi dòng đang có đều sinh ra trước khi hàm biết tới ngôn ngữ, và đều là tiếng
-- Việt — đó là một sự thật đã biết, không phải một ô trống. Đặt NULL rồi để tầng
-- trên đoán là mời một lần đoán sai vào hệ thống.
--
-- Cột NOT NULL DEFAULT 'vi' cũng khiến bản app CŨ chưa gửi ngôn ngữ vẫn ghi
-- được: nó không truyền cột này, Postgres điền 'vi', và đó đúng là thứ bản cũ
-- sinh ra.

alter table public.wr_pattern_narratives
  add column if not exists locale text not null default 'vi';

-- Chỉ nhận đúng hai giá trị app biết đọc. Thiếu ràng buộc này thì một lỗi gõ
-- phía hàm ('en-US', 'eng') sẽ lặng lẽ biến mọi lần kể thành "khác ngôn ngữ
-- đang bật", và app kể lại vô tận — mỗi lần là một lượt tiêu tiền cho model.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'wr_pattern_narratives_locale_check'
  ) then
    alter table public.wr_pattern_narratives
      add constraint wr_pattern_narratives_locale_check
      check (locale in ('vi', 'en'));
  end if;
end $$;

comment on column public.wr_pattern_narratives.locale is
  'Ngôn ngữ của đoạn kể. Khác ngôn ngữ app đang chạy thì kể lại.';

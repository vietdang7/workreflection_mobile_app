-- Trụ S / C / A của từng tình huống — `WorkReflection_DienGiaiSau_v2.docx` §2.1.
--
-- VÌ SAO CẦN MỘT CỘT RIÊNG, KHÔNG SUY TỪ `sca_dimension`.
--
-- Với 160 dòng SCA thì trụ đúng bằng ký tự đầu của `sca_dimension` (S1 → S).
-- Nhưng 10 tình huống tích cực nằm ở hai nhóm P-ACHIEVE / P-STEADY, và bảng
-- §2.1 gán trụ cho chúng CẮT NGANG hai nhóm đó:
--
--     P-07, P-08  thuộc P-STEADY   nhưng trụ A
--     P-09        thuộc P-STEADY   nhưng trụ C
--     P-02, P-03, P-05             trụ C, tuy cùng P-ACHIEVE với P-01/P-04 trụ A
--
-- Nên không có phép biến đổi nào từ `sca_dimension` ra được bảng đó. Phải là
-- dữ liệu.
--
-- HỆ QUẢ CỦA VIỆC THIẾU CỘT NÀY, đo trên dữ liệu thật ngày 11/09/2026: một tài
-- khoản có 31 lần nhìn lại trong 30 ngày, trong đó 10 lần thuộc nhóm P. Mười
-- lần ấy không được đếm vào trụ nào, mà mẫu số vẫn là 31 — nên trụ cao nhất
-- chỉ ra 7/31 = 22%, không chạm ngưỡng 40%, và màn Diễn giải sâu trả về nhánh
-- "chưa có nhóm nào nổi trội". Chia đúng mẫu số thì 7/17 = 41%. Cùng một người,
-- cùng một ngày, chỉ khác cái mẫu số.
--
-- ĐỂ NULLABLE. Đội nội dung thêm tình huống mới bằng tay sẽ quên cột này, và
-- một hàng thiếu trụ tốt hơn một hàng bị chặn không insert được. Dart rơi về
-- ký tự đầu của `sca_dimension` khi cột null, nên tình huống SCA mới vẫn đúng
-- ngay cả khi bỏ trống; chỉ tình huống P mới bắt buộc phải điền.

alter table public.wr_situations
  add column if not exists pillar text
    check (pillar is null or pillar in ('S', 'C', 'A'));

comment on column public.wr_situations.pillar is
  'Trụ S/C/A của tình huống (DienGiaiSau v2 §2.1). Null thì đọc từ ký tự đầu '
  'của sca_dimension — chỉ đúng với 160 dòng SCA, 10 dòng P bắt buộc phải điền.';

-- 160 dòng SCA: trụ chính là ký tự đầu của chiều.
update public.wr_situations
   set pillar = left(sca_dimension, 1)
 where sca_dimension not like 'P-%'
   and pillar is null;

-- 10 dòng tích cực: bảng §2.1, chép nguyên.
update public.wr_situations s
   set pillar = m.pillar
  from (values
    ('P-01', 'A'),  -- Tôi vừa hoàn thành một việc khó hơn mong đợi
    ('P-02', 'C'),  -- Tôi được ghi nhận tích cực từ cấp trên
    ('P-03', 'C'),  -- Tôi giúp được đồng nghiệp gỡ một vấn đề khó
    ('P-04', 'A'),  -- Tôi được tăng lương hoặc thăng chức
    ('P-05', 'C'),  -- Tôi nhận được lời cảm ơn bất ngờ từ ai đó
    ('P-06', 'S'),  -- Công việc hôm nay diễn ra đúng như tôi mong đợi
    ('P-07', 'A'),  -- Tôi cảm thấy làm chủ được nhịp độ công việc của mình
    ('P-08', 'A'),  -- Tôi vừa học được một điều nhỏ nhưng hữu ích
    ('P-09', 'C'),  -- Tôi có một cuộc trò chuyện tốt với đồng nghiệp
    ('P-10', 'S')   -- Hôm nay không có gì đặc biệt, nhưng tôi thấy ổn
  ) as m(code, pillar)
 where s.code = m.code;

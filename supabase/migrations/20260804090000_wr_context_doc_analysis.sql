-- Phân tích tài liệu bối cảnh (JD · CV) bằng AI.
--
-- Trước migration này, `wr_context_documents` chỉ lưu LOẠI tài liệu và đường
-- dẫn file trong Storage. Không có bước nào đọc nội dung, nên ảnh JD/CV người
-- dùng tải lên nằm chết một chỗ: trợ lý trò chuyện phải tự khai là không đọc
-- được, và phần đối chiếu kỹ năng phải quay sang dùng `role_text` người dùng tự
-- gõ.
--
-- Bốn cột dưới đây là chỗ chứa kết quả của Edge Function `wr-doc-analyze`:
-- chữ đọc được từ tài liệu, bản phân tích có cấu trúc, và trạng thái để giao
-- diện biết đang chờ hay đã xong.
--
-- KHÔNG tạo bảng mới: một tài liệu vẫn là một dòng, phân tích là thuộc tính của
-- chính dòng đó. Tách bảng thì mọi nơi đọc tài liệu đều phải join, và sẽ có lúc
-- một bên có dòng còn bên kia không.

alter table public.wr_context_documents
  add column if not exists extracted_text  text,
  add column if not exists analysis        jsonb,
  add column if not exists analysis_status text not null default 'pending',
  add column if not exists analysis_error  text,
  add column if not exists analyzed_at     timestamptz,
  add column if not exists analysis_model  text;

-- Trạng thái hợp lệ. `pending` = vừa tải lên, chưa gọi phân tích.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'wr_context_documents_analysis_status_check'
  ) then
    alter table public.wr_context_documents
      add constraint wr_context_documents_analysis_status_check
      check (analysis_status in ('pending', 'processing', 'ready', 'failed'));
  end if;
end $$;

comment on column public.wr_context_documents.extracted_text is
  'Toàn bộ chữ đọc được từ tài liệu (OCR/parse). Nguồn cho trợ lý và đối chiếu kỹ năng.';
comment on column public.wr_context_documents.analysis is
  'Bản phân tích có cấu trúc: chức danh, trách nhiệm, yêu cầu, kỹ năng, trọng số ba trụ S/C/A.';
comment on column public.wr_context_documents.analysis_status is
  'pending → processing → ready | failed.';

-- Tài liệu đã phân tích xong, mới nhất trước — truy vấn mà cả Edge Function lẫn
-- app đều chạy mỗi lần dựng ngữ cảnh.
create index if not exists wr_context_documents_ready_idx
  on public.wr_context_documents (user_id, uploaded_at desc)
  where analysis_status = 'ready';

-- RLS: bốn policy owner-only đã có từ 20260722000000 áp cho cả cột mới, không
-- cần thêm gì. Ghi chú lại ở đây để lần sau không ai đi tìm.

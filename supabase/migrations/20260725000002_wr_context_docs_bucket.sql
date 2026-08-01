-- WorkReflection: bucket lưu tài liệu bối cảnh (JD · CV).
-- Hai Lớp v1.2 §III: tải lên Free (giới hạn số lượng), phân tích sâu Paid.
-- Bucket private — chỉ chủ sở hữu truy cập được thư mục {user_id}/.

insert into storage.buckets (id, name, public)
values ('context-docs', 'context-docs', false)
on conflict (id) do nothing;

drop policy if exists "context_docs_owner_select" on storage.objects;
drop policy if exists "context_docs_owner_insert" on storage.objects;
drop policy if exists "context_docs_owner_update" on storage.objects;
drop policy if exists "context_docs_owner_delete" on storage.objects;

create policy "context_docs_owner_select" on storage.objects
  for select using (
    bucket_id = 'context-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "context_docs_owner_insert" on storage.objects
  for insert with check (
    bucket_id = 'context-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "context_docs_owner_update" on storage.objects
  for update using (
    bucket_id = 'context-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "context_docs_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'context-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

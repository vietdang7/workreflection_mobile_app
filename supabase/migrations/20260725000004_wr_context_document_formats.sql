-- Giới hạn upload Context Document giống validation trên mobile.
-- Bucket vẫn private; policy owner-only nằm trong migration 20260725000002.

update storage.buckets
set
  file_size_limit = 10485760,
  allowed_mime_types = array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/png',
    'image/jpeg'
  ]
where id = 'context-docs';

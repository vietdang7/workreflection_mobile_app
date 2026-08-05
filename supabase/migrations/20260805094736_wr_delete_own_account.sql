-- Người dùng tự xoá tài khoản mình — App Store Review Guideline 5.1.1(v).
--
-- Apple bắt buộc: app nào cho tạo tài khoản thì phải cho xoá tài khoản NGAY
-- TRONG APP, không được đẩy sang email hay trang web. Thiếu là bị từ chối.
--
-- Vì sao là RPC chứ không phải Edge Function:
--   Xoá `auth.users` chỉ cần quyền, mà `security definer` đã có sẵn quyền đó.
--   Đi đường Edge Function thì phải mang theo service_role key, thêm một chỗ
--   để lộ khoá mà không được gì thêm.
--
-- Vì sao phải dọn tay trước khi xoá:
--   Toàn bộ bảng `wr_*` (app) đã `on delete cascade`, xoá user là sạch. Nhưng
--   phía web có 11 cột trỏ tới `auth.users` KHÔNG khai `on delete` — mặc định
--   là NO ACTION, tức lệnh xoá sẽ ném lỗi khoá ngoại. Đa số là cột ghi vết
--   quản trị (ai tạo, ai duyệt, ai tải lên) nên chỉ chặn khi người xoá là
--   admin/coach; nhưng đã là chức năng bắt buộc thì không được phép có tài
--   khoản nào xoá không nổi.
--
-- Cố ý KHÔNG đụng vào `cc_orders`/`cc_invoices`/`cc_payments`: mấy bảng đó giữ
-- `user_id` dạng text, không có khoá ngoại nên không chặn gì, mà chứng từ tài
-- chính thì luật kế toán buộc lưu. Apple cũng cho phép giữ lại phần dữ liệu
-- pháp luật yêu cầu.

create or replace function public.wr_delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'wr_delete_own_account: chưa đăng nhập'
      using errcode = '28000';
  end if;

  -- 1. Cột ghi vết quản trị, cho phép null → gỡ liên kết, giữ nguyên nội dung.
  --    Xoá tài khoản người tạo mà kéo theo cả bài viết/tài nguyên của tổ chức
  --    thì hỏng dữ liệu chung.
  if to_regclass('public.cc_workshop_registrations') is not null then
    update public.cc_workshop_registrations
       set assigned_by = null where assigned_by = v_uid;
  end if;

  if to_regclass('public.cc_workshops') is not null then
    update public.cc_workshops set created_by = null where created_by = v_uid;
  end if;

  if to_regclass('public.cc_workshop_resources') is not null then
    update public.cc_workshop_resources
       set created_by = null where created_by = v_uid;
  end if;

  if to_regclass('public.cc_question_set_config') is not null then
    update public.cc_question_set_config
       set updated_by = null where updated_by = v_uid;
  end if;

  if to_regclass('public.cc_blog_posts') is not null then
    update public.cc_blog_posts set author_id = null where author_id = v_uid;
  end if;

  if to_regclass('public.cc_lnd_programs') is not null then
    update public.cc_lnd_programs set created_by = null where created_by = v_uid;
  end if;

  if to_regclass('public.cc_lnd_enrollments') is not null then
    update public.cc_lnd_enrollments
       set enrolled_by = null where enrolled_by = v_uid;
  end if;

  if to_regclass('public.cc_lnd_resources') is not null then
    update public.cc_lnd_resources
       set uploaded_by = null where uploaded_by = v_uid;
  end if;

  -- 2. `cc_workshop_employee_requests.user_id` NOT NULL và không cascade →
  --    phải xoá hẳn dòng. Đây là đơn xin tham gia workshop của chính người
  --    dùng, xoá là đúng.
  if to_regclass('public.cc_workshop_employee_requests') is not null then
    delete from public.cc_workshop_employee_requests where user_id = v_uid;
    update public.cc_workshop_employee_requests
       set reviewed_by = null where reviewed_by = v_uid;
  end if;

  -- 3. `cc_custom_roadmap_tasks.created_by` NOT NULL. Dòng của chính người
  --    dùng tự cascade theo `user_id`. Còn việc do coach tạo trên lộ trình
  --    NGƯỜI KHÁC thì không được xoá — chuyển quyền tác giả về chủ lộ trình
  --    để nội dung ở lại với người đang dùng nó.
  if to_regclass('public.cc_custom_roadmap_tasks') is not null then
    update public.cc_custom_roadmap_tasks
       set created_by = user_id
     where created_by = v_uid and user_id <> v_uid;
  end if;

  -- 4. Xoá user. Mọi bảng `wr_*` và phần lớn `cc_*` cascade theo đây.
  delete from auth.users where id = v_uid;
end;
$$;

comment on function public.wr_delete_own_account() is
  'Người dùng tự xoá tài khoản mình (App Store Guideline 5.1.1(v)). '
  'Gỡ các liên kết NO ACTION phía cc_* rồi xoá auth.users; phần còn lại cascade.';

-- Chỉ người đã đăng nhập gọi được, và hàm chỉ đụng tới auth.uid() của chính
-- phiên đó nên không có đường nào xoá tài khoản người khác.
revoke all on function public.wr_delete_own_account() from public;
revoke all on function public.wr_delete_own_account() from anon;
grant execute on function public.wr_delete_own_account() to authenticated;

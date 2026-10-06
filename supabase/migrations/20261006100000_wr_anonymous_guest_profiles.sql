-- Khách dùng thử không cần tài khoản (mockup v47, chốt 06/10/2026).
--
-- App di động cho người dùng làm lần nhìn lại đầu tiên TRƯỚC khi đăng ký, bằng
-- Supabase anonymous sign-in. Sau lần đầu, sheet "Lưu lại hành trình" gắn
-- email + mật khẩu vào CHÍNH user ẩn danh đó (`auth.updateUser`), nên dữ liệu
-- giữ nguyên `user_id`, không phải chuyển bảng nào.
--
-- Vướng duy nhất: trigger `on_auth_user_created` chèn `NEW.email` vào
-- `cc_profiles.email`, cột NOT NULL. User ẩn danh không có email, nên đăng
-- nhập ẩn danh hỏng ngay với lỗi "Database error saving new user".
--
-- Sửa:
--   1. `handle_new_user` bỏ qua user ẩn danh. Phần còn lại giữ NGUYÊN VĂN,
--      vì web cũng tạo user qua trigger này.
--   2. Trigger mới trên UPDATE: khi user ẩn danh được gắn email lần đầu thì
--      tạo hàng `cc_profiles` như lúc đăng ký thường.
--
-- Không có hàng `cc_profiles` thì app tính là gói free (mọi chỗ đọc đều chịu
-- được hàng rỗng). Web không tạo user ẩn danh nên không bị ảnh hưởng.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $function$
begin
  -- User ẩn danh của app di động: chưa có email, chưa có hồ sơ web.
  -- Hàng cc_profiles được tạo khi họ gắn email (handle_user_email_attached).
  if new.is_anonymous or new.email is null then
    return new;
  end if;

  insert into public.cc_profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    case
      when new.raw_user_meta_data->>'account_type' = 'enterprise' then 'enterprise'
      else 'free'
    end
  );
  return new;
end;
$function$;

create or replace function public.handle_user_email_attached()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  -- Chỉ lúc user CHƯA có email nay có email. Đổi email của tài khoản thường
  -- (old.email đã có) không đi vào đây.
  if new.email is null or old.email is not null then
    return new;
  end if;

  insert into public.cc_profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    'free'
  )
  on conflict (id) do update
    set email = excluded.email,
        full_name = coalesce(public.cc_profiles.full_name, excluded.full_name);
  return new;
end;
$function$;

drop trigger if exists on_auth_user_email_attached on auth.users;
create trigger on_auth_user_email_attached
  after update of email on auth.users
  for each row
  execute function public.handle_user_email_attached();

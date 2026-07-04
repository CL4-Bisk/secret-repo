-- Purpose:
-- Create a profile row automatically whenever Supabase Auth creates a user.
--
-- Where to run:
-- Supabase Dashboard -> SQL Editor -> paste this file -> Run.
--
-- Why this exists:
-- Flutter should create the auth account only. The database should own profile
-- creation so email confirmation and OAuth signups work the same way.

create schema if not exists private;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(split_part(new.email, '@', 1), ''),
      'New user'
    )
  )
  on conflict (id) do update
    set
      full_name = excluded.full_name,
      updated_at = now();

  return new;
end;
$$;

revoke all on function private.handle_new_user() from public;
revoke all on function private.handle_new_user() from anon;
revoke all on function private.handle_new_user() from authenticated;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

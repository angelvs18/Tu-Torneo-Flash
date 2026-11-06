-- M1 auth: harden profiles, sanitize the signup trigger and add the avatars bucket.

-- ===== profiles: constraints, updated_at and column privileges =====
alter table public.profiles
  add column updated_at timestamptz not null default now(),
  add constraint profiles_display_name_len
    check (display_name is null or char_length(btrim(display_name)) between 1 and 60),
  add constraint profiles_avatar_url_fmt
    check (avatar_url is null or (avatar_url ~ '^https://' and char_length(avatar_url) <= 2048));

create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Rows are created by handle_new_user() and removed by the auth.users cascade.
revoke all on public.profiles from anon;
revoke insert, update, delete on public.profiles from authenticated;
grant update (display_name, avatar_url) on public.profiles to authenticated;

-- ===== Signup trigger: sanitize provider metadata =====
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  meta constant jsonb := coalesce(new.raw_user_meta_data, '{}');
  v_name text;
  v_avatar text := btrim(meta ->> 'avatar_url');
begin
  v_name := coalesce(
    nullif(btrim(meta ->> 'full_name'), ''),
    nullif(btrim(meta ->> 'name'), ''),
    -- Apple private relay aliases are meaningless: leave null so the app asks for a name.
    case when lower(new.email) not like '%@privaterelay.appleid.com'
         then nullif(btrim(split_part(new.email, '@', 1)), '') end);
  v_name := nullif(btrim(left(v_name, 60)), '');

  if v_avatar !~ '^https://' or char_length(v_avatar) > 2048 then
    v_avatar := null;
  end if;

  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, v_name, v_avatar)
  on conflict (id) do nothing;
  return new;
end $$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- ===== Avatars bucket. Path: {user_id}/avatar.{ext} =====
-- Public bucket: reads go through the public URL, so anon needs no policy.
-- TODO(product): purge orphaned avatars on account deletion (Edge Function + Storage API).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 1048576, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;

-- SELECT is required by upsert uploads.
create policy avatars_select on storage.objects for select to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text
         and array_length(storage.foldername(name), 1) = 1);
create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text
              and array_length(storage.foldername(name), 1) = 1);
create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text
         and array_length(storage.foldername(name), 1) = 1)
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text
              and array_length(storage.foldername(name), 1) = 1);
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text
         and array_length(storage.foldername(name), 1) = 1);

-- Profiles, signup trigger and avatars bucket tests. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(29);

-- ===== Fixtures (as postgres, bypassing RLS) =====
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@test.dev',
   '{"full_name":"  Ana López  ","name":"Ana","avatar_url":"https://lh3.googleusercontent.com/a/x"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@test.dev',
   '{"full_name":"   ","name":"Beto","avatar_url":"http://insecure.dev/a.png"}'),
  ('33333333-3333-3333-3333-333333333333', 'carla.r@test.dev',
   '{"avatar_url":"javascript:alert(1)"}'),
  ('44444444-4444-4444-4444-444444444444', 'xyz123@privaterelay.appleid.com', '{}'),
  ('55555555-5555-5555-5555-555555555555', 'long@test.dev',
   jsonb_build_object('full_name', repeat('a', 200))),
  ('66666666-6666-6666-6666-666666666666', 'gone@test.dev', '{}');

insert into public.tournaments (id, owner_id, name, sport, public_code) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Ana''s league', 'basketball', 'ANA234');

insert into storage.objects (bucket_id, name) values
  ('avatars', '22222222-2222-2222-2222-222222222222/avatar.webp');

-- Backdate updated_at (the trigger would overwrite it) to observe it advancing.
alter table public.profiles disable trigger set_updated_at;
update public.profiles set updated_at = '2000-01-01'
 where id = '11111111-1111-1111-1111-111111111111';
alter table public.profiles enable trigger set_updated_at;

-- ===== Signup trigger =====
select is((select display_name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'Ana López', 'full_name wins and is trimmed');
select is((select display_name from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  'Beto', 'a blank full_name falls back to name');
select is((select display_name from public.profiles where id = '33333333-3333-3333-3333-333333333333'),
  'carla.r', 'without metadata the email local part is used');
select is((select display_name from public.profiles where id = '44444444-4444-4444-4444-444444444444'),
  null, 'an Apple private relay email leaves display_name null');
select is((select char_length(display_name) from public.profiles
            where id = '55555555-5555-5555-5555-555555555555'),
  60, 'long names are truncated to 60 chars');
select is((select avatar_url from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'https://lh3.googleusercontent.com/a/x', 'an https avatar_url is copied');
select is((select count(*)::int from public.profiles
            where id in ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333')
              and avatar_url is null),
  2, 'non-https avatar_urls are dropped');

delete from auth.users where id = '66666666-6666-6666-6666-666666666666';
select is((select count(*)::int from public.profiles
            where id = '66666666-6666-6666-6666-666666666666'),
  0, 'deleting the auth user cascades to the profile');

select is(
  (select row(public, file_size_limit, allowed_mime_types)::text
     from storage.buckets where id = 'avatars'),
  row(true, 1048576::bigint, array['image/png', 'image/jpeg', 'image/webp'])::text,
  'avatars bucket is public, 1 MB, png/jpeg/webp');

-- ===== Authenticated user (Ana) =====
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is((select array_agg(id) from public.profiles),
  array['11111111-1111-1111-1111-111111111111'::uuid],
  'a user only sees their own profile');

with u as (
  update public.profiles set display_name = 'Ana L.'
   where id = '11111111-1111-1111-1111-111111111111' returning 1)
select is((select count(*)::int from u), 1, 'a user updates their display_name');
select ok((select updated_at > '2000-01-01' from public.profiles
            where id = '11111111-1111-1111-1111-111111111111'),
  'updated_at advances on update');

with u as (
  update public.profiles set display_name = 'Hacked'
   where id = '22222222-2222-2222-2222-222222222222' returning 1)
select is((select count(*)::int from u), 0, 'a user cannot update another profile');

select throws_ok(
  $$update public.profiles set created_at = now()
     where id = '11111111-1111-1111-1111-111111111111'$$,
  '42501', null, 'created_at is not updatable');
select throws_ok(
  $$update public.profiles set id = '22222222-2222-2222-2222-222222222222'
     where id = '11111111-1111-1111-1111-111111111111'$$,
  '42501', null, 'id is not updatable');
select throws_ok(
  $$insert into public.profiles (id) values ('77777777-7777-7777-7777-777777777777')$$,
  '42501', null, 'users cannot insert profiles');
select throws_ok(
  $$delete from public.profiles where id = '11111111-1111-1111-1111-111111111111'$$,
  '42501', null, 'users cannot delete profiles');
select throws_ok(
  $$update public.profiles set display_name = '   '
     where id = '11111111-1111-1111-1111-111111111111'$$,
  '23514', null, 'a blank display_name is rejected');

-- ===== Avatars storage =====
select lives_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '11111111-1111-1111-1111-111111111111/avatar.webp')$$,
  'a user uploads to their own folder');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'),
  1, 'a user only lists their own avatar');
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '22222222-2222-2222-2222-222222222222/evil.webp')$$,
  '42501', null, 'a user cannot upload to another user''s folder');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('avatars', 'avatar.webp')$$,
  '42501', null, 'uploads at the bucket root are rejected');
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '11111111-1111-1111-1111-111111111111/sub/avatar.webp')$$,
  '42501', null, 'nested folders are rejected');

with u as (
  update storage.objects set metadata = '{}'
   where bucket_id = 'avatars' and name = '22222222-2222-2222-2222-222222222222/avatar.webp'
  returning 1)
select is((select count(*)::int from u), 0, 'a user cannot overwrite another avatar');

-- Lift storage.protect_delete so only RLS decides.
select set_config('storage.allow_delete_query', 'true', true);
with d as (
  delete from storage.objects
   where bucket_id = 'avatars' and name = '22222222-2222-2222-2222-222222222222/avatar.webp'
  returning 1)
select is((select count(*)::int from d), 0, 'a user cannot delete another avatar');

select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('media', '11111111-1111-1111-1111-111111111111/avatar.webp')$$,
  '42501', null, 'avatar paths do not grant access to the media bucket');
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', 'tournaments/aaaaaaaa-0000-0000-0000-000000000001/logo.png')$$,
  '42501', null, 'tournament paths do not grant access to the avatars bucket');

-- ===== anon =====
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok('select * from public.profiles', '42501', null,
  'anon cannot read profiles');
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '11111111-1111-1111-1111-111111111111/anon.webp')$$,
  '42501', null, 'anon cannot upload avatars');

reset role;
select * from finish();
rollback;

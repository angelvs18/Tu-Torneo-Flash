-- RLS and integrity tests. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(32);

-- ===== Fixtures (as postgres, bypassing RLS) =====
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'admin@test.dev'),
  ('33333333-3333-3333-3333-333333333333', 'scorer@test.dev'),
  ('44444444-4444-4444-4444-444444444444', 'stranger@test.dev');

insert into public.tournaments (id, owner_id, name, sport, visibility, public_code) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Public', 'basketball', 'public', 'PUB234'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Unlisted', 'basketball', 'unlisted', 'UNL234'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Private', 'football', 'private', 'PRV234');

insert into public.tournament_staff (tournament_id, user_id, role) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'admin'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'scorer');

insert into public.teams (id, tournament_id, name) values
  ('bbbbbbbb-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', 'Team A'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'aaaaaaaa-0000-0000-0000-000000000001', 'Team B'),
  ('bbbbbbbb-0000-0000-0000-0000000000a2', 'aaaaaaaa-0000-0000-0000-000000000002', 'Team U'),
  ('bbbbbbbb-0000-0000-0000-0000000000a3', 'aaaaaaaa-0000-0000-0000-000000000003', 'Team X');

insert into public.players (id, team_id, first_name, jersey_number, birth_date) values
  ('cccccccc-0000-0000-0000-00000000000a', 'bbbbbbbb-0000-0000-0000-00000000000a', 'Ana', 10, '1985-05-14'),
  ('cccccccc-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-00000000000b', 'Beto', 7, '1990-01-01');

insert into public.competitions (id, tournament_id, name, type) values
  ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Regular', 'league');

insert into public.rounds (id, competition_id, number) values
  ('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001', 1);

insert into public.matches (id, competition_id, round_id, home_team_id, away_team_id) values
  ('ffffffff-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001',
   'eeeeeeee-0000-0000-0000-000000000001',
   'bbbbbbbb-0000-0000-0000-00000000000a', 'bbbbbbbb-0000-0000-0000-00000000000b');

-- ===== Schema =====
select is(
  (select count(*)::int from public.profiles), 4,
  'a profile is created for every new auth user');

select ok(
  (select bool_and(public.generate_public_code() ~ '^[2-9A-HJ-NP-Z]{6}$')
     from generate_series(1, 200)),
  'generate_public_code uses 6 chars without 0/O/1/I');

select hasnt_column('public', 'public_players', 'birth_date',
  'public_players never exposes birth_date');

-- ===== anon =====
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is((select count(*)::int from public.tournaments), 1,
  'anon lists only public tournaments');
select is((select count(*)::int from public.get_tournament_by_code(' unl234 ')), 1,
  'anon opens an unlisted tournament by code');
select is((select count(*)::int from public.get_tournament_by_code('PRV234')), 0,
  'anon cannot open a private tournament by code');
select is((select count(*)::int from public.teams), 3,
  'anon reads teams of public and unlisted tournaments only');
select throws_ok('select * from public.players', '42501', null,
  'anon cannot read the players table');
select is((select count(*)::int from public.public_players), 2,
  'anon reads players through public_players');
select is((select count(*)::int from public.matches), 1,
  'anon reads matches of public tournaments');
select throws_ok(
  $$insert into public.teams (tournament_id, name)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'Hack')$$,
  '42501', null, 'anon cannot insert teams');

-- ===== stranger (authenticated, no role) =====
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);

select is((select count(*)::int from public.players), 0,
  'stranger cannot read players');
select throws_ok(
  $$insert into public.teams (tournament_id, name)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'Hack')$$,
  '42501', null, 'stranger cannot insert teams');
with u as (
  update public.teams set name = 'Hacked'
   where id = 'bbbbbbbb-0000-0000-0000-00000000000a' returning 1)
select is((select count(*)::int from u), 0, 'stranger cannot update teams');
with u as (
  update public.matches set home_score = 99
   where id = 'ffffffff-0000-0000-0000-000000000001' returning 1)
select is((select count(*)::int from u), 0, 'stranger cannot update matches');
select is((select count(*)::int from public.teams
            where tournament_id = 'aaaaaaaa-0000-0000-0000-000000000003'), 0,
  'stranger cannot see private tournament teams');

-- ===== scorer =====
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select is((select count(*)::int from public.players), 2,
  'scorer reads the roster of their tournament');
with u as (
  update public.matches set home_score = 80, away_score = 70, status = 'finished'
   where id = 'ffffffff-0000-0000-0000-000000000001' returning 1)
select is((select count(*)::int from u), 1, 'scorer updates the result');
select throws_ok(
  $$update public.matches set scheduled_at = now()
     where id = 'ffffffff-0000-0000-0000-000000000001'$$,
  '42501', 'scorers can only update result fields',
  'scorer cannot reschedule a match');
select throws_ok(
  $$insert into public.matches (competition_id, home_team_id, away_team_id)
    values ('dddddddd-0000-0000-0000-000000000001',
            'bbbbbbbb-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-00000000000a')$$,
  '42501', null, 'scorer cannot create matches');
with d as (
  delete from public.matches where id = 'ffffffff-0000-0000-0000-000000000001' returning 1)
select is((select count(*)::int from d), 0, 'scorer cannot delete matches');
select lives_ok(
  $$insert into public.player_match_stats (match_id, player_id, team_id, stat_key, value)
    values ('ffffffff-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-00000000000a',
            'bbbbbbbb-0000-0000-0000-00000000000a', 'points', 21)$$,
  'scorer records player stats');

-- ===== admin =====
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.teams (tournament_id, name)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'Team C')$$,
  'admin creates teams');
select lives_ok(
  $$update public.matches set scheduled_at = now()
     where id = 'ffffffff-0000-0000-0000-000000000001'$$,
  'admin reschedules a match');
select throws_ok(
  $$update public.tournaments set public_code = 'ZZZ234'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  '42501', null, 'admin cannot change the public code');
with d as (
  delete from public.tournaments where id = 'aaaaaaaa-0000-0000-0000-000000000001' returning 1)
select is((select count(*)::int from d), 0, 'admin cannot delete the tournament');
select throws_ok(
  $$insert into public.tournament_staff (tournament_id, user_id, role)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 'admin')$$,
  '42501', null, 'admin cannot add staff (owner only)');

-- ===== owner =====
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.tournaments (owner_id, name, sport)
    values ('11111111-1111-1111-1111-111111111111', 'New one', 'football')
    returning id, public_code$$,
  'owner creates a tournament and reads it back (INSERT ... RETURNING)');
select throws_ok(
  $$update public.tournaments set owner_id = '44444444-4444-4444-4444-444444444444'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  '42501', null, 'owner_id is immutable');
select is((select count(*)::int from public.teams
            where tournament_id = 'aaaaaaaa-0000-0000-0000-000000000003'), 1,
  'owner sees their private tournament');
select throws_ok(
  $$insert into public.competition_teams (competition_id, team_id)
    values ('dddddddd-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-0000000000a3')$$,
  '23514', null, 'a team from another tournament cannot join a competition');
select throws_ok(
  $$insert into public.player_match_stats (match_id, player_id, team_id, stat_key, value)
    values ('ffffffff-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-00000000000b',
            'bbbbbbbb-0000-0000-0000-00000000000a', 'points', 3)$$,
  '23514', null, 'stats must use the player''s own team');

reset role;
select * from finish();
rollback;

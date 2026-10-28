-- Initial schema (SPEC §4). RLS lives in the next migration.

-- ===== Utilities =====
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- 6 chars without 0/O/1/I. The alphabet has 32 symbols, so byte % 32 is unbiased.
create function public.generate_public_code() returns text
language plpgsql volatile security definer set search_path = '' as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  bytes bytea;
  code text;
begin
  loop
    bytes := extensions.gen_random_bytes(6);
    code := '';
    for i in 0..5 loop
      code := code || substr(alphabet, 1 + get_byte(bytes, i) % 32, 1);
    end loop;
    exit when not exists (select 1 from public.tournaments t where t.public_code = code);
  end loop;
  return code;
end $$;

-- ===== Profiles (1:1 with auth.users) =====
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (new.id,
          coalesce(new.raw_user_meta_data ->> 'full_name',
                   new.raw_user_meta_data ->> 'name',
                   split_part(new.email, '@', 1)),
          new.raw_user_meta_data ->> 'avatar_url');
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ===== Tournament: public unit, owns teams and players =====
create table public.tournaments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  sport text not null check (sport in ('football', 'basketball')),
  sport_variant text check (
    sport_variant is null
    or (sport = 'football'   and sport_variant in ('football_11', 'football_7', 'futsal'))
    or (sport = 'basketball' and sport_variant in ('basketball_5', 'basketball_3x3'))),
  category text,
  season_label text,
  city text,
  state text,
  venue_default text,
  logo_url text,
  cover_url text,
  visibility text not null default 'public'
    check (visibility in ('public', 'unlisted', 'private')),
  public_code text not null unique default public.generate_public_code()
    check (public_code ~ '^[2-9A-HJ-NP-Z]{6}$'),
  default_settings jsonb not null default '{}'
    check (jsonb_typeof(default_settings) = 'object'),
  status text not null default 'draft'
    check (status in ('draft', 'in_progress', 'finished')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.tournaments (owner_id);

create table public.tournament_staff (
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('admin', 'scorer')),
  created_at timestamptz not null default now(),
  primary key (tournament_id, user_id)
);
create index on public.tournament_staff (user_id);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  name text not null,
  short_name varchar(4),
  logo_url text,
  primary_color text check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  captain_name text,
  copied_from_team_id uuid references public.teams (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (tournament_id, name)
);

create table public.players (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  first_name text not null,
  last_name text,
  jersey_number int check (jersey_number between 0 and 999),
  position text,
  photo_url text,
  birth_date date, -- PRIVATE: never exposed to the public (see public_players view)
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (team_id, jersey_number)
);

-- ===== Competitions inside a tournament =====
create table public.competitions (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  name text not null, -- free text; never hardcode names in logic
  type text not null check (type in ('league', 'quadrangular', 'knockout', 'groups_knockout')),
  sort_order int not null default 0,
  source_competition_id uuid references public.competitions (id) on delete set null,
  source_rank_from int,
  source_rank_to int,
  settings jsonb not null default '{}' check (jsonb_typeof(settings) = 'object'),
  status text not null default 'draft'
    check (status in ('draft', 'in_progress', 'finished')),
  champion_team_id uuid references public.teams (id) on delete set null,
  is_featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tournament_id, name),
  check (source_competition_id <> id),
  check ((source_rank_from is null) = (source_rank_to is null)),
  check (source_rank_from is null or (source_rank_from >= 1 and source_rank_to >= source_rank_from))
);
create unique index competitions_one_featured on public.competitions (tournament_id)
  where is_featured;

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.competitions (id) on delete cascade,
  name text not null,
  sort_order int not null default 0
);
create index on public.groups (competition_id);

create table public.competition_teams (
  competition_id uuid not null references public.competitions (id) on delete cascade,
  team_id uuid not null references public.teams (id) on delete cascade,
  group_id uuid references public.groups (id) on delete set null,
  seed int check (seed > 0),
  primary key (competition_id, team_id),
  unique (competition_id, seed) deferrable initially deferred -- allows reordering seeds
);
create index on public.competition_teams (team_id);

create table public.rounds (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.competitions (id) on delete cascade,
  number int not null check (number > 0),
  name text,
  unique (competition_id, number)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.competitions (id) on delete cascade,
  round_id uuid references public.rounds (id) on delete cascade,
  home_team_id uuid references public.teams (id), -- null = to be defined (bracket)
  away_team_id uuid references public.teams (id),
  bracket_slot text,
  next_slot text,
  leg int not null default 1 check (leg >= 1),
  scheduled_at timestamptz,
  venue text,
  referee text,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'live', 'finished', 'postponed', 'cancelled', 'forfeit')),
  home_score int check (home_score >= 0),
  away_score int check (away_score >= 0),
  home_penalties int check (home_penalties >= 0),
  away_penalties int check (away_penalties >= 0),
  period_scores jsonb check (period_scores is null or jsonb_typeof(period_scores) = 'array'),
  forfeit_winner_id uuid references public.teams (id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competition_id, bracket_slot, leg),
  check (home_team_id is null or away_team_id is null or home_team_id <> away_team_id),
  check (status <> 'finished' or (home_score is not null and away_score is not null)),
  check (status <> 'forfeit' or forfeit_winner_id in (home_team_id, away_team_id))
);
create index on public.matches (competition_id, scheduled_at);
create index on public.matches (round_id);
create index on public.matches (home_team_id);
create index on public.matches (away_team_id);

create table public.player_match_stats (
  match_id uuid not null references public.matches (id) on delete cascade,
  player_id uuid not null references public.players (id),
  team_id uuid not null references public.teams (id),
  stat_key text not null check (stat_key ~ '^[a-z_]+$'),
  value int not null default 0 check (value >= 0),
  primary key (match_id, player_id, stat_key)
);
create index on public.player_match_stats (player_id);
create index on public.player_match_stats (team_id);

create table public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  team_id uuid references public.teams (id),
  player_id uuid references public.players (id),
  related_player_id uuid references public.players (id),
  type text not null, -- TODO(product): catalog of live football events
  minute int check (minute >= 0),
  created_at timestamptz not null default now()
);
create index on public.match_events (match_id);

create table public.sanctions ( -- phase 2; sanctions belong to the tournament
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  reason text,
  matches_suspended int not null default 0 check (matches_suspended >= 0),
  created_at timestamptz not null default now()
);
create index on public.sanctions (tournament_id);
create index on public.sanctions (player_id);

-- ===== Integrity: nothing may point into another tournament =====
create function public.check_tournament_consistency() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  t_id uuid;
  bad boolean := false;
begin
  case tg_table_name
  when 'competitions' then
    select exists (
      select 1 from public.competitions c
       where c.id = new.source_competition_id and c.tournament_id <> new.tournament_id
      union all
      select 1 from public.teams tm
       where tm.id = new.champion_team_id and tm.tournament_id <> new.tournament_id)
    into bad;
  when 'competition_teams' then
    select c.tournament_id into t_id from public.competitions c where c.id = new.competition_id;
    select exists (
      select 1 from public.teams tm where tm.id = new.team_id and tm.tournament_id <> t_id
      union all
      select 1 from public.groups g
       where g.id = new.group_id and g.competition_id <> new.competition_id)
    into bad;
  when 'matches' then
    select c.tournament_id into t_id from public.competitions c where c.id = new.competition_id;
    select exists (
      select 1 from public.teams tm
       where tm.id in (new.home_team_id, new.away_team_id, new.forfeit_winner_id)
         and tm.tournament_id <> t_id
      union all
      select 1 from public.rounds r
       where r.id = new.round_id and r.competition_id <> new.competition_id)
    into bad;
  when 'player_match_stats' then
    select not exists (
      select 1 from public.matches m
        join public.players p on p.id = new.player_id
       where m.id = new.match_id
         and new.team_id in (m.home_team_id, m.away_team_id)
         and p.team_id = new.team_id)
    into bad;
  end case;
  if bad then
    raise exception 'inconsistent tournament reference in %', tg_table_name
      using errcode = '23514';
  end if;
  return new;
end $$;

create trigger consistency before insert or update on public.competitions
  for each row execute function public.check_tournament_consistency();
create trigger consistency before insert or update on public.competition_teams
  for each row execute function public.check_tournament_consistency();
create trigger consistency before insert or update on public.matches
  for each row execute function public.check_tournament_consistency();
create trigger consistency before insert or update on public.player_match_stats
  for each row execute function public.check_tournament_consistency();

create trigger set_updated_at before update on public.tournaments
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.competitions
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.matches
  for each row execute function public.set_updated_at();

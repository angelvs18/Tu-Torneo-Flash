-- Row Level Security (SPEC §4). Public read, writes by owner/staff.

-- ===== Helpers (security definer: avoid nested RLS and recursion) =====
create function public.has_tournament_role(p_tournament_id uuid, p_roles text[] default '{admin}')
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tournaments t
                  where t.id = p_tournament_id and t.owner_id = (select auth.uid()))
      or exists (select 1 from public.tournament_staff s
                  where s.tournament_id = p_tournament_id
                    and s.user_id = (select auth.uid())
                    and s.role = any (p_roles));
$$;

create function public.can_view_tournament(p_tournament_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tournaments t
                  where t.id = p_tournament_id and t.visibility in ('public', 'unlisted'))
      or public.has_tournament_role(p_tournament_id, '{admin,scorer}');
$$;

create function public.tournament_of_competition(p_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select tournament_id from public.competitions where id = p_id
$$;

create function public.tournament_of_team(p_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select tournament_id from public.teams where id = p_id
$$;

create function public.tournament_of_match(p_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select c.tournament_id
    from public.matches m
    join public.competitions c on c.id = m.competition_id
   where m.id = p_id
$$;

-- ===== Enable RLS =====
alter table public.profiles           enable row level security;
alter table public.tournaments        enable row level security;
alter table public.tournament_staff   enable row level security;
alter table public.teams              enable row level security;
alter table public.players            enable row level security;
alter table public.competitions       enable row level security;
alter table public.groups             enable row level security;
alter table public.competition_teams  enable row level security;
alter table public.rounds             enable row level security;
alter table public.matches            enable row level security;
alter table public.player_match_stats enable row level security;
alter table public.match_events       enable row level security;
alter table public.sanctions          enable row level security;

-- ===== profiles =====
-- TODO(product): widen to staff colleagues when the Staff screen lands.
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- ===== tournaments =====
-- The table only lists 'public' ones; 'unlisted' open through get_tournament_by_code.
create policy tournaments_select on public.tournaments for select to anon, authenticated
  using (visibility = 'public'
         or owner_id = (select auth.uid()) -- needed for INSERT ... RETURNING
         or public.has_tournament_role(id, '{admin,scorer}'));
create policy tournaments_insert on public.tournaments for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy tournaments_update on public.tournaments for update to authenticated
  using (public.has_tournament_role(id)) with check (public.has_tournament_role(id));
create policy tournaments_delete on public.tournaments for delete to authenticated
  using (owner_id = (select auth.uid()));

-- owner_id and public_code can only change through security definer RPCs.
create function public.tournaments_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated')
     and (new.owner_id is distinct from old.owner_id
          or new.public_code is distinct from old.public_code) then
    raise exception 'owner_id and public_code are immutable' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger guard before update on public.tournaments
  for each row execute function public.tournaments_guard();

-- ===== tournament_staff: managed by the owner; members can leave =====
-- TODO(product): should admins manage scorers too?
create policy staff_select on public.tournament_staff for select to authenticated
  using (user_id = (select auth.uid()) or public.has_tournament_role(tournament_id));
create policy staff_insert on public.tournament_staff for insert to authenticated
  with check (exists (select 1 from public.tournaments t
                       where t.id = tournament_id and t.owner_id = (select auth.uid())));
create policy staff_update on public.tournament_staff for update to authenticated
  using (exists (select 1 from public.tournaments t
                  where t.id = tournament_id and t.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.tournaments t
                       where t.id = tournament_id and t.owner_id = (select auth.uid())));
create policy staff_delete on public.tournament_staff for delete to authenticated
  using (user_id = (select auth.uid())
         or exists (select 1 from public.tournaments t
                     where t.id = tournament_id and t.owner_id = (select auth.uid())));

-- ===== Public read + admin write (owner or staff admin) =====
create policy teams_select on public.teams for select to anon, authenticated
  using (public.can_view_tournament(tournament_id));
create policy teams_write on public.teams for all to authenticated
  using (public.has_tournament_role(tournament_id))
  with check (public.has_tournament_role(tournament_id));

create policy competitions_select on public.competitions for select to anon, authenticated
  using (public.can_view_tournament(tournament_id));
create policy competitions_write on public.competitions for all to authenticated
  using (public.has_tournament_role(tournament_id))
  with check (public.has_tournament_role(tournament_id));

create policy groups_select on public.groups for select to anon, authenticated
  using (public.can_view_tournament(public.tournament_of_competition(competition_id)));
create policy groups_write on public.groups for all to authenticated
  using (public.has_tournament_role(public.tournament_of_competition(competition_id)))
  with check (public.has_tournament_role(public.tournament_of_competition(competition_id)));

create policy competition_teams_select on public.competition_teams for select to anon, authenticated
  using (public.can_view_tournament(public.tournament_of_competition(competition_id)));
create policy competition_teams_write on public.competition_teams for all to authenticated
  using (public.has_tournament_role(public.tournament_of_competition(competition_id)))
  with check (public.has_tournament_role(public.tournament_of_competition(competition_id)));

create policy rounds_select on public.rounds for select to anon, authenticated
  using (public.can_view_tournament(public.tournament_of_competition(competition_id)));
create policy rounds_write on public.rounds for all to authenticated
  using (public.has_tournament_role(public.tournament_of_competition(competition_id)))
  with check (public.has_tournament_role(public.tournament_of_competition(competition_id)));

-- ===== players: staff only; the public reads the public_players view =====
revoke all on public.players from anon;
create policy players_select on public.players for select to authenticated
  using (public.has_tournament_role(public.tournament_of_team(team_id), '{admin,scorer}'));
create policy players_write on public.players for all to authenticated
  using (public.has_tournament_role(public.tournament_of_team(team_id)))
  with check (public.has_tournament_role(public.tournament_of_team(team_id)));

-- ===== matches: admin everything; scorer only updates result fields =====
create policy matches_select on public.matches for select to anon, authenticated
  using (public.can_view_tournament(public.tournament_of_competition(competition_id)));
create policy matches_admin on public.matches for all to authenticated
  using (public.has_tournament_role(public.tournament_of_competition(competition_id)))
  with check (public.has_tournament_role(public.tournament_of_competition(competition_id)));
create policy matches_scorer_update on public.matches for update to authenticated
  using (public.has_tournament_role(public.tournament_of_competition(competition_id), '{scorer}'))
  with check (public.has_tournament_role(public.tournament_of_competition(competition_id), '{scorer}'));

create function public.matches_scorer_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated')
     and not public.has_tournament_role(public.tournament_of_competition(old.competition_id))
     and (new.competition_id, new.round_id, new.home_team_id, new.away_team_id,
          new.bracket_slot, new.next_slot, new.leg, new.scheduled_at, new.venue, new.referee)
         is distinct from
         (old.competition_id, old.round_id, old.home_team_id, old.away_team_id,
          old.bracket_slot, old.next_slot, old.leg, old.scheduled_at, old.venue, old.referee) then
    raise exception 'scorers can only update result fields' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger scorer_guard before update on public.matches
  for each row execute function public.matches_scorer_guard();

-- ===== Stats and events: admin or scorer =====
create policy pms_select on public.player_match_stats for select to anon, authenticated
  using (public.can_view_tournament(public.tournament_of_match(match_id)));
create policy pms_write on public.player_match_stats for all to authenticated
  using (public.has_tournament_role(public.tournament_of_match(match_id), '{admin,scorer}'))
  with check (public.has_tournament_role(public.tournament_of_match(match_id), '{admin,scorer}'));

create policy events_select on public.match_events for select to anon, authenticated
  using (public.can_view_tournament(public.tournament_of_match(match_id)));
create policy events_write on public.match_events for all to authenticated
  using (public.has_tournament_role(public.tournament_of_match(match_id), '{admin,scorer}'))
  with check (public.has_tournament_role(public.tournament_of_match(match_id), '{admin,scorer}'));

-- ===== Sanctions: staff only =====
create policy sanctions_select on public.sanctions for select to authenticated
  using (public.has_tournament_role(tournament_id, '{admin,scorer}'));
create policy sanctions_write on public.sanctions for all to authenticated
  using (public.has_tournament_role(tournament_id))
  with check (public.has_tournament_role(tournament_id));

-- ===== Public players view (no birth_date) =====
-- Runs as the view owner on purpose so anon can read rows without the private column.
create view public.public_players with (security_barrier = true) as
  select p.id, p.team_id, p.first_name, p.last_name, p.jersey_number,
         p.position, p.photo_url, p.is_active
    from public.players p
    join public.teams t on t.id = p.team_id
   where public.can_view_tournament(t.tournament_id);
revoke all on public.public_players from anon, authenticated;
grant select on public.public_players to anon, authenticated;

-- ===== Open a tournament by code (QR / link / code), including 'unlisted' =====
create function public.get_tournament_by_code(p_code text) returns setof public.tournaments
language sql stable security definer set search_path = '' as $$
  select * from public.tournaments
   where public_code = upper(trim(p_code)) and visibility in ('public', 'unlisted');
$$;

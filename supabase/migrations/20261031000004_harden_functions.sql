-- Hide security definer helpers from the REST API (advisors 0028/0029).
-- `private` is not in config.toml [api].schemas, so PostgREST never exposes it.
-- Policies, the column default and the public_players view reference functions
-- by OID, so `set schema` keeps them working; only text bodies need rewriting.

create schema private;
revoke all on schema private from public;
-- RLS policies run as the caller, so anon/authenticated still need access.
grant usage on schema private to anon, authenticated;

-- ===== RLS helpers =====
alter function public.has_tournament_role(uuid, text[]) set schema private;
alter function public.can_view_tournament(uuid)         set schema private;
alter function public.tournament_of_competition(uuid)   set schema private;
alter function public.tournament_of_team(uuid)          set schema private;
alter function public.tournament_of_match(uuid)         set schema private;

-- Used as the tournaments.public_code default: inserting users need EXECUTE.
alter function public.generate_public_code() set schema private;

create or replace function private.can_view_tournament(p_tournament_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tournaments t
                  where t.id = p_tournament_id and t.visibility in ('public', 'unlisted'))
      or private.has_tournament_role(p_tournament_id, '{admin,scorer}');
$$;

create or replace function public.matches_scorer_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated')
     and not private.has_tournament_role(private.tournament_of_competition(old.competition_id))
     and (new.competition_id, new.round_id, new.home_team_id, new.away_team_id,
          new.bracket_slot, new.next_slot, new.leg, new.scheduled_at, new.venue, new.referee)
         is distinct from
         (old.competition_id, old.round_id, old.home_team_id, old.away_team_id,
          old.bracket_slot, old.next_slot, old.leg, old.scheduled_at, old.venue, old.referee) then
    raise exception 'scorers can only update result fields' using errcode = '42501';
  end if;
  return new;
end $$;

-- ===== Trigger functions: firing a trigger does not check EXECUTE =====
revoke execute on function public.check_tournament_consistency() from public, anon, authenticated;
revoke execute on function public.handle_new_user()              from public, anon, authenticated;

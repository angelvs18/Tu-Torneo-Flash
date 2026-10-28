-- Live scores (Realtime enforces the matches_select policy).
alter publication supabase_realtime add table public.matches;

-- Public bucket for crests, covers and photos. Path: tournaments/{tournament_id}/...
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 2097152, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;

create function public.storage_tournament_id(p_name text) returns uuid
language plpgsql stable set search_path = '' as $$
begin
  if (storage.foldername(p_name))[1] is distinct from 'tournaments' then
    return null;
  end if;
  return (storage.foldername(p_name))[2]::uuid;
exception when invalid_text_representation then
  return null;
end $$;

create policy media_write on storage.objects for all to authenticated
  using (bucket_id = 'media'
         and public.has_tournament_role(public.storage_tournament_id(name)))
  with check (bucket_id = 'media'
              and public.has_tournament_role(public.storage_tournament_id(name)));

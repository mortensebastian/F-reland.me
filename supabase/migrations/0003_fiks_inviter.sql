-- 0003_fiks_inviter.sql
-- Retter feilen «column reference "epost" is ambiguous» ved invitering.
--
-- I inviter_bruker() het funksjonsparameteren det samme som kolonnen
-- expedition_invites.epost. I DELETE-setningen (som rydder bort en ev. ventende
-- invitasjon når vennen allerede har konto) klarte ikke Postgres å avgjøre om
-- «epost» var parameteren eller kolonnen, og avbrøt hele invitasjonen.
--
-- Fiksen kvalifiserer kolonnereferansen (public.expedition_invites.epost) så den
-- ikke er tvetydig. Funksjonen er ellers uendret.
--
-- Kjør i Supabase SQL Editor (lim inn hele → Run). Trygt å kjøre på nytt.

create or replace function public.inviter_bruker(exp uuid, epost text)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  ren  text := lower(trim(epost));
  mott uuid;
begin
  if not public.er_eier(exp, auth.uid()) then
    raise exception 'Bare eieren kan invitere.';
  end if;
  if ren = '' then
    raise exception 'Skriv inn en e-postadresse.';
  end if;

  select id into mott from auth.users where lower(email) = ren limit 1;

  if mott is not null then
    if mott = auth.uid() then
      return 'eier';
    end if;
    insert into public.expedition_members (ekspedisjon, bruker)
      values (exp, mott)
      on conflict do nothing;
    -- Rydd bort en ev. ventende invitasjon på samme e-post. Kolonnen kvalifiseres
    -- så den ikke forveksles med funksjonsparameteren «epost».
    delete from public.expedition_invites
      where ekspedisjon = exp
        and lower(public.expedition_invites.epost) = ren;
    return 'lagt_til';
  else
    -- Ingen konto ennå: lagre en ventende invitasjon. Den blir til medlemskap
    -- automatisk første gang vennen logger inn med denne e-posten (se trigger
    -- handle_new_user i 0002).
    insert into public.expedition_invites (ekspedisjon, epost, invitert_av)
      values (exp, ren, auth.uid())
      on conflict (ekspedisjon, epost) do nothing;
    return 'invitert';
  end if;
end;
$$;

grant execute on function public.inviter_bruker(uuid, text) to authenticated;

-- 0002_deling.sql
-- Deling: privat/offentlig styres allerede av «offentlig»-kolonna fra 0001.
-- Dette legger til invitasjoner: eieren kan invitere en venn på e-post til å
-- bidra på en ekspedisjon.
--
-- Utfordringen er at vennen kanskje ikke har logget inn ennå. Derfor:
--  · Har de allerede en konto  → de legges rett inn som medlem.
--  · Har de ikke konto ennå     → invitasjonen lagres «ventende» på e-post, og
--                                 gjøres om til medlemskap første gang de logger inn.
--
-- Kjør denne etter 0001_init.sql (SQL Editor → lim inn → Run).

-- ---------------------------------------------------------------------------
-- Ventende invitasjoner (på e-post, før vennen har en konto)
-- ---------------------------------------------------------------------------
create table if not exists public.expedition_invites (
  ekspedisjon uuid not null references public.expeditions(id) on delete cascade,
  epost       text not null,
  invitert_av uuid references auth.users(id) on delete set null,
  opprettet   timestamptz not null default now(),
  primary key (ekspedisjon, epost)
);

alter table public.expedition_invites enable row level security;

-- Hjelpefunksjon: e-posten til den innloggede brukeren. SECURITY DEFINER fordi
-- vanlige roller ikke får lese auth.users direkte.
create or replace function public.min_epost()
returns text
language sql
security definer
stable
set search_path = public, auth
as $$
  select email from auth.users where id = auth.uid();
$$;

-- Eieren styrer invitasjonene på sine turer; den inviterte kan se sine egne
-- (på e-post) mens de venter på å logge inn.
drop policy if exists "se invitasjoner" on public.expedition_invites;
create policy "se invitasjoner"
  on public.expedition_invites for select
  using (
    public.er_eier(ekspedisjon, auth.uid())
    or lower(epost) = lower(coalesce(public.min_epost(), ''))
  );

drop policy if exists "eier lager invitasjon" on public.expedition_invites;
create policy "eier lager invitasjon"
  on public.expedition_invites for insert
  with check (public.er_eier(ekspedisjon, auth.uid()));

drop policy if exists "eier fjerner invitasjon" on public.expedition_invites;
create policy "eier fjerner invitasjon"
  on public.expedition_invites for delete
  using (public.er_eier(ekspedisjon, auth.uid()));

-- ---------------------------------------------------------------------------
-- Invitere: slår opp om vennen finnes, og legger dem enten rett inn som medlem
-- eller lagrer en ventende invitasjon. Returnerer hva som skjedde:
--   'lagt_til'  – vennen fantes og er nå medlem
--   'invitert'  – ingen konto ennå, invitasjon lagret (kobles ved innlogging)
--   'eier'      – du prøvde å invitere deg selv
-- ---------------------------------------------------------------------------
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
    -- Rydd bort en ev. ventende invitasjon på samme e-post.
    delete from public.expedition_invites where ekspedisjon = exp and lower(epost) = ren;
    return 'lagt_til';
  else
    insert into public.expedition_invites (ekspedisjon, epost, invitert_av)
      values (exp, ren, auth.uid())
      on conflict (ekspedisjon, epost) do nothing;
    return 'invitert';
  end if;
end;
$$;

grant execute on function public.min_epost() to authenticated;
grant execute on function public.inviter_bruker(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Oppdater profil-triggeren så ventende invitasjoner blir til medlemskap ved
-- registrering. Erstatter funksjonen fra 0001 (samme trigger).
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, visningsnavn)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;

  -- Gjør ventende invitasjoner (lagret på e-post) om til medlemskap.
  insert into public.expedition_members (ekspedisjon, bruker)
    select i.ekspedisjon, new.id
    from public.expedition_invites i
    where lower(i.epost) = lower(new.email)
    on conflict do nothing;
  delete from public.expedition_invites where lower(epost) = lower(new.email);

  return new;
end;
$$;

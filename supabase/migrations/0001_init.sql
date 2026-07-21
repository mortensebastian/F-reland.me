-- 0001_init.sql
-- Grunnmuren for delte ekspedisjoner på foreland.me.
--
-- Tanken: siden er fortsatt statiske filer, men ekspedisjonene hentes fra
-- Postgres (Supabase) i stedet for turer.json. Hver bruker eier sine egne
-- turer, kan invitere venner til å bidra, og velger selv om en tur er
-- privat eller offentlig. All tilgangsstyring håndheves av Row Level
-- Security her i databasen – derfor er det trygt at nettleseren bruker den
-- offentlige «anon»-nøkkelen.
--
-- Kjør denne i Supabase (SQL Editor → lim inn → Run). Se supabase/LES-MEG.md.

-- ---------------------------------------------------------------------------
-- Tabeller
-- ---------------------------------------------------------------------------

-- Profil per innlogget bruker. Kobles 1:1 til Supabase sin auth.users.
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  visningsnavn text,
  opprettet    timestamptz not null default now()
);

-- En ekspedisjon. Hele turen ligger i «data» på nøyaktig samme form som en
-- oppføring i turer.json (navn, beskrivelse, etapper, pakkeliste, rute …), så
-- resten av siden slipper å endre form. Kolonnene ved siden er det vi trenger
-- for å styre tilgang og sortering.
create table if not exists public.expeditions (
  id        uuid primary key default gen_random_uuid(),
  slug      text not null,                              -- tur-id (brukes til pakkeliste-huking i nettleseren)
  eier      uuid not null references auth.users(id) on delete cascade,
  offentlig boolean not null default false,             -- privat (false) eller offentlig (true)
  data      jsonb not null default '{}'::jsonb,         -- selve turen, samme form som turer.json
  opprettet timestamptz not null default now(),
  endret    timestamptz not null default now()
);
create index if not exists expeditions_eier_idx on public.expeditions (eier);
create index if not exists expeditions_offentlig_idx on public.expeditions (offentlig);
-- Samme eier kan ikke ha to turer med samme slug (så GPX-filnavn holder seg unike per person).
create unique index if not exists expeditions_eier_slug_uniq on public.expeditions (eier, slug);

-- Inviterte bidragsytere. Eieren legger til venner som får redigere turen.
create table if not exists public.expedition_members (
  ekspedisjon uuid not null references public.expeditions(id) on delete cascade,
  bruker      uuid not null references auth.users(id) on delete cascade,
  rolle       text not null default 'bidragsyter',
  lagt_til    timestamptz not null default now(),
  primary key (ekspedisjon, bruker)
);
create index if not exists expedition_members_bruker_idx on public.expedition_members (bruker);

-- ---------------------------------------------------------------------------
-- Hjelpefunksjoner
-- ---------------------------------------------------------------------------

-- Er brukeren invitert bidragsyter på turen? SECURITY DEFINER gjør at
-- funksjonen kan lese medlemstabellen uten å utløse RLS på nytt (og dermed
-- unngå at policyene refererer til hverandre i ring).
create or replace function public.er_medlem(exp uuid, usr uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.expedition_members m
    where m.ekspedisjon = exp and m.bruker = usr
  );
$$;

-- Er brukeren eier av turen? Samme grunn til SECURITY DEFINER.
create or replace function public.er_eier(exp uuid, usr uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.expeditions e
    where e.id = exp and e.eier = usr
  );
$$;

-- Oppdater «endret» automatisk hver gang en tur lagres.
create or replace function public.sett_endret()
returns trigger
language plpgsql
as $$
begin
  new.endret = now();
  return new;
end;
$$;

drop trigger if exists expeditions_sett_endret on public.expeditions;
create trigger expeditions_sett_endret
  before update on public.expeditions
  for each row execute function public.sett_endret();

-- Lag en profilrad automatisk når en ny bruker registrerer seg.
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
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles          enable row level security;
alter table public.expeditions       enable row level security;
alter table public.expedition_members enable row level security;

-- Profiler: alle kan lese visningsnavn (til «lagt til av»), men bare din egen kan endres.
drop policy if exists "profiler er lesbare" on public.profiles;
create policy "profiler er lesbare"
  on public.profiles for select using (true);

drop policy if exists "sett egen profil" on public.profiles;
create policy "sett egen profil"
  on public.profiles for insert with check (id = auth.uid());

drop policy if exists "endre egen profil" on public.profiles;
create policy "endre egen profil"
  on public.profiles for update using (id = auth.uid());

-- Ekspedisjoner:
--  · Se:    offentlige, eller dine egne, eller de du er invitert til.
--  · Lag:   innlogget – du blir eier.
--  · Endre: eier eller invitert bidragsyter.
--  · Slett: kun eier.
drop policy if exists "se turer man har tilgang til" on public.expeditions;
create policy "se turer man har tilgang til"
  on public.expeditions for select
  using (
    offentlig
    or eier = auth.uid()
    or public.er_medlem(id, auth.uid())
  );

drop policy if exists "lag egne turer" on public.expeditions;
create policy "lag egne turer"
  on public.expeditions for insert
  with check (eier = auth.uid());

drop policy if exists "endre egne eller inviterte turer" on public.expeditions;
create policy "endre egne eller inviterte turer"
  on public.expeditions for update
  using (eier = auth.uid() or public.er_medlem(id, auth.uid()));

drop policy if exists "slett egne turer" on public.expeditions;
create policy "slett egne turer"
  on public.expeditions for delete
  using (eier = auth.uid());

-- Medlemmer:
--  · Se:  dine egne medlemskap, eller alle på turer du eier.
--  · Lag/slett: kun eieren av turen inviterer og fjerner.
drop policy if exists "se medlemskap" on public.expedition_members;
create policy "se medlemskap"
  on public.expedition_members for select
  using (bruker = auth.uid() or public.er_eier(ekspedisjon, auth.uid()));

drop policy if exists "eier inviterer" on public.expedition_members;
create policy "eier inviterer"
  on public.expedition_members for insert
  with check (public.er_eier(ekspedisjon, auth.uid()));

drop policy if exists "eier fjerner" on public.expedition_members;
create policy "eier fjerner"
  on public.expedition_members for delete
  using (public.er_eier(ekspedisjon, auth.uid()));

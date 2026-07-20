# Delte ekspedisjoner – Supabase-oppsett

Dette er backend-en som lar deg og venner lage ekspedisjoner sammen: hver bruker
eier sine egne turer, kan invitere andre til å bidra, og velger selv om en tur
er **privat** eller **offentlig**.

Nettstedet er fortsatt bare statiske filer. `ekspedisjon.html` laster Supabase
sin JavaScript-klient fra CDN og snakker med databasen fra nettleseren – ingen
server å drifte, ingen byggesteg. Tilgangsstyringen ligger i databasen (Row Level
Security), så den offentlige «anon»-nøkkelen er trygg å ha i koden.

## Trinnvis oppbygging
Dette bygges i tre trinn. Du leser dette etter **trinn 1**:

1. **Skjema + innlogging** ✅ – databasen (denne mappa) og «Logg inn»-feltet på
   ekspedisjonssiden. Innloggede brukere ser sine egne + offentlige turer.
2. **Lagre/redigere fra planleggeren** – «Lagre»-knapp som skriver rett til
   databasen (kommer).
3. **Privat/offentlig-bryter + invitere venner** (kommer).

## Sett opp Supabase (engangsjobb)

1. Lag en gratis konto på [supabase.com](https://supabase.com) og et nytt
   prosjekt. Velg region i Europa (f.eks. Frankfurt) og et sterkt
   database-passord.
2. Åpne **SQL Editor** i prosjektet, lim inn hele innholdet i
   [`migrations/0001_init.sql`](migrations/0001_init.sql) og trykk **Run**.
   Da opprettes tabellene, tilgangsreglene og triggerne.
3. Skru på innlogging med e-postlenke: **Authentication → Providers → Email**,
   og la «Email» stå på. (Google e.l. kan legges til senere samme sted.)
4. **Authentication → URL Configuration:** sett *Site URL* til
   `https://foreland.me` og legg `https://foreland.me/ekspedisjon.html` til
   under *Redirect URLs*, slik at innloggingslenka i e-posten sender deg
   tilbake til riktig side.
5. Hent de to **offentlige** verdiene under **Project Settings → API**:
   - *Project URL* (f.eks. `https://abcxyz.supabase.co`)
   - *anon public* API-nøkkel

## Koble siden til prosjektet

Åpne `ekspedisjon.html` og fyll inn de to verdiene i konfig-blokka øverst:

```html
<script>
  // Fyll inn prosjektets offentlige verdier for å skru på innlogging og deling.
  // Begge er ment å være offentlige – tilgang styres av databasen (RLS).
  window.FORELAND_SUPABASE = {
    url:     "https://DITT-PROSJEKT.supabase.co",
    anonKey: "DIN-ANON-NØKKEL"
  };
</script>
```

Er feltene tomme, oppfører siden seg nøyaktig som før (kun turer fra
`turer.json`), og innloggingsfeltet er skjult. Så snart begge er fylt ut, dukker
«Logg inn»-feltet opp og databaseturene blir med i lista.

## Datamodell (kort)

| Tabell | Innhold |
| --- | --- |
| `profiles` | Én rad per bruker: id + visningsnavn. Lages automatisk ved registrering. |
| `expeditions` | Én rad per tur: `eier`, `offentlig`, `slug`, og hele turen i `data` (samme form som en `turer.json`-oppføring). |
| `expedition_members` | Inviterte bidragsytere: hvem som får redigere hvilken tur. |

## Tilgangsregler (håndheves i databasen)

- **Se en tur:** hvis den er offentlig, ELLER du eier den, ELLER du er invitert.
- **Lage:** innlogget – du blir eier.
- **Endre:** eier eller invitert bidragsyter.
- **Slette / invitere / fjerne medlemmer:** kun eieren.

## Forholdet til `turer.json`

`turer.json` forsvinner ikke: de innebygde/eksisterende turene vises fortsatt fra
fila. Databaseturene legges til i tillegg. Vil du senere flytte en `turer.json`-tur
inn i databasen, lager du den bare på nytt som innlogget bruker (trinn 2).

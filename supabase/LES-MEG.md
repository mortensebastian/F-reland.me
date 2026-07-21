# Delte ekspedisjoner – Supabase-oppsett

Dette er backend-en som lar deg og venner lage ekspedisjoner sammen: hver bruker
eier sine egne turer, kan invitere andre til å bidra, og velger selv om en tur
er **privat** eller **offentlig**.

Nettstedet er fortsatt bare statiske filer. `ekspedisjon.html` laster Supabase
sin JavaScript-klient fra CDN og snakker med databasen fra nettleseren – ingen
server å drifte, ingen byggesteg. Tilgangsstyringen ligger i databasen (Row Level
Security), så den offentlige «anon»-nøkkelen er trygg å ha i koden.

## Trinnvis oppbygging
Alle tre trinn er nå på plass:

1. **Skjema + innlogging** ✅ – databasen (denne mappa) og «Logg inn»-feltet på
   ekspedisjonssiden. Innloggede brukere ser sine egne + offentlige turer.
2. **Lagre/redigere fra planleggeren** ✅ – knappen «Lagre til Ekspedisjon» skriver
   turen (inkludert rute) rett til databasen, uten commit eller filopplasting.
   «Rediger denne turen» på egne databaseturer henter alt tilbake i planleggeren.
3. **Privat/offentlig + invitere venner** ✅ – synlighetsvelger i lagre-skjemaet og
   en bryter på hvert eget turkort, pluss et felt for å invitere venner på e-post
   til å bidra på en ekspedisjon.

## Sett opp Supabase (engangsjobb)

1. Lag en gratis konto på [supabase.com](https://supabase.com) og et nytt
   prosjekt. Velg region i Europa (f.eks. Frankfurt) og et sterkt
   database-passord.
2. Åpne **SQL Editor** i prosjektet, lim inn hele innholdet i
   [`migrations/0001_init.sql`](migrations/0001_init.sql) og trykk **Run**.
   Da opprettes tabellene, tilgangsreglene og triggerne. Kjør deretter
   [`migrations/0002_deling.sql`](migrations/0002_deling.sql) på samme måte –
   den legger til invitasjoner (privat/offentlig-deling og «inviter en venn»).
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

## Lagre en tur (når du er logget inn)

Åpne **Ekspedisjonsplanlegger** → **Lagre som tur**, fyll ut det du vil og trykk
**«Lagre til Ekspedisjon»** (i stedet for «Lag JSON», som fortsatt er der for
Mortens egne showcase-turer i `turer.json`). Ruta legges rett inn i databaseraden
som GPX-tekst – ingen filer å laste ned eller commite. Turen dukker straks opp
under **Ekspedisjoner**, med en **«Rediger denne turen»**-knapp som henter alt
(felter, etapper, pakkeliste og ruta) tilbake i planleggeren. Lagrer du på nytt
med samme id, oppdateres samme rad i stedet for å lage en ny.

## Dele en tur (privat/offentlig + invitere)

På hvert av dine egne turkort ligger et **Deling**-panel:

- **Privat/offentlig-bryter.** Privat = bare du og de du inviterer ser turen.
  Offentlig = alle som besøker siden ser den. Du kan også velge synlighet
  allerede når du lagrer, via «Synlighet»-feltet i lagre-skjemaet.
- **Inviter en venn** ved å skrive e-posten deres og trykke «Inviter».
  - Har vennen allerede logget inn på siden, blir de lagt til som bidragsyter
    med en gang og kan redigere turen.
  - Har de ikke en konto ennå, lagres invitasjonen «ventende», og de blir
    bidragsyter automatisk første gang de logger inn med den e-posten.
- Lista under viser bidragsytere og ventende invitasjoner, hver med et kryss for
  å fjerne / trekke tilbake.

En **bidragsyter** ser turen (også om den er privat) og får sin egen «Rediger
denne turen»-knapp – de kan endre innhold og rute, og lagringen oppdaterer den
samme turen. Bare **eieren** kan endre synlighet, invitere/fjerne folk eller
slette turen.

## Datamodell (kort)

| Tabell | Innhold |
| --- | --- |
| `profiles` | Én rad per bruker: id + visningsnavn. Lages automatisk ved registrering. |
| `expeditions` | Én rad per tur: `eier`, `offentlig`, `slug`, og hele turen i `data` (samme form som en `turer.json`-oppføring). |
| `expedition_members` | Bidragsytere som får redigere en tur (venner som allerede har konto). |
| `expedition_invites` | Ventende invitasjoner på e-post, for venner uten konto ennå. Blir til medlemskap ved innlogging. |

## Tilgangsregler (håndheves i databasen)

- **Se en tur:** hvis den er offentlig, ELLER du eier den, ELLER du er invitert.
- **Lage:** innlogget – du blir eier.
- **Endre:** eier eller invitert bidragsyter.
- **Slette / invitere / fjerne medlemmer:** kun eieren.

## Forholdet til `turer.json`

`turer.json` forsvinner ikke: de innebygde/eksisterende turene vises fortsatt fra
fila. Databaseturene legges til i tillegg. Vil du senere flytte en `turer.json`-tur
inn i databasen, åpner du den med «Rediger denne turen» og trykker «Lagre til
Ekspedisjon» i stedet for «Lag JSON» – da lagres den som en ny, privat tur under
din bruker.

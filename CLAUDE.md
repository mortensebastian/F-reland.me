# CLAUDE.md

Veiledning for arbeid i dette repoet.

## Om nettstedet
- **foreland.me** er Mortens personlige nettsted – et utstillingsvindu som samler og
  publiserer ting han jobber med og utvikler: prosjekter, web-apper, CV, og litt moro
  ved siden av. Forsiden er en enkel meny av kort som lenker videre til hver underside.
- Det er et statisk nettsted som hostes på **GitHub Pages** (se `CNAME`).
- Det finnes **ingen backend, byggesteg eller rammeverk** – kun håndskrevne HTML-filer
  med innebygd CSS og litt vanilla JavaScript. En fil = én side.
- Språk: **norsk** (bokmål). Ny tekst og kommentarer skrives på norsk.

## Filer
| Fil | Side |
| --- | --- |
| `index.html` | Forside med kort som lenker videre |
| `prosjekter.html` | Prosjekter |
| `apper.html` | Web-apper |
| `cv.html` | CV |
| `gardogslekt.html` | Gård og ætt |
| `ansiennitet.html` | Ansiennitet |
| `ekspedisjon.html` | Ekspedisjoner + planlegger (kart/GPX) |

## Designsystem (gjenbruk alltid)
Alle sider deler samme uttrykk. Kopier fra en eksisterende side i stedet for å finne opp nytt.

- **Fargevariabler** (`:root`):
  `--paper:#f3ede1; --ink:#20302f; --muted:#6c726a; --line:#d7cdb9;`
  `--accent:#2f7d72; --warm:#c0762f; --card:#faf6ee;`
- **Fonter:** Fraunces (overskrifter) + Hanken Grotesk (brødtekst), lastes fra Google Fonts.
- **Faste elementer:** dekorative høydekoter (`.contours` SVG), `.wrap`-container (maks 720px),
  `.back`-lenke øverst, `.kicker`, `h1`, `.lede`, `.card`-rutenett, `footer` med årstall-script.
- **Animasjon:** `@keyframes rise` med trappet `animation-delay`. Respekter
  `prefers-reduced-motion`.

## Legge til en ny side
1. Kopier en eksisterende side (f.eks. `prosjekter.html`) som mal.
2. Bytt `<title>`, `.kicker`, `h1`, `.lede` og innhold.
3. Legg til et nytt `.card` i `index.html` som lenker til den nye siden.

## Kart / GPX (`ekspedisjon.html`)
- Kart via **Leaflet** (CDN, ingen API-nøkkel).
- Gratis kartlag: **Kartverket topo** (standard), **OpenTopoMap**, **OpenStreetMap**.
- GPX parses klient-side med `DOMParser`. Unntak: når du lager en tur i
  planleggeren, hentes høyde fra **Kartverkets høyde-API** (`ws.geonorge.no`,
  gratis, ingen nøkkel) og skrives inn som `<ele>` i GPX-fila. Publiserte sider
  leser høyden fra fila og kaller ikke Kartverket per visning.
- Turer lagres i `turer.json` (+ GPX i `turer/`), som `ekspedisjon.html` henter
  datadrevet. Se `turer/LES-MEG.md`.
- Skjulte Leaflet-kart må kalle `map.invalidateSize()` når de blir synlige.

## Konvensjoner
- Behold innebygd CSS/JS i hver fil (ingen delte assets/byggesteg).
- Interne lenker starter med `/` (f.eks. `/ekspedisjon.html`).
- Test ved å åpne HTML-fila direkte i nettleser; ingen server trengs.
- Ekstern e-post/lenker beholdes slik de er på de andre sidene.

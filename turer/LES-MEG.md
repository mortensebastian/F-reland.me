# Turer – slik lagrer du en ekspedisjon

Ekspedisjonene på `/ekspedisjon.html` hentes fra `turer.json` i rota av repoet.
Siden har **ingen backend** – lagring = å legge en fil i repoet og committe.
Alt du legger inn her blir synlig for alle som besøker siden.

## Legge til en tur (3 steg)

1. **Lag ruta.** Åpne ekspedisjonsplanleggeren, tegn eller last opp ruta, og
   trykk «Last ned som GPX». Legg fila her i `turer/`, f.eks.
   `turer/min-tur.gpx`.
2. **Legg til en oppføring** i `turer.json` (se skjema under). Sett `gpx` til
   `/turer/min-tur.gpx`.
3. **Commit og push.** Siden oppdaterer seg selv – ingen bygg trengs.

Har du ikke en rute ennå? Dropp `gpx`-feltet, så vises turen uten kart (fint for
en tur du fortsatt planlegger).

## Skjema

| Felt | Påkrevd | Forklaring |
| --- | --- | --- |
| `id` | ja | Unik, små bokstaver, bindestrek. Brukes til å huske avkryssing i pakkelista. |
| `navn` | ja | Tittelen på turen. |
| `status` | ja | `"planlagt"` eller `"fullfort"`. Styrer merkelappen på kortet. |
| `type` | nei | F.eks. `"Fottur"`, `"Ski"`, `"Løping"`. |
| `dato` | nei | ISO-dato, f.eks. `"2026-08-15"`. |
| `dager` | nei | Antall dager (tall). |
| `beskrivelse` | ja | Kort ingress som vises på kortet. |
| `gpx` | nei | Sti til GPX-fila, f.eks. `"/turer/min-tur.gpx"`. |
| `distanse_km` | nei | Tall. Vises hvis satt; ellers regnes den ut fra GPX. |
| `stigning_m` | nei | Tall. Vises hvis satt; ellers regnes den ut fra GPX. |
| `notater` | nei | Fritekst – tanker underveis, refleksjoner. Linjeskift blir avsnitt. |
| `etapper` | nei | Liste med etapper, hver med `navn`, `notat` og `sporsmal`. |
| `pakkeliste` | nei | Liste med grupper, hver med `gruppe` og `ting` (liste av tekst). |

### Etappe

```json
{
  "navn": "Dag 1 – Inn til hytta",
  "notat": "Rolig start. Fyll vann ved bekken.",
  "sporsmal": ["Er broa åpen?", "Må hytta forhåndsbookes?"]
}
```

`sporsmal` er spørsmål du vil ha svar på før eller under turen – nyttig når du
planlegger. La den stå tom (`[]`) om du ikke har noen.

### Pakkeliste

```json
{
  "gruppe": "Klær",
  "ting": ["Ullundertøy", "Regnjakke", "Ekstra sokker"]
}
```

Selve lista deles med alle. Avkryssingen din («har jeg pakket dette?») lagres
kun lokalt i din egen nettleser, og påvirker ikke det andre ser.

## Eksempel

Se `eksempel-hardangervidda` i `turer.json` for en komplett oppføring med alle
feltene. Slett den når du har lagt inn dine egne turer.

## Fase 2 (senere)

Når det blir aktuelt med innlogging og flere bidragsytere, byttes bare *kilden*:
siden henter samme JSON-form fra en database (f.eks. Supabase) i stedet for
denne fila. Resten av siden er uendret.

# Routes to Safety — A Wildfire Evacuation Map from Open Data

Hands-on workshop for **FOSS4G North America 2026** · Sacramento, CA · **Mon Nov 2, 2026, 09:00–12:00** · room Beavis.

**Demo site:** <https://vishal4c.github.io/routes-to-safety-workshop/> — the finished map you build the pieces of (hazard zones, 10 shelters, drive-time bands, drop a pin → nearest shelter by road).

In 2018 Paradise and in 2023 Lahaina learned that a map saying "go" is not the same as a road that can carry people. In three
hours you build a wildfire-evacuation map for a real place — the **Placer County I-80 corridor** — on your own laptop, with open data
and open tools: **Overture Maps** and **CAL FIRE** hazard zones queried with **DuckDB**, tiled with **Planetiler** into **PMTiles**,
styled in **MapLibre GL JS**, and routed with **OSRM** (nearest shelter by road; "what if I-80 is closed?"). Most open-mapping workshops stop
at the rendered map; here you also compute over it — and you learn what such a map cannot tell you.

> ⚠️ **Materials being finalised; structure stable.** Module scripts, data and slides are filled in before the session; file
> names and the lab order will not change.

> **Teaching example, not an official evacuation resource. Drive-time estimates assume no traffic and no closures. In an emergency follow county OES / Genasys-Zonehaven alerts and CAL FIRE incident pages.**

## Quickstart

```bash
git clone --depth 1 https://github.com/vishal4c/routes-to-safety-workshop.git
cd routes-to-safety-workshop
# pick a tier (below), then:
python3 setup/check_setup.py                     # green/red per tool
duckdb -c ".read setup/hello-geo.sql"            # one line, the same on every screen
```

Always run commands from the **repo root**. Windows: use **Git Bash**.

| Tier | For | Installs | Routing |
|---|---|---|---|
| 1 Codespaces | no Docker / corporate laptop | nothing — **personal** GitHub account; open the URL from the Ports tab (globe icon) | yes |
| 2 Local containers (**recommended if you can**) | wants to survive wifi loss | Finch / Docker Desktop / OrbStack / Colima; `docker compose pull`; `scripts/get-bundle.sh` | yes |
| 3 Native, no Docker | containers blocked | Git, DuckDB, Temurin 21, Node, uv, go-pmtiles; `scripts/get-bundle.sh` | no (map + shelters) |
| 4 Browser only | laptop failed | nothing — the demo site | no |

Routing needs Docker or Codespaces (OSRM ships no native Windows/macOS binaries). Details and PowerShell equivalents: [`setup/`](setup/).
Serve the repo with Caddy (:8080, containers) or `npx serve -l 8080 .` — **never** `python -m http.server` (no Range requests, PMTiles breaks).

## Module map and agenda

| Time | Block | Folder | What you do | Tools |
|---|---|---|---|---|
| 0:00–0:15 | 0 Setup & welcome | [`setup/`](setup/) | Lab 0: confirm your environment | DuckDB |
| 0:15–0:30 | 1 The problem and the plan | slides | River Fire 2021, Mosquito Fire 2022, the two questions, what we leave out; live demo | — |
| 0:30–1:10 | 2 Extract the data | [`00-data/`](00-data/) | Labs 1a–1c: look around, candidate shelters, export to GeoJSON | DuckDB, Overture |
| 1:10–1:20 | Break | | | |
| 1:20–2:05 | 3 Build the basemap | [`01-tiles/`](01-tiles/) · [`02-web/`](02-web/) | Labs 2a–2c: Planetiler → PMTiles, render, restyle | Planetiler, PMTiles, MapLibre |
| 2:05–**2:37** | 4 Compute the routes | [`03-routing/`](03-routing/) | Labs 3a–3c: hello route, nearest shelter by road, "I-80 is closed" | OSRM |
| 2:37–3:00 | 5 Reproduce, adapt, scale | [`04-adapt/`](04-adapt/) | Lab 4: `scripts/make-data.sh --plan` for your own town; recap | — |

Instructor material: [`instructor/`](instructor/) (prep checklist, wifi-death runbook).

## The stack (pinned in [`versions.env`](versions.env))

| Tool | Version |
|---|---|
| DuckDB CLI (+ spatial) | 2.0.0 |
| Temurin / OpenJDK | 21 |
| Planetiler | v0.10.2 |
| go-pmtiles | v1.31.2 |
| OSRM | `ghcr.io/project-osrm/osrm-backend:v26.10.0-debian` |
| Overture Maps release | 2026-09-23.1 |
| Node | 22 |
| MapLibre GL JS | 6.14.0 (ESM only) |
| PMTiles (JS) | 4.5.0 |
| Marp CLI (slides) | 4.5.1 |
| osmium-tool | 1.19 |

DuckDB 2.0 note: start spatial SQL with `LOAD spatial; SET geometry_always_xy = true;` (becomes the default in 2.1).

## Study area

**Placer County I-80 corridor: Rocklin → Auburn → Colfax → Foresthill.**
Bounding box (W,S,E,N): **-121.40, 38.72, -120.52, 39.20** (≈ 0.42 sq. degrees; values live in `versions.env`).
Why here: the **River Fire (2021)** forced mandatory evacuations at Colfax (2,619 acres; evacuation ordered Aug 4, lifted about two days later); the **Mosquito Fire (2022, 76,771 acres)** moved the
evacuation shelter to Sierra College in Rocklin mid-incident; CAL FIRE's Very High hazard zone rings Auburn and Colfax; I-80 is the lifeline
and about 30 minutes from the venue. The box is wide enough to contain the whole Mosquito perimeter. Swap it for your own town in Lab 4.

## Licensing

- **Code** (scripts, config, JS, `build.sh`): [MIT](LICENSE)
- **Materials** (slides, docs, exercises, READMEs): [CC BY-SA 4.0](LICENSE-materials)
- **Data** keeps its source licences: [`data/LICENSE-data.md`](data/LICENSE-data.md). Provenance, sizes and regeneration: [`data/README.md`](data/README.md).

## Data attribution

© OpenStreetMap contributors · © Overture Maps Foundation · Fire Hazard Severity Zones: CAL FIRE FRAP (CC-BY) · Land cover: ESA WorldCover (CC-BY)

- OpenStreetMap — ODbL 1.0 · Overture Maps — ODbL / CDLA-Permissive-2.0 by theme · CAL FIRE FRAP — CC-BY · ESA WorldCover — CC-BY 4.0.

## Instructors

**Vishal Kumar** · **Shaishav Maisuria** — Amazon Maps. The workshop teaches only the public open stack.

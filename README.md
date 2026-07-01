# Routes to Safety — A Wildfire Evacuation Map from Open Data

Hands-on workshop materials for **FOSS4G North America 2026** (Sacramento, CA · Nov 2, 2026).

Build a wildfire-evacuation map for a Sacramento-area community and compute its routes to
safety — on your laptop, with open tools and open data. One open pipeline runs from **DuckDB**
and **Overture Maps** through **Planetiler** tiles and **MapLibre GL JS** to live **OSRM**
routing. Most open-mapping workshops stop at the rendered map; here you also compute over it.

> ⚠️ **Work in progress.** This is the public skeleton for the workshop repo. Module scripts and
> the pre-clipped data bundle are filled in ahead of the session. Structure and tool choices are
> stable; contents are being added.

## Quickstart (~5 lines)

```bash
git clone https://github.com/vishal4c/routes-to-safety-workshop.git
cd routes-to-safety-workshop
# 1. Check your setup (see setup/checklist.md), then run the environment check:
duckdb < setup/hello-geo.sql
# 2. Extract data → 3. build tiles → 4. route. Follow each module's README in order:
#    00-data/ → 01-tiles/ → 02-web/ → 03-routing/
```

## Module map

| Module | Agenda slot | What you do | Tools |
|---|---|---|---|
| [`setup/`](setup/) | 0:00–0:15 | Confirm your environment | DuckDB |
| [`00-data/`](00-data/) | 0:30–1:10 | Extract & query roads + shelters | DuckDB, Overture, OSM |
| [`01-tiles/`](01-tiles/) | 1:20–2:05 | Build your own vector basemap | Planetiler, PMTiles |
| [`02-web/`](02-web/) | 1:20–2:05 | Render & restyle in the browser | MapLibre GL JS, PMTiles |
| [`03-routing/`](03-routing/) | 2:05–2:35 | Compute & visualize evacuation routes | OSRM |

## The stack (open source over open data)

DuckDB · Planetiler · PMTiles · MapLibre GL JS · OSRM · Overture Maps · OpenStreetMap

## Prerequisites

A laptop (macOS, Windows, or Linux). Comfort with a command line helps but is not required —
every command is written and explained. No prior GIS, cartography, vector-tile, or routing
experience is assumed. Complete [`setup/checklist.md`](setup/checklist.md) **about a week ahead**;
the session goes straight into building.

## Study area

Sacramento and Northern California — the region's roads, rivers, and wildfire-prone terrain.
Re-point the pipeline at your own community by swapping the bounding box in [`00-data/`](00-data/).

## Licensing

- **Code** (scripts, config, `route-demo.js`, `build.sh`): [MIT](LICENSE)
- **Materials** (slides, docs, exercises, READMEs): [CC BY-SA 4.0](LICENSE-materials)

## Data sources & attribution

- **Overture Maps** — © Overture Maps Foundation, from the public cloud release.
- **OpenStreetMap** — © OpenStreetMap contributors, ODbL.
- Wildfire perimeters — CAL FIRE FRAP (CC-BY) and/or NIFC/WFIGS (public).
- Flood hazard zones — FEMA National Flood Hazard Layer (US Government Work).

Exact dataset versions and the bounding box used are pinned in [`00-data/README.md`](00-data/README.md).

## Instructors

Vishal Kumar · Shaishav Maisuria — Amazon Maps. The workshop teaches only the public open stack.

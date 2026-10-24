---
marp: true
theme: rts
paginate: true
footer: Routes to Safety · FOSS4G NA 2026
size: 16:9
---

# Reproducibility

- `versions.env` — one file pins every tool and image
- **Dated extracts**: Overture `2026-09-23.1`, a dated Geofabrik norcal snapshot
- `data/CHECKSUMS.sha256` — verify what you downloaded
- `scripts/make-data.sh` regenerates the data
- `scripts/check-versions.sh` fails CI on drift

<!--
Phase 4 = 23 min (talk 8 · Phase 4 8 · close 4 · slack 3). Opening: "Everything you built today is a recipe. Here is how to rerun it, change it, and make it bigger."
⏱ 1.5 min. Say: "If we can't rebuild it next year with the same answers, it's a demo, not a method."
-->

---
<!-- _class: card -->

# 🧪 Phase 4 — Swap the community  (6 min +2, offline)

1. Open `scripts/make-data.sh`
2. Edit `BBOX` to your town (W,S,E,N)
3. Run `scripts/make-data.sh --plan`

It prints the exact queries, files and estimated sizes — **without network**. 👀

The real run is **homework**.

<!--
⏱ 8 min incl. regroup. Say: "Pick a town you know. Edit one line. The plan shows what would be downloaded and how big, and touches no network."
Hard-stop cut order: Phase 4 live part is the first to go.
-->

---

# Swap the hazard

- **FEMA NFHL** (National Flood Hazard Layer): flood zones instead of fire zones
- Same pattern: polygons → `ST_Intersects` with shelters → tiles → `match` on a zone field
- **CAL FIRE live feed** could replace the static perimeters
- ⚠️ **Going live raises the stakes on every caveat from "What we leave out."**

<!--
⏱ 1.5 min. Say: "Swapping the hazard is a data change, not a code change. But going live raises the stakes on every caveat we listed at the start: status, drive time, closures, capacity."
-->

---

# Laptop → planet

- **Planetiler**: planet-scale builds are a documented use case (larger heap, more disk)
- **PMTiles** on object storage: one file, HTTP Range requests, no tile server
- **OSRM** regional graphs: one per region, not one planet graph per laptop
- **Overture** publishes monthly releases — bump the pin in `versions.env`

<!--
⏱ 1.5 min. Say: "Same tools, bigger inputs. The shape of the pipeline doesn't change."
Avoid specific numbers (build times, sizes) — not measured by us.
-->

---

# In the wild

- **OpenStreetMap** data underlies OSRM routing; the public demo server is `router.project-osrm.org`
- **Planetiler** generates OpenMapTiles-style and custom vector tiles
- **PMTiles** is the Protomaps single-file tile format
- **Overture Maps** releases open map data under the Linux Foundation
- **MapLibre** is the open-source fork-lineage of Mapbox GL JS, used for web maps

Real systems add live closures, shelter status, capacity and traffic. We didn't.

<!--
⏱ 1 min. Say: "These are the building blocks others use. Public emergency tools layer live data and official processes on top."
Generic on purpose; no specific agency deployments cited — none in our research reports.
-->

---

# Learn more

- DuckDB spatial: duckdb.org/docs/extensions/spatial
- Overture: docs.overturemaps.org
- Planetiler: github.com/onthegomap/planetiler
- PMTiles: docs.protomaps.com/pmtiles
- MapLibre: maplibre.org
- OSRM API: project-osrm.org/docs/v5.24.0/api

Workshop repo: github.com/vishal4c/routes-to-safety-workshop

<!--
⏱ 1 min. Say: "Everything is in the repo. Links are on this slide and in the README."
Note: OSRM docs URL is the v5.24.0 API reference per brief; our image is v26.10.0-debian (calendar versioning; the v26.9.0 tag does not exist).
-->

# 02-web — Lab 2b / 2c card: serve, render, restyle

`index.html` is one page: MapLibre GL JS 6.14.0 (ESM) + pmtiles 4.5.0. It reads `../out/evac.pmtiles` (the file you built in Lab 2a); if that is missing it falls back to `../data/prebuilt/evac.pmtiles` and says so in the console and on the map. Before you paste anything it shows a blank, working map with the footer disclaimer.

## Open it (pick your tier)

| Tier | Start | Open |
|---|---|---|
| 1 Codespaces | already running | **Ports** tab → row **8080** → click the 🌐 globe → add `/02-web/` |
| 2 Docker / Finch | `docker compose up -d` (or `finch compose up -d`) | `http://localhost:8080/02-web/` |
| 3 Native | `npx serve -l 8080 .` (from the repo root) | `http://localhost:8080/02-web/` |
| 4 Browser-only | — | the Pages site: `https://vishal4c.github.io/routes-to-safety-workshop/02-web/` |

### The Range-request trap
PMTiles reads a few KB at a time with HTTP `Range` requests. `python -m http.server` ignores them → the map stays blank (console: `HTTP 200` instead of `206`). Use Caddy (the compose file) or `npx serve`. Never `python -m http.server`.

## Lab 2b — roads + attribution (8 min)
1. In `02-web/index.html` find `// STEP 1: paste here`.
2. Open `02-web/steps/step1-roads.json`, copy **everything**, and paste it **in place of the `[]`** on the line `const STEP1 = [];`.
3. Find the commented `AttributionControl` lines, uncomment them. Reload.

**Expected:** a grey road network (motorways darker and thicker) and the attribution text bottom-right: *© OpenStreetMap contributors · © Overture Maps Foundation · Fire Hazard Severity Zones: CAL FIRE FRAP (CC-BY) · Land cover: ESA WorldCover (CC-BY)*. No "Using the prebuilt tiles" note = you are looking at your own build.

## Lab 2c — restyle (12 min)
- **[R]** Paste `steps/step2-hazard-water.json` at `// STEP 2` → orange-to-red hazard (OrRd `match` on `FHSZ_Description`), blue water, muted-green land cover, 10 shelter circles (**filled = verified, hollow = candidate**) and **city/town labels** (`places` symbol layer: Roseville in caps, towns from z6, villages z9, hamlets z11 — the fonts are in `fonts/`, so labels work offline).
- **[M]** Paste `steps/step3-styled.json` at `// STEP 3` → adds the dashed grey fire perimeters (River 2021, Mosquito 2022). It already contains steps 1+2, so it also works as the bail-out.
- **[F]** Paste `steps/step4-final.json` at `// STEP 4` → 3D buildings: zoom to Auburn (zoom ≥ 13), then tilt with right-drag / ctrl-drag / the compass button. Click a shelter for its name (already wired).

**Expected:** Very High solid dark red, water blue, 10 shelter circles (1 filled, Sierra College), Mosquito perimeter dashed, attribution visible.

⏱ Stuck past minute 8 → paste `steps/step3-styled.json` at STEP 3.

Layer order is automatic: the page sorts pasted layers (water < land cover < hazard < perimeters < roads < buildings < route < shelters), so paste order does not matter. Pasting the same layer id twice is fine — the last paste wins.

## Three views, one at a time (buttons top-left, next to zoom)
- **Evac view** (default, offline): our tiles — fire hazard, land cover, water, roads, buildings, places, shelters.
- **Normal view**: the standard OpenStreetMap raster basemap (roads, places, land use, boundaries) with shelters, perimeters and the route kept on top — handy to orient yourself and a nice way to show *why* we built our own tiles. Needs internet (`tile.openstreetmap.org`).
- **Shelter reach view**: drive-time isochrones on a plain base (water + roads + places). For every shelter, the area it can be reached **from** within ≤ 10 min (green), ≤ 20 min (blue), ≤ 30 min (light red). Click a shelter to isolate its own reach; click anywhere else to return to all shelters. The hazard and land-cover layers are switched off here on purpose: the bands must never be read on top of the hazard colours. Data: `data/coverage/coverage_bands.geojson`, precomputed by `scripts/make-coverage.py` — H3 res-8 cell centroids → OSRM `/table` → minutes to each shelter → dissolved per shelter and band (free-flow speeds, no closures; cells more than 1.5 km from a road are skipped, hence the holes). Loaded lazily on first use; `window.setView('reach')` / `window.setReachShelter('placer-high')` from the console.

Implementation: no style swap — each view is `setLayoutProperty(id, 'visibility', …)` over a list of layer ids (`VIEW_LAYERS` in index.html), so routing keeps working in every view.

## Legend copy (already in the page)
- **Fire hazard (FHSZ):** Moderate `#fdbb84` · High `#e34a33` · Very High `#b30000` — Source: CAL FIRE FRAP (CC-BY)
- **Fire perimeters:** dashed grey — River 2021 · Mosquito 2022
- **Shelters:** ○ hollow = candidate (not confirmed) · ● filled = verified

## FHSZ value card (`hazard` layer, property `FHSZ_Description`)
| value | `FHSZ` | polygons | colour |
|---|---|---|---|
| Moderate | 1 | 84 | `#fdbb84` |
| High | 2 | 67 | `#e34a33` |
| Very High | 3 | 204 | `#b30000` |

(355 polygons in total; `SRA` = `SRA`/`LRA` responsibility area.)

## Inspect your tiles (60 s)
`pmtiles show out/evac.pmtiles` → 8 layers, zoom 4–14. In the page's console: `map.queryRenderedFeatures()[0].properties`.

## Other files
- `solution.html` — **the bail-out**: `index.html` with step 4 pasted, attribution on and `03-routing/route.js` imported. Open `http://localhost:8080/02-web/solution.html` if you are behind; otherwise keep working in `index.html`.
- `style.json` — the finished style as a standalone MapLibre style (same layers as step 4), for Maputnik and the demo. Serve the tiles with `pmtiles serve out --port 8077 --cors="*"` (it exposes `http://localhost:8077/evac/{z}/{x}/{y}.mvt`, the URL in the style), then open Maputnik → *Open → Load from URL* `http://localhost:8080/02-web/style.json`. (Maputnik must be allowed to reach both URLs; run it locally or use the instructor machine.)
- `steps/*.json` — plain JSON arrays of MapLibre layer objects.
- `fonts/` — Noto Sans glyph PBFs (OFL) for the labels; see `fonts/README.md`.
- `scripts/make-solution.py` (repo root) regenerates `solution.html` after you change `index.html` or step 4.
- Routing (Lab 3): the last block of `index.html` has commented `import(...)` lines → `03-routing/README.md`.

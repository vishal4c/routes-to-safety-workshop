# Demo site — Routes to Safety (Placer County I-80 corridor)

A static page (no build step): MapLibre GL JS 6.14.0 + PMTiles 4.5.0 from unpkg.
Shows the evacuation basemap, 10 shelters (filled = verified, hollow = candidate), precomputed drive-time coverage, and a drop-a-pin "nearest shelter by road" router.

> Teaching example, not an official evacuation resource. Drive-time estimates assume no traffic and no closures. In an emergency follow county OES / Genasys-Zonehaven alerts and CAL FIRE incident pages.

## Run locally
From the **repo root** (so `data/` is reachable from `/demo/`):

    npx serve -l 8080 .
    # open http://localhost:8080/demo/

Do not use `python -m http.server`: it has no Range support, so PMTiles fails.

## Data it reads (tries `data/…` first)
`data/prebuilt/evac.pmtiles`, `data/shelters.geojson`, `data/coverage/coverage_bands.geojson`, `data/coverage/coverage_hex.geojson`.
If a GeoJSON file is missing, the app uses `demo/dev-fixtures/…` and shows a "fixture data" badge. If the PMTiles file is missing a notice appears; shelters and coverage still draw.

## Routing endpoint detection
On load, in order, the first one that answers `GET {base}/nearest/v1/driving/-121.08,38.90` with `"code":"Ok"` wins:
1. same-origin `/osrm` (Caddy proxy in Docker/Codespaces)
2. `http://localhost:5000`
3. `https://router.project-osrm.org` — only if the page is served over https or from GitHub Pages
`?osrm=https://host` tries that base first (testing). The footer of the panel shows which one is in use, or "Routing unavailable — map and shelters still work". Routing never blocks the map.

Per click: one `/table` call (start + all shelters, durations and distances) → shelter with the smallest duration → one `/route` call for the line. A point outside the bbox (-121.40, 38.72, -120.85, 39.15) is rejected without calling OSRM.

**I-80 closed** adds `exclude=motorway`. The public demo server does not support that flag (it replies `InvalidValue`); the page says so. Use local OSRM for this toggle.

## URL state
`?lng=-121.00&lat=39.06&closed=1` reproduces a dropped pin.

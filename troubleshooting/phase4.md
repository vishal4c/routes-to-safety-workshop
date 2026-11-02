# Phase 4 troubleshooting — another box

Phase 4 only works when every output describes **the same box**: the four `BBOX_*` lines in `versions.env`, the Overture
files, the shelters, the routing graph OSRM is serving, the tiles and the reach bands.

| Output | Made by (Phase 4 step) |
|---|---|
| `data/overture/*.geojson` | `scripts/fetch-overture.sh` (2) |
| `data/hazard/*.geojson` | `scripts/fetch-hazard.sh` or `--none` (3) |
| `data/shelters.geojson` | `00-data/03-export.sql` → `scripts/pick-shelters.sh <ids>` (4) |
| `data/osrm/study-area.osrm.*` | `scripts/fetch-osm.sh` → `scripts/build-osrm.sh` → restart osrm (5) |
| `out/evac.pmtiles` | `01-tiles/build.sh` (6) |
| `data/coverage/*.geojson` | `scripts/make-coverage.py` (7) |

Run `scripts/check-phase4.sh` (container shell). It tests each row and names the step to redo. The sections below
explain each red line.

---

## `could not convert string to float: '-122.244    # west'`

**Means:** an older `scripts/make-coverage.py` read `versions.env` with a simple parser that kept an inline comment as part
of the value.

**Fix:** the current script strips inline comments. With an old copy, put each comment on its own line:
```ini
# west
BBOX_W=-122.244
```

---

## `0 shelters`, then `HTTP Error 400: Bad Request` from `make-coverage.py`

**Means:** `data/shelters.geojson` has no features. With no destinations, the OSRM `/table` request is invalid. The usual
cause is step 4 run with the README's example ids (`'id-1', 'id-2', 'id-3'`) instead of real ones. They match nothing,
so an empty file is written.

**Check:**
```bash
duckdb -c "LOAD spatial; SELECT count(*) AS candidates FROM ST_Read('out/shelter-candidates.geojson')"
duckdb -c "LOAD spatial; SELECT id, name, type, town FROM ST_Read('out/shelter-candidates.geojson') ORDER BY type, name"
duckdb -c "LOAD spatial; SELECT count(*) AS shelters FROM ST_Read('data/shelters.geojson')"
```

**Fix:** pick real ids from the `id` column and let the script write the file. It refuses placeholders and unknown ids,
and writes nothing in that case:
```bash
scripts/pick-shelters.sh mercer-island-community-event-center bellevue-high-school medina-city-hall
```
The shelter count must be above zero before `make-coverage.py`. Every picked place is a `candidate`: being in Overture
does not make it an operational emergency shelter, so confirm it with an authoritative (county) source.

---

## OSRM answers `"code":"Ok"`, but snaps hundreds of km away

**Means:** OSRM is still serving the **old graph** (Placer County). It always snaps to the nearest road it has, even
900 km away, so `"code":"Ok"` proves nothing; the `distance` does. In the Bellevue run, the shelters first snapped to
(-121.362127, 39.20797), about 934 km away.

**Check:** a point inside the box should snap within a few dozen metres:
```bash
curl -s "$OSRM_URL/nearest/v1/driving/-122.2269,47.5900"
```

**Fix:** Phase 4 step 5, all three parts:
1. `scripts/fetch-osm.sh` (container shell): download the region in `OSM_EXTRACT_URL` and clip it to the box.
2. `scripts/build-osrm.sh` (laptop terminal for option B, the Codespaces terminal for A). Typed in the container shell it
   only prints what it would do, and the old graph stays.
3. Restart OSRM so it loads the new graph: `docker compose restart osrm`, or in Codespaces
   `docker restart $(docker ps -qf name=osrm)`.

After the restart, the Mercer Island check above returned `location: [-122.226859, 47.59005]`, `distance: 40.4` m: the
new graph is serving. Then rerun `scripts/make-coverage.py --osrm http://osrm:5000`. That script now stops with this
explanation instead of failing later.

---

## Browser: `out/evac.pmtiles: Wrong magic number for PMTiles archive`

**Means:** the bytes the page received do not start with `PMTiles`. Possible causes:
- the page fetched the archive while `01-tiles/build.sh` was still writing it (the build now writes to
  `out/evac.building.pmtiles` and moves it into place at the end, so this should not recur);
- a stale page or browser cache from before the rebuild;
- a web server that ignores Range requests, or a wrong path that returns an HTML error page.

**Check** (container shell, or the Codespaces terminal):
```bash
pmtiles show out/evac.pmtiles
curl -sS -D - -o /dev/null -H 'Range: bytes=0-15' "$WEB_URL/out/evac.pmtiles"
curl -sS --range 0-15 "$WEB_URL/out/evac.pmtiles" | od -An -tx1c
```
Expected: `pmtiles show` prints the **new** bounds; the server answers `HTTP/1.1 206 Partial Content`; the bytes start with
`50 4d 54 69 6c 65 73` (`PMTiles`).

**Fix:** rebuild with `01-tiles/build.sh`, then hard-refresh the page (Shift+Reload) and click **Reload** on row 0.
Serve with Caddy (`docker compose up -d`) or `npx serve -l 8080 .`, never `python -m http.server` (no Range support).

In the Bellevue run, the error showed briefly after a successful build. The server check then returned 206 with a
`PMTiles` header and the map worked. The exact cause was not established, so if it comes back, run the checks above and
read the failing request in the browser's Network tab.

---

## Planetiler warns about empty `hazard` / `fire_perimeters`

**Means:** outside California `scripts/fetch-hazard.sh --none` writes empty layers on purpose. Planetiler leaves those
layers out (the archive has 5–6 layers instead of 8) and still writes the file. Nothing to fix; rows 2–3 of the map
simply draw no hazard.

---

## Roads stop short of the box edge

**Means:** `scripts/fetch-overture.sh` keeps a feature only when its whole bounding box is **inside** the box, so a road
crossing the edge is left out. On a small box this shows as gaps along the edges.

**Fix:** draw the box a little larger than the area of interest. Keep shelters well inside it: one near the edge may get
no reach cells in step 7.

---

## The routing pin is in the old area, or every click says "Outside the study area"

**Means:** the routing row reads the box from `versions.env` when it is **added**. A page opened before the edit still
uses the old box.

**Fix:** save `versions.env`, refresh the page, add the rows again, then **Routing → Add**. The pin drops on the road
nearest the box centre. Click the map to move the start; right-click or Shift+click to pick the destination.

---

## Worked case — Bellevue / Mercer Island, WA

Box `-122.244, 47.581, -122.159, 47.639` (Codespaces). What went wrong, in order:

| Step | Symptom | Cause | Fix |
|---|---|---|---|
| 7 | `could not convert string to float` | inline comments in `versions.env` | comments on their own lines (now handled) |
| 7 | `58 road-bearing hex cells … 0 shelters`, then HTTP 400 | step 4 used placeholder ids | 12 candidates; picked `mercer-island-community-event-center`, `bellevue-high-school`, `medina-city-hall` → 3 shelters |
| 7 | shelters snapped ≈ 934 km away | OSRM still on the Placer graph | step 5 build + `docker restart $(docker ps -qf name=osrm)` → snap 40 m |
| 8 | `Wrong magic number for PMTiles archive` | not established (see above) | rebuild: 47 tiles, ≈ 680 KB, bounds = the box; Caddy answered 206 with `PMTiles`; the map worked |

End state: 3 shelters (all `candidate`), OSRM serving the Washington graph, `out/evac.pmtiles` valid with the Bellevue
bounds, and Caddy serving it with Range support. `scripts/check-phase4.sh` now flags each of these failures before it
reaches the map.

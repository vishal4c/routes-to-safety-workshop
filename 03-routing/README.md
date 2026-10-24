# 03-routing — OSRM and the three files you edit

OSRM (Open Source Routing Machine) turns a road graph into three HTTP calls. The graph for the study area is pre-built (`data/osrm/study-area.osrm.*`, 99 MB).

## How OSRM runs, per tier

| Tier | How | Routing? |
|---|---|---|
| 1 Codespaces | `docker compose` inside the devcontainer starts `osrm` (not published) + `caddy` on :8080; Caddy proxies `/osrm/*` → `osrm:5000` | yes |
| 2 Local Docker / Finch / Podman | `docker compose up` (or `finch compose up`) — same two services | yes |
| 3 Native, no Docker | — (OSRM ships no native Windows/Mac binary) | **no** |
| 4 Browser-only (Pages) | — | **no** (map + shelters only) |

Never forward port 5000 in Codespaces (private-port auth wall). Use the Caddy path `/osrm`.

## The three endpoints (OSRM HTTP API v1, profile `driving`)

| Call | Used for |
|---|---|
| `GET {OSRM_URL}/nearest/v1/driving/{lon},{lat}` | sanity check; snaps a point to the road (`"code":"Ok"`, `waypoints`) |
| `GET {OSRM_URL}/table/v1/driving/{from};{to1};…?sources=0&annotations=duration,distance` | `durations[0][i]` seconds, `distances[0][i]` metres, house → each shelter |
| `GET {OSRM_URL}/route/v1/driving/{from};{to}?overview=full&geometries=geojson[&exclude=motorway]` | `routes[0].geometry`, `.duration` (s), `.distance` (m) |

## `$OSRM_URL` per tier

| Tier | `$OSRM_URL` (terminal / `curl`) | In the page (automatic) |
|---|---|---|
| 1 Codespaces | `<forwarded-8080-URL>/osrm` (Ports tab → port 8080) | same-origin `/osrm` |
| 2 Docker | `http://localhost:8080/osrm` (or `http://localhost:5000` if you published it yourself) | same-origin `/osrm`, else `http://localhost:5000` |
| 3 / 4 | none | shows *"Routing needs OSRM (Docker or Codespaces) — map and shelters still work"* |

The page tries, in order: same-origin `/osrm` → `http://localhost:5000` → `https://router.project-osrm.org` (only when the page is served over https; that server cannot do `exclude=motorway`, so the I-80 checkbox is disabled).

## Files

| File | Lab |
|---|---|
| `steps/step1-route.js` | 3a — one route, hard-coded |
| `steps/step2-scaffold.js` | 3b — you write 6 lines |
| `steps/step3-solution.js` = `route.js` | 3b+3c finished (checkbox "I-80 closed") |
| `grid.sql` | Stretch A |
| `exercises.md` | the lab card |

Each is an ES module exporting `start(map, maplibregl)`; `02-web/index.html` has the commented import lines.

## Stretch B — build the graph yourself

```bash
scripts/build-osrm.sh data/osm/colfax.osm.pbf out/osrm
```
Runs `osrm-extract` (car profile) → `osrm-partition` → `osrm-customize` in the pinned image (`ghcr.io/project-osrm/osrm-backend:v26.10.0-debian`) with whichever of docker/finch/podman/nerdctl you have. Then point a second `osrm-routed` at `out/osrm/colfax.osrm`.

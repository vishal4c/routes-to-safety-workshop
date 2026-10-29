# Phase 3c — Routing (hands-on card)

Needs routing (OSRM). **Tier 1 Codespaces / Tier 2 Docker:** do the steps below. **Tier 3 native / Tier 4 browser-only:** there is no routing on your machine by design (OSRM ships no native Windows/Mac binary). Pair with a Docker/Codespaces neighbour, or follow the screen. The page tells you: *"Routing needs OSRM (Docker or Codespaces) — map and shelters still work"*.

Footer rule: the disclaimer stays visible. *Teaching example, not an official evacuation resource.*

## Step 1 — Hello route

```bash
curl "$OSRM_URL/nearest/v1/driving/-121.08,38.90"        # PowerShell: curl.exe
```
`$OSRM_URL` is preset in the tool container (`http://caddy:8080/osrm`); laptop terminal: `http://localhost:8080/osrm` (README → Phase 0 → Where to type).

**Expected:** JSON containing `"code":"Ok"` and a `waypoints` array (a snapped location near Auburn).

Then draw a route: in `02-web/index.html` find the line
`// import('../03-routing/steps/step1-route.js')…` and **uncomment it** → reload.

**Expected:** a pink line (`#d81b60`, white casing) from Foresthill to Placer High School; the console prints `Route: 35.8 min, 31.8 km`.

No pink line? Check the console (F12). A red `/osrm 404` means your port-8080 server is not Caddy — use the tier URL from the card.

## Step 2 — Nearest shelter by road

Comment out the step1 import, uncomment `…/steps/step2-scaffold.js`. Open that file, find
`// ===== YOU WRITE THESE 6 LINES =====` and write six lines:

1. `/table` with `sources=0&annotations=duration,distance` (house first, then 10 shelters)
2. `secs` = `durations[0]` without its first entry (house → house)
3. `best` = argmin of `secs`
4. `/route` to the best shelter (`overview=full&geometries=geojson`)
5. `setRoute(route.geometry)`
6. `showPopup(…, "Name · ~N min drive (free-flow, no traffic) · K km")`

**Expected (start = Foresthill, the default):** line to **Placer High School**, popup
`Placer High School · ~36 min drive (free-flow, no traffic) · 31.8 km` (OSRM says 35.8 min).

**Nearest on the map ≠ nearest by road.** From Foresthill the closest shelter as the crow flies is Georgetown School, **12.4 km** away. OSRM does not choose it: by road Georgetown is **59.7 min / 54 km** (American River canyon), Placer High is **35.8 min / 31.8 km**.
Check it yourself: drag the pink shelter marker onto Georgetown School (-120.833, 38.909) → the popup shows the long way round.

**Drag the pink shelter marker** to any spot: the route is redrawn to where you dropped it (the popup says "Your chosen spot").
Drag a marker outside the bbox → *"This demo covers the Placer I-80 corridor only"* and no OSRM call.

Not routing? → open `03-routing/steps/step3-solution.js` (or point the import at `../03-routing/route.js`).

## Step 3 — "I-80 is closed"

Add the toggle: `&exclude=motorway` on both URLs (the `exclude` variable is already there). The finished version has a checkbox; hover it for the caveat.

**Demo origin: Dutch Flat (-120.838, 39.198)** → Sierra Vista Community Center (Colfax)

| | time | distance |
|---|---|---|
| I-80 open | **17.9 min** | 19.3 km |
| `exclude=motorway` | **31.3 min** (+13.4 min) | 20.4 km |

Same shelter both times; the route leaves I-80 and uses Dutch Flat Rd / Magra Rd / Rollins Lake Rd. (Foresthill → Placer High only changes 35.8 → 37.3 min, +1.5: the route barely uses I-80, so it's a poor demo.)

> Real closures aren't a parameter — nobody flags a downed power line before you drive into it. This shows the calculation, not detection.

Public `router.project-osrm.org` rejects `exclude=motorway`; the checkbox is disabled there.

## Stretch A (finish early) — 15-minute reach (finish at home — the repo has the solution)

`duckdb -c ".read 03-routing/grid.sql"` makes 400 grid points and one coordinate string; POST it to `/table` once; colour the points with a `step` expression in **GnBu** (not red/orange). Expected: 400 points routable, 0.6–74 min.

## Stretch B (finish early) — build the OSRM graph yourself

```bash
scripts/build-osrm.sh data/osm/colfax.osm.pbf out/osrm
```
Tiny clip, about a minute — laptop terminal with Docker/Finch (option B) or the Codespaces terminal. Inside `docker compose exec workshop` on a laptop there is no Docker: the script prints what it would run and stops. Details: README → Phase 2b.

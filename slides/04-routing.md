---
marp: true
theme: rts
paginate: true
footer: Routes to Safety · FOSS4G NA 2026
size: 16:9
---

# Routing in 3 minutes

- **Graph**: intersections = nodes, road segments = edges
- **Weight**: each edge costs seconds — length ÷ speed (free-flow, no traffic)
- **Shortest path**: Dijkstra explores outward from the start until it reaches the target
- **Too slow at scale** → preprocess once so queries touch far fewer edges
- OSRM uses **MLD** (multi-level Dijkstra): partition the graph into cells, precompute costs between cell borders

<!--
Phase 3c = 32 min (talk 6 · step 1 7 · step 2 12 · step 3 7). Swap A/B instructor here. Opening: "You have a basemap. Now we make it answer: how long to the nearest shelter, by road?"
⏱ 3 min. Say: "A road map is a graph, and a route is the cheapest path through it. Everything else is making that fast."
One picture: draw a small graph, numbers on edges, highlight the cheapest path; then show cells with border shortcuts. Stress: weights are free-flow speeds, not traffic.
-->

---

# OSRM API: three calls + `$OSRM_URL`

| Call | Question it answers |
|---|---|
| `/nearest` | Which road point is closest to this coordinate? (snap) |
| `/route` | Path + duration + distance between two points |
| `/table` | Durations (and distances) from many points to many points |

All under `/{service}/v1/driving/{lon,lat};{lon,lat}` — **longitude first**.

**`$OSRM_URL` per tier** — Caddy strips `/osrm` and forwards to `osrm:5000`; never forward port 5000 in Codespaces.

| Tier | `$OSRM_URL` |
|---|---|
| 1 Codespaces | `<your-forwarded-8080-URL>/osrm` (Ports tab → globe) |
| 2 Local Docker | `http://localhost:8080/osrm` (or `http://localhost:5000`) |
| 3 Native · 4 Browser-only | **no routing** — pair with a neighbour |

<!--
⏱ 2.5 min. Say: "Three verbs: snap a point, route between two points, fill a matrix of times. Routing needs Docker or Codespaces — OSRM ships no native Windows or Mac binaries. Tier 3 or 4: turn to your neighbour."
Instructor note: don't forward port 5000 in Codespaces (private-port auth wall); use the Caddy path. Opening spoken line for block is on the Routing slide.
-->
---

# How we built the graph

```bash
wget https://download.geofabrik.de/north-america/us/california/norcal-latest.osm.pbf
osmium extract -b -121.40,38.72,-120.85,39.15 norcal-latest.osm.pbf -o study-area.osm.pbf
osrm-extract   -p car.lua study-area.osm.pbf
osrm-partition study-area.osrm
osrm-customize study-area.osrm
osrm-routed --algorithm mld --max-table-size 500 study-area.osrm
```

(finish early) You can build it: `scripts/build-osrm.sh data/osm/colfax.osm.pbf`

<!--
⏱ 1.5 min. Say: "We cut a dated Geofabrik NorCal extract down to our bbox, extracted with the car profile, partitioned, customized. Same image, OSRM v26.10.0, every tier."
Dated extract = reproducible. --max-table-size 500 lets /table take our shelter list and the stretch grid. Real sizes: prep task (b).
-->

---

# Nearest by road ≠ nearest on the map

- **Crow-flies** (Exercise B): straight-line distance with `ST_Distance`
- **By road**: `/table` from the house to all 10 shelters, then argmin of `durations[0]`
- A ridge, a river canyon or a missing bridge makes the "close" shelter far
- Foresthill is the case to remember (crow-flies Georgetown 12.4 km vs. by road Placer High 36 min)

```
GET $OSRM_URL/table/v1/driving/{house};{s1};…;{s10}?sources=0&annotations=duration,distance
```

<!--
⏱ 1.5 min. Say: "Remember your answer to Exercise B. In a minute you'll find out whether the road agrees with the crow."
-->

---
<!-- _class: card -->

# 🧪 Phase 3c — Routing  (working dir = repo root)

**Step 1 · Hello route · 5 min +2** — `curl "$OSRM_URL/nearest/v1/driving/-121.08,38.90"` (PowerShell: `curl.exe`)
*Expected:* JSON with `"code":"Ok"` and a `waypoints` array. Then `/route/v1/driving/…?geometries=geojson`, paste via `steps/step1-route.js`. 👀

**Step 2 · Nearest shelter by road · 10 min +2** — in `steps/step2-scaffold.js` **you write 6 lines**: `/table` URL → argmin `durations[0]` → `/route` → `setData` → popup. Compare with Exercise B. Drag either marker. 👀
⏱ not routing by minute 6 → open `steps/step3-solution.js`

**Step 3 · I-80 is closed · 5 min +2** — add `&exclude=motorway` toggle; start from **Dutch Flat** (-120.838, 39.198): 17 → 31 min to Sierra Vista CC, route leaves I-80 for Dutch Flat Rd / Rollins Lake Rd. 👀
> Real closures aren't a parameter — nobody flags a downed power line before you drive into it. This shows the calculation, not detection.

**Tiers 3/4:** no routing by design — pair with a Docker/Codespaces neighbour.
**Stretch A** 15-min reach (`grid.sql` → one `/table` POST) · **Stretch B** build the graph — no dedicated minutes, finish at home; the repo has the solution.

<!--
⏱ Phase 3c = step 1 7 + step 2 12 + step 3 7 = 26 min incl. regroups. B is timekeeper.
Say: "Card is on screen. Open 03-routing/. Tiers 3 and 4: sit with a Docker or Codespaces neighbour."
Checkpoint: drag anywhere → line + popup update; toggle changes the route; footer disclaimer visible.
Fallback: steps/step3-solution.js; Pages demo (map + shelters).
-->

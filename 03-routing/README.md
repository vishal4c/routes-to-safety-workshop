# Module 3 — Compute & visualize routes (2:05–2:35)

**Goal:** send a neighborhood to its **nearest shelter by road** with OSRM, and draw the route
on the map you built in Module `../02-web/` as an **interactive route layer** — draggable start
and end markers that re-route as you move them, with a popup showing travel time.

## Run it

```bash
docker compose up -d          # starts OSRM over the pre-built graph (../data-bundle/osrm)
# then open ../02-web/index.html; route-demo.js queries http://localhost:5000
```

> **Pre-built by design.** OSRM runs as *query-and-draw* over a graph we ship ready-made, so the
> room starts routing in seconds. Building the graph yourself (osrm-extract / partition / customize
> on the Northern California OSM extract) is an **optional stretch**.

## What you do

1. **Route** a neighborhood point to a shelter (`/route`, GeoJSON geometry).
2. **Confirm the closest by road** using the distance matrix (`/table`) — often not the one that
   looks nearest on the map.
3. **Visualize**: draw the route in MapLibre GL JS with draggable start/end markers + a travel-time popup.
4. **Point-to-point**: route between any two clicked points.
5. *(Optional stretch)* a reachability area around a shelter — the homes within ~15 minutes.

See [`route-demo.js`](route-demo.js) (placeholder) and [`docker-compose.yml`](docker-compose.yml).

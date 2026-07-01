// 03-routing/route-demo.js — Module 3 (2:05–2:35): compute & visualize routes
//
// Queries the pre-built OSRM service (see docker-compose.yml) to:
//   1. route a neighborhood to its nearest shelter, and
//   2. use the distance matrix (/table) to confirm the closest shelter BY ROAD
//      (often not the one that looks nearest on the map).
// The resulting GeoJSON line is drawn on the map from ../02-web as an interactive
// route layer with draggable start/end markers and a travel-time popup.
//
// Placeholder: wire this into ../02-web/index.html before the session.

const OSRM = 'http://localhost:5000';

// Route between two points; returns GeoJSON geometry + duration (seconds).
export async function route(start, end) {
  // start/end = [lon, lat]
  const url = `${OSRM}/route/v1/driving/${start[0]},${start[1]};${end[0]},${end[1]}`
            + `?overview=full&geometries=geojson`;
  const r = await fetch(url);
  const j = await r.json();
  // TODO: handle j.code !== 'Ok'
  return { geometry: j.routes?.[0]?.geometry, durationSec: j.routes?.[0]?.duration };
}

// Nearest shelter BY ROAD, via the OSRM distance/duration matrix (/table).
export async function nearestShelter(origin, shelters) {
  // origin = [lon,lat]; shelters = [[lon,lat], ...]
  const coords = [origin, ...shelters].map(c => `${c[0]},${c[1]}`).join(';');
  const url = `${OSRM}/table/v1/driving/${coords}?sources=0&annotations=duration`;
  const r = await fetch(url);
  const j = await r.json();
  const durations = j.durations?.[0]?.slice(1) ?? [];   // drop self (origin→origin)
  // TODO: argmin over durations → index of nearest shelter; then call route(origin, shelters[i]).
  return durations;
}

// Optional stretch: a reachability area (isochrone-style) around a shelter — placeholder.
export async function reachableArea(/* shelter, minutes */) {
  // OSRM has no native isochrone; approximate with a table over a point grid,
  // or note this as a discussion item. TODO.
  return null;
}

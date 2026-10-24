// Routes to Safety — nearest shelter BY ROAD, with draggable house + shelter markers.
// Lab 3b scaffold: steps/step2-scaffold.js · finished version (this file) = steps/step3-solution.js
// Loaded from 02-web/index.html:  import('../03-routing/route.js').then(m => m.start(map, maplibregl))

const STUDY_BBOX = [-121.40, 38.72, -120.52, 39.20];   // W, S, E, N — same as versions.env
const START = [-120.8182, 39.0199];                    // Foresthill (lon, lat)
const ROUTE_COLOR = '#d81b60';

let OSRM = null;           // base URL of the routing server (found by detectOsrm)
let OSRM_IS_PUBLIC = false;
let shelters = [];         // GeoJSON features from data/shelters.geojson
let map, maplibregl, houseMarker, shelterMarker, popup;
let shelterDragged = false; // true after you drag the shelter marker yourself

// ---------- small helpers (read, don't edit) ----------

function say(text) {
  const el = document.getElementById('notice');
  if (!el) return console.warn(text);
  el.textContent = text;
  el.style.display = text ? 'block' : 'none';
}

// Try each OSRM address in order; the first one that answers "Ok" wins.
async function detectOsrm() {
  const test = '/nearest/v1/driving/-121.08,38.90';
  const candidates = ['/osrm', 'http://localhost:5000'];
  if (location.protocol === 'https:') candidates.push('https://router.project-osrm.org');
  for (const base of candidates) {
    try {
      const r = await fetch(base + test);
      if (r.ok && (await r.json()).code === 'Ok') {
        OSRM_IS_PUBLIC = base.includes('router.project-osrm.org');
        return base;
      }
    } catch (e) { /* not there, try the next one */ }
  }
  return null;
}

// One OSRM call = one GET returning JSON.
async function osrm(path) {
  const r = await fetch(OSRM + path);
  const json = await r.json();
  if (json.code !== 'Ok') throw new Error('OSRM: ' + (json.message || json.code));
  return json;
}

function insideStudyArea([lon, lat]) {
  const [w, s, e, n] = STUDY_BBOX;
  return lon >= w && lon <= e && lat >= s && lat <= n;
}

function setRoute(geometry) {
  map.getSource('route').setData({ type: 'Feature', geometry });
}

function showPopup(lngLat, text) {
  shelterMarker.setLngLat(lngLat);   // park the shelter marker on the destination
  popup.setLngLat(lngLat).setHTML(text).addTo(map);
}

function addRouteLayers() {
  map.addSource('route', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
  const top = map.getLayer('shelters') ? 'shelters' : undefined;   // route sits under the shelter circles
  const layout = { 'line-cap': 'round', 'line-join': 'round' };
  map.addLayer({ id: 'route-casing', type: 'line', source: 'route', layout, paint: { 'line-color': '#fff', 'line-width': 7 } }, top);
  map.addLayer({ id: 'route', type: 'line', source: 'route', layout, paint: { 'line-color': ROUTE_COLOR, 'line-width': 4 } }, top);
}

// Lab 3c: the "I-80 closed" checkbox. Returns the extra URL text for /route and /table.
function closureParam() {
  const box = document.getElementById('i80-closed');
  return box && box.checked ? '&exclude=motorway' : '';
}

function addClosureToggle() {
  const panel = document.createElement('label');
  panel.style.cssText = 'position:absolute;top:8px;right:50px;z-index:5;background:#fffffff0;border-radius:4px;padding:6px 10px;font-size:13px;box-shadow:0 1px 4px #0004;cursor:help';
  panel.title = 'Real closures aren\'t a parameter — nobody flags a downed power line before you drive into it. '
              + 'This shows the calculation, not detection.';
  panel.innerHTML = '<input type="checkbox" id="i80-closed"> I-80 closed';
  document.body.appendChild(panel);
  const box = panel.querySelector('input');
  if (OSRM_IS_PUBLIC) {   // the public demo server rejects exclude=motorway
    box.disabled = true;
    panel.title = 'The public OSRM demo server does not support exclude=motorway. Use Docker or Codespaces.';
  }
  box.addEventListener('change', () => update());
}

// Drag the shelter marker yourself: route to wherever you drop it.
async function routeToDroppedShelter() {
  const from = houseMarker.getLngLat().toArray();
  const to = shelterMarker.getLngLat().toArray();
  // OSRM call: route between your two markers
  const r = await osrm(`/route/v1/driving/${from.join(',')};${to.join(',')}?overview=full&geometries=geojson${closureParam()}`);
  setRoute(r.routes[0].geometry);
  showPopup(to, `Your chosen spot · ~${Math.round(r.routes[0].duration / 60)} min drive (free-flow, no traffic) · ${(r.routes[0].distance / 1000).toFixed(1)} km`);
}

// ---------- the main loop ----------

async function update() {
  const house = houseMarker.getLngLat().toArray();
  if (!insideStudyArea(house)) {
    say('This demo covers the Placer I-80 corridor only');
    return;
  }
  say('');
  if (shelterDragged) { routeToDroppedShelter().catch((e) => say(e.message)); return; }
  const exclude = closureParam();
  try {
    await findNearestShelter(house, exclude);
  } catch (err) {
    console.warn(err);
    say('Routing failed: ' + err.message);
  }
}

async function findNearestShelter(house, exclude) {
  // house first, then every shelter, as "lon,lat;lon,lat;..." (ready-made for you)
  const coords = [house, ...shelters.map((s) => s.geometry.coordinates)].map((c) => c.join(',')).join(';');

  // ===== YOU WRITE THESE 6 LINES =====
  // `shelters` = list of GeoJSON features; a shelter's [lon, lat] is s.geometry.coordinates
  // `exclude` = '' or '&exclude=motorway' — add it at the end of both OSRM URLs (Lab 3c)
  // OSRM call 1 (/table): house first, then all shelters; durations[0][1..] are the drive times
  const table = await osrm(`/table/v1/driving/${coords}?sources=0&annotations=duration,distance${exclude}`);
  const secs = table.durations[0].slice(1).map((s) => s ?? Infinity);   // null = unreachable
  const best = shelters[secs.indexOf(Math.min(...secs))];               // argmin = nearest by ROAD
  // OSRM call 2 (/route): the line to draw
  const route = (await osrm(`/route/v1/driving/${house.join(',')};${best.geometry.coordinates.join(',')}?overview=full&geometries=geojson${exclude}`)).routes[0];
  setRoute(route.geometry);
  showPopup(best.geometry.coordinates, `${best.properties.name} · ~${Math.round(route.duration / 60)} min drive (free-flow, no traffic) · ${(route.distance / 1000).toFixed(1)} km`);
  // ===== END OF YOUR 6 LINES =====
}

// ---------- start ----------

export async function start(mapArg, maplibreArg) {
  map = mapArg;
  maplibregl = maplibreArg;

  OSRM = await detectOsrm();
  if (!OSRM) {
    say('Routing needs OSRM (Docker or Codespaces) — map and shelters still work');
    return;
  }
  console.info('OSRM at', OSRM);

  try {
    shelters = (await (await fetch('../data/shelters.geojson')).json()).features;
  } catch (e) {
    say('Could not load data/shelters.geojson');
    return;
  }

  addRouteLayers();
  addClosureToggle();
  popup = new maplibregl.Popup({ closeOnClick: false, maxWidth: '300px' });

  houseMarker = new maplibregl.Marker({ draggable: true }).setLngLat(START).addTo(map);
  shelterMarker = new maplibregl.Marker({ draggable: true, color: ROUTE_COLOR }).setLngLat(START).addTo(map);

  houseMarker.on('dragend', () => { shelterDragged = false; update(); });
  shelterMarker.on('dragend', () => { shelterDragged = true; routeToDroppedShelter().catch((e) => say(e.message)); });

  update();
}

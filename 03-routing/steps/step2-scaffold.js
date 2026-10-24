// Lab 3b SCAFFOLD — everything is ready except the 6 lines in findNearestShelter().
// Load it from 02-web/index.html:  import('../03-routing/steps/step2-scaffold.js').then(m => m.start(map, maplibregl))

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

// Lab 3c (later): returns '&exclude=motorway' when the "I-80 closed" box is ticked.
function closureParam() {
  return '';
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
  // Helpers you can call:  osrm(path) -> JSON      setRoute(geometry)      showPopup([lon, lat], htmlText)
  // `shelters` = array of GeoJSON features: name = s.properties.name, position = s.geometry.coordinates
  // `exclude`  = '' for now; Lab 3c turns it into '&exclude=motorway' — add it to the end of both URLs.
  //
  // 1. OSRM call (/table): const table = await osrm(`/table/v1/driving/${coords}?sources=0&annotations=duration,distance${exclude}`)
  //    -> table.durations[0] = seconds from the house to [house, shelter1, shelter2, ...]
  // 2. const secs = the durations WITHOUT the first entry (that one is house -> house); turn null into Infinity
  // 3. const best = the shelter whose time is smallest (argmin: Math.min + indexOf)
  // 4. OSRM call (/route): const route = (await osrm(`/route/v1/driving/<house>;<best shelter>?overview=full&geometries=geojson${exclude}`)).routes[0]
  // 5. setRoute(route.geometry)
  // 6. showPopup(<shelter position>, `Name · ~N min drive (free-flow, no traffic) · K km`)
  //    route.duration is seconds, route.distance is metres.
  //
  // Stuck for 6 minutes?  Open 03-routing/steps/step3-solution.js
  console.warn('Lab 3b: write the 6 lines in findNearestShelter() — see 03-routing/exercises.md');
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
  // addClosureToggle();   // Lab 3c: you will add this (solution in step3-solution.js)
  popup = new maplibregl.Popup({ closeOnClick: false, maxWidth: '300px' });

  houseMarker = new maplibregl.Marker({ draggable: true }).setLngLat(START).addTo(map);
  shelterMarker = new maplibregl.Marker({ draggable: true, color: ROUTE_COLOR }).setLngLat(START).addTo(map);

  houseMarker.on('dragend', () => { shelterDragged = false; update(); });
  shelterMarker.on('dragend', () => { shelterDragged = true; routeToDroppedShelter().catch((e) => say(e.message)); });

  update();
}

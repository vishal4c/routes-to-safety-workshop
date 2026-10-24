/* Routes to Safety demo — Placer County I-80 corridor.
   Static page: MapLibre + PMTiles basemap, GeoJSON shelters/coverage, OSRM routing. */
/* maplibre-gl 6.x ships ESM only (no UMD maplibre-gl.js), so this file is a module.
   Module scope keeps everything out of window. */
import * as maplibregl from 'https://unpkg.com/maplibre-gl@6.14.0/dist/maplibre-gl.mjs';
{
  const BBOX = [-121.40, 38.72, -120.52, 39.20]; // W,S,E,N study area — keep in sync with versions.env BBOX_*
  const PMTILES_URL = new URL('../data/prebuilt/evac.pmtiles', location.href).href;
  const PALETTE = ['#8dd3c7','#ffffb3','#bebada','#fb8072','#80b1d3','#fdb462','#b3de69','#fccde5','#d9d9d9','#bc80bd']; // Set3-like, 10 shelters
  const $ = (id) => document.getElementById(id);
  const state = { shelters: [], osrm: null, start: null, closed: false, override: null, reach: null, seq: 0, fixtures: false };
  let map, startMarker, destMarker, hoverPopup, resultPopup;

  // ---- small helpers -------------------------------------------------------
  function el(tag, props, children) {
    const n = Object.assign(document.createElement(tag), props || {});
    (children || []).forEach((c) => n.append(c));
    return n;
  }
  function notice(msg) { $('notices').append(el('div', { textContent: msg })); }
  const inBbox = (lng, lat) => lng >= BBOX[0] && lng <= BBOX[2] && lat >= BBOX[1] && lat <= BBOX[3];
  const coord = (c) => c[0].toFixed(5) + ',' + c[1].toFixed(5);
  const mins = (s) => Math.round(s / 60);
  const km = (m) => Math.round(m / 1000);

  // Load data/<path>; if 404, fall back to demo/dev-fixtures/<file> and flag it.
  async function loadData(path, file) {
    for (const [url, fixture] of [['../data/' + path, false], ['dev-fixtures/' + file, true]]) {
      try {
        const r = await fetch(url);
        if (r.ok) { const j = await r.json(); if (fixture) { state.fixtures = true; $('fixture-badge').hidden = false; console.warn('Using fixture for', path); } return j; }
      } catch (e) { /* try next */ }
    }
    console.warn('Missing data:', path);
    notice('Missing data file: ' + path);
    return { type: 'FeatureCollection', features: [] };
  }

  // ---- OSRM endpoint detection --------------------------------------------
  // Order: same-origin /osrm (Caddy) -> http://localhost:5000 -> public demo server
  // (public only on https/Pages). `?osrm=URL` overrides for testing.
  async function detectOsrm() {
    const q = new URLSearchParams(location.search).get('osrm');
    const publicOk = location.protocol === 'https:' || /github\.io$/.test(location.hostname);
    const cands = [];
    if (q) cands.push([q, q]);
    cands.push([location.origin + '/osrm', 'local OSRM'], ['http://localhost:5000', 'local OSRM']);
    if (publicOk) cands.push(['https://router.project-osrm.org', 'router.project-osrm.org (public demo server)']);
    for (const [base, label] of cands) {
      try {
        // /nearest is a cheap health check; a static server answers 404/HTML, which fails the JSON/code test.
        const r = await fetch(base + '/nearest/v1/driving/-121.08,38.90', { signal: AbortSignal.timeout(4000) });
        const j = await r.json();
        if (j.code === 'Ok') return { base, label };
      } catch (e) { /* next */ }
    }
    return null;
  }

  // ---- OSRM calls ----------------------------------------------------------
  // /table: one request gives duration+distance from the start (source 0) to every shelter.
  async function osrmTable(from, exclude) {
    const pts = [from].concat(state.shelters.map((s) => s.geometry.coordinates));
    const url = state.osrm.base + '/table/v1/driving/' + pts.map(coord).join(';') +
      '?sources=0&annotations=duration,distance' + (exclude ? '&exclude=motorway' : '');
    const j = await (await fetch(url)).json();
    if (j.code !== 'Ok') throw new Error('table: ' + j.code);
    return state.shelters.map((s, i) => ({ s, sec: j.durations[0][i + 1], m: j.distances[0][i + 1] }));
  }
  // /route: full geometry (GeoJSON) for the chosen start->shelter pair.
  async function osrmRoute(from, to, exclude) {
    const url = state.osrm.base + '/route/v1/driving/' + coord(from) + ';' + coord(to) +
      '?overview=full&geometries=geojson' + (exclude ? '&exclude=motorway' : '');
    const j = await (await fetch(url)).json();
    if (j.code !== 'Ok') throw new Error('route: ' + j.code);
    return j.routes[0];
  }
  // Table -> argmin over shelters (null durations = unreachable) -> route to the winner.
  async function solve(from, exclude, forceId) {
    const rows = (await osrmTable(from, exclude)).filter((r) => r.sec != null).sort((a, b) => a.sec - b.sec);
    if (!rows.length) throw new Error('no reachable shelter');
    const best = (forceId && rows.find((r) => r.s.properties.id === forceId)) || rows[0];
    const route = await osrmRoute(from, best.s.geometry.coordinates, exclude);
    return { rows, best, route };
  }

  // ---- routing UI ----------------------------------------------------------
  async function run() {
    if (!state.start) return;
    const [lng, lat] = state.start;
    const out = $('result');
    if (!inBbox(lng, lat)) { out.textContent = 'This demo covers the Placer I-80 corridor only'; $('list').replaceChildren(); return; }
    if (!state.osrm) { out.textContent = 'Routing needs OSRM (Docker or Codespaces) — map and shelters still work'; return; }
    const seq = ++state.seq;
    out.textContent = 'Routing…';
    try {
      const force = state.override;
      const main = await solve(state.start, state.closed, force);
      // With I-80 closed, also solve the open network so the panel can show before/after.
      const before = state.closed ? await solve(state.start, false) : null;
      if (seq !== state.seq) return; // a newer request superseded this one
      show(main, before);
    } catch (e) {
      console.warn(e);
      if (seq !== state.seq) return;
      // router.project-osrm.org is built without exclude classes: it answers InvalidValue to exclude=motorway.
      out.textContent = state.closed && /InvalidValue/.test(e.message)
        ? 'The I-80 closure needs local OSRM (the public demo server does not support exclude=motorway).'
        : 'Routing failed: ' + e.message;
    }
  }

  function show({ rows, best, route }, before) {
    const p = best.s.properties, c = best.s.geometry.coordinates;
    const text = `${p.name} · ~${mins(route.duration)} min drive (free-flow, no traffic) · ${km(route.distance)} km`;
    $('result').textContent = text + (state.closed ? ' [I-80 closed]' : '');
    if (before) {
      $('result').append(el('div', { className: 'src', textContent:
        `Before: ${before.best.s.properties.name}, ${mins(before.route.duration)} min · After (I-80 closed): ${mins(route.duration)} min` }));
    }
    // The style may still be loading (slow tiles, hidden tab): retry once on 'styledata'.
    const feat = { type: 'Feature', properties: {}, geometry: route.geometry };
    const src = map.getSource('route');
    if (src) src.setData(feat); else map.once('styledata', () => map.getSource('route').setData(feat));
    const list = $('list'); list.replaceChildren();
    rows.forEach((r) => {
      const btn = el('button', { type: 'button', textContent: `${r.s.properties.name} — ${mins(r.sec)} min, ${km(r.m)} km`, title: 'Route here instead' });
      btn.onclick = () => { state.override = r.s.properties.id; run(); };
      list.append(el('li', { className: r.s === best.s ? 'chosen' : '' }, [btn]));
    });
    if (resultPopup) resultPopup.remove();
    resultPopup = new maplibregl.Popup({ closeOnClick: false, offset: 10 }).setLngLat(c).setText(text).addTo(map);
    // Second draggable marker on the chosen shelter: drag it to another shelter to override the destination.
    if (!destMarker) {
      destMarker = new maplibregl.Marker({ draggable: true, color: '#d81b60' }).setLngLat(c).addTo(map);
      destMarker.on('dragend', () => {
        const d = destMarker.getLngLat();
        const near = state.shelters.map((s) => ({ s, d: Math.hypot(s.geometry.coordinates[0] - d.lng, s.geometry.coordinates[1] - d.lat) })).sort((a, b) => a.d - b.d)[0];
        state.override = near.s.properties.id; run();
      });
    } else destMarker.setLngLat(c);
  }

  function setStart(lng, lat, fromUrl) {
    state.start = [lng, lat]; state.override = null;
    if (state.reach) showShelterReach(null);
    if (!startMarker) {
      startMarker = new maplibregl.Marker({ draggable: true, color: '#3fb1ce' }).setLngLat([lng, lat]).addTo(map);
      startMarker.on('dragend', () => { const l = startMarker.getLngLat(); setStart(l.lng, l.lat); });
    } else startMarker.setLngLat([lng, lat]);
    const u = new URLSearchParams({ lng: lng.toFixed(5), lat: lat.toFixed(5) });
    if (state.closed) u.set('closed', '1');
    history.replaceState(null, '', '?' + u);
    if (!fromUrl && !inBbox(lng, lat)) notice('This demo covers the Placer I-80 corridor only');
    run();
  }

  // ---- map layers / legend ---------------------------------------------------
  const GROUPS = { bands: ['coverage-bands'], hex: ['coverage-hex'], hazard: ['hazard'], fires: ['fire_perimeters'] };
  function wireToggles() {
    document.querySelectorAll('[data-layer]').forEach((b) => {
      const apply = () => GROUPS[b.dataset.layer].forEach((l) => map.setLayoutProperty(l, 'visibility', b.getAttribute('aria-pressed') === 'true' ? 'visible' : 'none'));
      b.onclick = () => {
        const on = b.getAttribute('aria-pressed') !== 'true';
        b.setAttribute('aria-pressed', on);
        // Bands and shelter areas are alternatives: turning one on turns the other off.
        if (on && (b.dataset.layer === 'bands' || b.dataset.layer === 'hex')) {
          const other = document.querySelector(`[data-layer=${b.dataset.layer === 'bands' ? 'hex' : 'bands'}]`);
          other.setAttribute('aria-pressed', false); other.onclick && GROUPS[other.dataset.layer].forEach((l) => map.setLayoutProperty(l, 'visibility', 'none'));
        }
        apply();
      };
    });
  }
  function legendRow(swatch, label) { return el('div', { className: 'row' }, [swatch, label]); }
  const sw = (c) => el('span', { className: 'sw', style: 'background:' + c });
  function buildLegend() {
    const L = $('legend');
    L.append(el('div', { className: 'src', textContent: 'Fire hazard severity' }));
    [['#fdbb84', 'Moderate'], ['#e34a33', 'High'], ['#b30000', 'Very High']].forEach(([c, t]) => L.append(legendRow(sw(c), t)));
    L.append(el('div', { className: 'src', textContent: 'Source: CAL FIRE FRAP (CC-BY)' }));
    L.append(legendRow(el('span', { className: 'sw', style: 'border:0;border-top:2px dashed #4d4d4d;height:0;margin:5px 0' }), 'Past fire perimeter (Mosquito 2022, River 2021)'));
    [['#a8ddb5', '10 min drive'], ['#7bccc4', '20 min drive'], ['#43a2ca', '30 min drive']].forEach(([c, t]) => L.append(legendRow(sw(c), t + ' (free-flow)')));
    // legend dots sit on a grey chip so 'white fill' and 'no fill' are distinguishable on the white panel
    L.append(legendRow(el('span', { className: 'chip' }, [el('span', { className: 'dot', style: 'background:#fff' })]), 'Shelter — verified (documented incident shelter)'));
    L.append(legendRow(el('span', { className: 'chip' }, [el('span', { className: 'dot', style: 'background:transparent' })]), 'Shelter — candidate (not confirmed)'));
    L.append(el('div', { className: 'src', id: 'hex-legend', textContent: 'Nearest-shelter colours appear on the map when that layer is on; hover a cell for minutes.' }));
  }

  function colourHexes(style) {
    const m = ['match', ['get', 'shelter_id']];
    state.shelters.forEach((s, i) => m.push(s.properties.id, PALETTE[i % PALETTE.length]));
    m.push('#cccccc');
    style.layers.find((l) => l.id === 'coverage-hex').paint['fill-color'] = m;
    const L = $('hex-legend'); L.replaceChildren('Nearest shelter areas:');
    state.shelters.forEach((s, i) => L.append(legendRow(sw(PALETTE[i % PALETTE.length]), s.properties.name)));
  }

  // Shelter "isochrone": the precomputed 10/20/30-min bands filtered to one shelter (null = all shelters).
  function showShelterReach(id) {
    state.reach = id;
    map.setFilter('coverage-bands', id ? ['==', ['get', 'shelter_id'], id] : null);
    // One shelter's reach reads better when it is opaque and the hazard fill steps back.
    map.setPaintProperty('coverage-bands', 'fill-opacity', id ? 0.75 : 0.35);
    map.setPaintProperty('hazard', 'fill-opacity', id ? 0.12 : 0.3);
    if (id) { // make sure the bands are visible and the alternative layer is off
      const b = document.querySelector('[data-layer=bands]'); if (b.getAttribute('aria-pressed') !== 'true') b.click();
    }
    const s = state.shelters.find((x) => x.properties.id === id);
    $('reach-status').textContent = id ? `Drive-time bands: ${s ? s.properties.name : id} only` : '';
  }

  function wireHover() {
    hoverPopup = new maplibregl.Popup({ closeButton: false, closeOnClick: false, offset: 12 });
    const layers = ['shelters-verified', 'shelters-candidate', 'coverage-hex'];
    map.on('mousemove', (e) => {
      const f = map.queryRenderedFeatures(e.point, { layers: layers.filter((l) => map.getLayoutProperty(l, 'visibility') !== 'none') })[0];
      map.getCanvas().style.cursor = f ? 'pointer' : '';
      if (!f) return hoverPopup.remove();
      const p = f.properties;
      const t = f.layer.id === 'coverage-hex' ? `Nearest shelter: ${(state.shelters.find((s) => s.properties.id === p.shelter_id) || { properties: { name: p.shelter_id } }).properties.name} · ${Math.round(p.minutes)} min` : `${p.name} (${p.status})`;
      hoverPopup.setLngLat(f.layer.id === 'coverage-hex' ? e.lngLat : f.geometry.coordinates).setText(t).addTo(map);
    });
    map.on('click', (e) => {
      const f = map.queryRenderedFeatures(e.point, { layers: ['shelters-verified', 'shelters-candidate'] })[0];
      if (f) { // shelter click -> info popup (not a pin drop)
        const p = f.properties;
        showShelterReach(p.id);
        const node = el('div', {}, [el('strong', { textContent: p.name }), el('br'), `Type: ${p.type}`, el('br'), `Town: ${p.town}`, el('br'), `Status: ${p.status}`, el('br'), `Source: ${p.source}`,
          el('br'), el('em', { textContent: 'Showing the area within 10 / 20 / 30 min of this shelter. Click the map to drop a pin and reset.' })]);
        new maplibregl.Popup({ offset: 12 }).setLngLat(f.geometry.coordinates).setDOMContent(node).addTo(map);
        return;
      }
      setStart(e.lngLat.lng, e.lngLat.lat);
    });
  }

  // ---- startup -----------------------------------------------------------------
  async function init() {
    buildLegend();
    const style = await (await fetch('style.json')).json();
    style.sources.evac.url = 'pmtiles://' + PMTILES_URL;
    // Label fonts are vendored in 02-web/fonts (Noto Sans, OFL) so labels also work offline / in the room.
    style.glyphs = new URL('../02-web/fonts/', location.href).href + '{fontstack}/{range}.pbf';
    const [shelters, bands, hex] = await Promise.all([
      loadData('shelters.geojson', 'shelters.geojson'),
      loadData('coverage/coverage_bands.geojson', 'coverage_bands.geojson'),
      loadData('coverage/coverage_hex.geojson', 'coverage_hex.geojson')
    ]);
    // Data goes straight into the style, so the map never waits on an event to show it.
    state.shelters = shelters.features;
    style.sources.shelters.data = shelters;
    style.sources.coverage_bands.data = bands;
    style.sources.coverage_hex.data = hex;
    colourHexes(style);
    maplibregl.addProtocol('pmtiles', new pmtiles.Protocol().tile);
    map = new maplibregl.Map({ container: 'map', style, center: [-121.10, 38.93], zoom: 10, attributionControl: false });
    map.addControl(new maplibregl.AttributionControl({ compact: false }));
    map.addControl(new maplibregl.NavigationControl(), 'top-right');
    map.addControl(new maplibregl.ScaleControl({ unit: 'metric' }), 'bottom-right');
    let tileWarned = false;
    map.on('error', (e) => {
      const msg = String((e.error && e.error.message) || '');
      console.warn('map error:', msg);
      if (!tileWarned && (e.sourceId === 'evac' || /pmtiles|evac|404|Range/i.test(msg))) { tileWarned = true; notice('Basemap tiles (data/prebuilt/evac.pmtiles) not found — shelters and coverage still work.'); }
    });
    wireToggles(); wireHover();

    $('closed').onchange = (e) => { state.closed = e.target.checked; state.override = null; if (state.start) setStart(state.start[0], state.start[1]); };
    // Never block the map on routing: detect after everything else is drawn.
    state.osrm = await detectOsrm();
    $('routing-status').textContent = state.osrm ? 'Routing: ' + state.osrm.label : 'Routing unavailable — map and shelters still work';
    const q = new URLSearchParams(location.search);
    if (q.get('closed') === '1') { state.closed = true; $('closed').checked = true; }
    if (q.has('lng') && q.has('lat')) setStart(+q.get('lng'), +q.get('lat'), true);
    if (q.get('shelter')) showShelterReach(q.get('shelter'));
    // Console / automation hook (the module scope hides everything else): rts.setStart(lng, lat), rts.showShelterReach(id)
    window.rts = { map, setStart, showShelterReach, state };
  }
  init().catch((e) => { console.error(e); notice('Demo failed to start: ' + e.message); });
}

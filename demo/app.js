/* Routes to Safety demo — Placer County I-80 corridor.
   Static page: MapLibre + PMTiles basemap, GeoJSON shelters/coverage, OSRM routing.
   Three exclusive views (Fire evac map / Base map / Shelter reach); routing works in all of them. */
/* maplibre-gl 6.x ships ESM only (no UMD maplibre-gl.js), so this file is a module.
   Module scope keeps everything out of window. */
import * as maplibregl from 'https://unpkg.com/maplibre-gl@6.14.0/dist/maplibre-gl.mjs';
{
  // ---- PHASE 4: the three lines to change for your own community ---------------------------------------------
  const BBOX = [-121.40, 38.72, -120.52, 39.20];     // W,S,E,N — same four numbers as BBOX_* in versions.env
  const CENTER = [-121.10, 38.93], ZOOM = 10;        // where the map opens
  const PMTILES_URL = new URL('../data/prebuilt/evac.pmtiles', location.href).href;   // your tiles: cp out/evac.pmtiles data/prebuilt/
  // ------------------------------------------------------------------------------------------------------------
  const $ = (id) => document.getElementById(id);
  const state = { shelters: [], osrm: null, start: null, closed: false, override: null, view: 'evac', reach: null, seq: 0, fixtures: false };
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
    updateUrl();
    if (!fromUrl && !inBbox(lng, lat)) notice('This demo covers the Placer I-80 corridor only');
    run();
  }

  // ---- views ---------------------------------------------------------------
  // Exactly one view is on at a time. Switching a view only flips layer visibility;
  // shelters, the pin and the route are drawn in every view, so routing works everywhere.
  //   evac   — fire hazard severity + past fire perimeters on our own tiles (default, works offline)
  //   normal — plain OpenStreetMap basemap (internet needed)
  //   reach  — 10 / 20 / 30-min drive-time bands per shelter on a plain base; hazard is OFF so colours never mix
  const THEME = ['water', 'land_cover', 'hazard', 'fire_perimeters', 'roads-minor', 'roads-major', 'roads-motorway', 'buildings', 'towns'];
  const VIEWS = {
    evac:   { show: THEME, hide: ['basemap-osm', 'coverage-bands'] },
    normal: { show: ['basemap-osm'], hide: THEME.concat('coverage-bands') },
    reach:  { show: ['water', 'roads-minor', 'roads-major', 'roads-motorway', 'towns', 'coverage-bands'], hide: ['basemap-osm', 'land_cover', 'hazard', 'fire_perimeters', 'buildings'] }
  };
  const vis = (id, on) => { if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', on ? 'visible' : 'none'); };
  function setView(name) {
    if (!VIEWS[name]) return;
    state.view = name;
    document.querySelectorAll('[data-view]').forEach((b) => b.setAttribute('aria-pressed', b.dataset.view === name));
    VIEWS[name].hide.forEach((id) => vis(id, false));
    VIEWS[name].show.forEach((id) => vis(id, true));
    if (name !== 'reach') showShelterReach(null);
    if (name === 'normal' && !navigator.onLine) notice('Base map needs internet for the Esri basemap tiles.');
    buildLegend();
    updateUrl();
  }
  function wireViews() { document.querySelectorAll('[data-view]').forEach((b) => { b.onclick = () => setView(b.dataset.view); }); }

  // ---- legend (per view) ---------------------------------------------------
  function legendRow(swatch, label) { return el('div', { className: 'row' }, [swatch, label]); }
  const sw = (c) => el('span', { className: 'sw', style: 'background:' + c });
  const dot = (bg) => el('span', { className: 'chip' }, [el('span', { className: 'dot', style: 'background:' + bg })]);
  function buildLegend() {
    const L = $('legend'); L.replaceChildren();
    if (state.view === 'evac') {
      L.append(el('div', { className: 'src', textContent: 'Fire hazard severity (CAL FIRE FRAP)' }));
      [['#fdbb84', 'Moderate'], ['#e34a33', 'High'], ['#b30000', 'Very High']].forEach(([c, t]) => L.append(legendRow(sw(c), t)));
      L.append(legendRow(el('span', { className: 'sw', style: 'border:0;border-top:2px dashed #4d4d4d;height:0;margin:5px 0' }), 'Past fire perimeter (River 2021, Mosquito 2022)'));
    } else if (state.view === 'reach') {
      L.append(el('div', { className: 'src', textContent: 'Drive time to reach a shelter (free-flow, no traffic)' }));
      [['#a8ddb5', '≤ 10 min'], ['#74a9cf', '≤ 20 min'], ['#fcae91', '≤ 30 min']].forEach(([c, t]) => L.append(legendRow(sw(c), t)));
    }
    L.append(legendRow(dot('#fff'), 'Shelter — verified'));
    L.append(legendRow(dot('transparent'), 'Shelter — candidate (not confirmed)'));
    L.append(legendRow(sw('#d81b60'), 'Route to nearest shelter'));
  }

  // Shelter reach: the precomputed 10/20/30-min bands filtered to one shelter (null = all shelters).
  function showShelterReach(id) {
    state.reach = id;
    if (map.getLayer('coverage-bands')) map.setFilter('coverage-bands', id ? ['==', ['get', 'shelter_id'], id] : null);
    const s = state.shelters.find((x) => x.properties.id === id);
    $('reach-status').textContent = id ? `Showing the reach of ${s ? s.properties.name : id} only — click the map to show all shelters.` : '';
    updateUrl();
  }

  function updateUrl() {
    const u = new URLSearchParams();
    if (state.start) { u.set('lng', state.start[0].toFixed(5)); u.set('lat', state.start[1].toFixed(5)); }
    if (state.closed) u.set('closed', '1');
    if (state.view && state.view !== 'evac') u.set('view', state.view);
    if (state.reach) u.set('shelter', state.reach);
    history.replaceState(null, '', u.toString() ? '?' + u : location.pathname);
  }

  function wireHover() {
    hoverPopup = new maplibregl.Popup({ closeButton: false, closeOnClick: false, offset: 12 });
    const layers = ['shelters-verified', 'shelters-candidate'];
    map.on('mousemove', (e) => {
      const f = map.queryRenderedFeatures(e.point, { layers })[0];
      map.getCanvas().style.cursor = f ? 'pointer' : '';
      if (!f) return hoverPopup.remove();
      hoverPopup.setLngLat(f.geometry.coordinates).setText(`${f.properties.name} (${f.properties.status})`).addTo(map);
    });
    map.on('click', (e) => {
      const f = map.queryRenderedFeatures(e.point, { layers })[0];
      if (f) { // shelter click -> info popup (not a pin drop); in the reach view it also isolates that shelter's bands
        const p = f.properties;
        const node = el('div', {}, [el('strong', { textContent: p.name }), el('br'), `Type: ${p.type}`, el('br'), `Town: ${p.town}`, el('br'), `Status: ${p.status}`, el('br'), `Source: ${p.source}`]);
        if (state.view === 'reach') { showShelterReach(p.id); node.append(el('br'), el('em', { textContent: 'Showing only this shelter’s 10 / 20 / 30-min reach. Click the map to show all.' })); }
        new maplibregl.Popup({ offset: 12 }).setLngLat(f.geometry.coordinates).setDOMContent(node).addTo(map);
        return;
      }
      setStart(e.lngLat.lng, e.lngLat.lat);
    });
  }

  // ---- startup -----------------------------------------------------------------
  async function init() {
    const style = await (await fetch('style.json')).json();
    style.sources.evac.url = 'pmtiles://' + PMTILES_URL;
    // Label fonts are vendored in 02-web/fonts (Noto Sans, OFL) so labels also work offline / in the room.
    style.glyphs = new URL('../02-web/fonts/', location.href).href + '{fontstack}/{range}.pbf';
    const [shelters, bands] = await Promise.all([
      loadData('shelters.geojson', 'shelters.geojson'),
      loadData('coverage/coverage_bands.geojson', 'coverage_bands.geojson')
    ]);
    // Data goes straight into the style, so the map never waits on an event to show it.
    state.shelters = shelters.features;
    style.sources.shelters.data = shelters;
    style.sources.coverage_bands.data = bands;
    maplibregl.addProtocol('pmtiles', new pmtiles.Protocol().tile);
    map = new maplibregl.Map({ container: 'map', style, center: CENTER, zoom: ZOOM, attributionControl: false });
    map.addControl(new maplibregl.AttributionControl({ compact: false }));
    map.addControl(new maplibregl.NavigationControl(), 'top-right');
    map.addControl(new maplibregl.ScaleControl({ unit: 'metric' }), 'bottom-right');
    let tileWarned = false;
    map.on('error', (e) => {
      const msg = String((e.error && e.error.message) || '');
      console.warn('map error:', msg);
      if (!tileWarned && (e.sourceId === 'evac' || /pmtiles|evac|404|Range/i.test(msg))) { tileWarned = true; notice('Basemap tiles (data/prebuilt/evac.pmtiles) not found — shelters and coverage still work.'); }
    });
    wireViews(); wireHover();

    $('closed').onchange = (e) => { state.closed = e.target.checked; state.override = null; if (state.start) setStart(state.start[0], state.start[1]); };
    // Never block the map on routing: detect after everything else is drawn.
    state.osrm = await detectOsrm();
    $('routing-status').textContent = state.osrm ? 'Routing: ' + state.osrm.label : 'Routing unavailable — map and shelters still work';
    const q = new URLSearchParams(location.search);
    if (q.get('closed') === '1') { state.closed = true; $('closed').checked = true; }
    if (q.has('lng') && q.has('lat')) setStart(+q.get('lng'), +q.get('lat'), true);
    const applyView = () => { setView(VIEWS[q.get('view')] ? q.get('view') : 'evac'); if (q.get('shelter') && state.view === 'reach') showShelterReach(q.get('shelter')); };
    if (map.isStyleLoaded()) applyView(); else map.once('load', applyView);
    // Console / automation hook (the module scope hides everything else): rts.setView('reach'), rts.setStart(lng, lat), rts.showShelterReach(id)
    window.rts = { map, setStart, setView, showShelterReach, state };
  }
  init().catch((e) => { console.error(e); notice('Demo failed to start: ' + e.message); });
}

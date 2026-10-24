// Lab 3a — Hello route: draw ONE route from OSRM on the map.
// Use it by uncommenting the step1 line at the bottom of 02-web/index.html.
//
// $OSRM_URL for the browser = same-origin "/osrm" (Caddy proxies it to OSRM; works in Codespaces and Docker).
// If you run OSRM without Caddy, use 'http://localhost:5000' instead.
const OSRM_URL = '/osrm';

const FORESTHILL = [-120.8182, 39.0199];     // lon, lat
const PLACER_HIGH = [-121.07088, 38.89523];  // a shelter, 35 km away by road

export async function start(map, maplibregl) {
  // OSRM call: ask for the driving route, geometry as GeoJSON (so MapLibre can draw it directly)
  const url = `${OSRM_URL}/route/v1/driving/${FORESTHILL.join(',')};${PLACER_HIGH.join(',')}?overview=full&geometries=geojson`;
  const answer = await (await fetch(url)).json();
  if (answer.code !== 'Ok') {
    console.warn('OSRM said:', answer);
    return;
  }
  const route = answer.routes[0];
  console.log(`Route: ${(route.duration / 60).toFixed(1)} min, ${(route.distance / 1000).toFixed(1)} km`);

  // A GeoJSON source holds the line; two layers draw it: white casing underneath, pink line on top
  map.addSource('route', { type: 'geojson', data: { type: 'Feature', geometry: route.geometry } });
  const beforeShelters = map.getLayer('shelters') ? 'shelters' : undefined;  // keep shelters on top
  map.addLayer({ id: 'route-casing', type: 'line', source: 'route',
    layout: { 'line-cap': 'round', 'line-join': 'round' },
    paint: { 'line-color': '#ffffff', 'line-width': 7 } }, beforeShelters);
  map.addLayer({ id: 'route', type: 'line', source: 'route',
    layout: { 'line-cap': 'round', 'line-join': 'round' },
    paint: { 'line-color': '#d81b60', 'line-width': 4 } }, beforeShelters);

  new maplibregl.Marker().setLngLat(FORESTHILL).addTo(map);
  map.flyTo({ center: [-120.95, 38.96], zoom: 10 });
}

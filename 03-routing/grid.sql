-- Stretch A — "15-minute reach": drive time from a 20 x 20 grid of points to the nearest shelter.
-- Run from the repo root:   duckdb -c ".read 03-routing/grid.sql"
-- Writes:  out/grid.geojson  (400 points)  and  out/grid-coords.txt  (ONE coordinate string for a /table call)
LOAD spatial;
SET geometry_always_xy = true;   -- DuckDB 2.0: lon/lat order must be explicit

-- Study area from versions.env (W, S, E, N)
CREATE OR REPLACE TABLE bbox AS SELECT -121.40 AS w, 38.72 AS s, -120.52 AS e, 39.20 AS n;

-- 20 columns x 20 rows = 400 points, centred in grid cells (the "grid" is just two generate_series)
CREATE OR REPLACE TABLE grid AS
SELECT
  row_number() OVER (ORDER BY y, x) - 1 AS i,        -- 0..399 = the index OSRM will use
  round(w + (x + 0.5) * (e - w) / 20, 5) AS lon,
  round(s + (y + 0.5) * (n - s) / 20, 5) AS lat
FROM bbox, generate_series(0, 19) AS gx(x), generate_series(0, 19) AS gy(y);

-- (the same 400 points via ST_MakeEnvelope, to prove they are all inside the bbox)
SELECT count(*) AS points_inside_bbox
FROM grid, bbox
WHERE ST_Within(ST_Point(lon, lat), ST_MakeEnvelope(w, s, e, n));

COPY (SELECT i, lon, lat, ST_Point(lon, lat) AS geom FROM grid)
TO 'out/grid.geojson' (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'WRITE_BBOX=NO');

-- One string: 400 grid points first, then the 10 shelters  ->  "lon,lat;lon,lat;..."  (410 coordinates)
COPY (
  SELECT string_agg(lon || ',' || lat, ';' ORDER BY ord) AS coords
  FROM (
    SELECT i AS ord, lon, lat FROM grid
    UNION ALL
    SELECT 1000 + row_number() OVER () AS ord,
           ST_X(geom), ST_Y(geom)
    FROM ST_Read('data/shelters.geojson')
  )
) TO 'out/grid-coords.txt' (FORMAT CSV, HEADER false, QUOTE '', DELIMITER '|');

SELECT 'grid-coords.txt written: 400 grid points + 10 shelters' AS done;

-- ---------------------------------------------------------------------------------------------
-- Next, in the browser console (or a script) — ONE call:
--   OSRM's GET URL is limited to ~8000 characters; 410 coordinates are too long, so POST JSON instead:
--
--   const coords = (await (await fetch('../out/grid-coords.txt')).text()).trim().split(';').map(p => p.split(',').map(Number));
--   // OSRM call (/table, POST): rows = the 400 grid points, columns = the 10 shelters (point -> shelter, like a resident driving out)
--   const r = await (await fetch(OSRM + '/table/v1/driving', {
--     method: 'POST', headers: { 'Content-Type': 'application/json' },
--     body: JSON.stringify({ coordinates: coords, sources: [...Array(400).keys()],
--                            destinations: [400,401,402,403,404,405,406,407,408,409], annotations: ['duration'] }) })).json();
--   const minutes = r.durations.map(row => Math.min(...row.filter(x => x !== null)) / 60);   // nearest shelter by road
--
-- (Measured on the pre-staged graph: all 400 points routable; range 0.6 – 74 min.)
--
-- Render: put minutes[i] on each grid point as a GeoJSON property `minutes` (out/grid.geojson has the points),
-- then draw circles with a STEP expression in a sequential GnBu ramp (never red/orange — red means fire hazard here):
--   'circle-color': ['step', ['get', 'minutes'],
--       '#a8ddb5',  10,      // < 10 min
--       '#7bccc4',  20,      // 10-20 min
--       '#43a2ca',  30,      // 20-30 min
--       '#0868ac']           // > 30 min
-- Points OSRM cannot reach return null durations: draw them grey (#cccccc).

-- Lab 0 — "hello, geo". Run from the repo root:  duckdb -c ".read setup/hello-geo.sql"
-- Every machine, every tier, must print the same line.
LOAD spatial;
SET geometry_always_xy = true;   -- lon/lat axis order (becomes the default in DuckDB 2.1)

.mode list
.headers off
SELECT concat(
         'OK — DuckDB ', replace(version(), 'v', ''),
         ' · ', count(*), ' shelters (',
         count(*) FILTER (status = 'verified'), ' verified, ',
         count(*) FILTER (status = 'candidate'), ' candidate)',
         ' · nearest to Colfax (crow-flies): ',
         arg_min(name, ST_Distance_Sphere(geom, ST_Point(-120.9533, 39.1007))),
         ', ',
         printf('%.1f', min(ST_Distance_Sphere(geom, ST_Point(-120.9533, 39.1007))) / 1000.0),
         ' km'
       )
FROM (SELECT name, status, geom FROM ST_Read('data/shelters.geojson'));

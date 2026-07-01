-- hello-geo.sql — the 0:00–0:15 environment check.
-- If this prints one row saying your setup is OK, you're ready for the workshop.
--
-- Run it with:   duckdb < setup/hello-geo.sql
--
-- Placeholder: the real check also loads a tiny sample from data-bundle/ before the session.

INSTALL spatial;
LOAD spatial;

SELECT
    'OK — DuckDB ' || version()                     AS status,
    ST_AsText(ST_Point(-121.4944, 38.5816))         AS sacramento_point,   -- lon/lat of Sacramento, CA
    ST_Distance(
        ST_Point(-121.4944, 38.5816),               -- Sacramento
        ST_Point(-122.2712, 37.8044)                -- Oakland
    )                                               AS degrees_apart;

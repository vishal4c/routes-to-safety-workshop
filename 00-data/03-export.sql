-- Phase 1c — Export: write a GeoJSON file with SQL.  Run from the repo root:
--     duckdb -c ".read 00-data/03-export.sql"
-- COPY (query) TO 'file' (FORMAT GDAL, DRIVER 'GeoJSON') is how every file in data/ was made (scripts/fetch-*.sh).
-- Here it writes out/shelter-candidates.geojson: the "shelter-ish" Overture places from 1b, in the same shape as
-- data/shelters.geojson (id, name, status, type, town, source). Phase 4 runs this for your own box and you keep the
-- real ones. id is the name as a slug; two places with the same name get -1, -2 so every id is unique.
-- Expected: 95 features — check with
--     duckdb -c "LOAD spatial; SELECT type, count(*) FROM ST_Read('out/shelter-candidates.geojson') GROUP BY type ORDER BY 2 DESC"
--   ┌──────────────────┬───────┐
--   │       type       │   n   │
--   │     varchar      │ int64 │
--   ├──────────────────┼───────┤
--   │ school           │    39 │
--   │ community_center │    19 │
--   │ college          │    18 │
--   │ town_hall        │     8 │
--   │ fairground       │     7 │
--   │ stadium_arena    │     4 │
--   └──────────────────┴───────┘
LOAD spatial;
SET geometry_always_xy = true;

COPY (
  WITH picked AS (
    SELECT name, category, confidence, locality, geom,
           -- the name as a slug: "Placer High School" → placer-high-school; a name that is only punctuation → NULL
           nullif(trim(lower(regexp_replace(trim(name), '[^A-Za-z0-9]+', '-', 'g')), '-'), '') AS slug
    FROM ST_Read('data/overture/places.geojson')
    WHERE category IN ('community_center','fairgrounds','town_hall','high_school','college_university','stadium_arena')
      AND confidence >= 0.7
  ),
  numbered AS (                                      -- two rows with the same slug → slug-1, slug-2 (unique ids)
    SELECT *, coalesce(slug, 'unnamed') AS base,
           count(*)     OVER (PARTITION BY coalesce(slug, 'unnamed')) AS same_name,
           row_number() OVER (PARTITION BY coalesce(slug, 'unnamed') ORDER BY confidence DESC, ST_X(geom), ST_Y(geom)) AS k
    FROM picked
  )
  SELECT CASE WHEN same_name > 1 THEN base || '-' || k ELSE base END AS id,
         name,
         'candidate' AS status,                       -- nothing is verified until a primary source says so
         CASE category WHEN 'high_school' THEN 'school' WHEN 'college_university' THEN 'college'
                       WHEN 'fairgrounds' THEN 'fairground' ELSE category END AS type,
         locality AS town,
         'Overture places (' || category || ', confidence ' || round(confidence, 2) || ') — unverified' AS source,
         geom AS geometry
  FROM numbered
  ORDER BY type, name
) TO 'out/shelter-candidates.geojson' (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');

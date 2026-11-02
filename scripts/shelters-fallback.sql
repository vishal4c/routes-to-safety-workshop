-- Fallback shelters — when Phase 4 step 4 picks nothing, the schools in the box stand in.
-- Tier 1: high schools (category = 'high_school'). None in the box? Tier 2: any K-12 campus — school, elementary,
-- middle, public, private, charter, montessori, religious (not driving, music, flight … schools, not preschools).
-- Up to 10 of the best tier, confidence >= 0.7, highest confidence first, every one status = 'candidate' (nothing is
-- verified until a county source says so). Same columns and id slugs as 00-data/03-export.sql.
-- Used by scripts/pick-shelters.sh, 01-tiles/build.sh and scripts/make-coverage.py; run from the repo root:
--     duckdb -c ".read scripts/shelters-fallback.sql"          → data/shelters.geojson
LOAD spatial;
SET geometry_always_xy = true;

COPY (
  WITH schools AS (
    SELECT name, category, confidence, locality, geom,
           CASE WHEN category = 'high_school' THEN 1 ELSE 2 END AS tier,
           nullif(trim(lower(regexp_replace(trim(name), '[^A-Za-z0-9]+', '-', 'g')), '-'), '') AS slug
    FROM ST_Read('data/overture/places.geojson')
    WHERE category IN ('high_school',
                       'school', 'elementary_school', 'middle_school', 'public_school', 'private_school',
                       'charter_school', 'montessori_school', 'religious_school')
      AND confidence >= 0.7 AND name IS NOT NULL
  ),
  best AS (                                          -- the best tier that has at least one school
    SELECT * FROM schools WHERE tier = (SELECT min(tier) FROM schools)
    ORDER BY confidence DESC, name
    LIMIT 10
  ),
  numbered AS (                                      -- two schools with the same name → slug-1, slug-2
    SELECT *, coalesce(slug, 'unnamed') AS base,
           count(*)     OVER (PARTITION BY coalesce(slug, 'unnamed')) AS same_name,
           row_number() OVER (PARTITION BY coalesce(slug, 'unnamed') ORDER BY confidence DESC, ST_X(geom), ST_Y(geom)) AS k
    FROM best
  )
  SELECT CASE WHEN same_name > 1 THEN base || '-' || k ELSE base END AS id,
         name,
         'candidate' AS status,
         'school'    AS type,
         locality    AS town,
         'Overture places (' || category || ', confidence ' || round(confidence, 2) || ') — fallback, unverified' AS source,
         geom AS geometry
  FROM numbered
  ORDER BY name
) TO 'data/shelters.geojson' (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');

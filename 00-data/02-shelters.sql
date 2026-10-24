-- Lab 1b — Candidate shelters (8 min + 2).  Run from the REPO ROOT:
--     duckdb -c ".read 00-data/02-shelters.sql"
-- Idea: ask Overture for "places that could be shelters", look at what comes back, then compare with the
-- hand-checked data/shelters.geojson and ask the hazard layer which shelters sit in a Very High zone.
LOAD spatial;
SET geometry_always_xy = true;   -- DuckDB 2.0: required for spatial functions / GDAL I/O (default from 2.1)

-- Query 1 — community centers with confidence >= 0.7.  19 rows. Look at the names: a Chevrolet dealer and a
-- child-support office are labelled community_center.  Category data looks authoritative and isn't.
-- Expected:
--   ┌────────────────────────────────────────────────────┬──────────────────┬────────────┐
--   │                        name                        │     category     │ confidence │
--   │                      varchar                       │     varchar      │   double   │
--   ├────────────────────────────────────────────────────┼──────────────────┼────────────┤
--   │ Meadow Vista Community Center                      │ community_center │        1.0 │
--   │ Pollock Pines-Camino Community Center              │ community_center │        1.0 │
--   │ Canyon View Community Center                       │ community_center │       0.99 │
--   │ Roseville Veterans Memorial Hall                   │ community_center │       0.99 │
--   │ Whitney Ranch Community Association                │ community_center │       0.99 │
--   │ Mt Pleasant Hall - Lincoln, CA                     │ community_center │       0.97 │
--   │ Placer County Department of Child Support Services │ community_center │       0.95 │
--   │ Applegate Community Center                         │ community_center │       0.92 │
--   │ Bluedoor Community Center Inc.                     │ community_center │       0.92 │
--   │ Connect at The Meadow                              │ community_center │       0.92 │
--   │ Higgins Lions Community Center                     │ community_center │       0.92 │
--   │ John L Sullivan Chevrolet                          │ community_center │       0.92 │
--   │ Lincoln Community Center                           │ community_center │       0.92 │
--   │ Pilot Hill Grange #1                               │ community_center │       0.92 │
--   │ Shugyo Empowerment Center                          │ community_center │       0.92 │
--   │ Sierra Vista Community Center                      │ community_center │       0.92 │
--   │ South Placer Teen Center                           │ community_center │       0.92 │
--   │ Rocklin Community Center                           │ community_center │       0.77 │
--   │ Orangevale Grange Hall                             │ community_center │       0.74 │
--   └────────────────────────────────────────────────────┴──────────────────┴────────────┘
--     19 rows                                                                  3 columns
SELECT name, category, round(confidence, 2) AS confidence
FROM 'data/overture/places.parquet'
WHERE category = 'community_center'
  AND confidence >= 0.7
ORDER BY confidence DESC, name;

-- Query 2 — the broader 'shelter-ish' filter: community centers, fairgrounds, town halls, high schools, colleges, arenas.
-- Expected:
--   ┌────────────────────┬───────┐
--   │      category      │   n   │
--   │      varchar       │ int64 │
--   ├────────────────────┼───────┤
--   │ high_school        │    39 │
--   │ community_center   │    19 │
--   │ college_university │    18 │
--   │ town_hall          │     8 │
--   │ fairgrounds        │     7 │
--   │ stadium_arena      │     4 │
--   └────────────────────┴───────┘
SELECT category, count(*) AS n
FROM 'data/overture/places.parquet'
WHERE category IN ('community_center','fairgrounds','town_hall','high_school','college_university','stadium_arena')
  AND confidence >= 0.7
GROUP BY category
ORDER BY n DESC;

-- Query 3 — the hand-checked file: data/shelters.geojson (10 shelters; 1 verified, 9 candidate).
-- ST_Read opens any GDAL format (GeoJSON, Shapefile, GeoPackage …) as a table.
-- Expected:
--   ┌──────────────────────────┬─────────────────────────────────────────┬───────────┬──────────────────┬────────────────────────────────────┐
--   │            id            │                  name                   │  status   │       type       │                town                │
--   │         varchar          │                 varchar                 │  varchar  │     varchar      │              varchar               │
--   ├──────────────────────────┼─────────────────────────────────────────┼───────────┼──────────────────┼────────────────────────────────────┤
--   │ sierra-college           │ Sierra College, Rocklin                 │ verified  │ college          │ Rocklin                            │
--   │ applegate-cc             │ Applegate Community Center              │ candidate │ community_center │ Applegate                          │
--   │ colfax-high              │ Colfax High School                      │ candidate │ school           │ Colfax                             │
--   │ georgetown-school        │ Georgetown School                       │ candidate │ school           │ Georgetown (El Dorado County)      │
--   │ gold-country-fairgrounds │ Gold Country Fairgrounds & Event Center │ candidate │ fairground       │ Auburn                             │
--   │ higgins-lions-cc         │ Higgins Lions Community Center          │ candidate │ community_center │ Lake of the Pines / Higgins Corner │
--   │ lincoln-cc               │ Lincoln Community Center                │ candidate │ community_center │ Lincoln                            │
--   │ meadow-vista-cc          │ Meadow Vista Community Center           │ candidate │ community_center │ Meadow Vista                       │
--   │ placer-high              │ Placer High School                      │ candidate │ school           │ Auburn                             │
--   │ sierra-vista-cc          │ Sierra Vista Community Center           │ candidate │ community_center │ Colfax                             │
--   └──────────────────────────┴─────────────────────────────────────────┴───────────┴──────────────────┴────────────────────────────────────┘
--     10 rows                                                                                                                      5 columns
SELECT id, name, status, type, town
FROM ST_Read('data/shelters.geojson')
ORDER BY status DESC, name;

-- Query 4 — which shelters are inside a Very High fire hazard zone?  ST_Intersects(a, b) is a yes/no question about two shapes.
-- Expected:
--   ┌───────────────────────────────┬───────────┬──────────────────┬──────────────────┐
--   │             name              │  status   │       type       │ FHSZ_Description │
--   │            varchar            │  varchar  │     varchar      │     varchar      │
--   ├───────────────────────────────┼───────────┼──────────────────┼──────────────────┤
--   │ Colfax High School            │ candidate │ school           │ Very High        │
--   │ Georgetown School             │ candidate │ school           │ Very High        │
--   │ Sierra Vista Community Center │ candidate │ community_center │ Very High        │
--   └───────────────────────────────┴───────────┴──────────────────┴──────────────────┘
SELECT s.name, s.status, s.type, h.FHSZ_Description
FROM ST_Read('data/shelters.geojson') AS s
JOIN 'data/hazard/fhsz.parquet' AS h
  ON ST_Intersects(s.geom, h.geometry)
WHERE h.FHSZ_Description = 'Very High'
ORDER BY s.name;

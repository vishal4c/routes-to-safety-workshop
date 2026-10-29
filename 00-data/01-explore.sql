-- Phase 1a — Look around.  Run from the repo root:
--     duckdb -c ".read 00-data/01-explore.sql"
-- Three queries over two of the staged files. Plain SQL: SELECT (which columns) / WHERE (which rows) / GROUP BY (count per group).
-- ST_Read() opens any GeoJSON (or Shapefile, GeoPackage …) as a table; LOAD spatial switches that on.
-- The output you should see is written above each query (Overture release 2026-09-23.1).
LOAD spatial;
SET geometry_always_xy = true;   -- lon/lat axis order (DuckDB 2.0 needs this for spatial I/O; default from 2.1)

-- Query 1 — what columns does the roads file have?  (36,294 drivable road segments in the box)
-- Expected:
--   [90m┌─────────────────────────────────┐[00m[90m
--   [00m[90m│            [00m[1mDescribe[00m[90m             │[00m[90m
--   [00m[90m│                                 │[00m[90m
--   [00m[90m│ [00mOGC_FID[90m   [00m[90mbigint[00m[90m                [00m[90m│[00m[90m
--   [00m[90m│ [00mid[90m        [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00mclass[90m     [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00msubclass[90m  [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00mname[90m      [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00mroute_ref[90m [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00mgeom[90m      [00m[90mgeometry('ogc:crs84')[00m[90m [00m[90m│[00m[90m
--   [00m[90m└─────────────────────────────────┘[00m[90m
--   [00m
DESCRIBE SELECT * FROM ST_Read('data/overture/roads.geojson');

-- Query 2 — roads by class.  Sum = 36,294 — the number every later step must reproduce.
-- (scripts/fetch-overture.sh kept only the drivable classes; footways, tracks and service roads never left Overture.)
-- Expected:
--   ┌──────────────┬───────┐
--   │    class     │   n   │
--   │   varchar    │ int64 │
--   ├──────────────┼───────┤
--   │ residential  │ 25995 │
--   │ tertiary     │  4333 │
--   │ secondary    │  2792 │
--   │ primary      │  1305 │
--   │ unclassified │  1265 │
--   │ motorway     │   541 │
--   │ trunk        │    63 │
--   └──────────────┴───────┘
SELECT class, count(*) AS n
FROM ST_Read('data/overture/roads.geojson')
GROUP BY class
ORDER BY n DESC;

-- Query 3 — places by category, top 15  (27,096 places in total; NULL = no category in Overture)
-- Expected:
--   ┌─────────────────────────────┬───────┐
--   │          category           │   n   │
--   │           varchar           │ int64 │
--   ├─────────────────────────────┼───────┤
--   │ real_estate_agent           │  1240 │
--   │ NULL                        │   919 │
--   │ health_care                 │   559 │
--   │ real_estate_service         │   517 │
--   │ insurance_agency            │   437 │
--   │ financial_service           │   350 │
--   │ contractor                  │   349 │
--   │ beauty_salon                │   341 │
--   │ hair_salon                  │   333 │
--   │ mortgage_broker             │   322 │
--   │ christian_place_of_worship  │   289 │
--   │ park                        │   287 │
--   │ social_or_community_service │   246 │
--   │ automotive_repair           │   243 │
--   │ professional_service        │   234 │
--   └─────────────────────────────┴───────┘
--     15 rows                   2 columns
SELECT category, count(*) AS n
FROM ST_Read('data/overture/places.geojson')
GROUP BY category
ORDER BY n DESC
LIMIT 15;

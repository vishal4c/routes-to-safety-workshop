-- Lab 1a — Look around (6 min + 2).  Run from the REPO ROOT:
--     duckdb -c ".read 00-data/01-explore.sql"
-- Three queries. Each one is preceded by the output you should see (measured on Overture 2026-09-23.1).
-- Plain SQL only: SELECT (which columns) / WHERE (which rows) / GROUP BY (count per group).

-- Query 1 — what columns does the roads table have?  (96,059 rows: every road-type segment in the bbox)
-- Expected:
--   [90m┌─────────────────────────────────┐[00m[90m
--   [00m[90m│ [00m[1mdata/overture/segments.parquet[00m[90m  │[00m[90m
--   [00m[90m│                                 │[00m[90m
--   [00m[90m│ [00mid[90m        [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00msubtype[90m   [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00mclass[90m     [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00msubclass[90m  [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00mname[90m      [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00mroute_ref[90m [00m[90mvarchar[00m[90m               [00m[90m│[00m[90m
--   [00m[90m│ [00mgeometry[90m  [00m[90mgeometry('ogc:crs84')[00m[90m [00m[90m│[00m[90m
--   [00m[90m└─────────────────────────────────┘[00m[90m
--   [00m
DESCRIBE SELECT * FROM 'data/overture/segments.parquet';

-- Query 2 — roads by class, drivable classes only (this WHERE is the same filter Lab 1c uses for roads.geojson;
-- remove it to also see service / footway / track / path …).  Sum = 36,294.
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
FROM 'data/overture/segments.parquet'
WHERE class IN ('motorway','trunk','primary','secondary','tertiary','residential','unclassified','living_street',
                'motorway_link','trunk_link','primary_link','secondary_link','tertiary_link')
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
FROM 'data/overture/places.parquet'
GROUP BY category
ORDER BY n DESC
LIMIT 15;

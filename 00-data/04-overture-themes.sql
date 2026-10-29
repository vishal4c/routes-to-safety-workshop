-- Phase 1 (optional) — Look inside every Overture theme we staged.  Run from the REPO ROOT:
--     duckdb -c ".read 00-data/04-overture-themes.sql"
--
-- data/overture/ holds seven Parquet files, one per Overture theme/type, already clipped to the study-area bbox
-- (scripts/sql/overture.sql did that against the public Overture release; scripts/make-data.sh overture re-runs it).
-- Phase 1a used two of them (segments, places). This file opens all seven, so you know what else is on the shelf.
-- Each query is preceded by the output you should see (Overture 2026-09-23.1). Plain SELECT / WHERE / GROUP BY only.

LOAD spatial;

-- 0. Inventory — which file came from which Overture theme, and how many rows each holds.
-- Expected:
--   ┌──────────────────┬──────────────────────────────┬────────┐
--   │       file       │        overture_theme        │  rows  │
--   ├──────────────────┼──────────────────────────────┼────────┤
--   │ segments         │ transportation / segment     │  96059 │
--   │ connectors       │ transportation / connector   │ 143316 │
--   │ places           │ places / place               │  27096 │
--   │ water            │ base / water                 │   6654 │
--   │ land_cover       │ base / land_cover            │   2564 │
--   │ localities       │ divisions / division         │    134 │
--   │ buildings_auburn │ buildings / building (Auburn)│  12606 │
--   └──────────────────┴──────────────────────────────┴────────┘
SELECT 'segments' AS file, 'transportation / segment' AS overture_theme, count(*) AS rows FROM 'data/overture/segments.parquet'
UNION ALL SELECT 'connectors',       'transportation / connector',    count(*) FROM 'data/overture/connectors.parquet'
UNION ALL SELECT 'places',           'places / place',                count(*) FROM 'data/overture/places.parquet'
UNION ALL SELECT 'water',            'base / water',                  count(*) FROM 'data/overture/water.parquet'
UNION ALL SELECT 'land_cover',       'base / land_cover',             count(*) FROM 'data/overture/land_cover.parquet'
UNION ALL SELECT 'localities',       'divisions / division',          count(*) FROM 'data/overture/localities.parquet'
UNION ALL SELECT 'buildings_auburn', 'buildings / building (Auburn)', count(*) FROM 'data/overture/buildings_auburn.parquet';

-- 1. The study area the files were clipped to — compare with BBOX_W/S/E/N in versions.env (-121.40, 38.72, -120.52, 39.20).
-- Expected:  west -121.4 · south 38.72 · east -120.52 · north 39.2
SELECT round(min(ST_XMin(geometry)), 3) AS west,  round(min(ST_YMin(geometry)), 3) AS south,
       round(max(ST_XMax(geometry)), 3) AS east,  round(max(ST_YMax(geometry)), 3) AS north
FROM 'data/overture/segments.parquet';

-- 2. transportation / segment — the numbered routes. route_ref is what a sign says: 80 = I-80, 49 = CA-49, 193 = CA-193.
-- Expected (top 6):  49 → 178 segments · 193 → 130 · 80 → 129 · E3 → 98 · 174 → 83 · 65 → 52
SELECT route_ref, count(*) AS segments
FROM 'data/overture/segments.parquet'
WHERE route_ref IS NOT NULL
GROUP BY route_ref ORDER BY segments DESC LIMIT 6;

-- 3. transportation / connector — the points where segments join (intersections, dead ends). OSRM builds its graph from these.
-- Expected:  143316 connectors for 96059 segments
SELECT count(*) AS connectors, (SELECT count(*) FROM 'data/overture/segments.parquet') AS segments
FROM 'data/overture/connectors.parquet';

-- 4. places / place — how sure Overture is about each place. 02-shelters.sql keeps confidence >= 0.7: that is the top four rows.
-- Expected:  1.0 → 6373 · 0.9 → 11725 · 0.8 → 2247 · 0.7 → 1663 · 0.6 → 2004 · … · 0.0 → 36
SELECT round(confidence, 1) AS confidence, count(*) AS places
FROM 'data/overture/places.parquet'
GROUP BY 1 ORDER BY 1 DESC;

-- 5. base / water — what kinds of water there are. The map keeps polygons only (03-export.sql); streams are lines.
-- Expected (top 8):  stream 3003 · swimming_pool 791 · canal 780 · water 741 · ditch 445 · drain 276 · pond 258 · river 163
SELECT subtype, class, count(*) AS n
FROM 'data/overture/water.parquet'
GROUP BY subtype, class ORDER BY n DESC LIMIT 8;

-- 6. base / land_cover — ESA WorldCover classes as polygons. The map draws them in pale green under everything.
-- Expected:  barren 770 · shrub 743 · forest 391 · urban 361 · crop 288 · grass 7 · wetland 4
SELECT subtype, count(*) AS n
FROM 'data/overture/land_cover.parquet'
GROUP BY subtype ORDER BY n DESC;

-- 7. divisions / division — the town labels. One city, five towns, ten villages, 105 hamlets, plus 13 unclassed (neighborhoods) = 134; population where Overture has it.
-- Expected (top 5 by population):  Roseville 107158 · Rocklin 50131 · Lincoln 39566 · Auburn 13330 · Placerville 10086
SELECT subtype, class, name, population
FROM 'data/overture/localities.parquet'
ORDER BY population DESC NULLS LAST LIMIT 5;

-- 8. buildings / building — Auburn only (AUBURN_* in versions.env), for the 3D step. height is in metres; most buildings have no subtype.
-- Expected (top 4):  NULL 11530 (10393 with a height) · residential 773 · commercial 144 · transportation 51
SELECT subtype, count(*) AS n, count(height) AS with_height, round(avg(height), 1) AS avg_height_m
FROM 'data/overture/buildings_auburn.parquet'
GROUP BY subtype ORDER BY n DESC LIMIT 4;

-- Try: DESCRIBE SELECT * FROM 'data/overture/water.parquet';   -- the columns of any file
--      SELECT name FROM 'data/overture/water.parquet' WHERE subtype = 'reservoir' AND name IS NOT NULL ORDER BY name;

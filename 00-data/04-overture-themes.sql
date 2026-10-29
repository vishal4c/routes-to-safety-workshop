-- Optional — a tour of every Overture file in data/overture/ (Phase 1).  Run from the repo root:
--     duckdb -c ".read 00-data/04-overture-themes.sql"
-- Six GeoJSON files, each one Overture theme/type clipped to the box by scripts/fetch-overture.sh:
--   roads.geojson       theme=transportation  type=segment   drivable classes only (subtype = 'road')
--   water.geojson       theme=base            type=water     polygons only (the theme also has shoreline lines and spring points)
--   towns.geojson       theme=divisions       type=division  subtype = 'locality' → city / town / village / hamlet labels
--   land_cover.geojson  theme=base            type=land_cover  ESA WorldCover polygons, with the zoom range Overture suggests
--   buildings.geojson   theme=buildings       type=building  Auburn box only (BUILDINGS_* in versions.env)
--   places.geojson      theme=places          type=place     points of interest with a category and a confidence score
-- Not staged: transportation/connector (143,316 points where segments meet — OSRM has its own graph), addresses, infrastructure.
-- The output you should see is written above each query.
LOAD spatial;
SET geometry_always_xy = true;

-- 1. Inventory — feature count per file
-- Expected:
--   ┌────────────────────┬──────────┐
--   │        file        │ features │
--   │      varchar       │  int64   │
--   ├────────────────────┼──────────┤
--   │ roads.geojson      │    36294 │
--   │ water.geojson      │     1920 │
--   │ towns.geojson      │      121 │
--   │ land_cover.geojson │     2564 │
--   │ buildings.geojson  │    12606 │
--   │ places.geojson     │    27096 │
--   └────────────────────┴──────────┘
SELECT 'roads.geojson'      AS file, count(*) AS features FROM ST_Read('data/overture/roads.geojson')      UNION ALL
SELECT 'water.geojson',              count(*)             FROM ST_Read('data/overture/water.geojson')      UNION ALL
SELECT 'towns.geojson',              count(*)             FROM ST_Read('data/overture/towns.geojson')      UNION ALL
SELECT 'land_cover.geojson',         count(*)             FROM ST_Read('data/overture/land_cover.geojson') UNION ALL
SELECT 'buildings.geojson',          count(*)             FROM ST_Read('data/overture/buildings.geojson')  UNION ALL
SELECT 'places.geojson',             count(*)             FROM ST_Read('data/overture/places.geojson');

-- 2. The box — min/max of every road coordinate; compare with BBOX_* in versions.env (-121.40, 38.72, -120.52, 39.20)
-- Expected:
--   ┌────────┬────────┬─────────┬────────┐
--   │  west  │ south  │  east   │ north  │
--   │ double │ double │ double  │ double │
--   ├────────┼────────┼─────────┼────────┤
--   │ -121.4 │  38.72 │ -120.53 │   39.2 │
--   └────────┴────────┴─────────┴────────┘
SELECT round(min(ST_XMin(geom)), 2) AS west, round(min(ST_YMin(geom)), 2) AS south,
       round(max(ST_XMax(geom)), 2) AS east, round(max(ST_YMax(geom)), 2) AS north
FROM ST_Read('data/overture/roads.geojson');

-- 3. Roads — numbered routes (route_ref comes from Overture's routes[] list): I-80, CA-49, CA-193 …
-- Expected:
--   ┌───────────┬──────────┬────────┐
--   │ route_ref │ segments │   km   │
--   │  varchar  │  int64   │ double │
--   ├───────────┼──────────┼────────┤
--   │ 80        │      129 │  143.7 │
--   │ 49        │      178 │   62.2 │
--   │ 193       │      130 │   55.1 │
--   │ 65        │       52 │   54.9 │
--   │ 96        │        7 │   44.6 │
--   │ E3        │       98 │   18.7 │
--   └───────────┴──────────┴────────┘
SELECT route_ref, count(*) AS segments, round(sum(ST_Length_Spheroid(geom)) / 1000, 1) AS km
FROM ST_Read('data/overture/roads.geojson')
WHERE route_ref IS NOT NULL
GROUP BY route_ref ORDER BY km DESC LIMIT 6;

-- 4. Places — the confidence ladder: how sure Overture is that a place exists at all
-- Expected:
--   ┌────────────┬────────┐
--   │ confidence │ places │
--   │  varchar   │ int64  │
--   ├────────────┼────────┤
--   │ < 0.5      │   2711 │
--   │ 0.9 – 1.0  │  16680 │
--   │ 0.7 – 0.9  │   4036 │
--   │ 0.5 – 0.7  │   3669 │
--   └────────────┴────────┘
SELECT CASE WHEN confidence >= 0.9 THEN '0.9 – 1.0' WHEN confidence >= 0.7 THEN '0.7 – 0.9'
            WHEN confidence >= 0.5 THEN '0.5 – 0.7' ELSE '< 0.5' END AS confidence, count(*) AS places
FROM ST_Read('data/overture/places.geojson')
GROUP BY 1 ORDER BY 1 DESC;

-- 5. Water — what kind of water polygons the box has
-- Expected:
--   ┌───────────────┬───────┬────────┐
--   │     class     │   n   │  km2   │
--   │    varchar    │ int64 │ double │
--   ├───────────────┼───────┼────────┤
--   │ reservoir     │    66 │   17.5 │
--   │ water         │   741 │    4.7 │
--   │ river         │     1 │    2.2 │
--   │ pond          │   258 │    1.4 │
--   │ basin         │    53 │    0.5 │
--   │ lake          │    16 │    0.3 │
--   │ wastewater    │    21 │    0.1 │
--   │ swimming_pool │   749 │    0.1 │
--   │ drain         │     1 │    0.0 │
--   │ spring        │     1 │    0.0 │
--   │ stream        │    13 │    0.0 │
--   └───────────────┴───────┴────────┘
--     11 rows              3 columns
SELECT class, count(*) AS n, round(sum(ST_Area_Spheroid(geom)) / 1e6, 1) AS km2
FROM ST_Read('data/overture/water.geojson')
GROUP BY class ORDER BY km2 DESC;

-- 6. Land cover — the WorldCover classes by area
-- Expected:
--   ┌─────────┬──────────┬────────┐
--   │ subtype │ polygons │  km2   │
--   │ varchar │  int64   │ double │
--   ├─────────┼──────────┼────────┤
--   │ forest  │      391 │ 1621.0 │
--   │ shrub   │      743 │  574.0 │
--   │ urban   │      361 │   88.0 │
--   │ barren  │      770 │   39.0 │
--   │ crop    │      288 │   35.0 │
--   │ grass   │        7 │    0.0 │
--   │ wetland │        4 │    0.0 │
--   └─────────┴──────────┴────────┘
SELECT subtype, count(*) AS polygons, round(sum(ST_Area_Spheroid(geom)) / 1e6) AS km2
FROM ST_Read('data/overture/land_cover.geojson')
GROUP BY subtype ORDER BY km2 DESC;

-- 7. Towns — the biggest places by population (class = city / town / village / hamlet drives the label zoom in 01-tiles/evac.yml)
-- Expected:
--   ┌───────────────┬─────────┬────────────┐
--   │     name      │  class  │ population │
--   │    varchar    │ varchar │   int32    │
--   ├───────────────┼─────────┼────────────┤
--   │ Roseville     │ city    │     107158 │
--   │ Rocklin       │ town    │      50131 │
--   │ Lincoln       │ town    │      39566 │
--   │ Auburn        │ town    │      13330 │
--   │ Placerville   │ town    │      10086 │
--   │ Pollock Pines │ village │       6871 │
--   │ Loomis        │ town    │       6699 │
--   │ Meadow Vista  │ village │       5840 │
--   └───────────────┴─────────┴────────────┘
SELECT name, class, population
FROM ST_Read('data/overture/towns.geojson')
ORDER BY population DESC LIMIT 8;

-- 8. Buildings — about one building in ten has no height; the 3D layer in 02-web uses a default for those
-- Expected:
--   ┌───────────┬───────────┐
--   │  height   │ buildings │
--   │  varchar  │   int64   │
--   ├───────────┼───────────┤
--   │ < 5 m     │      6677 │
--   │ 5 – 10 m  │      4534 │
--   │ no height │      1363 │
--   │ ≥ 10 m    │        32 │
--   └───────────┴───────────┘
SELECT CASE WHEN height IS NULL THEN 'no height' WHEN height < 5 THEN '< 5 m' WHEN height < 10 THEN '5 – 10 m' ELSE '≥ 10 m' END AS height,
       count(*) AS buildings
FROM ST_Read('data/overture/buildings.geojson')
GROUP BY 1 ORDER BY buildings DESC;

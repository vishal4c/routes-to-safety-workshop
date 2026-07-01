-- 00-data/extract.sql — Module 1 (0:30–1:10): extract & query
-- DuckDB spatial SQL: pull the community's road network + candidate shelters
-- from Overture Maps and OpenStreetMap-derived GeoParquet, with no database server.
--
-- Placeholder: bbox and exact Overture release are pinned in README.md before the session.

INSTALL spatial; LOAD spatial;
INSTALL httpfs; LOAD httpfs;                 -- read Overture GeoParquet directly from S3

-- The metro-area bounding box (Sacramento). Small enough for a fast in-room build.
-- TODO: pin final bbox in README.md.
--   xmin, ymin, xmax, ymax = -121.60, 38.44, -121.35, 38.68  (placeholder)

-- 1) Roads: Overture "transportation" segments clipped to the bbox.
-- COPY (
--   SELECT id, names.primary AS name, class, geometry
--   FROM read_parquet('s3://overturemaps-us-west-2/release/<RELEASE>/theme=transportation/type=segment/*', hive_partitioning=1)
--   WHERE bbox.xmin > -121.60 AND bbox.xmax < -121.35
--     AND bbox.ymin >   38.44 AND bbox.ymax <   38.68
--     AND class IN ('motorway','trunk','primary','secondary','tertiary','residential')
-- ) TO 'roads.parquet' (FORMAT parquet);

-- 2) Candidate shelters: schools, community centers, fairgrounds from Overture "places".
-- COPY (
--   SELECT id, names.primary AS name, categories.primary AS category, geometry
--   FROM read_parquet('s3://overturemaps-us-west-2/release/<RELEASE>/theme=places/type=place/*', hive_partitioning=1)
--   WHERE bbox.xmin > -121.60 AND bbox.xmax < -121.35
--     AND bbox.ymin >   38.44 AND bbox.ymax <   38.68
--     AND categories.primary IN ('school','community_center','fairground')
-- ) TO 'shelters.parquet' (FORMAT parquet);

-- Exercise A: filter a single feature class (e.g., only 'primary' roads).
-- Exercise B: clip to a tighter bbox around one neighborhood.

SELECT 'extract.sql is a placeholder — see 00-data/README.md for the pinned bbox and release' AS note;

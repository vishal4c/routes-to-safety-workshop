-- Lab 1c — export the study area to GeoJSON for Planetiler.
-- Run from the repo root:   duckdb -c ".read 00-data/03-export.sql"
-- Every COPY names its columns: list-typed Overture columns must never reach the GeoJSON writer.
LOAD spatial;
SET geometry_always_xy = true;            -- DuckDB ≥ 2.0: GDAL writer needs this (lon/lat axis order)
SET VARIABLE out  = coalesce(getvariable('out'),  'out');    -- scripts/make-data.sh overrides these
SET VARIABLE data = coalesce(getvariable('data'), 'data');

-- 1. roads: drivable classes only (what OSRM routes on)
COPY (
  SELECT id, class, subclass, name, route_ref, geometry
  FROM read_parquet(getvariable('data') || '/overture/segments.parquet')
  WHERE class IN ('motorway','trunk','primary','secondary','tertiary','residential','unclassified','living_street',
                  'motorway_link','trunk_link','primary_link','secondary_link','tertiary_link')
) TO (getvariable('out') || '/roads.geojson') (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');

-- 2. water: polygons only (the source mixes points, lines and polygons)
COPY (
  SELECT id, subtype, class, name, geometry
  FROM read_parquet(getvariable('data') || '/overture/water.parquet')
  WHERE ST_GeometryType(geometry) IN ('POLYGON', 'MULTIPOLYGON')
) TO (getvariable('out') || '/water.geojson') (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');

-- 3. shelters: hand-curated, carries status = verified | candidate
COPY (
  SELECT id, name, status, type, town, geom AS geometry
  FROM ST_Read(getvariable('data') || '/shelters.geojson')
) TO (getvariable('out') || '/shelters.geojson') (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');

-- 4. hazard: CAL FIRE Fire Hazard Severity Zones (SRA + LRA)
COPY (
  SELECT SRA, FHSZ, FHSZ_Description, FHSZ_6Class, geometry
  FROM read_parquet(getvariable('data') || '/hazard/fhsz.parquet')
) TO (getvariable('out') || '/hazard.geojson') (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');

-- 5. fire perimeters: Mosquito 2022, River 2021
COPY (
  SELECT fire_name, year, acres, alarm_date, containment_date, geom AS geometry
  FROM ST_Read(getvariable('data') || '/hazard/fire_perimeters.geojson')
) TO (getvariable('out') || '/fire_perimeters.geojson') (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');

-- 6. buildings (Auburn only — for the [F] fill-extrusion exercise)
COPY (
  SELECT id, subtype, class, height, num_floors, geometry
  FROM read_parquet(getvariable('data') || '/overture/buildings_auburn.parquet')
) TO (getvariable('out') || '/buildings_auburn.geojson') (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');

-- 7. land cover (ESA WorldCover via Overture base)
COPY (
  SELECT id, subtype, min_zoom, max_zoom, geometry
  FROM read_parquet(getvariable('data') || '/overture/land_cover.parquet')
) TO (getvariable('out') || '/land_cover.geojson') (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=5');

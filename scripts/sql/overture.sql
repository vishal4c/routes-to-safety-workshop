-- Pull the study area from the public Overture release into local GeoParquet.
-- Every query names its columns explicitly: list-typed columns (road_flags[], speed_limits[], …)
-- must never reach the GeoJSON writer later. Variables come from scripts/make-data.sh.
SET VARIABLE base = getvariable('s3') || '/' || getvariable('rel');
SET VARIABLE outdir = getvariable('outdir');

COPY (
  SELECT id, subtype, class, subclass, names.primary AS name, routes[1].ref AS route_ref, geometry
  FROM read_parquet(getvariable('base') || '/theme=transportation/type=segment/*')
  WHERE subtype = 'road'
    AND bbox.xmin > getvariable('xmin') AND bbox.xmax < getvariable('xmax')
    AND bbox.ymin > getvariable('ymin') AND bbox.ymax < getvariable('ymax')
) TO (getvariable('outdir') || '/segments.parquet') (FORMAT PARQUET, COMPRESSION ZSTD);

COPY (
  SELECT id, geometry
  FROM read_parquet(getvariable('base') || '/theme=transportation/type=connector/*')
  WHERE bbox.xmin > getvariable('xmin') AND bbox.xmax < getvariable('xmax')
    AND bbox.ymin > getvariable('ymin') AND bbox.ymax < getvariable('ymax')
) TO (getvariable('outdir') || '/connectors.parquet') (FORMAT PARQUET, COMPRESSION ZSTD);

COPY (
  SELECT id, names.primary AS name, taxonomy.primary AS category, basic_category, confidence,
         addresses[1].freeform AS address, addresses[1].locality AS locality, geometry
  FROM read_parquet(getvariable('base') || '/theme=places/type=place/*')
  WHERE bbox.xmin > getvariable('xmin') AND bbox.xmax < getvariable('xmax')
    AND bbox.ymin > getvariable('ymin') AND bbox.ymax < getvariable('ymax')
) TO (getvariable('outdir') || '/places.parquet') (FORMAT PARQUET, COMPRESSION ZSTD);

COPY (
  SELECT id, subtype, class, names.primary AS name, is_salt, is_intermittent, geometry
  FROM read_parquet(getvariable('base') || '/theme=base/type=water/*')
  WHERE bbox.xmin > getvariable('xmin') AND bbox.xmax < getvariable('xmax')
    AND bbox.ymin > getvariable('ymin') AND bbox.ymax < getvariable('ymax')
) TO (getvariable('outdir') || '/water.parquet') (FORMAT PARQUET, COMPRESSION ZSTD);

COPY (
  SELECT id, subtype, class, names.primary AS name, population, geometry
  FROM read_parquet(getvariable('base') || '/theme=divisions/type=division/*')
  WHERE subtype IN ('locality', 'neighborhood')
    AND bbox.xmin > getvariable('xmin') AND bbox.xmax < getvariable('xmax')
    AND bbox.ymin > getvariable('ymin') AND bbox.ymax < getvariable('ymax')
) TO (getvariable('outdir') || '/localities.parquet') (FORMAT PARQUET, COMPRESSION ZSTD);

COPY (
  SELECT id, subtype, class, height, num_floors, names.primary AS name, geometry
  FROM read_parquet(getvariable('base') || '/theme=buildings/type=building/*')
  WHERE bbox.xmin > getvariable('a_xmin') AND bbox.xmax < getvariable('a_xmax')
    AND bbox.ymin > getvariable('a_ymin') AND bbox.ymax < getvariable('a_ymax')
) TO (getvariable('outdir') || '/buildings_auburn.parquet') (FORMAT PARQUET, COMPRESSION ZSTD);

COPY (
  SELECT id, subtype, cartography.min_zoom AS min_zoom, cartography.max_zoom AS max_zoom, geometry
  FROM read_parquet(getvariable('base') || '/theme=base/type=land_cover/*')
  WHERE bbox.xmin > getvariable('xmin') AND bbox.xmax < getvariable('xmax')
    AND bbox.ymin > getvariable('ymin') AND bbox.ymax < getvariable('ymax')
) TO (getvariable('outdir') || '/land_cover.parquet') (FORMAT PARQUET, COMPRESSION ZSTD);

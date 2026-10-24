-- CAL FIRE layers: GeoJSON (already WGS84 via f=geojson) → GeoParquet; perimeters clipped to the study bbox.
COPY (
  SELECT SRA, FHSZ, FHSZ_Description, FHSZ_6Class, geom AS geometry
  FROM ST_Read(getvariable('hazdir') || '/fhsz_raw.geojson')
) TO (getvariable('hazdir') || '/fhsz.parquet') (FORMAT PARQUET, COMPRESSION ZSTD);

COPY (
  SELECT FIRE_NAME AS fire_name, YEAR_ AS year, round(GIS_ACRES) AS acres,
         strftime(to_timestamp(ALARM_DATE / 1000), '%Y-%m-%d') AS alarm_date,
         strftime(to_timestamp(CONT_DATE  / 1000), '%Y-%m-%d') AS containment_date,
         geom AS geometry
  FROM ST_Read(getvariable('hazdir') || '/perimeters_raw.geojson')
  WHERE ST_Intersects(geom, ST_MakeEnvelope(getvariable('xmin'), getvariable('ymin'), getvariable('xmax'), getvariable('ymax')))
) TO (getvariable('hazdir') || '/fire_perimeters.geojson') (FORMAT GDAL, DRIVER 'GeoJSON');

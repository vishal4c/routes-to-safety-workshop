#!/usr/bin/env bash
# Hazard layers for the box in versions.env → data/hazard/fhsz.geojson + data/hazard/fire_perimeters.geojson.
# California only (CAL FIRE publishes both as ArcGIS feature services; scripts/fetch_arcgis.py pages through them).
#
#   scripts/fetch-hazard.sh            California: Fire Hazard Severity Zones in the box + the fires named in FIRE_PERIMETERS_WHERE
#   scripts/fetch-hazard.sh --none     anywhere else: writes two EMPTY layers so the rest of the pipeline runs unchanged
#                                      (swap in your own polygons later — README.md Phase 4 → "Swap the hazard")
. "$(dirname "$0")/lib.sh"
HZ="$REPO_ROOT/data/hazard"; mkdir -p "$HZ"
# An "empty" layer holds one feature without geometry (empty_layer, lib.sh): Planetiler 0.10 cannot parse zero features.
empty() { empty_layer "$HZ/$1.geojson"; log "$1.geojson: empty layer (no features)"; }
if [ "${1:-}" = "--none" ]; then empty fhsz; empty fire_perimeters; exit 0; fi
offline_fallback_hint

need python3; need duckdb
BBOX="$BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N"
PRELUDE="LOAD spatial; SET geometry_always_xy = true;"
GEOJSON="(FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6')"

log "Fire Hazard Severity Zones in the box  ←  $CALFIRE_FHSZ_URL"
python3 "$REPO_ROOT/scripts/fetch_arcgis.py" "$CALFIRE_FHSZ_URL" "$HZ/fhsz_raw.geojson" --bbox="$BBOX" --fields SRA,FHSZ,FHSZ_Description,FHSZ_6Class
if [ "$(count_features "$HZ/fhsz_raw.geojson")" = 0 ]; then empty fhsz; else
  duckdb -c "$PRELUDE COPY (SELECT SRA, FHSZ, FHSZ_Description, FHSZ_6Class, geom AS geometry FROM ST_Read('$HZ/fhsz_raw.geojson'))
             TO '$HZ/fhsz.geojson' $GEOJSON;" >/dev/null
  log "fhsz.geojson: $(count_features "$HZ/fhsz.geojson") polygons"
fi
check_count hazard/fhsz "$(count_features "$HZ/fhsz.geojson")"

log "Past fire perimeters  ←  $CALFIRE_PERIMETERS_URL  WHERE $FIRE_PERIMETERS_WHERE (clipped to the box)"
python3 "$REPO_ROOT/scripts/fetch_arcgis.py" "$CALFIRE_PERIMETERS_URL" "$HZ/perimeters_raw.geojson" --bbox="$BBOX" --where "$FIRE_PERIMETERS_WHERE" --fields FIRE_NAME,YEAR_,GIS_ACRES,ALARM_DATE,CONT_DATE
if [ "$(count_features "$HZ/perimeters_raw.geojson")" = 0 ]; then empty fire_perimeters; else
  duckdb -c "$PRELUDE COPY (
      SELECT FIRE_NAME AS fire_name, YEAR_ AS year, round(GIS_ACRES) AS acres,
             strftime(to_timestamp(ALARM_DATE / 1000), '%Y-%m-%d') AS alarm_date,
             strftime(to_timestamp(CONT_DATE  / 1000), '%Y-%m-%d') AS containment_date,
             geom AS geometry
      FROM ST_Read('$HZ/perimeters_raw.geojson')) TO '$HZ/fire_perimeters.geojson' $GEOJSON;" >/dev/null
  log "fire_perimeters.geojson: $(count_features "$HZ/fire_perimeters.geojson") fires"
fi
check_count hazard/fire_perimeters "$(count_features "$HZ/fire_perimeters.geojson")"
rm -f "$HZ/fhsz_raw.geojson" "$HZ/perimeters_raw.geojson"

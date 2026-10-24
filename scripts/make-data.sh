#!/usr/bin/env bash
# Build data/ for the study area in versions.env.
#   scripts/make-data.sh                 run every stage
#   scripts/make-data.sh overture hazard  run only these stages (overture | hazard | osm | exports)
#   scripts/make-data.sh --plan          print what would run (queries, files, estimated sizes) — no network
# Lab 4: edit BBOX_* in versions.env and run with --plan to see the pipeline re-pointed at your town.
. "$(dirname "$0")/lib.sh"

PLAN=0; STAGES=()
for a in "$@"; do case "$a" in --plan) PLAN=1 ;; *) STAGES+=("$a") ;; esac; done
[ ${#STAGES[@]} -eq 0 ] && STAGES=(overture hazard osm exports)
want() { printf '%s\n' "${STAGES[@]}" | grep -qx "$1"; }

D="$REPO_ROOT/data"
BBOX="$BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N"
# rough size model: MB per square degree, measured on the Placer corridor (Overture 2026-09-23.1)
AREA=$(awk -v w="$BBOX_W" -v e="$BBOX_E" -v s="$BBOX_S" -v n="$BBOX_N" 'BEGIN{printf "%.3f", (e-w)*(n-s)}')
est() { awk -v a="$AREA" -v k="$1" 'BEGIN{printf "%.1f MB", a*k}'; }

echo "Study area bbox: $BBOX  (${AREA} sq. degrees)   Overture release: $OVERTURE_RELEASE"
echo

if want overture; then
  echo "== overture → data/overture/*.parquet  (DuckDB reads $OVERTURE_S3/$OVERTURE_RELEASE directly, bbox pushdown)"
  echo "   segments.parquet  (roads: id, subtype, class, subclass, name, route_ref)   ~$(est 42)"
  echo "   connectors.parquet                                                       ~$(est 15)"
  echo "   places.parquet    (id, name, category, basic_category, confidence, address) ~$(est 5)"
  echo "   water.parquet · localities.parquet · land_cover.parquet · buildings_auburn.parquet (Auburn bbox only)"
  if [ $PLAN -eq 0 ]; then
    need duckdb; mkdir -p "$D/overture"
    duck_run "$REPO_ROOT/scripts/sql/overture.sql" s3="$OVERTURE_S3" rel="$OVERTURE_RELEASE" outdir="$D/overture" \
      $(bbox_args) a_xmin="$AUBURN_W" a_ymin="$AUBURN_S" a_xmax="$AUBURN_E" a_ymax="$AUBURN_N"
    ls -lh "$D/overture"/*.parquet >&2
  fi; echo
fi

if want hazard; then
  echo "== hazard → data/hazard/   (CAL FIRE ArcGIS REST, f=geojson so the server reprojects EPSG:2226 ft → WGS84)"
  echo "   fhsz.parquet            FHSZ 2024/25 SRA+LRA polygons intersecting the bbox   ~1–5 MB"
  echo "   fire_perimeters.geojson Mosquito 2022 + River 2021 (clipped to bbox)           <1 MB"
  if [ $PLAN -eq 0 ]; then
    need duckdb; need python3; mkdir -p "$D/hazard"
    python3 "$REPO_ROOT/scripts/fetch_arcgis.py" "$CALFIRE_FHSZ_URL" "$D/hazard/fhsz_raw.geojson" \
      --bbox="$BBOX" --fields SRA,FHSZ,FHSZ_Description,FHSZ_6Class
    python3 "$REPO_ROOT/scripts/fetch_arcgis.py" "$CALFIRE_PERIMETERS_URL" "$D/hazard/perimeters_raw.geojson" \
      --where "(FIRE_NAME='MOSQUITO' AND YEAR_=2022) OR (FIRE_NAME='RIVER' AND YEAR_=2021)" \
      --fields FIRE_NAME,YEAR_,GIS_ACRES,ALARM_DATE,CONT_DATE
    duck_run "$REPO_ROOT/scripts/sql/hazard.sql" hazdir="$D/hazard" $(bbox_args)
    rm -f "$D/hazard/fhsz_raw.geojson" "$D/hazard/perimeters_raw.geojson"
    ls -lh "$D/hazard" >&2
  fi; echo
fi

if want osm; then
  echo "== osm → data/osm/study-area.osm.pbf + colfax.osm.pbf  (osmium extract from $OSM_EXTRACT_URL, ~1 GB download)"
  if [ $PLAN -eq 0 ]; then
    need osmium; mkdir -p "$D/osm"
    SRC="${OSM_SOURCE_PBF:-$D/osm/norcal-latest.osm.pbf}"
    if [ ! -f "$SRC" ]; then log "downloading $OSM_EXTRACT_URL"; curl -L --fail -o "$SRC" "$OSM_EXTRACT_URL"; fi
    osmium extract --overwrite -b "$BBOX" -s smart -o "$D/osm/study-area.osm.pbf" "$SRC"
    osmium extract --overwrite -b "$COLFAX_W,$COLFAX_S,$COLFAX_E,$COLFAX_N" -s smart -o "$D/osm/colfax.osm.pbf" "$D/osm/study-area.osm.pbf"
    osmium fileinfo -e "$D/osm/study-area.osm.pbf" | grep -E "Number of (nodes|ways)|Timestamp" >&2
    ls -lh "$D/osm"/*.pbf >&2
  fi; echo
fi

if want exports; then
  echo "== exports → data/prebuilt/out/*.geojson  (the fallback copy of what attendees produce in Lab 1c; same SQL as 00-data/03-export.sql)"
  if [ $PLAN -eq 0 ]; then
    need duckdb; mkdir -p "$D/prebuilt/out"
    duck_run "$REPO_ROOT/00-data/03-export.sql" out="$D/prebuilt/out" data="$D"
    ls -lh "$D/prebuilt/out" >&2
  fi; echo
fi
[ $PLAN -eq 1 ] && echo "(plan only — nothing was downloaded or written)"

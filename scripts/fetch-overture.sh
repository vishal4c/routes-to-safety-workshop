#!/usr/bin/env bash
# Pull the Overture Maps themes for the box in versions.env straight from the public release into GeoJSON.
# This is how data/overture/*.geojson was made, and Phase 4 step 2 for your own community.
#
#   scripts/fetch-overture.sh                 all six files
#   scripts/fetch-overture.sh roads towns     only these: roads | water | towns | land_cover | buildings | places
#
# How it works (https://docs.overturemaps.org/getting-data/): Overture publishes each theme as Parquet files on S3,
# one row per feature with a bbox column. DuckDB reads those files in place (httpfs), uses the bbox to skip every
# row group outside your box, and writes what is left as GeoJSON (spatial extension, GDAL writer). No account, no
# download tool. Times for two boxes are in README.md (Phase 1 → "How the data was fetched").
. "$(dirname "$0")/lib.sh"
need duckdb
OUT="${OVERTURE_OUT:-$REPO_ROOT/data/overture}"; mkdir -p "$OUT"
BASE="$OVERTURE_S3/$OVERTURE_RELEASE"
IN_BOX="bbox.xmin > $BBOX_W AND bbox.xmax < $BBOX_E AND bbox.ymin > $BBOX_S AND bbox.ymax < $BBOX_N"
IN_BUILDINGS_BOX="bbox.xmin > $BUILDINGS_W AND bbox.xmax < $BUILDINGS_E AND bbox.ymin > $BUILDINGS_S AND bbox.ymax < $BUILDINGS_N"
DRIVABLE="('motorway','trunk','primary','secondary','tertiary','residential','unclassified','living_street','motorway_link','trunk_link','primary_link','secondary_link','tertiary_link')"
PRELUDE="INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs; SET s3_region='us-west-2'; SET geometry_always_xy = true;"
GEOJSON="(FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6')"

# fetch <file> <theme>/<type> "<columns>" "<where>"  — one COPY statement, timed
fetch() {
  local name="$1" theme="${2%%/*}" type="${2##*/}" cols="$3" where="$4" t0 n
  t0=$(date +%s)
  log "$name  ←  theme=$theme/type=$type  ($where)"
  duckdb -c "$PRELUDE
COPY (SELECT $cols FROM read_parquet('$BASE/theme=$theme/type=$type/*') WHERE $where)
TO '$OUT/$name.geojson' $GEOJSON;"
  n=$(duckdb -noheader -csv -c "LOAD spatial; SELECT count(*) FROM ST_Read('$OUT/$name.geojson')")
  log "$name.geojson: $n features, $(du -h "$OUT/$name.geojson" | cut -f1), $(( $(date +%s) - t0 )) s"
}

THEMES=("$@"); [ ${#THEMES[@]} -eq 0 ] && THEMES=(roads water towns land_cover buildings places)
echo "Overture $OVERTURE_RELEASE · box $BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N → $OUT" >&2
for t in "${THEMES[@]}"; do
  case "$t" in
    roads)      fetch roads      transportation/segment "id, class, subclass, names.primary AS name, routes[1].ref AS route_ref, geometry" \
                                 "subtype = 'road' AND class IN $DRIVABLE AND $IN_BOX" ;;
    water)      fetch water      base/water             "id, subtype, class, names.primary AS name, geometry" \
                                 "ST_GeometryType(geometry) IN ('POLYGON', 'MULTIPOLYGON') AND $IN_BOX" ;;
    towns)      fetch towns      divisions/division     "id, class, names.primary AS name, coalesce(population, 0) AS population, geometry" \
                                 "subtype = 'locality' AND names.primary IS NOT NULL AND $IN_BOX" ;;
    land_cover) fetch land_cover base/land_cover        "id, subtype, cartography.min_zoom AS min_zoom, cartography.max_zoom AS max_zoom, geometry" \
                                 "$IN_BOX" ;;
    buildings)  fetch buildings  buildings/building     "id, subtype, class, height, num_floors, geometry" \
                                 "$IN_BUILDINGS_BOX" ;;
    places)     fetch places     places/place           "id, names.primary AS name, taxonomy.primary AS category, basic_category, confidence, addresses[1].freeform AS address, addresses[1].locality AS locality, geometry" \
                                 "$IN_BOX" ;;
    *) die "unknown theme '$t' (roads | water | towns | land_cover | buildings | places)" ;;
  esac
done
ls -lh "$OUT"/*.geojson >&2

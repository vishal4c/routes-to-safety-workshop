#!/usr/bin/env bash
# Phase 4 step 4 — keep the candidates that really are shelters: copy those ids from out/shelter-candidates.geojson
# (written by 00-data/03-export.sql) into data/shelters.geojson. Nothing is written unless every id is found.
#
#   scripts/pick-shelters.sh <id> <id> ...      ids from the id column of out/shelter-candidates.csv
. "$(dirname "$0")/lib.sh"
need duckdb
SRC="$REPO_ROOT/out/shelter-candidates.geojson"; DST="$REPO_ROOT/data/shelters.geojson"
[ -f "$SRC" ] || die "out/shelter-candidates.geojson missing — run: duckdb -c \".read 00-data/03-export.sql\""
[ $# -gt 0 ] || die "no ids — usage: scripts/pick-shelters.sh <id> <id> ... (the id column of out/shelter-candidates.csv)"
for id in "$@"; do
  case "$id" in id-[0-9]*|actual-id*|real-id*|'<'*) die "'$id' is a placeholder — use real ids from out/shelter-candidates.csv" ;; esac
  [[ "$id" =~ ^[A-Za-z0-9._:-]+$ ]] || die "'$id' is not an id (letters, digits and - _ . : only)"
done
LIST=$(printf "'%s'," "$@"); LIST="${LIST%,}"
missing=$(duckdb -noheader -csv -c "LOAD spatial; SELECT coalesce(string_agg(i, ' '), '') FROM (SELECT unnest([$LIST]) AS i) WHERE i NOT IN (SELECT id FROM ST_Read('$SRC'))")
[ -z "$missing" ] || die "not in out/shelter-candidates.geojson: $missing — copy ids from the id column of out/shelter-candidates.csv"
rm -f "$DST"
duckdb -c "LOAD spatial; SET geometry_always_xy = true;
  COPY (SELECT * FROM ST_Read('$SRC') WHERE id IN ($LIST)) TO '$DST' (FORMAT GDAL, DRIVER 'GeoJSON')" >/dev/null
n=$(duckdb -noheader -csv -c "LOAD spatial; SELECT count(*) FROM ST_Read('$DST')")
out=$(duckdb -noheader -csv -c "LOAD spatial; SET geometry_always_xy = true; SELECT coalesce(string_agg(name, ', '), '') FROM ST_Read('$DST')
  WHERE NOT (ST_X(geom) BETWEEN $BBOX_W AND $BBOX_E AND ST_Y(geom) BETWEEN $BBOX_S AND $BBOX_N)")
log "data/shelters.geojson: $n shelters (status candidate until a county source confirms one)"
[ -z "$out" ] || log "warning: outside the box in versions.env: $out"

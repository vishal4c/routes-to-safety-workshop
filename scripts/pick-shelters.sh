#!/usr/bin/env bash
# Phase 4 step 4 — keep the real shelters out of the Phase 1c candidates:
#     scripts/pick-shelters.sh id-1 id-2 id-3 …          → data/shelters.geojson
# ids are the id column of out/shelter-candidates.geojson (the name as a slug: "Placer High School" → placer-high-school);
# the whole list: out/shelter-candidates.csv (README Phase 4 step 4). It is the Phase 1c export in reverse — one DuckDB
#     COPY (SELECT … FROM ST_Read('out/shelter-candidates.geojson') WHERE id IN (…)) TO 'data/shelters.geojson' (FORMAT GDAL, DRIVER 'GeoJSON')
# plus two checks: every id must exist (typos and Placer ids are reported), and a pick that matches nothing becomes
# one placeholder shelter at the south-west corner of the box (shelter_placeholder, lib.sh) so steps 6–8 still run.
. "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"
need duckdb
SRC="${CANDIDATES:-out/shelter-candidates.geojson}"; OUT="${SHELTERS_OUT:-data/shelters.geojson}"
[ -f "$SRC" ] || die "$SRC missing — run: duckdb -c \".read 00-data/03-export.sql\""
[ $# -gt 0 ] || die "usage: scripts/pick-shelters.sh id-1 id-2 …   (the ids: out/shelter-candidates.csv, or  duckdb -c \"LOAD spatial; SELECT id, name, type, town FROM ST_Read('$SRC') ORDER BY type, name\")"
list=""; for id in "$@"; do list="$list'${id//\'/\'\'}',"; done; list="${list%,}"     # 'a','b','c' — quotes in an id are doubled
missing="$(duckdb -csv -noheader -c "LOAD spatial; SELECT id FROM (SELECT unnest([$list]) AS id) WHERE id NOT IN (SELECT id FROM ST_Read('$SRC'))")"
[ -z "$missing" ] || log "not in $SRC (typo? a Placer id?): $(echo "$missing" | tr '\n' ' ')"
mkdir -p "$(dirname "$OUT")"
duckdb -c "LOAD spatial; SET geometry_always_xy = true;
  COPY (SELECT id, name, status, type, town, source, geom AS geometry FROM ST_Read('$SRC') WHERE id IN ($list) ORDER BY type, name)
  TO '$OUT' (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=6');" >/dev/null
n="$(count_features "$OUT")"
if [ "$n" = 0 ]; then shelter_placeholder "$OUT"; exit 0; fi
log "$OUT: $n shelters (all 'candidate' until a county source confirms one)"
duckdb -c "LOAD spatial; SELECT id, name, type, town FROM ST_Read('$OUT') ORDER BY type, name"

#!/usr/bin/env bash
# Phase 2a — build out/evac.pmtiles from the GeoJSON you exported in Phase 1c.
# Usage (from anywhere):  01-tiles/build.sh            → uses out/*.geojson
#                          01-tiles/build.sh --prebuilt → uses data/prebuilt/out/*.geojson (fallback)
# The actual command is the single line on the phase card; this script only adds the fallback and a timer.
. "$(dirname "$0")/../scripts/lib.sh"
cd "$REPO_ROOT"
need java
JAR="01-tiles/planetiler.jar"
[ -f "$JAR" ] || { log "downloading Planetiler v$PLANETILER_VERSION"; curl -L --fail -o "$JAR" "https://github.com/onthegomap/planetiler/releases/download/v$PLANETILER_VERSION/planetiler.jar"; }
if [ "${1:-}" = "--prebuilt" ]; then mkdir -p out; cp data/prebuilt/out/*.geojson out/; fi
[ -f out/roads.geojson ] || die "out/roads.geojson missing — run Phase 1c first, or pass --prebuilt"
START=$(date +%s)
java -Xmx2g -jar "$JAR" generate-custom --schema=01-tiles/evac.yml --output=out/evac.pmtiles --force \
  --bounds="$BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N" --minzoom=4 --maxzoom=14 "${@:2}"
log "built out/evac.pmtiles in $(( $(date +%s) - START ))s ($(du -h out/evac.pmtiles | cut -f1))"

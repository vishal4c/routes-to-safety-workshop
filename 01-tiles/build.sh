#!/usr/bin/env bash
# Phase 2a — build out/evac.pmtiles from the GeoJSON in data/ (Overture themes, hazard, shelters).
# Usage (from anywhere):  01-tiles/build.sh [extra planetiler args]
# The real work is one Java command (printed below); this script adds the box from versions.env, the file checks and a timer.
. "$(dirname "$0")/../scripts/lib.sh"
cd "$REPO_ROOT"
need java
JAR="01-tiles/planetiler.jar"
[ -f "$JAR" ] || { log "downloading Planetiler v$PLANETILER_VERSION"; curl -L --fail -o "$JAR" "https://github.com/onthegomap/planetiler/releases/download/v$PLANETILER_VERSION/planetiler.jar"; }
for f in data/overture/roads.geojson data/overture/water.geojson data/overture/towns.geojson data/overture/land_cover.geojson data/overture/buildings.geojson; do
  [ -f "$f" ] || die "$f missing — run scripts/fetch-overture.sh (or git checkout $f)"
done
for f in data/hazard/fhsz.geojson data/hazard/fire_perimeters.geojson; do
  [ -f "$f" ] || die "$f missing — run scripts/fetch-hazard.sh (California) or scripts/fetch-hazard.sh --none (anywhere else)"
done
[ -f data/shelters.geojson ] || die "data/shelters.geojson missing"
mkdir -p out
START=$(date +%s)
log "java -Xmx2g -jar $JAR generate-custom --schema=01-tiles/evac.yml --output=out/evac.pmtiles --force --bounds=$BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N --minzoom=4 --maxzoom=14 $*"
java -Xmx2g -jar "$JAR" generate-custom --schema=01-tiles/evac.yml --output=out/evac.pmtiles --force \
  --bounds="$BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N" --minzoom=4 --maxzoom=14 "$@"
log "built out/evac.pmtiles in $(( $(date +%s) - START ))s ($(du -h out/evac.pmtiles | cut -f1))"

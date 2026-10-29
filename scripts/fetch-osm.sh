#!/usr/bin/env bash
# OpenStreetMap roads for the routing graph: download the Geofabrik region in versions.env (OSM_EXTRACT_URL) once,
# cut the box out of it with osmium → data/osm/study-area.osm.pbf. Then scripts/build-osrm.sh turns that into the graph.
#
#   scripts/fetch-osm.sh                       download (if not already here) + clip
#   OSM_SOURCE_PBF=/path/region.osm.pbf scripts/fetch-osm.sh      clip a file you already have
# The region download is the big one (a US state is 100 MB – 1 GB); the clipped file is a few MB to a few tens of MB.
. "$(dirname "$0")/lib.sh"
need osmium; need curl
D="$REPO_ROOT/data/osm"; mkdir -p "$D"
SRC="${OSM_SOURCE_PBF:-$D/$(basename "$OSM_EXTRACT_URL")}"
BBOX="$BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N"
if [ ! -f "$SRC" ]; then
  log "downloading $OSM_EXTRACT_URL → $SRC"
  curl -L --fail --retry 3 -C - -o "$SRC" "$OSM_EXTRACT_URL"
fi
log "osmium extract -b $BBOX  (-s smart keeps every way that touches the box complete)"
osmium extract --overwrite -b "$BBOX" -s smart -o "$D/study-area.osm.pbf" "$SRC"
osmium fileinfo -e "$D/study-area.osm.pbf" | grep -E "Number of (nodes|ways)|Last" >&2
log "done → data/osm/study-area.osm.pbf ($(du -h "$D/study-area.osm.pbf" | cut -f1)) · next: scripts/build-osrm.sh"

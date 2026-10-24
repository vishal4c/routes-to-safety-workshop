#!/usr/bin/env bash
# Build an OSRM routing graph (MLD) from an .osm.pbf, inside the pinned OSRM container.
#   scripts/build-osrm.sh                                    → data/osrm/study-area.osrm.*   (what the workshop ships)
#   scripts/build-osrm.sh data/osm/colfax.osm.pbf out/osrm   → Phase 3c Stretch B: tiny graph
# Works with docker, finch, podman or nerdctl (auto-detected; override with CONTAINER_CLI=finch).
. "$(dirname "$0")/lib.sh"

PBF="${1:-$REPO_ROOT/data/osm/study-area.osm.pbf}"
OUT="${2:-$REPO_ROOT/data/osrm}"
[ -f "$PBF" ] || die "no such file: $PBF (run scripts/make-data.sh osm, or scripts/get-bundle.sh)"
CLI="$(detect_container_cli)" || die "no container CLI found (docker / finch / podman). Routing needs one — see setup/README.md"
mkdir -p "$OUT"
NAME="$(basename "${PBF%.osm.pbf}")"
cp -f "$PBF" "$OUT/$NAME.osm.pbf"

# Everything happens in /data inside the container, bind-mounted to $OUT.
run() { "$CLI" run --rm -t -v "$OUT:/data" "$OSRM_IMAGE" "$@"; }
log "osrm-extract  (car profile) ← $NAME.osm.pbf  [$CLI, $OSRM_IMAGE]"
run osrm-extract   -p /opt/car.lua "/data/$NAME.osm.pbf"
log "osrm-partition"
run osrm-partition "/data/$NAME.osrm"
log "osrm-customize"
run osrm-customize "/data/$NAME.osrm"
rm -f "$OUT/$NAME.osm.pbf"
log "done → $OUT/$NAME.osrm.*  ($(du -sh "$OUT" | cut -f1))"
echo
echo "Serve it:   $CLI run --rm -p 5000:5000 -v \"$OUT:/data\" $OSRM_IMAGE osrm-routed --algorithm mld --max-table-size 500 /data/$NAME.osrm"
echo "Test it:    curl \"http://localhost:5000/nearest/v1/driving/-121.08,38.90\""

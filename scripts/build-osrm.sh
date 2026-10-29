#!/usr/bin/env bash
# Build an OSRM routing graph (MLD) from an .osm.pbf, inside the pinned OSRM container.
#   scripts/build-osrm.sh                                    → data/osrm/study-area.osrm.*   (what the workshop ships)
#   scripts/build-osrm.sh data/osm/colfax.osm.pbf out/osrm   → Phase 2b (optional): tiny graph, about a minute
# Needs a container CLI where you run it: docker, finch, podman or nerdctl (auto-detected; override with
# CONTAINER_CLI=finch). Laptop terminal (option B) — or the Codespaces terminal, which can drive the Docker of
# its host VM (docker-outside-of-docker, see .devcontainer/devcontainer.json; the repo path is the same on both
# sides, so the bind mount works). Inside `docker compose exec workshop bash` on a laptop there is no Docker:
# the script explains what it would do and exits 0.
. "$(dirname "$0")/lib.sh"

PBF="${1:-$REPO_ROOT/data/osm/study-area.osm.pbf}"
OUT="${2:-$REPO_ROOT/data/osrm}"
NAME="$(basename "${PBF%.osm.pbf}")"
[ -f "$PBF" ] || die "no such file: $PBF (run scripts/make-data.sh osm, or scripts/get-bundle.sh)"
if ! CLI="$(detect_container_cli)"; then
  cat <<MSG
build-osrm.sh: no docker / finch / podman here, so the graph cannot be built from this shell.
${WORKSHOP_CONTAINER:+
  You are inside the tool container (docker compose exec workshop). It has no Docker in it, on purpose.
  Nothing is missing: the study-area graph from the bundle is already running —  curl "\$OSRM_URL/nearest/v1/driving/-121.08,38.90"
  To build a graph yourself, run this same command in a laptop terminal in the clone folder (option B), or in a Codespaces terminal.
}
  What this script runs, in the OSRM container ($OSRM_IMAGE), with $OUT mounted at /data:
    osrm-extract   -p /opt/car.lua /data/$NAME.osm.pbf     # roads out of the .osm.pbf, speeds from the car profile → $NAME.osrm.*
    osrm-partition /data/$NAME.osrm                        # split the graph into cells
    osrm-customize /data/$NAME.osrm                        # precompute cell shortcuts → /table and /route answer in milliseconds
  Then osrm-routed serves /data/$NAME.osrm (the osrm service in docker-compose.yml does this for data/osrm/study-area.osrm).
MSG
  exit 0
fi
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"    # docker -v needs an absolute host path (out/osrm alone is read as a volume name)
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
if [ -n "${WORKSHOP_CONTAINER:-}" ]; then   # Codespaces: the container must join the compose network to be reachable from this shell
  NET="$("$CLI" network ls --format '{{.Name}}' | grep -m1 routes-to-safety || echo bridge)"
  echo "Serve it:   $CLI run -d --rm --name osrm-$NAME --network $NET -v \"$OUT:/data\" $OSRM_IMAGE osrm-routed --algorithm mld --max-table-size 500 /data/$NAME.osrm"
  echo "Test it:    curl \"http://osrm-$NAME:5000/nearest/v1/driving/-120.95,39.10\"      # Colfax is inside the clip; stop with: $CLI rm -f osrm-$NAME"
else
  echo "Serve it:   $CLI run --rm -p 5000:5000 -v \"$OUT:/data\" $OSRM_IMAGE osrm-routed --algorithm mld --max-table-size 500 /data/$NAME.osrm"
  echo "Test it:    curl \"http://localhost:5000/nearest/v1/driving/-120.95,39.10\"        # Colfax is inside the clip"
fi

# shellcheck shell=bash
# Shared helpers for scripts/*.sh — source this, do not run it.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../versions.env
set -a; . "$REPO_ROOT/versions.env"; set +a

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found — see README.md, Phase 0"; }

# Container CLI detection: docker → finch → podman → nerdctl. Override with CONTAINER_CLI=... .
detect_container_cli() {
  if [ -n "${CONTAINER_CLI:-}" ]; then echo "$CONTAINER_CLI"; return; fi
  for c in docker finch podman nerdctl; do
    if command -v "$c" >/dev/null 2>&1; then echo "$c"; return; fi
  done
  return 1
}

# Run a DuckDB script file with a set of variables: duck_run file.sql VAR=value ...
# Variables are exposed as getvariable('VAR') inside the SQL.
duck_run() {
  local sql="$1"; shift
  local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/rts.XXXXXX")"
  {
    echo "INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;"
    echo "SET s3_region='us-west-2'; SET geometry_always_xy = true;"
    for kv in "$@"; do
      local k="${kv%%=*}" v="${kv#*=}"
      if [[ "$v" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then echo "SET VARIABLE $k = $v;"      # number
      else echo "SET VARIABLE $k = '$v';"; fi                                          # string
    done
    cat "$sql"
  } > "$tmp"
  duckdb -c ".read $tmp"
  rm -f "$tmp"
}

# Phase 1 · Fetch — the counts README Phase 1 expects for the Placer box. Another box (Phase 4) has none.
PLACER_BBOX="-121.40,38.72,-120.52,39.20"
is_placer_box() { [ "$BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N" = "$PLACER_BBOX" ]; }
expected_count() {
  is_placer_box || return 0
  case "$1" in
    overture/roads) echo 36294 ;;      overture/water) echo 1920 ;;          overture/towns) echo 121 ;;
    overture/land_cover) echo 2564 ;;  overture/buildings) echo 12606 ;;     overture/places) echo 27096 ;;
    hazard/fhsz) echo 355 ;;           hazard/fire_perimeters) echo 2 ;;
  esac
}
check_count() {   # check_count overture/roads 36294 — a mismatch fails the script
  local want; want="$(expected_count "$1")"
  [ -z "$want" ] || [ "$2" = "$want" ] || die "$1.geojson: $2 features, expected $want (download cut short, or the source changed)"
}
# On the Placer box, any failure (or Ctrl-C) ends with exactly one line pointing at the committed copies.
offline_fallback_hint() {
  is_placer_box || return 0
  trap 'rc=$?; [ "$rc" -eq 0 ] || printf "\033[1;33m→ offline fallback: scripts/stage-data.sh\033[0m\n" >&2' EXIT
}
count_features() { python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['features']))" "$1"; }

bbox_args() { echo "xmin=$BBOX_W ymin=$BBOX_S xmax=$BBOX_E ymax=$BBOX_N"; }

# Planetiler 0.10 cannot read a FeatureCollection with zero features (NullPointerException in <layer>_read).
# An "empty" layer is one feature with no geometry: every reader accepts it, and Planetiler writes no tiles for it.
empty_layer() { printf '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{},"geometry":null}]}\n' > "$1"; }

# No shelter picked for this box (Phase 4 step 4 matched nothing) → the schools in the box stand in: up to 10 high
# schools, or any K-12 campus if there is no high school (scripts/shelters-fallback.sql, all status = candidate). No
# school either → one placeholder at the box's south-west corner (shelter_placeholder). Either way tiles, reach bands
# and the pages still build. Replace them with real shelters: scripts/pick-shelters.sh <id> …
shelter_fallback() {   # shelter_fallback  → data/shelters.geojson (run from anywhere)
  local n=0
  if command -v duckdb >/dev/null 2>&1 && [ -f "$REPO_ROOT/data/overture/places.geojson" ]; then
    (cd "$REPO_ROOT" && duckdb -c ".read scripts/shelters-fallback.sql" >/dev/null) && n="$(count_features "$REPO_ROOT/data/shelters.geojson")"
  fi
  if [ "$n" -gt 0 ]; then
    log "no shelters picked → data/shelters.geojson is $n school(s) from Overture places, all 'candidate' (scripts/shelters-fallback.sql); replace them: scripts/pick-shelters.sh <id> …"
  else
    shelter_placeholder "$REPO_ROOT/data/shelters.geojson"
  fi
}
# Last resort: no school in the box either → one placeholder shelter at the box's south-west corner (BBOX_W, BBOX_S).
shelter_placeholder() {
  printf '{"type":"FeatureCollection","name":"shelters","features":[{"type":"Feature","properties":{"id":"placeholder","name":"Placeholder shelter (no shelter picked)","status":"candidate","type":"placeholder","town":"","source":"placeholder at the south-west corner of the box in versions.env - no shelter picked yet; replace with real shelters (scripts/pick-shelters.sh)"},"geometry":{"type":"Point","coordinates":[%s,%s]}}]}\n' "$BBOX_W" "$BBOX_S" > "$1"
  log "no shelters, no school in the box → $1 is one placeholder at the box's south-west corner ($BBOX_W, $BBOX_S); replace it with real ones: scripts/pick-shelters.sh <id> …"
}

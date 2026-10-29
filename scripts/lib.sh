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

bbox_args() { echo "xmin=$BBOX_W ymin=$BBOX_S xmax=$BBOX_E ymax=$BBOX_N"; }

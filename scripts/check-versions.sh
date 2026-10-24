#!/usr/bin/env bash
# Fails (exit 1) if any pinned value in versions.env is out of sync with the files that repeat it.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
set -a; . ./versions.env; set +a
fail=0
# expect FILE_GLOB... -- PATTERN DESCRIPTION : every existing file must contain PATTERN (fixed string)
expect() {
  local pat="$1" desc="$2"; shift 2
  local f found=0
  for f in "$@"; do
    [ -f "$f" ] || continue
    found=1
    grep -qF -- "$pat" "$f" || { echo "DRIFT  $f: expected $desc → '$pat'"; fail=1; }
  done
  [ $found = 1 ] || echo "skip   (no files for $desc)"
}
# forbid: stale value must NOT appear
forbid() {
  local pat="$1" desc="$2"; shift 2
  local f
  for f in "$@"; do
    [ -f "$f" ] || continue
    grep -qF -- "$pat" "$f" && { echo "DRIFT  $f: stale $desc → '$pat'"; fail=1; }
  done
}
WEB=$(find 02-web demo slides -type f \( -name '*.html' -o -name '*.md' -o -name '*.js' -o -name '*.mjs' \) -not -path '*/node_modules/*' -not -path 'slides/out/*' 2>/dev/null)

expect "\${OSRM_IMAGE:-$OSRM_IMAGE}"   "OSRM_IMAGE default"   docker-compose.yml
expect "\${CADDY_IMAGE:-$CADDY_IMAGE}" "CADDY_IMAGE default"  docker-compose.yml
for v in DUCKDB_VERSION JAVA_VERSION NODE_VERSION PMTILES_VERSION PLANETILER_VERSION OSMIUM_VERSION; do
  expect "ARG $v=${!v}" "$v ARG default" .devcontainer/Dockerfile
  expect "$v: \${$v:-${!v}}" "$v build-arg default" .devcontainer/docker-compose.yml
done
# CDN URLs: any maplibre-gl@X / pmtiles@X in web files must be the pinned one
for f in $WEB; do
  for m in $(grep -oE 'maplibre-gl@[0-9][0-9A-Za-z.\-]*' "$f" | sort -u); do
    [ "$m" = "maplibre-gl@$MAPLIBRE_VERSION" ] || { echo "DRIFT  $f: $m (pinned $MAPLIBRE_VERSION)"; fail=1; }
  done
  for m in $(grep -oE 'pmtiles@[0-9][0-9A-Za-z.\-]*' "$f" | sort -u); do
    [ "$m" = "pmtiles@$PMTILES_JS_VERSION" ] || { echo "DRIFT  $f: $m (pinned $PMTILES_JS_VERSION)"; fail=1; }
  done
done
# Marp pin in workflow / README
for f in .github/workflows/pages.yml README.md setup/README.md; do
  [ -f "$f" ] || continue
  for m in $(grep -oE 'marp-cli@[0-9][0-9A-Za-z.\-]*' "$f" | sort -u); do
    [ "$m" = "marp-cli@$MARP_VERSION" ] || { echo "DRIFT  $f: $m (pinned $MARP_VERSION)"; fail=1; }
  done
done
# README mentions of the headline pins
for f in README.md setup/README.md; do
  [ -f "$f" ] || continue
  while IFS= read -r m; do   # read line-wise: the match may contain a space ("go-pmtiles v1.31.2")
    [ -n "$m" ] || continue
    [[ "$m" == *"$PMTILES_VERSION" ]] || { echo "DRIFT  $f: '$m' (pinned $PMTILES_VERSION)"; fail=1; }
  done < <(grep -oE 'go-pmtiles[ _-]v?[0-9]+\.[0-9]+\.[0-9]+' "$f" | sort -u)
  for m in $(grep -oE 'osrm-backend:v[0-9.]+(-debian)?' "$f" | sort -u); do
    [ "ghcr.io/project-osrm/$m" = "$OSRM_IMAGE" ] || { echo "DRIFT  $f: $m (pinned $OSRM_IMAGE)"; fail=1; }
  done
done
if [ $fail = 0 ]; then echo "check-versions: OK (all pins match versions.env)"; else echo; echo "check-versions: FAILED — fix the files above or update versions.env"; exit 1; fi

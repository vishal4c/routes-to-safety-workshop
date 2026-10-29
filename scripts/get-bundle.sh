#!/usr/bin/env bash
# Download data-bundle.zip (OSM extracts, OSRM graph, prebuilt evac.pmtiles, planetiler.jar),
# verify CHECKSUMS.sha256 and unpack. Idempotent: re-running with everything in place and matching does nothing.
# Offline / USB:  BUNDLE_ZIP=/path/to/data-bundle.zip scripts/get-bundle.sh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
BUNDLE_TAG="${BUNDLE_TAG:-data-v2}"
URL="https://github.com/vishal4c/routes-to-safety-workshop/releases/download/${BUNDLE_TAG}/data-bundle.zip"
mkdir -p dist data

# Already here AND matching the checksums committed in data/CHECKSUMS.sha256 (so an old bundle is replaced, not kept)
have_all() {
  [ -f data/prebuilt/evac.pmtiles ] && [ -f data/osrm/study-area.osrm.mldgr ] && [ -f 01-tiles/planetiler.jar ] && [ -d data/osm ] || return 1
  if command -v sha256sum >/dev/null; then sha256sum -c data/CHECKSUMS.sha256 --quiet >/dev/null 2>&1
  else shasum -a 256 -c data/CHECKSUMS.sha256 --quiet >/dev/null 2>&1; fi
}
if have_all && [ "${FORCE:-0}" != 1 ]; then
  echo "Bundle already in place and matches data/CHECKSUMS.sha256 (FORCE=1 to re-download)."
else
  ZIP="${BUNDLE_ZIP:-dist/data-bundle.zip}"
  if [ ! -f "$ZIP" ]; then
    echo "Downloading $URL"
    if command -v curl >/dev/null; then curl -fL --retry 3 -C - -o "$ZIP" "$URL"
    elif command -v wget >/dev/null; then wget -c -O "$ZIP" "$URL"
    else echo "error: need curl or wget" >&2; exit 1; fi
  fi
  STAGE="$(mktemp -d "${TMPDIR:-/tmp}/rts-bundle.XXXXXX")"
  trap 'rm -rf "$STAGE"' EXIT
  unzip -q -o "$ZIP" -d "$STAGE"
  [ -f "$STAGE/CHECKSUMS.sha256" ] || { echo "error: CHECKSUMS.sha256 missing in bundle" >&2; exit 1; }
  echo "Verifying checksums..."
  if command -v sha256sum >/dev/null; then (cd "$STAGE" && sha256sum -c CHECKSUMS.sha256 --quiet)
  else (cd "$STAGE" && shasum -a 256 -c CHECKSUMS.sha256 --quiet); fi
  echo "Checksums OK. Installing..."
  mkdir -p data/prebuilt 01-tiles
  for d in osm osrm; do
    [ -d "$STAGE/data/$d" ] && { mkdir -p "data/$d"; cp -R "$STAGE/data/$d/." "data/$d/"; }
  done
  [ -f "$STAGE/data/prebuilt/evac.pmtiles" ] && cp "$STAGE/data/prebuilt/evac.pmtiles" data/prebuilt/
  [ -f "$STAGE/01-tiles/planetiler.jar" ] && cp "$STAGE/01-tiles/planetiler.jar" 01-tiles/
  cp "$STAGE/CHECKSUMS.sha256" data/CHECKSUMS.sha256
fi
echo "Sizes:"
du -sh data/osm data/osrm data/prebuilt/evac.pmtiles 01-tiles/planetiler.jar 2>/dev/null || true

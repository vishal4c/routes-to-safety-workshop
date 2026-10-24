#!/usr/bin/env bash
# Instructor: build dist/data-bundle.zip (the Release asset / USB payload).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
for p in data/osm data/osrm data/prebuilt/evac.pmtiles 01-tiles/planetiler.jar; do
  [ -e "$p" ] || { echo "error: missing $p" >&2; exit 1; }
done
mkdir -p dist
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/rts-make.XXXXXX")"; trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/data/prebuilt" "$STAGE/01-tiles"
cp -R data/osm data/osrm "$STAGE/data/"
cp data/prebuilt/evac.pmtiles "$STAGE/data/prebuilt/"
cp 01-tiles/planetiler.jar "$STAGE/01-tiles/"
( cd "$STAGE"
  if command -v sha256sum >/dev/null; then find data 01-tiles -type f | sort | xargs sha256sum > CHECKSUMS.sha256
  else find data 01-tiles -type f | sort | xargs shasum -a 256 > CHECKSUMS.sha256; fi
  rm -f "$REPO_ROOT/dist/data-bundle.zip"
  zip -qr "$REPO_ROOT/dist/data-bundle.zip" data 01-tiles CHECKSUMS.sha256 )
ls -lh dist/data-bundle.zip
echo
echo "Publish with:"
echo "  gh release create data-v1 dist/data-bundle.zip --title 'Workshop data bundle' --notes 'OSM extracts, OSRM graph, prebuilt evac.pmtiles, planetiler.jar'"
echo "(re-upload: gh release upload data-v1 dist/data-bundle.zip --clobber)"

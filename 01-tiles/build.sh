#!/usr/bin/env bash
# 01-tiles/build.sh — Module 2 (1:20–2:05): the main build.
# Run Planetiler over the extracted region to produce basemap.pmtiles.
#
# Placeholder: pins the Planetiler release and profile before the session.
# A pre-built basemap.pmtiles ships in ../data-bundle/ as the fallback so the
# Java build can never block a participant.

set -euo pipefail

PLANETILER_VERSION="0.8.x"          # TODO: pin exact release
PLANETILER_JAR="planetiler.jar"
OUT="basemap.pmtiles"

# 1) Download the Planetiler JAR if missing (pin the exact release URL before the session).
if [[ ! -f "$PLANETILER_JAR" ]]; then
  echo "TODO: download Planetiler ${PLANETILER_VERSION} JAR to ${PLANETILER_JAR}"
  # curl -L -o "$PLANETILER_JAR" https://github.com/onthegomap/planetiler/releases/download/v<VERSION>/planetiler.jar
fi

# 2) Run Planetiler with the workshop profile over the extracted GeoParquet from Module 1.
echo "TODO: run Planetiler over ../00-data output → ${OUT}"
# java -Xmx4g -jar "$PLANETILER_JAR" \
#   --profile=planetiler-config/evac-profile.yml \
#   --output="$OUT"

echo "Placeholder build.sh — see 01-tiles/README.md. Fallback: ../data-bundle/basemap.pmtiles"
